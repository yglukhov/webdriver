import asyncdispatch, osproc, os, json

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

method adjustSessionArguments*(d: ChromeDriver, args: JsonNode, headless: bool) =
  if headless:
    args["capabilities"]["alwaysMatch"]["goog:chromeOptions"] = %*{
      "args": [
        "-headless"
      ]
    }
