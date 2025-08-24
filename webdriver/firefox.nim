import asyncdispatch, strutils, json, osproc, os, times, tables, base64

import asyncnet

import private/utils

import ./driver
export driver

## Marionette client for firefox
## Reference: https://github.com/njasm/marionette_client/blob/master/client.go
## Even better "official" reference: https://github.com/mozilla-firefox/firefox/blob/main/remote/marionette/driver.sys.mjs

type FirefoxDriver* = ref object of Driver
  process: Process
  marionetteProtocol: int
  profileFolder*: string
  persistingProfile*: bool
  reqCounter: int
  sock: AsyncSocket
  marionettePort*: Port
  prefs*: Table[string, JsonNode] # Firefox user_prefs for prefs.js

proc createProfileFolder(d: FirefoxDriver) =
  if not d.persistingProfile:
    removeDir(d.profileFolder)
  if not dirExists(d.profileFolder):
    createDir(d.profileFolder)
    var profile = """
user_pref("marionette.contentListener", true);
user_pref("marionette.port", """ & $d.marionettePort.int & """);
  """
    if d.downloadDir != "":
      doAssert('"' notin d.downloadDir)
      profile &= """user_pref("browser.download.dir", '""" & d.downloadDir & "');\n"
      profile &= "user_pref('browser.download.manager.showWhenStarting', false);\n"
      profile &= "user_pref('browser.download.folderList', 2);\n"

    for k, v in d.prefs:
      profile &= "user_pref('" & k & "', " & $v & ");\n"
    writeFile(d.profileFolder / "prefs.js", profile)

proc startDriverProcess(d: FirefoxDriver, headless = false) =
  let exe = findExe("firefox")
  var args = @["-marionette", "-profile", d.profileFolder]
  if headless:
    args.add("-headless")
  d.process = startProcess(exe, args = args)

proc newFirefoxDriver*(): FirefoxDriver =
  result.new()
  result.init()
  result.marionettePort = allocateRandomPort()

method close*(d: FirefoxDriver) {.async.} =
  await procCall Driver(d).close()
  d.process.terminate()
  if not d.persistingProfile:
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

proc readMessage(d: FirefoxDriver): Future[JsonNode] {.async.} =
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

proc send(d: FirefoxDriver, meth: string, o: JsonNode = nil): Future[JsonNode] {.async.} =
  inc d.reqCounter
  let data = %*[0, d.reqCounter, "WebDriver:" & meth, o]
  var b: string
  toUgly(b, data)
  await d.sock.send($(b.len) & ":" & b)
  let r = await d.readMessage()
  checkErr(r)
  return r[3]

method setUrl*(d: FirefoxDriver, url: string) {.async.} =
  discard await send(d, "Navigate", %*{"url": url})

method getUrl*(d: FirefoxDriver): Future[string] {.async.} =
  let r = await send(d, "GetCurrentURL", %*{})
  return r["value"].getStr()

method getSource*(d: FirefoxDriver): Future[string] {.async.} =
  let r = await send(d, "GetPageSource", %*{})
  return r["value"].getStr()

method getElementHandles*(d: FirefoxDriver, strategy: By, value: string): Future[seq[string]] {.async.} =
  let r = await send(d, "FindElements", %*{"using": $strategy, "value": value})
  var res: seq[string]
  for e in r:
    for k, v in e:
      res.add(v.getStr())
  return res

method getElementHandle*(d: FirefoxDriver, strategy: By, value: string): Future[string] {.async.} =
  let r = await send(d, "FindElement", %*{"using": $strategy, "value": value})
  var res: string
  for k, v in r["value"]:
    res.add(v.getStr())
  return res

method getElementsFromElement*(d: FirefoxDriver, e: string, strategy: By, value: string): Future[seq[string]] {.async.} =
  let r = await send(d, "FindElements", %*{"element": e, "using": $strategy, "value": value})
  var res: seq[string]
  for e in r:
    for k, v in e:
      res.add(v.getStr())
  return res

