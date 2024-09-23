local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local read_file = t.read_file

local path = './downloaded_file'
local anything_path = './anything'
describe('vim.net', function()
  before_each(function()
    os.remove(path)
    os.remove(anything_path)
  end)

  describe('request()', function()
    it('can download a file without a path', function()
      eq(nil, read_file(anything_path))
      exec_lua([[
        local done
        vim.net.request("https://httpbingo.org/anything", {
          on_exit = function()
            done = true
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
      ]])
      local data = read_file(anything_path)
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
    end)

    it('can download a file to a path', function()
      eq(nil, read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.request("https://httpbingo.org/anything", {
          file = path,
          on_exit = function()
            done = true
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
      ]],
        path
      )
      local data = read_file(path)
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
    end)

    it('can send headers', function()
      eq(nil, read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.request("https://httpbingo.org/bearer", {
          file = path,
          headers = {
            Authorization = { "Bearer foo" },
          },
          on_exit = function(err)
            done = true
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
      ]],
        path
      )
      local data = read_file(path)
      eq(true, vim.json.decode(data).authenticated)
    end)

    it('can handle basic auth', function()
      eq(nil, read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.request("https://httpbingo.org/basic-auth/user/password", {
          file = path,
          user = "user:password",
          on_exit = function(err)
            done = true
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
      ]],
        path
      )
      local data = read_file(path)
      eq(true, vim.json.decode(data).authorized)
    end)

    it('can download a file without a path (sync)', function()
      eq(nil, read_file(anything_path))
      exec_lua([[
        vim.net.request("https://httpbingo.org/anything"):wait(10000)
      ]])
      local data = read_file(anything_path)
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
    end)
  end)
end)
