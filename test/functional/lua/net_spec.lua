local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

local exec_lua = n.exec_lua

-- Serve one request and record what curl sent.
local function http_server(body, status)
  t.skip(n.fn.executable('curl') == 0, 'curl not found')
  return exec_lua(function()
    vim.env.no_proxy = '127.0.0.1'
    local server = assert(vim.uv.new_tcp())
    assert(server:bind('127.0.0.1', 0))
    assert(server:listen(1, function(err)
      assert(not err, err)
      local client = assert(vim.uv.new_tcp())
      assert(server:accept(client))
      server:close()
      local data = ''
      client:read_start(function(read_err, chunk)
        assert(not read_err, read_err)
        assert(chunk, 'Connection closed before the request was complete')
        data = data .. chunk
        -- TCP can split the headers and body across reads.
        local header_end = data:find('\r\n\r\n', 1, true)
        if not header_end then
          return
        end
        local headers = {}
        for name, value in data:sub(1, header_end + 1):gmatch('\r\n([^:]+):[ \t]*([^\r\n]*)') do
          headers[name:lower()] = value
        end
        local request_body = data:sub(header_end + 4)
        if #request_body < (tonumber(headers['content-length']) or 0) then
          return
        end
        client:read_stop()
        local method = data:match('^(%S+)')
        _G.http_request = { method = method, headers = headers, body = request_body }
        local response = ('HTTP/1.1 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s'):format(
          status or '200 OK',
          #body,
          method == 'HEAD' and '' or body
        )
        client:write(response, function(write_err)
          assert(not write_err, write_err)
          client:close()
        end)
      end)
    end))
    return ('http://127.0.0.1:%d/'):format(server:getsockname().port)
  end)
end

---@param method vim.net.HttpMethod
---@param url string
---@param opts? vim.net.request.Opts
---@return table
local function request(method, url, opts)
  exec_lua(function()
    vim.net.request(method, url, opts, function(err, res)
      vim.rpcnotify(1, 'response', { error = err, response = res and res.body })
    end)
  end)

  local msg = assert(n.next_msg(), 'Timed out waiting for HTTP response')
  t.eq({ 'notification', 'response' }, { msg[1], msg[2] })
  return msg[3][1]
end

describe('vim.net.request', function()
  before_each(function()
    n:clear()
  end)

  it('fetches a URL into memory (async success)', function()
    ---@type table
    local result = request('GET', http_server('hello'))

    t.eq(nil, result.error)
    t.eq('hello', result.response)
  end)

  it("detects filetype, sets 'nomodified'", function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')

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
    local result = request('GET', http_server('', '404 Not Found'))
    t.matches('404', result.error)
  end)

  it('plugin writes output to buffer', function()
    local url = http_server('<html>test</html>')

    local content = exec_lua(function()
      ---@type string[]
      local lines

      local buf = vim.api.nvim_create_buf(false, true)
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.net.request(url, { outbuf = buf })

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines[1] ~= ''
      end)

      return lines
    end)
    assert(content and content[1]:find('html'))
  end)

  it('works with :read', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')

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
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')

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

  it('dispatches remote zip URLs to zip.lua', function()
    n.clear({ args_rm = { '-u' } })
    local fixture =
      vim.fs.joinpath(t.paths.test_source_path, 'test/functional/fixtures/zip/browser.zip')
    local rv = exec_lua(function(path)
      vim.net.request = function(_, opts, callback)
        assert(vim.uv.fs_copyfile(path, opts.outpath))
        callback(nil)
      end
      vim.cmd.edit('https://example.com/browser.zip')
      vim.wait(1000, function()
        return vim.b.nvim_zip ~= nil
      end)
      require('nvim.zip').open_parent(0, vim.api.nvim_buf_get_name(0))
      return {
        legacy = vim.g.loaded_zip ~= nil,
        name = vim.api.nvim_buf_get_name(0),
        nvim_zip = vim.b.nvim_zip ~= nil,
      }
    end, fixture)

    t.eq(false, rv.legacy)
    t.eq('https://example.com/browser.zip', rv.name)
    t.eq(true, rv.nvim_zip)
  end)

  it('downloads a live remote zip URL', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')
    n.clear({ args = { '--clean' } })

    local rv = exec_lua(function()
      vim.cmd('edit https://github.com/neovim/neovim/releases/download/nightly/nvim-win-arm64.zip')

      vim.wait(2500, function()
        return vim.bo.filetype == 'zip' or vim.b.zipfile ~= nil
      end)

      require('nvim.zip').open_parent(0, vim.api.nvim_buf_get_name(0))
      return {
        filetype = vim.bo.filetype,
        legacy = vim.g.loaded_zip ~= nil,
        modified = vim.bo.modified,
        name = vim.api.nvim_buf_get_name(0),
        nvim_zip = vim.b.nvim_zip ~= nil,
        zipfile = vim.b.zipfile ~= nil,
      }
    end)

    t.eq('zip', rv.filetype)
    t.eq(false, rv.legacy)
    t.eq(false, rv.modified)
    t.eq('https://github.com/neovim/neovim/releases/download/nightly/nvim-win-arm64.zip', rv.name)
    t.eq(true, rv.nvim_zip)
    t.eq(false, rv.zipfile)
  end)

  it('accepts custom headers', function()
    ---@type table
    local result = request('GET', http_server('hello'), {
      headers = {
        Authorization = 'Bearer test-token',
        ['X-Custom-Header'] = 'custom-value',
        ['Empty'] = '',
      },
    })

    t.eq(nil, result.error)
    local headers = exec_lua('return http_request.headers')
    t.eq('Bearer test-token', headers.authorization, 'Expected Authorization header')
    t.eq('custom-value', headers['x-custom-header'], 'Expected X-Custom-Header')
    t.eq('', headers.empty, 'Expected Empty header')
  end)

  it('accepts multiple HTTP methods', function()
    local function assert_accept_method(method)
      local result = request(method, http_server('hello'))
      t.eq(nil, result.error)
      t.eq(method, exec_lua('return http_request.method'))
    end

    assert_accept_method('GET')
    assert_accept_method('PUT')
    assert_accept_method('PATCH')
    assert_accept_method('DELETE')

    -- HEAD request
    local result = request('HEAD', http_server('hello'))
    t.eq(nil, result.error)
    t.eq('HEAD', exec_lua('return http_request.method'))

    -- testing body payload
    result = request('POST', http_server('hello'), {
      body = '{"a": 1}',
      headers = {
        ['Content-Type'] = 'application/json',
      },
    })
    t.eq(nil, result.error)
    local sent = exec_lua('return http_request')
    t.eq('POST', sent.method)
    t.eq('application/json', sent.headers['content-type'])
    t.eq('{"a": 1}', sent.body)
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

    -- request headers asserts
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
