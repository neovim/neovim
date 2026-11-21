local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local describe, it, before_each = t.describe, t.it, t.before_each
local skip_integ = os.getenv('NVIM_TEST_INTEG') ~= '1'

local exec_lua = n.exec_lua

-- Serve one request per status (default "200 OK") and record what curl sent.
---@param status? string|string[]
---@param length? integer Content-Length (default: `#body`).
local function http_server(body, status, length)
  t.skip(n.fn.executable('curl') == 0, 'curl not found')
  return exec_lua(function()
    vim.env.no_proxy = '127.0.0.1'
    local statuses = type(status) == 'table' and status or { status or '200 OK' }
    local server = assert(vim.uv.new_tcp())
    assert(server:bind('127.0.0.1', 0))
    assert(server:listen(1, function(err)
      assert(not err, err)
      local client = assert(vim.uv.new_tcp())
      assert(server:accept(client))
      local client_status = table.remove(statuses, 1)
      if #statuses == 0 then
        server:close()
      end
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
        _G.http_request = { method = method, headers = headers, body = request_body, raw = data }
        local response_head = ('HTTP/1.1 %s\r\nContent-Length: %d\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nConnection: close\r\n\r\n'):format(
          client_status,
          length or #body
        )
        -- Body is not format()ed: PUC Lua 5.1 "%s" truncates at NUL.
        client:write({ response_head, method == 'HEAD' and '' or body }, function(write_err)
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
      vim.rpcnotify(1, 'response', { error = err, response = res })
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
    local result = request('GET', http_server('a<>b'))
    t.eq(nil, result.error)
    t.eq('a<>b', result.response.body)
    t.eq(200, result.response.status)
    t.eq('4', result.response.headers['content-length'])
    t.eq({ 'a=1', 'b=2' }, result.response.headers['set-cookie'])

    -- Output of a retried attempt is not in the response.
    result = request('GET', http_server('ok', { '503 Service Unavailable', '200 OK' }))
    t.eq({ 'ok', 200 }, { result.response.body, result.response.status })

    -- Non-HTTP URL: no status, no headers. Accepts vim.Uri. `on_response` is deferred/scheduled.
    local fname = t.tmpname()
    t.write_file(fname, 'local\n')
    local url = exec_lua('return vim.uri.from_fname(...)', fname)
    t.eq(
      { fast = false, response = { body = 'local\n', status = 0, headers = {} } },
      exec_lua(function()
        local rv ---@type table?
        vim.net.request(vim.uri.parse(url), {}, function()
          local fast = vim.in_fast_event()
          vim.net.request('GET', setmetatable(vim.uri.parse(url), nil), {}, function(err, res)
            rv = { fast = fast, error = err, response = res }
          end)
        end)
        vim.wait(5000, function()
          return rv ~= nil
        end)
        return rv
      end)
    )

    -- User's ".curlrc" should not change the output.
    local curl_home = t.tmpname(false)
    n.mkdir_p(curl_home)
    t.write_file(vim.fs.joinpath(curl_home, '.curlrc'), 'include\ncompressed\n')
    exec_lua(function()
      vim.env.CURL_HOME = curl_home
    end)
    result = request('GET', http_server('ok'))
    t.eq('ok', result.response.body)
    t.eq(nil, exec_lua('return http_request.headers')['accept-encoding'])
    n.rmdir(curl_home)
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

  it('invokes on_response(error) on 404 (async failure)', function()
    local result = request('GET', http_server('not found page', '404 Not Found'))
    t.matches('404', result.error)
    t.eq(404, result.response.status)
    t.eq({ 'a=1', 'b=2' }, result.response.headers['set-cookie'])

    -- The error page is not written to `outpath`.
    local outpath = t.tmpname(false)
    result = request('GET', http_server('not found page', '404 Not Found'), { outpath = outpath })
    t.matches('404', result.error)
    t.eq(nil, vim.uv.fs_stat(outpath))

    -- A partial (failed) download is removed from `outpath`.
    result = request('GET', http_server('ab', nil, 100), { outpath = outpath })
    t.matches('^curl: %(18%)', result.error)
    t.eq(nil, vim.uv.fs_stat(outpath))

    -- curl rejects a malformed URL.
    result = request('GET', 'http://127.0.0.1/a b')
    t.eq(nil, result.response)
    t.matches('^curl: %(3%)', result.error)
  end)

  it('with vim.async: await(), Task:close() cancels the request', function()
    local url = http_server('hello')
    t.eq(
      { body = 'hello' },
      exec_lua(function()
        local err, res = vim.async
          .run(function()
            return vim.async.await(3, vim.net.request, url, {})
          end)
          :wait(5000)
        return { err = err, body = res and res.body }
      end)
    )
    -- is_closing() after the request stopped.
    url = http_server('hello')
    t.eq(
      true,
      exec_lua(function()
        local done = false
        local req = vim.net.request(url, {}, function()
          done = true
        end)
        vim.wait(5000, function()
          return done
        end)
        return req:is_closing()
      end)
    )

    url = exec_lua(function()
      vim.env.no_proxy = '127.0.0.1'
      -- Accepts a connection, never responds.
      local server = assert(vim.uv.new_tcp())
      _G.handles = { server }
      assert(server:bind('127.0.0.1', 0))
      assert(server:listen(1, function()
        local client = assert(vim.uv.new_tcp())
        table.insert(_G.handles, client)
        assert(server:accept(client))
      end))
      return ('http://127.0.0.1:%d/'):format(server:getsockname().port)
    end)

    -- is_closing() after close(). Calls each close() callback. `on_response` gets an error.
    t.eq(
      { false, true, 2, 'Request closed' },
      exec_lua(function()
        local closed = 0
        local rv ---@type string?
        local req = vim.net.request(url, {}, function(err)
          rv = err
        end)
        local closing = req:is_closing()
        for _ = 1, 2 do
          req:close(function()
            closed = closed + 1
          end)
        end
        vim.wait(5000, function()
          return rv ~= nil
        end)
        return { closing, req:is_closing(), closed, rv }
      end)
    )
    -- The task completes after the request stops.
    t.eq(
      { false, true },
      exec_lua(function()
        local task = vim.async.run(function()
          return vim.async.await(3, vim.net.request, url, {})
        end)
        local ok = task:pwait(100)
        task:close()
        return { ok, vim.wait(5000, function()
          return task:completed()
        end) }
      end)
    )
    exec_lua(function()
      for _, h in ipairs(_G.handles) do
        h:close()
      end
    end)
  end)

  it('writes response to `outbuf`', function()
    local body = '<html>\0</html>\n'
    local url = http_server(body, { '200 OK', '200 OK', '200 OK', '200 OK' })

    local content = exec_lua(function()
      ---@type string[]
      local lines

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(buf)
      vim.net.request(url, { outbuf = 0 })

      -- Switch buffers before the response arrives.
      local other = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(other)
      vim.api.nvim_buf_set_lines(other, 0, -1, true, { 'unrelated text' })

      vim.wait(2000, function()
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines[1] ~= ''
      end)

      return { lines, vim.api.nvim_buf_get_lines(other, 0, -1, true) }
    end)
    t.eq({ '<html>\0</html>' }, content[1])
    t.eq({ 'unrelated text' }, content[2])

    -- Writes both `outpath` (relative to CWD at request time) and `outbuf`.
    local outpath = t.tmpname(false)
    t.eq(
      { '<html>\0</html>' },
      exec_lua(function()
        local done = false
        vim.cmd.cd(vim.fs.dirname(outpath))
        vim.net.request(url, { outpath = vim.fs.basename(outpath), outbuf = 0 }, function()
          done = true
        end)
        vim.cmd.cd('-')
        vim.wait(2000, function()
          return done
        end)
        return vim.api.nvim_buf_get_lines(0, 0, -1, true)
      end)
    )
    t.eq(body, t.read_file(outpath))

    -- A failed `outbuf` write is passed to `on_response`, else raised.
    t.matches(
      "not 'modifiable'",
      exec_lua(function()
        vim.bo.modifiable = false
        local rv ---@type string?
        vim.net.request(url, { outbuf = 0 }, function(err)
          rv = err
        end)
        vim.wait(2000, function()
          return rv ~= nil
        end)
        return rv
      end)
    )
    exec_lua(function()
      vim.net.request(url, { outbuf = 0 })
    end)
    t.retry(nil, 2000, function()
      t.matches("not 'modifiable'", n.eval('v:errmsg'))
    end)
  end)

  it('works with :read', function()
    local url = http_server('line1\nline2\n')
    t.eq(
      { 'a', 'line1', 'line2', 'b' },
      exec_lua(function()
        vim.cmd('runtime plugin/net.lua')
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b' })
        local buf = vim.api.nvim_get_current_buf()
        vim.cmd(('1read %s'):format(url))
        -- Switch buffers before the response arrives.
        vim.cmd.enew()
        vim.wait(2000, function()
          return vim.api.nvim_buf_line_count(buf) > 2
        end)
        return vim.api.nvim_buf_get_lines(buf, 0, -1, true)
      end)
    )
  end)

  it('opens remote tar.gz URLs as tar archives', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')

    local rv = exec_lua(function()
      vim.cmd('runtime! plugin/net.lua')
      vim.cmd('runtime! plugin/tarPlugin.vim')

      vim.cmd(
        'edit https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz'
      )

      vim.wait(20000, function()
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
      vim.net.request = function(_, opts, on_response)
        assert(vim.uv.fs_copyfile(path, opts.outpath))
        vim.schedule(on_response)
      end
      -- The query is not part of the path (see |vim.Uri|).
      vim.cmd.edit({ 'https://example.com/browser.zip?raw=1', magic = { file = false } })
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
    t.eq('https://example.com/browser.zip?raw=1', rv.name)
    t.eq(true, rv.nvim_zip)
  end)

  it('downloads a live remote zip URL', function()
    t.skip(skip_integ, 'NVIM_TEST_INTEG not set (network integration test)')
    n.clear({ args = { '--clean' } })

    local rv = exec_lua(function()
      vim.cmd('edit https://github.com/neovim/neovim/releases/download/nightly/nvim-win-arm64.zip')

      vim.wait(20000, function()
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
        ['Blank'] = ' ',
        ['X-Multi'] = { 'a', 'b' },
      },
    })

    t.eq(nil, result.error)
    t.matches('\r\nX%-Multi: a\r\nX%-Multi: b\r\n', exec_lua('return http_request.raw'))
    local headers = exec_lua('return http_request.headers')
    t.eq('Bearer test-token', headers.authorization, 'Expected Authorization header')
    t.eq('custom-value', headers['x-custom-header'], 'Expected X-Custom-Header')
    t.eq('', headers.empty, 'Expected Empty header')
    t.eq('', headers.blank)
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

    -- `method` defaults to GET.
    t.eq(nil, request(nil, http_server('hello')).error)
    t.eq('GET', exec_lua('return http_request.method'))

    -- HEAD request
    local result = request('HEAD', http_server('hello'))
    t.eq(nil, result.error)
    t.eq('HEAD', exec_lua('return http_request.method'))
    t.eq({ '', 200, '5' }, {
      result.response.body,
      result.response.status,
      result.response.headers['content-length'],
    })

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

    -- A body starting with "@" is not a filename.
    request('POST', http_server('hello'), { body = '@a' })
    t.eq('@a', exec_lua('return http_request.body'))

    -- A 303 redirect switches POST to GET.
    local redirect = '303 See Other\r\nLocation: /done' -- Status line + header.
    result = request('POST', http_server('done', { redirect, '200 OK' }), { body = 'a=1' })
    t.eq({ 'done', 'GET' }, { result.response.body, exec_lua('return http_request.method') })
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
    t.matches(
      'url: expected URI, got example.com',
      t.pcall_err(exec_lua, function()
        vim.net.request('GET', 'example.com', {})
      end)
    )
    t.matches(
      'url: expected URI, got example.com',
      t.pcall_err(exec_lua, function()
        vim.net.request('example.com', {})
      end)
    )
    t.matches(
      'url: expected URI, got function',
      t.pcall_err(exec_lua, function()
        vim.net.request('GET', print, {})
      end)
    )

    t.matches(
      'headers keys/values must be strings',
      t.pcall_err(exec_lua, function()
        vim.net.request('https://example.com', { headers = { [123] = 'value' } })
      end)
    )

    assert_wrong_request('opts.outbuf: expected number, got string', { outbuf = 'x' })
    assert_wrong_request('headers keys/values must be strings', { headers = { Header = 123 } })
    assert_wrong_request(
      'headers must not contain CR or LF',
      { headers = { ['X-Name'] = 'a\r\nAuthorization: Bearer evil' } }
    )
    assert_wrong_request(
      'headers keys/values must be strings',
      { headers = { Header = { a = 'b' } } }
    )
    assert_wrong_request(
      'header keys must not start with @ or end with : and ;',
      { headers = { ['Header:'] = {} } }
    )
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
    assert_wrong_request('opts.body: expected string, got number', { body = 123 })
    assert_wrong_request('opts.body: expected string, got table', { body = {} })
    assert_wrong_request('opts.retry: expected number, got table', { retry = {} })

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
