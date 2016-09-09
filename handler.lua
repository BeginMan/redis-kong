local BasePlugin = require "kong.plugins.base_plugin"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"

local RedHandler = BasePlugin:extend()
local set_header = ngx.req.set_header
local get_headers = ngx.req.get_headers


function RedHandler:new()
  RedHandler.super.new(self, "ax")
end

function RedHandler:access(conf)
  RedHandler.super.access(self)

  local key
  local headers = get_headers()
  local name = "apikey"

  local redis = require "resty.redis"
  local red = redis:new()

  red:set_timeout(1000) -- 1 sec

  local ok, err = red:connect("127.0.0.1", 6379)
  if not ok then
    ngx.say("failed to connect: ", err)
    return
  end

  -- get apikey from token from header
  local v = headers[name]
  if type(v) == "string" then
    key = v
  end

  -- this request is missing an API key, HTTP 401
  if not key then
    return responses.send_HTTP_UNAUTHORIZED("Not authorized")
  end

  -- fetch data on cache
  local res, err = red:get(":1:"..key)
  if type(res) == "userdata" then
    return responses.send_HTTP_FORBIDDEN("Invalid authentication credentials")
  end

  set_header('X-User', res)
  ngx.ctx.authenticated_credential = res
end

return RedHandler