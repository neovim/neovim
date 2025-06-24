local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua

local function assert_404_error(err)
  assert(
    err:lower():find('404') or err:find('22'),
    'Expected HTTP 404 or exit code 22, got: ' .. tostring(err)
  )
end

describe('vim.net.request', function()
  before_each(function()
    n:clear()
  end)

  it('fetches a URL into memory (async success)', function()
    local content = exec_lua([[
      local done = false
      local result
      local M = require('vim.net')

      M.request("https://httpbingo.org/anything", { retry = 3 }, function(err, body)
        assert(not err, err)
        result = body
        done = true
      end)

      vim.wait(2000, function() return done end)
      return result
    ]])

    assert(
      content and content:find('"url"%s*:%s*"https://httpbingo.org/anything"'),
      'Expected response body to contain the correct URL'
    )
  end)

  it('calls on_response with error on 404 (async failure)', function()
    local err = exec_lua([[
      local done = false
      local result
      local M = require('vim.net')

      M.request("https://httpbingo.org/status/404", {}, function(e, _)
        result = e
        done = true
      end)

      vim.wait(2000, function() return done end)
      return result
    ]])

    assert_404_error(err)
  end)

  it('fetches a URL into memory (sync success)', function()
    local content, err = exec_lua([[
      local M = require('vim.net')
      return M.request("https://httpbingo.org/anything", { retry = 3 })
    ]])

    assert(content, 'Expected synchronous request to succeed, got error: ' .. (err or 'nil'))

    assert(
      content:find('"url"%s*:%s*"https://httpbingo.org/anything"'),
      'Expected response body to contain the correct URL'
    )
  end)

  it('returns error on 404 (sync failure)', function()
    exec_lua([[
      local M = require('vim.net')
      local content, err = M.request("https://httpbingo.org/status/404", {})
      assert(content == nil, 'Expected nil content on failure')
      assert(err:lower():find('404'),
        'Expected HTTP 404 or exit code 22, got: ' .. tostring(err))
    ]])
  end)
end)
