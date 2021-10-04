import asyncdispatch, osproc, os, json, tables

import ./driver, ./webdriver_base
export driver

type ChromeDriver* = ref object of WebDriver
  process: Process
  prefs*: Table[string, JsonNode] # Chrome prefs

method startDriverProcess(d: ChromeDriver) =
  var exe = findExe("chromedriver")
  if exe.len == 0:
    exe = findExe("chromium.chromedriver")
  d.process = startProcess(exe, args = ["--port=" & $d.port.int])
  sleep(1000)

proc newChromeDriver*(): ChromeDriver =
  result.new()
  result.init()

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

  for k, v in d.prefs:
    args{"capabilities", "alwaysMatch", "goog:chromeOptions", "prefs", k} = v

  if d.downloadDir != "":
    args{"capabilities", "alwaysMatch", "goog:chromeOptions", "prefs", "download.default_directory"} = %d.downloadDir

  echo "adjustedArgs: ", args
