import asyncdispatch
import private/utils

type Driver* = ref object of RootObj

method setUrl*(d: Driver, url: string) {.async, base.} = noimpl()
method getUrl*(d: Driver): Future[string] {.async, base.} = noimpl()
method getSource*(d: Driver): Future[string] {.async, base.} = noimpl()
method getElements*(d: Driver, strategy, value: string): Future[seq[string]] {.async, base.} = noimpl()
method getElementAttribute*(d: Driver, e, a: string): Future[string] {.async, base.} = noimpl()
method getElementText*(d: Driver, e: string): Future[string] {.async, base.} = noimpl()
method elementClick*(d: Driver, e: string) {.async, base.} = noimpl()
method startSession*(d: Driver, headless = false) {.async, base.} = noimpl()
method deleteSession*(d: Driver) {.async, base.} = noimpl()
method back*(d: Driver) {.async, base.} = noimpl()
method close*(d: Driver) {.async, base.} = await d.deleteSession()

proc getElementsBySelector*(d: Driver, s: string): Future[seq[string]] = d.getElements("css selector", s)
proc getElementsByTagName*(d: Driver, s: string): Future[seq[string]] = d.getElements("tag name", s)
