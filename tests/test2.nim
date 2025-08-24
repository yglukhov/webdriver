import std/asyncdispatch
import webdriver/[geckodriver, firefox, chromedriver]

proc test() {.async.} =
  let d = newFirefoxDriver()
  await d.startSession()
  await d.setUrl("https://nim-lang.org")
  let text = d.getElement(tagName, "h1").await.getText().await
  await d.close()
  echo text

waitFor test()
