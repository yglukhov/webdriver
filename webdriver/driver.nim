import asyncdispatch, json, times

import private/utils

type
  By* = enum
    cssSelector = "css selector",
    linkText = "link text",
    partialLinkText = "partial link text",
    tagName = "tag name",
    xPath = "xpath"

type Driver* = ref object of RootObj
  downloadDir*: string

method setUrl*(d: Driver, url: string) {.async, base.} = noimpl()
method getUrl*(d: Driver): Future[string] {.async, base.} = noimpl()
method getSource*(d: Driver): Future[string] {.async, base.} = noimpl()
method getElements*(d: Driver, strategy: By, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElement*(d: Driver, strategy: By, value: string): Future[string] {.async, base.} = noimpl()
method getElementsFromElement*(d: Driver, e: string, strategy: By, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElementFromElement*(d: Driver, e: string, strategy: By, value: string): Future[string] {.async, base.} = noimpl()
method getElementAttribute*(d: Driver, e, a: string): Future[string] {.async, base.} = noimpl()
method getElementProperty*(d: Driver, e, a: string): Future[string] {.async, base.} = noimpl()
method getElementText*(d: Driver, e: string): Future[string] {.async, base.} = noimpl()
method elementClick*(d: Driver, e: string) {.async, base.} = noimpl()
method startSession*(d: Driver, options = %*{}, headless = false) {.async, base.} = noimpl()
method deleteSession*(d: Driver) {.async, base.} = noimpl()
method back*(d: Driver) {.async, base.} = noimpl()
method close*(d: Driver) {.async, base.} = await d.deleteSession()
method sendKeys*(d: Driver, e,t: string) {.async, base.} = noimpl()
method clear*(d: Driver, e: string) {.async, base.} = noimpl()
method executeScript*(d: Driver,code: string, args = %*[]): Future[string] {.async, base.} = noimpl()
method takeScreenshot*(d: Driver, elem: string): Future[string] {.async, base.} = noimpl()

proc getElementsByCssSelector*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElements(By.cssSelector, s)
proc getElementsByLinkText*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElements(By.linkText, s)
proc getElementsByPartialLinkText*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElements(By.partialLinkText, s)
proc getElementsByTagName*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElements(By.tagName, s)
proc getElementsByXPath*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElements(By.xPath, s)
proc getElementBySelector*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElement(By.cssSelector, s)
proc getElementByLinkText*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElement(By.linkText, s)
proc getElementByPartialLinkText*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElement(By.partialLinkText, s)
proc getElementByTagName*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElement(By.tagName, s)
proc getElementByXPath*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElement(By.xPath, s)


proc waitElement*(d: Driver, strategy: By, value: string, timeout = 20000, pollFrequency = 50): Future[string] {.async.} =
  ## When "setUrl ()" or" elementClick ()" is used, 
  ## wait for the page specified element loading to complete and then perform a subsequent action. 
  ## Otherwise, you may not get the element. 
  var curTime = getTime()
  var endTime = curTime + timeout.milliseconds
  while true:
    try:
      var ret = await d.getElement(strategy, value)
      if ret != "":
        return ret
    except:
      discard

    await sleepAsync(pollFrequency)

    if getTime() > endTime:
        break