method getElementFromElement*(d: FirefoxDriver, e: string, strategy: By, value: string): Future[string] {.async.} =
  let r = await send(d, "FindElement", %*{"element": e, "using": $strategy, "value": value})
  var res: string
  for k, v in r["value"]:
    res.add(v.getStr())
  return res

method getElementAttribute*(d: FirefoxDriver, e, a: string): Future[string] {.async.} =
  let r = await send(d, "GetElementAttribute", %*{"id": e, "name": a})
  return r["value"].getStr()

method getElementProperty*(d: FirefoxDriver, e, a: string): Future[string] {.async.} =
  let r = await send(d, "GetElementProperty", %*{"id": e, "name": a})
  return r["value"].getStr()

method getElementText*(d: FirefoxDriver, e: string): Future[string] {.async.} =
  let r = await send(d, "GetElementText", %*{"id": e})
  return r["value"].getStr()

method elementClick*(d: FirefoxDriver, e: string) {.async.} =
  discard await send(d, "ElementClick", %*{"id": e})

proc startSessionWithExistingProcess*(d: FirefoxDriver, options = %*{}) {.async.} =
  d.sock = newAsyncSocket()
  var args = %*{
    "acceptInsecureCerts": true
  }

  if options != %*{}:
    args["moz:firefoxOptions"] = options

  var endTime = getTime() + 20000.milliseconds
  while true:
    try:
      await d.sock.connect("localhost", d.marionettePort)
      break
    except:
      if getTime() > endTime:
        raise newException(Exception, "Firefox webdriver connection timeout")

    await sleepAsync(200)

  let hi = await d.readMessage()
  d.marionetteProtocol = hi["marionetteProtocol"].getInt()

  discard await send(d, "NewSession", args)

method startSession*(d: FirefoxDriver, options = %*{}, headless = false) {.async.} =
  if d.profileFolder == "":
    d.profileFolder = getTempDir() / "ffprofilenim" & $d.marionettePort.int

  d.createProfileFolder()
  d.startDriverProcess(headless)
  await d.startSessionWithExistingProcess(options)

method deleteSession*(d: FirefoxDriver) {.async.} =
  discard await send(d, "DeleteSession", %*{})

method back*(d: FirefoxDriver) {.async.} =
  discard await send(d, "Back", %*{})

method sendKeys*(d: FirefoxDriver, e,t: string) {.async.} =
  discard await send(d, "ElementSendKeys", %*{"id": e,"text": t})

method clear*(d: FirefoxDriver, e: string) {.async.} =
  discard await send(d, "ElementClear", %*{"id": e})

method executeScript*(d: FirefoxDriver, code: string, args = %*[]): Future[string] {.async.} =
  var json = %*{
    "script": code,
    "args": []
  }
  for i in args:
    json["args"].elems.add i

  let r = await send(d, "ExecuteScript", json)
  return $r["value"]

method getCurrentWindowHandle*(d: FirefoxDriver): Future[string] {.async.} =
  let r = await send(d, "GetWindowHandle", %*{})
  return r["value"].getStr()

method getWindowHandles*(d: FirefoxDriver): Future[seq[string]] {.async.} =
  let r = await send(d, "GetWindowHandles", %*{})
  for j in r:
    result.add(j.getStr())

method switchToWindow*(d: FirefoxDriver, handle: string) {.async.} =
  discard await send(d, "SwitchToWindow", %*{"handle": handle})

method closeCurrentWindow*(d: FirefoxDriver) {.async.} =
  discard await send(d, "CloseWindow", %*{})

# method getWindowHandle*(d: FirefoxDriver): Future[string] {.async.} =
#   let r = await send(d, "GetWindowHandle", %*{})
#   return r["value"].getStr()

# method setWindowRect*(d: FirefoxDriver, r: tuple[x, y, w, h: int]) {.async.} =
#   discard await send(d, "SetWindowRect", %*{"x": r.x, "y": r.y, "width": r.w, "height": r.h})

method takeScreenshot*(d: FirefoxDriver, elem: string): Future[string] {.async.} =
  let r = await send(d, "TakeScreenshot", %*{"id": elem})
  return base64.decode(r["value"].getStr())
