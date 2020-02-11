import asyncdispatch, osproc, os

import ./driver, ./webdriver_base
export driver

type GeckoDriver* = ref object of WebDriver
  process: Process

method startDriverProcess(d: GeckoDriver) =
  let exe = findExe("geckodriver")
  d.process = startProcess(exe, args = ["--port", $d.port.int])
  sleep(1000)

proc newGeckoDriver*(): GeckoDriver =
  result.new()
  result.init()

method close*(d: GeckoDriver) {.async.} =
  await procCall WebDriver(d).close()
  d.process.terminate()
