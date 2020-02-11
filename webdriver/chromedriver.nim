import asyncdispatch, osproc, os

import ./driver, ./webdriver_base
export driver

type ChromeDriver* = ref object of WebDriver
  process: Process

method startDriverProcess(d: ChromeDriver) =
  let exe = findExe("chromedriver")
  d.process = startProcess(exe, args = ["--port=" & $d.port.int])
  sleep(1000)

proc newChromeDriver*(): ChromeDriver =
  result.new()
  result.init()

method close*(d: ChromeDriver) {.async.} =
  await procCall WebDriver(d).close()
  d.process.terminate()
