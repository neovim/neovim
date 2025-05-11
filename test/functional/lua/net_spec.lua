local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local read_file = t.read_file

local path = './downloaded.txt'

local function assert_404_error(err)
  assert(
    err:lower():find('404') or err:find('22'),
    'Expected HTTP 404 or exit code 22, got: ' .. tostring(err)
  )
end

describe('vim.net.download', function()
  before_each(function()
    n:clear()
    os.remove(path)
  end)

  it('downloads a file from a URL (async success)', function()
    exec_lua(
      [[
      local done = false
      local M = require('vim.net')

      M.download("https://httpbingo.org/anything", ..., {
        retry = 3,
      }, function(err)
          assert(not err, err)
          done = true
        end)

      vim.wait(2000, function() return done end)
      ]],
      path
    )

    local content = read_file(path)
    assert(
      content and content:find('"url"%s*:%s*"https://httpbingo.org/anything"'),
      'Expected downloaded file to contain the correct URL'
    )
  end)

  it('calls on_exit with error on 404 (async failure)', function()
    local err = exec_lua([[
      local done = false
      local result
      local M = require('vim.net')

      M.download("https://httpbingo.org/status/404", "ignored.txt", {
      }, function(e)
          result = e
          done = true
        end)

      vim.wait(2000, function() return done end)
      return result
      ]])
    assert_404_error(err)
  end)

  it('downloads a file from a URL (sync success)', function()
    local success, err = exec_lua(
      [[
      local M = require('vim.net')
      return M.download(...)
      ]],
      'https://httpbingo.org/anything',
      path,
      {},
      nil
    )

    assert(success, 'Expected synchronous download to succeed, got error: ' .. (err or 'nil'))

    local content = read_file(path)
    assert(
      content and content:find('"url"%s*:%s*"https://httpbingo.org/anything"'),
      'Expected downloaded file to contain the correct URL'
    )
  end)

  it('returns error on 404 (sync failure)', function()
    exec_lua(
      [[
      local M = require('vim.net')
      local success, err =  M.download(...)
      assert(success == false, 'Expected synchronous download to fail')
      assert(err:lower():find('404'),
        'Expected HTTP 404 or exit code 22, got: ' .. tostring(err))
      ]],
      'https://httpbingo.org/status/404',
      'ignored.txt'
    )
  end)
end)
