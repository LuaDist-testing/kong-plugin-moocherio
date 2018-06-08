local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("Plugin: moocherio (access)", function()
  local client
  local admin_client
  local dev_env = {
    custom_plugins = 'moocherio'
  }

  local plugin
  local api_id

  setup(function()
      assert(helpers.start_kong(dev_env))

      local api1 = assert(helpers.dao.apis:insert {request_host = "test1.com", upstream_url = "http://mockbin.com"})

      api_id = api1.id

      plugin = assert(helpers.dao.plugins:insert {
        api_id = api1.id,
        name = "moocherio",
        config = {
          say_hello = true
        }
      })
    end)

    teardown(function()
      helpers.stop_kong(nil)
    end)

    before_each(function()
      client = helpers.proxy_client()
      admin_client = helpers.admin_client()
    end)
    after_each(function()
      if client then client:close() end
      if admin_client then admin_client:close() end
    end)

    describe("Settings", function()
      it("registered the plugin globally", function()
        local res = assert(admin_client:send {
          method = "GET",
          path = "/plugins/enabled",
        })
        local body = assert.res_status(200, res)
        local json = cjson.decode(body)
        assert.is_table(json.enabled_plugins)
        assert.is_not.falsy(json.enabled_plugins['moocherio'])
      end)

      it("registered the plugin for the api", function()
        local res = assert(admin_client:send {
          method = "GET",
          path = "/plugins/" ..plugin.id,
        })
        local body = assert.res_status(200, res)
        local json = cjson.decode(body)
        assert.is_equal(api_id, json.api_id)
      end)
    end)

    describe("Response", function()
      it("added the header", function()
        local res = assert(client:send {
          method = "GET",
          path = "/request",
          headers = {
            ["Host"] = "test1.com"
          }
        })

        assert.res_status(200, res)
        assert.response(res).has.header("moocherio")
        local header_value = res.headers["moocherio"]
        assert.is_equal("Hello World!!!", header_value)
      end)
    end)

end)
