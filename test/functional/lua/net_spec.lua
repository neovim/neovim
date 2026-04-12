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

local function assert_wrong_headers(expected_err, header)
  local err = t.pcall_err(exec_lua, [[
    return vim.net.request('https://example.com', {
      headers = ]] .. header .. [[,
    }, function() end)
  ]])
  t.matches(expected_err, err)
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

      vim.net.request("https://httpbingo.org/anything", { retry = 3 }, function(err, body)
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

      vim.net.request("https://httpbingo.org/status/404", {}, function(e, _)
        result = e
        done = true
      end)

      vim.wait(2000, function() return done end)
      return result
    ]])

    assert_404_error(err)
  end)

  it('plugin writes output to buffer', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
    local content = exec_lua([[
      local lines

      local buf = vim.api.nvim_create_buf(false, true)
      vim.net.request("https://httpbingo.org", { outbuf = buf })

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines[1] ~= ""
      end)

      return lines
    ]])
    assert(content and content[1]:find('html'))
  end)

  it('works with :read', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
    local content = exec_lua([[
      vim.cmd('runtime plugin/net.lua')
      local lines

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Here is some text' })
      vim.cmd(':read https://example.com')

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        return #lines > 1
      end)

      return lines
    ]])
    t.eq(true, content ~= nil)
    t.eq(true, content[1]:find('Here') ~= nil)
    t.eq(true, content[2]:find('html') ~= nil)
  end)

  it('opens remote tar.gz URLs as tar archives', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua([[
      vim.cmd('runtime! plugin/net.lua')
      vim.cmd('runtime! plugin/tarPlugin.vim')

      vim.cmd('edit https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz')

      vim.wait(2500, function()
        return vim.bo.filetype == 'tar' or vim.b.tarfile ~= nil
      end)

      return {
        filetype = vim.bo.filetype,
        modified = vim.bo.modified,
        tarfile = vim.b.tarfile ~= nil,
      }
    ]])

    t.eq('tar', rv.filetype)
    t.eq(false, rv.modified)
    t.eq(true, rv.tarfile)
  end)

  it('opens remote zip URLs as zip archives', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua([[
      vim.cmd('runtime! plugin/net.lua')
      vim.cmd('runtime! plugin/zipPlugin.vim')

      vim.cmd('edit https://github.com/neovim/neovim/releases/download/nightly/nvim-win-arm64.zip')

      vim.wait(2500, function()
        return vim.bo.filetype == 'zip' or vim.b.zipfile ~= nil
      end)

      return {
        filetype = vim.bo.filetype,
        modified = vim.bo.modified,
        zipfile = vim.b.zipfile ~= nil,
      }
    ]])

    t.eq('zip', rv.filetype)
    t.eq(false, rv.modified)
    t.eq(true, rv.zipfile)
  end)

  it('accepts custom headers', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local headers = exec_lua([[
      local done = false
      local result

      vim.net.request("https://httpbingo.org/headers", {
        headers = {
          Authorization = "Bearer test-token",
          ['X-Custom-Header'] = "custom-value",
          ['Empty'] = '',
        },
      }, function(err, res)
        if err then
          result = { error = err }
        else
          result = vim.json.decode(res.body).headers
        end
        done = true
      end)

      vim.wait(2000, function() return done end)
      return result
    ]])

    assert.is_table(headers)
    -- httpbingo.org/request returns each header as a list in the returned value
    t.eq(headers.Authorization[1], 'Bearer test-token', 'Expected Authorization header')
    t.eq(headers['X-Custom-Header'][1], 'custom-value', 'Expected X-Custom-Header')
    t.eq(headers['Empty'][1], '', 'Expected Empty header')
  end)

  it('validation', function()
    assert_wrong_headers('opts.headers: expected table, got number', '123')
    assert_wrong_headers('headers keys and values must be strings', "{ [123] = 'value' }")
    assert_wrong_headers('headers keys and values must be strings', '{ Header = 123 }')
    assert_wrong_headers(
      'header keys must not start with @ or end with : and ;',
      "{ ['Header:'] = 'value' }"
    )
    assert_wrong_headers(
      'header keys must not start with @ or end with : and ;',
      "{ ['Header;'] = 'value' }"
    )
    assert_wrong_headers(
      'header keys must not start with @ or end with : and ;',
      "{ ['@filename'] = '' }"
    )
  end)
end)
