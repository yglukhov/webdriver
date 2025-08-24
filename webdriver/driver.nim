import asyncdispatch, json, times

import private/utils

type
  By* = enum
    cssSelector = "css selector",
    linkText = "link text",
    partialLinkText = "partial link text",
    tagName = "tag name",
    xPath = "xpath"

type
  Driver* = ref object of RootObj
    downloadDir*: string
    timeout*: int # Default timeout in milliseconds for getElement/getElements operations
    pollRate*: int # Default poll rate (retry every pollRate milliseconds) for getElement/getElements operations

  Element* = ref object of RootObj
    handle*: string
    driver*: Driver

method setUrl*(d: Driver, url: string) {.async, base.} = noimpl()
method getUrl*(d: Driver): Future[string] {.async, base.} = noimpl()
method getSource*(d: Driver): Future[string] {.async, base.} = noimpl()
method getElementHandles*(d: Driver, strategy: By, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElementHandle*(d: Driver, strategy: By, value: string): Future[string] {.async, base.} = noimpl()
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

method getCurrentWindowHandle*(d: Driver): Future[string] {.async, base.} = noimpl()
method getWindowHandles*(d: Driver): Future[seq[string]] {.async, base.} = noimpl()
method switchToWindow*(d: Driver, handle: string) {.async, base.} = noimpl()
method closeCurrentWindow*(d: Driver) {.async, base.} = noimpl()

proc init*(d: Driver) = # Must be called by subclass constructors
  d.timeout = 20000
  d.pollRate = 50

proc elementsWithHandles(d: Driver, handles: openarray[string]): seq[Element] =
  result = newSeq[Element](handles.len)
  for i, h in handles:
    result[i] = Element(driver: d, handle: h)

proc getElements*(d: Driver, by: By, selector: string, timeout = 0, pollRate = 0): Future[seq[Element]] {.async.} =
  let timeout = if timeout == 0: d.timeout else: timeout
  let pollRate = if pollRate == 0: d.pollRate else: pollRate

  let endTime = getTime() + timeout.milliseconds
  while true:
    try:
      let ret = await d.getElementHandles(by, selector)
      if ret.len != 0:
        return elementsWithHandles(d, ret)
    except:
      discard

    await sleepAsync(pollRate)

    if getTime() > endTime:
      break

proc getElement*(d: Driver, by: By, selector: string, timeout = 0, pollRate = 0): Future[Element] {.async.} =
  let timeout = if timeout == 0: d.timeout else: timeout
  let pollRate = if pollRate == 0: d.pollRate else: pollRate

  let endTime = getTime() + timeout.milliseconds
  while true:
    try:
      let h = await d.getElementHandle(by, selector)
      if h != "":
        return Element(driver: d, handle: h)
    except:
      discard

    await sleepAsync(pollRate)

    if getTime() > endTime:
      break

proc getAttribute*(e: Element, a: string): Future[string] = e.driver.getElementAttribute(e.handle, a)
proc getProperty*(e: Element, p: string): Future[string] = e.driver.getElementProperty(e.handle, p)
proc getText*(e: Element): Future[string] = e.driver.getElementText(e.handle)
proc click*(e: Element): Future[void] = e.driver.elementClick(e.handle)
proc sendKeys*(e: Element, t: string): Future[void] = e.driver.sendKeys(e.handle, t)
proc takeScreenshot*(e: Element): Future[string] = e.driver.takeScreenshot(e.handle)

proc getElement*(e: Element, by: By, selector: string, timeout = -1, pollRate = 0): Future[Element] {.async.} =
  let timeout = if timeout == 0: e.driver.timeout else: timeout
  let pollRate = if pollRate == 0: e.driver.pollRate else: pollRate

  let endTime = getTime() + timeout.milliseconds
  while true:
    try:
      let h = await e.driver.getElementFromElement(e.handle, by, selector)
      if h != "":
        return Element(driver: e.driver, handle: h)
    except:
      discard

    await sleepAsync(pollRate)

    if getTime() > endTime:
      break

proc getElements*(e: Element, by: By, selector: string, timeout = -1, pollRate = 0): Future[seq[Element]] {.async.} =
  let timeout = if timeout == 0: e.driver.timeout else: timeout
  let pollRate = if pollRate == 0: e.driver.pollRate else: pollRate

  let endTime = getTime() + timeout.milliseconds
  while true:
    try:
      let ret = await e.driver.getElementsFromElement(e.handle, by, selector)
      if ret.len != 0:
        return elementsWithHandles(e.driver, ret)
    except:
      discard

    await sleepAsync(pollRate)

    if getTime() > endTime:
      break

proc getElementsByCssSelector*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElementHandles(By.cssSelector, s)
proc getElementsByLinkText*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElementHandles(By.linkText, s)
proc getElementsByPartialLinkText*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElementHandles(By.partialLinkText, s)
proc getElementsByTagName*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElementHandles(By.tagName, s)
proc getElementsByXPath*(d: Driver, s: string): Future[seq[string]] {.async.} =
  result = await d.getElementHandles(By.xPath, s)
proc getElementBySelector*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElementHandle(By.cssSelector, s)
proc getElementByLinkText*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElementHandle(By.linkText, s)
proc getElementByPartialLinkText*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElementHandle(By.partialLinkText, s)
proc getElementByTagName*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElementHandle(By.tagName, s)
proc getElementByXPath*(d: Driver, s: string): Future[string] {.async.} =
  result = await d.getElementHandle(By.xPath, s)


proc waitElement*(d: Driver, strategy: By, value: string, timeout = 20000, pollFrequency = 50): Future[string] {.async.} =
  ## When "setUrl ()" or" elementClick ()" is used, 
  ## wait for the page specified element loading to complete and then perform a subsequent action. 
  ## Otherwise, you may not get the element. 
  let endTime = getTime() + timeout.milliseconds
  while true:
    try:
      var ret = await d.getElementHandle(strategy, value)
      if ret != "":
        return ret
    except:
      discard

    await sleepAsync(pollFrequency)

    if getTime() > endTime:
        break

proc waitOneOfElements*(d: Driver, elems: seq[tuple[strategy: By, value: string]], timeout = 20000, pollFrequency = 50): Future[tuple[idx: int, id: string]] {.async.} =
  ## When "setUrl ()" or" elementClick ()" is used,
  ## wait for the page specified element loading to complete and then perform a subsequent action.
  ## Otherwise, you may not get the element.
  let endTime = getTime() + timeout.milliseconds
  for i in 0 ..< elems.len:
    while true:
      try:
        var ret = await d.getElementHandle(elems[i].strategy, elems[i].value)
        if ret != "":
          return (i, ret)
      except:
        discard

      await sleepAsync(pollFrequency)

      if getTime() > endTime:
        return (-1, "")
