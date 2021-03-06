# webdriver
Nim webdriver for Chrome and Firefox

## Here's an example of calling a Chrome browser, but not all code, just a simple way to use it.
## You can also use similar code to call the Firefox browser.

```nim
import asyncdispatch, terminal, strutils, json
import webdriver/chromedriver

proc login(driver: Driver, login_url, login_username, login_password: string): Future[bool] {.async.} =
  try:
    await driver.setUrl(login_url)
    var elem_username = await driver.getElementBySelector("#txtUserName2")
    await driver.send_keys(elem_username, login_username)
    var elem_password = await driver.getElementBySelector("#txtPassword2")
    await driver.send_keys(elem_password, login_password)
    var elem_loginbtn = await driver.getElementBySelector("#btnLogin2")
    await driver.elementClick(elem_loginbtn)
  except:
    styledEcho(fgRed, "Login failed" & getCurrentExceptionMsg())
    return false
  styledEcho(fgGreen, "Successful login")
  return true
  
proc main() {.async.} =
  let login_url = "http://www.test.com"
  let login_username = "login_username"
  let login_password = "login_password"
  let task_url = "http://www.test.com/task_url"
  let site_url = "http://www.test.com/site_url"
  let site_task_flag = "task"
  if site_task_flag != "task" and site_task_flag != "site":
    styledEcho(fgRed, "Configuration error")
    return

  var driver = newChromeDriver()
  var options = %*{
    "excludeSwitches": ["enable-automation"]
  }
  await driver.startSession(options)
  var ret = await login(driver, login_url, login_username, login_password)
  if ret:
    if site_task_flag=="task":
      await task(driver, task_url)
    elif site_task_flag=="site":
      await site(driver, site_url)

  await driver.close()

waitFor main()
```
