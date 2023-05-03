local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local exec_lua = helpers.exec_lua
local next_msg = helpers.next_msg
local file_exists = helpers.file_exists
local read_file = helpers.read_file
local meths = helpers.meths
local eq = helpers.eq

describe('vim.net', function()
  before_each(function()
    clear()
    local channel = meths.get_api_info()[1]
    meths.set_var('channel', channel)
  end)

  describe('create args', function()
    describe('fetch()', function()
      it('valid', function()
        eq(
          {
            'curl',
            '--no-progress-meter',
            '--include',
            '--get',
            '--location',
            '--write-out',
            '\\n%{json}',
            'https://httpbin.org/get',
          },
          exec_lua([[
            return vim.net.fetch("https://httpbin.org/get", {
              _dry = true
            })
          ]])
        )

        eq(
          {
            'curl',
            '--no-progress-meter',
            '--include',
            '--head',
            '--location',
            '--write-out',
            '\\n%{json}',
            'https://httpbin.org/head',
          },
          exec_lua([[
            return vim.net.fetch("https://httpbin.org/head", {
              method = "head",
              _dry = true
            })
          ]])
        )

        eq(
          {
            'curl',
            '--no-progress-meter',
            '--include',
            '--request',
            'DELETE',
            '--location',
            '--write-out',
            '\\n%{json}',
            'https://httpbin.org/delete',
          },
          exec_lua([[
            return vim.net.fetch("https://httpbin.org/delete", {
              method = "DELETE",
              _dry = true
            })
          ]])
        )
      end)
    end)

    describe('download()', function()
      it('valid', function()
        local path =
          exec_lua([[return vim.fn.fnameescape(vim.fn.fnamemodify("./download_file", ":p"))]])

        eq(
          {
            'curl',
            '--no-progress-meter',
            '--get',
            '--data-raw',
            'hi',
            '--output',
            path,
            'https://httpbin.org/get',
          },
          exec_lua([[
            return vim.net.download("https://httpbin.org/get", "./download_file", {
              follow_redirects = false,
              data = "hi",
              _dry = true
            })
          ]])
        )
      end)
    end)
  end)

  describe('fetch()', function()
    it('should read status', function()
      exec_lua([[
        local result

        vim.net.fetch("https://httpbingo.org/status/999", {
          on_complete = function (res)
            result = res
          end
        })

        -- wait 10 seconds and time-out
        local _, interrupted = vim.wait(10000, function()
          return result ~= nil
        end)

        vim.rpcnotify(vim.g.channel, 'method', result.method == "GET")
        vim.rpcnotify(vim.g.channel, 'ok', result.ok == false)
        vim.rpcnotify(vim.g.channel, 'status', result.status)
      ]])

      eq({ 'notification', 'method', { true } }, next_msg(500))
      eq({ 'notification', 'ok', { true } }, next_msg(500))
      eq({ 'notification', 'status', { 999 } }, next_msg(500))
    end)

    it('should post & read JSON', function()
      exec_lua([[
        local result

        vim.net.fetch("https://httpbingo.org/anything", {
          method = "POST",
          data = {
            A = "b"
          },
          on_complete = function(res)
            result = res
          end
        })

        -- wait 10 seconds and time-out
        local _, interrupted = vim.wait(10000, function()
          return result ~= nil
        end)

        vim.rpcnotify(vim.g.channel, 'method', result.method == "POST")
        vim.rpcnotify(vim.g.channel, 'ok', result.ok == true)
        vim.rpcnotify(vim.g.channel, 'json', result.json().json)
      ]])

      eq({ 'notification', 'method', { true } }, next_msg(500))
      eq({ 'notification', 'ok', { true } }, next_msg(500))
      eq({ 'notification', 'json', { { A = 'b' } } }, next_msg(500))
    end)

    it('should set headers', function()
      exec_lua([[
        local result

        vim.net.fetch("https://httpbingo.org/headers", {
          headers = {
            test_header = "value",
            NIL_HEADER = nil
          },
          on_complete = function(res)
            result = res
          end
        })

        -- wait 10 seconds and time-out
        local _, interrupted = vim.wait(10000, function()
          return result ~= nil
        end)

        vim.rpcnotify(vim.g.channel, 'method', result.method == "GET")
        vim.rpcnotify(vim.g.channel, 'ok', result.ok == true)
        vim.rpcnotify(vim.g.channel, 'headers.TEST_HEADER', result.json().headers["Test_header"][1] == "value")
        vim.rpcnotify(vim.g.channel, 'headers.NIL_HEADER', result.json().headers["Nil_header"] == nil)
      ]])

      eq({ 'notification', 'method', { true } }, next_msg(500))
      eq({ 'notification', 'ok', { true } }, next_msg(500))
      eq({ 'notification', 'headers.TEST_HEADER', { true } }, next_msg(500))
      eq({ 'notification', 'headers.NIL_HEADER', { true } }, next_msg(500))
    end)
  end)

  describe('download()', function()
    before_each(function()
      os.remove('./downloaded_file')
    end)

    it('saves files', function()
      eq(false, file_exists('./downloaded_file'))

      exec_lua([[
        local done

        vim.net.download("https://httpbingo.org/anything", "./download_file", {
          headers = {
            test_header = "value",
          },
          on_complete = function()
            done = true
          end
        })

        -- wait 10 seconds and time-out
        local _, interrupted = vim.wait(10000, function()
          return done
        end)

        vim.rpcnotify(vim.g.channel, 'done', done)
        vim.rpcnotify(vim.g.channel, 'path', "./download_file")
      ]])

      eq({ 'notification', 'done', { true } }, next_msg(500))

      local path = next_msg(500)[3][1]
      local data = read_file(path)

      eq(true, file_exists(path))
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
      eq({ 'value' }, vim.json.decode(data).headers['Test_header'])

      -- Just to be safe - can contain header information
      os.remove('./downloaded_file')
    end)
  end)
end)
