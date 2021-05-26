import asyncdispatch, httpclient, strutils, json
import private/utils
import ./driver
export driver

## Base class for the clients following WebDriver spec:
## https://www.w3.org/TR/webdriver1

type WebDriver* = ref object of Driver
  sessid: string
  port*: Port

method startDriverProcess(d: WebDriver) {.base.} = noimpl()

proc init*(d: WebDriver) =
  d.port = allocateRandomPort()
  d.startDriverProcess()

proc checkErr(j: JsonNode) =
  if j.kind == JObject:
    let e = j{"error"}
    let m = j{"message"}
    if not e.isNil and e.kind == JString:
      if not m.isNil and m.kind == JString:
        raise newException(Exception, m.getStr())
      raise newException(Exception, e.getStr())

proc request(d: WebDriver, meth: HttpMethod, path: string, o: JsonNode = nil): Future[JsonNode] {.async.} =
  let client = newAsyncHttpClient()
  var b: string
  if not o.isNil:
    toUgly(b, o)

  var url = "http://localhost:"
  url &= $d.port.int

  if d.sessid.len != 0:
    url &= "/session/"
    url &= d.sessid

  if path.len != 0:
    url &= "/"
    url &= path
  let r = await client.request(url, httpMethod = meth, body = b)
  let rb = await r.body
  let res = parseJson(rb)["value"]
  # echo "res: ", res
  checkErr(res)
  client.close()
  return res

proc post(d: WebDriver, path: string, o: JsonNode): Future[JsonNode] =
  request(d, HttpPost, path, o)

proc get(d: WebDriver, path: string): Future[JsonNode] =
  request(d, HttpGet, path)

method setUrl*(d: WebDriver, url: string) {.async.} =
  discard await post(d, "url", %*{"url": url})

method getUrl*(d: WebDriver): Future[string] {.async.} =
  let r = await get(d, "url")
  return r.getStr()

method getSource*(d: WebDriver): Future[string] {.async.} =
  let r = await get(d, "source")
  return r.getStr()

method getElements*(d: WebDriver, strategy: By, value: string): Future[seq[string]] {.async.} =
  let r = await post(d, "elements", %*{"using": $strategy, "value": value})
  var res: seq[string]
  for e in r:
    for k, v in e:
      res.add(v.getStr())
  return res

method getElement*(d: WebDriver, strategy: By, value: string): Future[string] {.async.} =
  let r = await post(d, "element", %*{"using": $strategy, "value": value})
  var res: string
  for k, v in r:
    res.add(v.getStr())
  return res

method getElementsFromElement*(d: WebDriver, e: string, strategy: By, value: string): Future[seq[string]] {.async.} =
  let r = await post(d, "element/" & e & "/elements", %*{"using": $strategy, "value": value})
  var res: seq[string]
  for e in r:
    for k, v in e:
      res.add(v.getStr())
  return res

method getElementFromElement*(d: WebDriver, e: string, strategy: By, value: string): Future[string] {.async.} =
  let r = await post(d, "element/" & e & "/element", %*{"using": $strategy, "value": value})
  var res: string
  for k, v in r:
    res.add(v.getStr())
  return res

method getElementProperty*(d: WebDriver, e, a: string): Future[string] {.async.} =
  let r = await get(d, "element/" & e & "/property/" & a)
  return r.getStr()

method getElementAttribute*(d: WebDriver, e, a: string): Future[string] {.async.} =
  let r = await get(d, "element/" & e & "/attribute/" & a)
  return r.getStr()

method getElementText*(d: WebDriver, e: string): Future[string] {.async.} =
  let r = await get(d, "element/" & e & "/text")
  return r.getStr()

method elementClick*(d: WebDriver, e: string) {.async.} =
  discard await post(d, "element/" & e & "/click", %*{})

method adjustSessionArguments*(d: WebDriver, args: JsonNode, options = %*{}, headless: bool) {.base.} = discard

method startSession*(d: WebDriver, options = %*{}, headless = false) {.async.} =
  var args = %*{
    "capabilities": {
      "alwaysMatch": {
        "acceptInsecureCerts": true
      }
    }
  }

  d.adjustSessionArguments(args, options, headless)

  let r = await post(d, "session", args)
  d.sessid = r["sessionId"].getStr()

method deleteSession*(d: WebDriver) {.async.} =
  discard await request(d, HttpDelete, "", %*{})

method back*(d: WebDriver) {.async.} =
  discard await post(d, "back", %*{})

method sendKeys*(d: WebDriver, e,t: string) {.async.} =
  discard await post(d, "element/" & e & "/value", %*{"text": t})

method clear*(d: WebDriver, e: string) {.async.} =
  discard await post(d, "element/" & e & "/clear", %*{})

method executeScript*(d: WebDriver, code: string, args = %*[]): Future[string] {.async.} =
  var json = %*{
    "script": code,
    "args": []
  }
  for i in args:
    json["args"].elems.add i

  let r = await post(d, "execute/sync", json)
  return $r
