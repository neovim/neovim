local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

local exec_lua = n.exec_lua

---@param method vim.net.HttpMethod
---@param opts? vim.net.request.Opts
---@return table
--- Helper method to make a HTTP request with a 2s timeout
local function request(method, url, opts)
  opts = opts or {}
  opts.retry = 3
  local result = exec_lua(function()
    local done = false
    local result

    vim.net.request(method, url, opts, function(err, res)
      if err then
        result = { error = err }
      else
        ---@type string|table
        local resp

        local ok, parsed = pcall(vim.json.decode, res.body)
        if ok then
          resp = parsed
        else
          resp = res.body
        end
        result = { error = nil, response = resp }
      end
      done = true
    end)

    vim.wait(2000, function()
      return done
    end)
    return result
  end)

  return result
end

describe('vim.net.request', function()
  before_each(function()
    n:clear()
  end)

  it('fetches a URL into memory (async success)', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    ---@type table
    local result = request('GET', 'https://httpbingo.org/anything')

    t.eq(nil, result.error, ('request failed: %s'):format(result.error))
    t.eq('https://httpbingo.org/anything', result.response.url)
  end)

  it("detects filetype, sets 'nomodified'", function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua(function()
      vim.cmd('runtime! plugin/nvim/net.lua')
      vim.cmd('runtime! filetype.lua')
      -- github raw dump of a small lua file in the neovim repo
      vim.cmd(
        'edit https://raw.githubusercontent.com/neovim/neovim/master/runtime/syntax/tutor.lua'
      )
      vim.wait(2000, function()
        return vim.bo.filetype ~= ''
      end)
      -- wait for buffer to have content
      vim.wait(2000, function()
        return vim.fn.wordcount().bytes > 0
      end)
      vim.wait(2000, function()
        return vim.bo.modified == false
      end)
      return { vim.bo.filetype, vim.bo.modified }
    end)

    t.eq('lua', rv[1])
    t.eq(false, rv[2], 'Expected buffer to be unmodified for remote content')
  end)

  it('calls on_response with error on 404 (async failure)', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local result = request('GET', 'https://httpbingo.org/status/404')
    t.matches('404', result.error)
  end)

  it('plugin writes output to buffer', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local content = exec_lua(function()
      ---@type string[]
      local lines

      local buf = vim.api.nvim_create_buf(false, true)
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.net.request('https://httpbingo.org', { outbuf = buf })

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines[1] ~= ''
      end)

      return lines
    end)
    assert(content and content[1]:find('html'))
  end)

  it('works with :read', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local content = exec_lua(function()
      vim.cmd('runtime plugin/net.lua')
      ---@type string[]
      local lines

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Here is some text' })
      vim.cmd(':read https://example.com')

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        return #lines > 1
      end)

      return lines
    end)

    t.eq(true, content ~= nil)
    t.eq(true, content[1]:find('Here') ~= nil)
    t.eq(true, content[2]:find('html') ~= nil)
  end)

  it('opens remote tar.gz URLs as tar archives', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua(function()
      vim.cmd('runtime! plugin/net.lua')
      vim.cmd('runtime! plugin/tarPlugin.vim')

      vim.cmd(
        'edit https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz'
      )

      vim.wait(2500, function()
        return vim.bo.filetype == 'tar' or vim.b.tarfile ~= nil
      end)

      return {
        filetype = vim.bo.filetype,
        modified = vim.bo.modified,
        tarfile = vim.b.tarfile ~= nil,
      }
    end)

    t.eq('tar', rv.filetype)
    t.eq(false, rv.modified)
    t.eq(true, rv.tarfile)
  end)

  it('opens remote zip URLs as zip archives', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local rv = exec_lua(function()
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
    end)

    t.eq('zip', rv.filetype)
    t.eq(false, rv.modified)
    t.eq(true, rv.zipfile)
  end)

  it('accepts custom headers', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')
    ---@type table
    local result = request('GET', 'https://httpbingo.org/anything', {
      headers = {
        Authorization = 'Bearer test-token',
        ['X-Custom-Header'] = 'custom-value',
        ['Empty'] = '',
      },
    })

    t.eq(nil, result.error, ('request failed: %s'):format(result.error))
    t.eq('table', type(result.response.headers), 'Expected headers to be a table')

    -- httpbingo.org/request returns each header as a list in the returned value
    t.eq(
      'Bearer test-token',
      result.response.headers.Authorization[1],
      'Expected Authorization header'
    )
    t.eq('custom-value', result.response.headers['X-Custom-Header'][1], 'Expected X-Custom-Header')
    t.eq('', result.response.headers['Empty'][1], 'Expected Empty header')
  end)

  it('accepts multiple HTTP methods', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set: skipping network integration test')

    local url = 'https://httpbingo.org/anything'

    local function assert_accept_method(method)
      local result = request(method, url)
      t.eq(nil, result.error)
      t.eq(method, result.response.method)
    end

    assert_accept_method('GET')
    assert_accept_method('PUT')
    assert_accept_method('PATCH')
    assert_accept_method('DELETE')

    -- HEAD request
    local result = request('HEAD', url)
    t.eq(nil, result.error)

    -- testing body payload
    result = request('POST', url, {
      body = '{"a": 1}',
      headers = {
        ['Content-Type'] = 'application/json',
      },
    })
    t.eq(nil, result.error)
    t.eq(1, result.response.json.a)
  end)

  it('validation', function()
    local function assert_wrong_request(expected_err, method, opts)
      if type(method) ~= 'string' then
        opts = method
        method = 'GET'
      end

      local result = t.pcall_err(exec_lua, function()
        vim.net.request(method, 'https://example.com', opts)
      end)
      t.matches(expected_err, result)
    end

    -- headers asserts
    assert_wrong_request('opts.headers: expected table, got number', { headers = 123 })

    --- FIXME(ellisonleao): this special assert is failing because the opts table is putting [""] in
    --- the key value instead of [123] upon calling the helper method
    -- assert_wrong_request(
    --   'headers keys and values must be strings',
    --   { headers = { [123] = 'value' } }
    -- )

    assert_wrong_request('headers keys and values must be strings', { headers = { Header = 123 } })
    assert_wrong_request(
      'header keys must not start with @ or end with : and ;',
      { headers = { ['Header:'] = 'value' } }
    )
    assert_wrong_request(
      'header keys must not start with @ or end with : and ;',
      { headers = { ['Header;'] = 'value' } }
    )
    assert_wrong_request(
      'header keys must not start with @ or end with : and ;',
      { headers = { ['@filename'] = '' } }
    )

    -- body asserts
    assert_wrong_request(
      'opts.body: expected body should be string and not start with @',
      { body = 123 }
    )
    assert_wrong_request(
      'opts.body: expected body should be string and not start with @',
      { body = {} }
    )
    assert_wrong_request(
      'opts.body: expected body should be string and not start with @',
      { body = '@test' }
    )

    -- OPTIONS is not accepted
    assert_wrong_request(
      'expected method should be one of GET, POST, PUT, PATCH, HEAD, DELETE, got OPTIONS',
      'OPTIONS'
    )
    -- lowercase methods are not accepted as well
    assert_wrong_request(
      'expected method should be one of GET, POST, PUT, PATCH, HEAD, DELETE, got options',
      'options'
    )
    assert_wrong_request(
      'expected method should be one of GET, POST, PUT, PATCH, HEAD, DELETE, got get',
      'get'
    )
  end)
end)
