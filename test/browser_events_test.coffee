{ assert, brains, Browser } = require("./helpers")
HTML = require("jsdom").dom.level3.html


# Events sent to Browser.events
describe "Browser.events", ->
  events =
    created: []
    console: []
    log:     []
  browsers = null


  describe "creating new instance", ->
    before ->
      Browser.events.on "created", (browser)->
        events.created.push(browser)
      browsers = [new Browser(), new Browser()]

    it "should receive created events", ->
      assert.deepEqual events.created, browsers


  describe "sending output to console", ->
    before ->
      Browser.events.on "console", (level, message)->
        events.console.push([level, message])
      browsers[0].console.log("Logging", "message")
      browsers[1].console.error("Some", new Error("error"))

    it "should receive console events", ->
      assert.deepEqual events.console[0], ["log", "Logging message"]
      assert.deepEqual events.console[1], ["error", "Some [Error: error]"]


  describe "logging a message", ->
    before ->
      Browser.events.on "log", (message)->
        events.log.push(message)
      browsers[0].log("Zombie", "log")
      browsers[1].log("Zombie", new Error("error"))

    it "should receive log events", ->
      assert.equal events.log[0], "Zombie log"
      assert.equal events.log[1], "Zombie [Error: error]"


  after ->
    for browser in browsers
      browser.destroy()


# Events sent to browser instance
describe "Browser instance", ->
  events =
    console:  []
    log:      []
    resource: []
  browser = new Browser()

  before (done)->
    brains.ready done


  describe "sending output to console", ->
    before ->
      browser.on "console", (level, message)->
        events.console.push([level, message])
      browser.console.log("Logging", "message")
      browser.console.error("Some", new Error("error"))

    it "should receive console events", ->
      assert.deepEqual events.console[0], ["log", "Logging message"]
      assert.deepEqual events.console[1], ["error", "Some [Error: error]"]


  describe "logging a message", ->
      # Zombie log
      browser.on "log", (message)->
        events.log.push(message)
      browser.log("Zombie", "log")
      browser.log("Zombie", new Error("error"))

    it "should receive log events", ->
      assert.equal events.log[0], "Zombie log"
      assert.equal events.log[1], "Zombie [Error: error]"


  describe "requesting a resource", ->
    before (done)->
      brains.get "/browser-events/resource", (req, res)->
        res.redirect "/browser-events/redirected"
      brains.get "/browser-events/redirected", (req, res)->
        res.send "Very well then"

      browser.on "request", (request, target)->
        events.resource.push([request, target])
      browser.on "redirect", (request, response)->
        events.resource.push([request, response])
      browser.on "response", (request, response, target)->
        events.resource.push([request, response, target])

      browser.visit "/browser-events/resource", done

    it "should receive resource requests", ->
      [request, target] = events.resource[0]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"
      assert target instanceof HTML.HTMLDocument

    it "should receive resource redirects", ->
      [request, response] = events.resource[1]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"
      assert.equal response.statusCode, 302
      assert.equal response.url, "http://localhost:3003/browser-events/redirected"

    it "should receive resource responses", ->
      [request, response, target] = events.resource[2]
      assert.equal request.url, "http://localhost:3003/browser-events/resource"
      assert.equal response.statusCode, 200
      assert.equal response.redirects, 1
      assert target instanceof HTML.HTMLDocument


  describe "opening a window", ->
    before ->
      browser.on "opened", (window)->
        events.open = window
      browser.on "active", (window)->
        events.active = window
      browser.open name: "open-test"

    it "should receive opened event", ->
      assert.equal events.open.name, "open-test"

    it "should receive active event", ->
      assert.equal events.active.name, "open-test"


  describe "closing a window", ->
    before ->
      browser.on "closed", (window)->
        events.close = window
      browser.on "inactive", (window)->
        events.inactive = window
      window = browser.open(name: "close-test")
      window.close()

    it "should receive closed event", ->
      assert.equal events.close.name, "close-test"

    it "should receive inactive event", ->
      assert.equal events.active.name, "open-test"


  describe "loading a document", ->
    before (done)->
      brains.get "/browser-events/document", (req, res)->
        res.send "Very well then"

      browser.on "loading", (document)->
        events.loading = [document.URL, document.readyState, document.outerHTML]
      browser.on "loaded", (document)->
        events.loaded = [document.URL, document.readyState, document.outerHTML]

      browser.visit "/browser-events/document", done

    it "should receive loading event", ->
      [url, readyState, html] = events.loading
      assert.equal url, "http://localhost:3003/browser-events/document"
      assert.equal readyState, "loading"
      assert.equal html, ""

    it "should receive loaded event", ->
      [url, readyState, html] = events.loaded
      assert.equal url, "http://localhost:3003/browser-events/document"
      assert.equal readyState, "complete"
      assert.equal html, "<html><head></head><body>Very well then</body></html>"


  describe "firing an event", ->
    before (done)->
      brains.get "/browser-events/document", (req, res)->
        res.send "Very well then"

      browser.on "event", (event, target)->
        if event.type == "click"
          events.click = [event, target]

      browser.visit "/browser-events/document", ->
        browser.fire("body", "click", done)

    it "should receive DOM event", ->
      event = events.click[0]
      assert.equal event.type, "click"

    it "should receive DOM event target", ->
      target = events.click[1]
      assert.equal target, browser.document.body


  describe "changing focus", ->
    before (done)->
      brains.get "/browser-events/focus", (req, res)->
        res.send """
        <input id="input">
        <script>document.getElementById("input").focus()</script>
        """

      browser.on "focus", (element)->
        events.focus = element

      browser.visit "/browser-events/focus", done

    it "should receive focus event", ->
      element = events.focus
      assert.equal element.id, "input"


  after ->
    browser.destroy()
