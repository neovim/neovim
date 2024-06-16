local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local read_file = t.read_file
local write_file = t.write_file

local path = './downloaded_file'
describe('vim.net', function()
  before_each(function()
    os.remove(path)
  end)

  describe('download()', function()
    it('can download a file without a path', function()
      local destination_path = './anything'
      eq(nil, read_file(destination_path))
      exec_lua([[
        local done
        vim.net.download("https://httpbingo.org/anything", {
          on_exit = function()
            done = true
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
      ]])
      local data = read_file(destination_path)
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
    end)

    it('can download a file to a path', function()
      eq(nil, read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.download("https://httpbingo.org/anything", {
          as = path,
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

    it('does not follow redirects', function()
      eq(nil, read_file(path))
      local response_code = exec_lua(
        [[
        local path = ...
        local done, metadata, err
        vim.net.download("https://httpbingo.org/redirect/1", {
          as = path,
          on_exit = function(err_, metadata_)
            done = true
            metadata = metadata_
            err = err_
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
        assert(not err, err)
        assert(metadata, 'no metadata was received')
        return metadata.response_code
      ]],
        path
      )
      eq(302, response_code)
      eq('', read_file(path))
    end)

    it('can follow redirects', function()
      eq(nil, read_file(path))
      local response_code = exec_lua(
        [[
        local path = ...
        local done, metadata, err
        vim.net.download("https://httpbingo.org/redirect/1", {
          as = path,
          follow_redirects = true,
          on_exit = function(err_, metadata_)
            done = true
            metadata = metadata_
            err = err_
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
        assert(not err, err)
        assert(metadata, 'no metadata was received')
        return metadata.response_code
      ]],
        path
      )
      eq(200, response_code)
      local data = read_file(path)
      eq('https://httpbingo.org/get', vim.json.decode(data).url)
    end)

    it('can send headers', function()
      eq(nil, read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.download("https://httpbingo.org/bearer", {
          as = path,
          headers = {
            Authorization = { "Bearer foo" },
          },
          on_exit = function(err, metadata)
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
        vim.net.download("https://httpbingo.org/basic-auth/user/password", {
          as = path,
          credentials = "user:password",
          on_exit = function(err, metadata)
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

    it('does not override file', function()
      write_file(path, '')
      eq('', read_file(path))
      exec_lua(
        [[
        local path = ...
        local done
        vim.net.download("https://httpbingo.org/anything", {
          as = path,
          override = false,
          on_exit = function(err, metadata)
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
      eq('', read_file(path))
    end)
  end)

  describe('download()', function()
    it('works with global options', function()
      local different_path = './different_path'
      eq(nil, read_file(path))
      eq(nil, read_file(different_path))
      local filename = exec_lua(
        [[
        local path,different_path = ...
        local done, metadata, err
        vim.net.config({as = path})

        vim.net.download("https://httpbingo.org/anything", {
          as = different_path,
          on_exit = function(err_, metadata_)
            done = true
            metadata = metadata_
            err = err_
          end
        })

        local _, interrupted = vim.wait(10000, function()
          return done
        end)
        assert(done, 'file was not downloaded')
        assert(not err, err)
        assert(metadata, 'no metadata was received')
        return metadata.filename_effective
      ]],
        path,
        different_path
      )
      eq(different_path, filename)
      eq(nil, read_file(path))
      local data = read_file(different_path)
      eq('https://httpbingo.org/anything', vim.json.decode(data).url)
    end)
  end)
end)
