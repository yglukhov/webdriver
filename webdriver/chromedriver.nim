import asyncdispatch, osproc, os, json

import ./driver, ./webdriver_base
export driver

type ChromeDriver* = ref object of WebDriver
  process: Process
  notInitialized: bool

method startDriverProcess(d: ChromeDriver) =
  var exe = findExe("chromedriver")
  # echo "exe: ", exe.len
  # if exe.len == 0:
  #   exe = findExe("chromium.chromedriver")
  #   echo "exe2: ", exe.len

  d.process = startProcess(exe, args = ["--port=" & $d.port.int])
  sleep(1000)

proc newChromeDriver*(): ChromeDriver =
  result.new()
  try:
    result.init()
  except:
    result.notInitialized = true
    discard

method close*(d: ChromeDriver) {.async.} =
  await procCall WebDriver(d).close()
  d.process.terminate()

method adjustSessionArguments*(d: ChromeDriver, args: JsonNode, options = %*{}, headless: bool) =
  if headless:
    args["capabilities"]["alwaysMatch"]["goog:chromeOptions"] = %*{
      "args": [
        "-headless"
      ]
    }

  if options != %*{}:
    args["capabilities"]["alwaysMatch"]["goog:chromeOptions"] = options
