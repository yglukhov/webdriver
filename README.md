# webdriver
Nim webdriver for Chrome and Firefox

## Usage

```nim
import asyncdispatch
import webdriver/[chromedriver, firefox]

proc test() {.async.} =
  let d = newFirefoxDriver()
  await d.startSession()
  await d.setUrl("https://nim-lang.org")
  let h1 = await d.getElementByTagName("h1")
  let text = await d.getElementText(h1)
  await d.close()
  echo text

waitFor test()
```
