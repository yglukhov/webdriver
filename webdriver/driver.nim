import asyncdispatch
import private/utils
import json

type
  LocationStrategy* = enum
    CssSelector,
    LinkTextSelector,
    PartialLinkTextSelector,
    TagNameSelector,
    XPathSelector

proc toKeyword(strategy: LocationStrategy): string =
  case strategy
  of CssSelector: "css selector"
  of LinkTextSelector: "link text"
  of PartialLinkTextSelector: "partial link text"
  of TagNameSelector: "tag name"
  of XPathSelector: "xpath"

type Driver* = ref object of RootObj

method setUrl*(d: Driver, url: string) {.async, base.} = noimpl()
method getUrl*(d: Driver): Future[string] {.async, base.} = noimpl()
method getSource*(d: Driver): Future[string] {.async, base.} = noimpl()
method getElements*(d: Driver, strategy, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElement*(d: Driver, strategy, value: string): Future[string] {.async, base.} = noimpl()
method getElementsFromElement*(d: Driver, e, strategy, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElementFromElement*(d: Driver, e, strategy, value: string): Future[string] {.async, base.} = noimpl()
method getElementAttribute*(d: Driver, e, a: string): Future[string] {.async, base.} = noimpl()
method getElementText*(d: Driver, e: string): Future[string] {.async, base.} = noimpl()
method elementClick*(d: Driver, e: string) {.async, base.} = noimpl()
method startSession*(d: Driver, options: JsonNode = %*{}, headless = false) {.async, base.} = noimpl()
method deleteSession*(d: Driver) {.async, base.} = noimpl()
method back*(d: Driver) {.async, base.} = noimpl()
method close*(d: Driver) {.async, base.} = await d.deleteSession()
method sendKeys*(d: Driver, e,t: string) {.async, base.} = noimpl()
method clear*(d: Driver, e: string) {.async, base.} = noimpl()
method executeScript*(d: Driver,code: string, args: JsonNode = %*{}): Future[string] {.async, base.} = noimpl()

proc getElementsBySelector*(d: Driver, s: string): Future[seq[string]] = d.getElements(toKeyword(CssSelector), s)
proc getElementsByLinkText*(d: Driver, s: string): Future[seq[string]] = d.getElements(toKeyword(LinkTextSelector), s)
proc getElementsByPartialLinkText*(d: Driver, s: string): Future[seq[string]] = d.getElements(toKeyword(PartialLinkTextSelector), s)
proc getElementsByTagName*(d: Driver, s: string): Future[seq[string]] = d.getElements(toKeyword(TagNameSelector), s)
proc getElementsByXPath*(d: Driver, s: string): Future[seq[string]] = d.getElements(toKeyword(XPathSelector), s)

proc getElementBySelector*(d: Driver, s: string): Future[string] = d.getElement(toKeyword(CssSelector), s)
proc getElementByLinkText*(d: Driver, s: string): Future[string] = d.getElement(toKeyword(LinkTextSelector), s)
proc getElementByPartialLinkText*(d: Driver, s: string): Future[string] = d.getElement(toKeyword(PartialLinkTextSelector), s)
proc getElementByTagName*(d: Driver, s: string): Future[string] = d.getElement(toKeyword(TagNameSelector), s)
proc getElementByXPath*(d: Driver, s: string): Future[string] = d.getElement(toKeyword(XPathSelector), s)

