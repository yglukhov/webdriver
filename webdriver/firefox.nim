import asyncdispatch, strutils, json, osproc, os

import asyncnet

import private/utils

import ./driver
export driver

## Marionette client for firefox
## Reference: https://github.com/njasm/marionette_client/blob/master/client.go

type FirefoDriver* = ref object of Driver
  process: Process
  marionetteProtocol: int
  profileFolder: string
  reqCounter: int
  sock: AsyncSocket
  marionettePort: Port

proc createProfileFolder(d: FirefoDriver) =
  d.profileFolder = getTempDir() / "ffprofilenim" & $d.marionettePort.int
  removeDir(d.profileFolder)
  createDir(d.profileFolder)
  writeFile(d.profileFolder / "prefs.js", """
user_pref("marionette.contentListener", true);
user_pref("marionette.port", """ & $d.marionettePort.int & """);
""")

proc startDriverProcess(d: FirefoDriver, headless = false) =
  let exe = findExe("firefox")
  var args = @["-marionette", "-profile", d.profileFolder]
  if headless:
    args.add("-headless")
  d.process = startProcess(exe, args = args)

proc newFirefoxDriver*(): FirefoDriver =
  result.new()
  result.marionettePort = allocateRandomPort()

method close*(d: FirefoDriver) {.async.} =
  await procCall Driver(d).close()
  d.process.terminate()
  removeDir(d.profileFolder)

proc checkErr(j: JsonNode) =
  if j.kind == JArray and j.len == 4:
    let typ = j.elems[0]
    if typ.kind == JInt and typ.getInt == 1:
      let e = j.elems[2]
      if e.kind != JNull:
        var m = e{"error"}.getStr() & ": " & e{"message"}.getStr()
        raise newException(Exception, m)
    else:
      raise newException(Exception, "Unexpected response type: " & $typ)
  else:
    raise newException(Exception, "Unexpected response: " & $j)

proc readMessage(d: FirefoDriver): Future[JsonNode] {.async.} =
  var strLen = ""
  while strLen.len < 100:
    var d = await d.sock.recv(1)
    if d == ":": break
    strLen &= d

  var sz = parseInt(strLen)
  var s = await d.sock.recv(sz)
  let j = parseJson(s)
  # echo "read message: ", j
  return j

proc send(d: FirefoDriver, meth: string, o: JsonNode = nil): Future[JsonNode] {.async.} =
  inc d.reqCounter
  let data = %*[0, d.reqCounter, "WebDriver:" & meth, o]
  var b: string
  toUgly(b, data)
  await d.sock.send($(b.len) & ":" & b)
  let r = await d.readMessage()
  checkErr(r)
  return r[3]

method setUrl*(d: FirefoDriver, url: string) {.async.} =
  discard await send(d, "Navigate", %*{"url": url})

method getUrl*(d: FirefoDriver): Future[string] {.async.} =
  let r = await send(d, "GetCurrentURL", %*{})
  return r["value"].getStr()

method getSource*(d: FirefoDriver): Future[string] {.async.} =
  let r = await send(d, "GetPageSource", %*{})
  return r["value"].getStr()

method getElements*(d: FirefoDriver, strategy, value: string): Future[seq[string]] {.async.} =
  let r = await send(d, "FindElements", %*{"using": strategy, "value": value})
  var res: seq[string]
  for e in r:
    for k, v in e:
      res.add(v.getStr())
  return res

method getElementAttribute*(d: FirefoDriver, e, a: string): Future[string] {.async.} =
  let r = await send(d, "GetElementAttribute", %*{"id": e, "name": a})
  return r["value"].getStr()

method getElementText*(d: FirefoDriver, e: string): Future[string] {.async.} =
  let r = await send(d, "GetElementText", %*{"id": e})
  return r["value"].getStr()

method elementClick*(d: FirefoDriver, e: string) {.async.} =
  discard await send(d, "ElementClick", %*{"id": e})

method startSession*(d: FirefoDriver, headless = false) {.async.} =
  d.createProfileFolder()
  d.startDriverProcess(headless)
  d.sock = newAsyncSocket()

  var args = %*{
    "acceptInsecureCerts": true,
  }

  for i in 0 .. 30:
    try:
      await d.sock.connect("localhost", d.marionettePort)
      break
    except:
      if i == 10:
        raise
    await sleepAsync(200)

  let hi = await d.readMessage()
  d.marionetteProtocol = hi["marionetteProtocol"].getInt()

  discard await send(d, "NewSession", args)

method deleteSession*(d: FirefoDriver) {.async.} =
  discard await send(d, "DeleteSession", %*{})

method back*(d: FirefoDriver) {.async.} =
  discard await send(d, "Back", %*{})
