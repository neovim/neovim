local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

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
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
    local content = exec_lua([[
      local done = false
      local result
      local M = require('vim.net')

      M.request("https://httpbingo.org/anything", { retry = 3 }, function(err, body)
        assert(not err, err)
        result = body.body
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

  it("detects filetype, sets 'nomodified'", function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua([[
      vim.cmd('runtime! plugin/nvim/net.lua')
      vim.cmd('runtime! filetype.lua')
      -- github raw dump of a small lua file in the neovim repo
      vim.cmd('edit https://raw.githubusercontent.com/neovim/neovim/master/runtime/syntax/tutor.lua')
      vim.wait(2000, function() return vim.bo.filetype ~= '' end)
      -- wait for buffer to have content
      vim.wait(2000, function() return vim.fn.wordcount().bytes > 0 end)
      vim.wait(2000, function() return vim.bo.modified == false end)
      return { vim.bo.filetype, vim.bo.modified }
    ]])

    t.eq('lua', rv[1])
    t.eq(false, rv[2], 'Expected buffer to be unmodified for remote content')
  end)

  it('calls on_response with error on 404 (async failure)', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
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
end)
