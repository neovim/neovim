local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local neq = helpers.neq
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local meths = helpers.meths
local source = helpers.source
local pcall_err = helpers.pcall_err

before_each(clear)

describe('autocmd api', function()
  describe('nvim_create_autocmd', function()
    it('validation', function()
      eq("Cannot use both 'callback' and 'command'", pcall_err(meths.create_autocmd, 'BufReadPost', {
        pattern = '*.py,*.pyi',
        command = "echo 'Should Have Errored",
        callback = 'NotAllowed',
      }))
      eq("Cannot use both 'pattern' and 'buffer' for the same autocmd", pcall_err(meths.create_autocmd, 'FileType', {
        command = 'let g:called = g:called + 1',
        buffer = 0,
        pattern = '*.py',
      }))
      eq("Required: 'event'", pcall_err(meths.create_autocmd, {}, {
        command = 'ls',
      }))
      eq("Required: 'command' or 'callback'", pcall_err(meths.create_autocmd, 'FileType', {
      }))
      eq("Invalid 'desc': expected String, got Integer", pcall_err(meths.create_autocmd, 'FileType', {
        command = 'ls',
        desc = 42,
      }))
      eq("Invalid 'callback': expected Lua function or Vim function name, got Integer", pcall_err(meths.create_autocmd, 'FileType', {
        callback = 0,
      }))
      eq("Invalid 'event' item: expected String, got Array", pcall_err(meths.create_autocmd,
        {'FileType', {}}, {}))
      eq("Invalid 'group': 0", pcall_err(meths.create_autocmd, 'FileType', {
        group = 0,
        command = 'ls',
      }))
    end)

    it('doesnt leak when you use ++once', function()
      eq(1, exec_lua([[
        local count = 0

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "*",
          callback = function() count = count + 1 end,
          once = true
        })

        vim.cmd "set filetype=txt"
        vim.cmd "set filetype=python"

        return count
      ]], {}))
    end)

    it('allows passing buffer by key', function()
      meths.set_var('called', 0)

      meths.create_autocmd("FileType", {
        command = "let g:called = g:called + 1",
        buffer = 0,
      })

      meths.command "set filetype=txt"
      eq(1, meths.get_var('called'))

      -- switch to a new buffer
      meths.command "new"
      meths.command "set filetype=python"

      eq(1, meths.get_var('called'))
    end)

    it('does not allow passing invalid buffers', function()
      local ok, msg = pcall(meths.create_autocmd, 'FileType', {
        command = "let g:called = g:called + 1",
        buffer = -1,
      })

      eq(false, ok)
      matches('Invalid buffer id', msg)
    end)

    it('errors on non-functions for cb', function()
      eq(false, pcall(exec_lua, [[
        vim.api.nvim_create_autocmd("BufReadPost", {
          pattern = "*.py,*.pyi",
          callback = 5,
        })
      ]]))
    end)

    it('allow passing pattern and <buffer> in same pattern', function()
      local ok = pcall(meths.create_autocmd, "BufReadPost", {
        pattern = "*.py,<buffer>",
        command = "echo 'Should Not Error'"
      })

      eq(true, ok)
    end)

    it('should handle multiple values as comma separated list', function()
      meths.create_autocmd("BufReadPost", {
        pattern = "*.py,*.pyi",
        command = "echo 'Should Not Have Errored'"
      })

      -- We should have one autocmd for *.py and one for *.pyi
      eq(2, #meths.get_autocmds { event = "BufReadPost" })
    end)

    it('should handle multiple values as array', function()
      meths.create_autocmd("BufReadPost", {
        pattern = { "*.py", "*.pyi", },
        command = "echo 'Should Not Have Errored'"
      })

      -- We should have one autocmd for *.py and one for *.pyi
      eq(2, #meths.get_autocmds { event = "BufReadPost" })
    end)

    describe('desc', function()
      it('can add description to one autocmd', function()
        local cmd =  "echo 'Should Not Have Errored'"
        local desc =  "Can show description"
        meths.create_autocmd("BufReadPost", {
          pattern = "*.py",
          command = cmd,
          desc = desc,
        })

        eq(desc, meths.get_autocmds { event = "BufReadPost" }[1].desc)
        eq(cmd, meths.get_autocmds { event = "BufReadPost" }[1].command)
      end)

      it('can add description to one autocmd that uses a callback', function()
        local desc = 'Can show description'
        meths.set_var('desc', desc)

        local result = exec_lua([[
          local callback = function() print 'Should Not Have Errored' end
          vim.api.nvim_create_autocmd("BufReadPost", {
            pattern = "*.py",
            callback = callback,
            desc = vim.g.desc,
          })
          local aus = vim.api.nvim_get_autocmds({ event = 'BufReadPost' })
          local first = aus[1]
          return {
            desc = first.desc,
            cbtype = type(first.callback)
          }
        ]])

        eq({ desc = desc, cbtype = 'function' }, result)
      end)

      it('will not add a description unless it was provided', function()
        exec_lua([[
          local callback = function() print 'Should Not Have Errored' end
          vim.api.nvim_create_autocmd("BufReadPost", {
            pattern = "*.py",
            callback = callback,
          })
        ]])

        eq(nil, meths.get_autocmds({ event = 'BufReadPost' })[1].desc)
      end)

      it('can add description to multiple autocmd', function()
        meths.create_autocmd("BufReadPost", {
          pattern = {"*.py", "*.pyi"},
          command = "echo 'Should Not Have Errored'",
          desc = "Can show description",
        })

        local aus = meths.get_autocmds { event = "BufReadPost" }
        eq(2, #aus)
        eq("Can show description", aus[1].desc)
        eq("Can show description", aus[2].desc)
      end)
    end)

    pending('script and verbose settings', function()
      it('marks API client', function()
        meths.create_autocmd("BufReadPost", {
          pattern = "*.py",
          command = "echo 'Should Not Have Errored'",
          desc = "Can show description",
        })

        local aus = meths.get_autocmds { event = "BufReadPost" }
        eq(1, #aus, aus)
      end)
    end)

    it('removes an autocommand if the callback returns true', function()
      meths.set_var("some_condition", false)

      exec_lua [[
      vim.api.nvim_create_autocmd("User", {
        pattern = "Test",
        desc = "A test autocommand",
        callback = function()
          return vim.g.some_condition
        end,
      })
      ]]

      meths.exec_autocmds("User", {pattern = "Test"})

      local aus = meths.get_autocmds({ event = 'User', pattern = 'Test' })
      local first = aus[1]
      eq(true, first.id > 0)

      meths.set_var("some_condition", true)
      meths.exec_autocmds("User", {pattern = "Test"})
      eq({}, meths.get_autocmds({event = "User", pattern = "Test"}))
    end)

    it('receives an args table', function()
      local group_id = meths.create_augroup("TestGroup", {})
      -- Having an existing autocmd calling expand("<afile>") shouldn't change args #18964
      meths.create_autocmd('User', {
        group = 'TestGroup',
        pattern = 'Te*',
        command = 'call expand("<afile>")',
      })

      local autocmd_id = exec_lua [[
        return vim.api.nvim_create_autocmd("User", {
          group = "TestGroup",
          pattern = "Te*",
          callback = function(args)
            vim.g.autocmd_args = args
          end,
        })
      ]]

      meths.exec_autocmds("User", {pattern = "Test pattern"})
      eq({
        id = autocmd_id,
        group = group_id,
        event = "User",
        match = "Test pattern",
        file = "Test pattern",
        buf = 1,
      }, meths.get_var("autocmd_args"))

      -- Test without a group
      autocmd_id = exec_lua [[
        return vim.api.nvim_create_autocmd("User", {
          pattern = "*",
          callback = function(args)
            vim.g.autocmd_args = args
          end,
        })
      ]]

      meths.exec_autocmds("User", {pattern = "some_pat"})
      eq({
        id = autocmd_id,
        group = nil,
        event = "User",
        match = "some_pat",
        file = "some_pat",
        buf = 1,
      }, meths.get_var("autocmd_args"))
    end)

    it('can receive arbitrary data', function()
      local function test(data)
        eq(data, exec_lua([[
          local input = ...
          local output
          vim.api.nvim_create_autocmd("User", {
            pattern = "Test",
            callback = function(args)
              output = args.data
            end,
          })

          vim.api.nvim_exec_autocmds("User", {
            pattern = "Test",
            data = input,
          })

          return output
        ]], data))
      end

      test("Hello")
      test(42)
      test(true)
      test({ "list" })
      test({ foo = "bar" })
    end)
  end)

  describe('nvim_get_autocmds', function()
    it('validation', function()
      eq("Invalid 'group': 9997999", pcall_err(meths.get_autocmds, {
        group = 9997999,
      }))
      eq("Invalid 'group': 'bogus'", pcall_err(meths.get_autocmds, {
        group = 'bogus',
      }))
      eq("Invalid 'group': 0", pcall_err(meths.get_autocmds, {
        group = 0,
      }))
      eq("Invalid 'group': expected String or Integer, got Array", pcall_err(meths.get_autocmds, {
        group = {},
      }))
      eq("Invalid 'buffer': expected Integer or Array, got Boolean", pcall_err(meths.get_autocmds, {
        buffer = true,
      }))
      eq("Invalid 'event': expected String or Array", pcall_err(meths.get_autocmds, {
        event = true,
      }))
      eq("Invalid 'pattern': expected String or Array, got Boolean", pcall_err(meths.get_autocmds, {
        pattern = true,
      }))
    end)

    describe('events', function()
      it('returns one autocmd when there is only one for an event', function()
        command [[au! InsertEnter]]
        command [[au InsertEnter * :echo "1"]]

        local aus = meths.get_autocmds { event = "InsertEnter" }
        eq(1, #aus)
      end)

      it('returns two autocmds when there are two for an event', function()
        command [[au! InsertEnter]]
        command [[au InsertEnter * :echo "1"]]
        command [[au InsertEnter * :echo "2"]]

        local aus = meths.get_autocmds { event = "InsertEnter" }
        eq(2, #aus)
      end)

      it('returns the same thing if you use string or list', function()
        command [[au! InsertEnter]]
        command [[au InsertEnter * :echo "1"]]
        command [[au InsertEnter * :echo "2"]]

        local string_aus = meths.get_autocmds { event = "InsertEnter" }
        local array_aus = meths.get_autocmds { event = { "InsertEnter" } }
        eq(string_aus, array_aus)
      end)

      it('returns two autocmds when there are two for an event', function()
        command [[au! InsertEnter]]
        command [[au! InsertLeave]]
        command [[au InsertEnter * :echo "1"]]
        command [[au InsertEnter * :echo "2"]]

        local aus = meths.get_autocmds { event = { "InsertEnter", "InsertLeave" } }
        eq(2, #aus)
      end)

      it('returns different IDs for different autocmds', function()
        command [[au! InsertEnter]]
        command [[au! InsertLeave]]
        command [[au InsertEnter * :echo "1"]]
        source [[
          call nvim_create_autocmd("InsertLeave", #{
            \ command: ":echo 2",
            \ })
        ]]

        local aus = meths.get_autocmds { event = { "InsertEnter", "InsertLeave" } }
        local first = aus[1]
        eq(first.id, nil)

        -- TODO: Maybe don't have this number, just assert it's not nil
        local second = aus[2]
        neq(second.id, nil)

        meths.del_autocmd(second.id)
        local new_aus = meths.get_autocmds { event = { "InsertEnter", "InsertLeave" } }
        eq(1, #new_aus)
        eq(first, new_aus[1])
      end)

      it('returns event name', function()
        command [[au! InsertEnter]]
        command [[au InsertEnter * :echo "1"]]

        local aus = meths.get_autocmds { event = "InsertEnter" }
        eq({ { buflocal = false, command = ':echo "1"', event = "InsertEnter", once = false, pattern = "*" } }, aus)
      end)

      it('works with buffer numbers', function()
        command [[new]]
        command [[au! InsertEnter]]
        command [[au InsertEnter <buffer=1> :echo "1"]]
        command [[au InsertEnter <buffer=2> :echo "2"]]

        local aus = meths.get_autocmds { event = "InsertEnter", buffer = 0 }
        eq({{
          buffer = 2,
          buflocal = true,
          command = ':echo "2"',
          event = 'InsertEnter',
          once = false,
          pattern = '<buffer=2>',
        }}, aus)

        aus = meths.get_autocmds { event = "InsertEnter", buffer = 1 }
        eq({{
          buffer = 1,
          buflocal = true,
          command = ':echo "1"',
          event = "InsertEnter",
          once = false,
          pattern = "<buffer=1>",
        }}, aus)

        aus = meths.get_autocmds { event = "InsertEnter", buffer = { 1, 2 } }
        eq({{
          buffer = 1,
          buflocal = true,
          command = ':echo "1"',
          event = "InsertEnter",
          once = false,
          pattern = "<buffer=1>",
        }, {
          buffer = 2,
          buflocal = true,
          command = ':echo "2"',
          event = "InsertEnter",
          once = false,
          pattern = "<buffer=2>",
        }}, aus)

        eq("Invalid 'buffer': expected Integer or Array, got String", pcall_err(meths.get_autocmds, { event = "InsertEnter", buffer = "foo" }))
        eq("Invalid 'buffer': expected Integer, got String", pcall_err(meths.get_autocmds, { event = "InsertEnter", buffer = { "foo", 42 } }))
        eq("Invalid buffer id: 42", pcall_err(meths.get_autocmds, { event = "InsertEnter", buffer = { 42 } }))

        local bufs = {}
        for _ = 1, 257 do
          table.insert(bufs, meths.create_buf(true, false))
        end

        eq("Too many buffers (maximum of 256)", pcall_err(meths.get_autocmds, { event = "InsertEnter", buffer = bufs }))
      end)

      it('returns autocmds when group is specified by id', function()
        local auid = meths.create_augroup("nvim_test_augroup", { clear = true })
        meths.create_autocmd("FileType", { group = auid, command = 'echo "1"' })
        meths.create_autocmd("FileType", { group = auid, command = 'echo "2"' })

        local aus = meths.get_autocmds { group = auid }
        eq(2, #aus)

        local aus2 = meths.get_autocmds { group = auid, event = "InsertEnter" }
        eq(0, #aus2)
      end)

      it('returns autocmds when group is specified by name', function()
        local auname = "nvim_test_augroup"
        meths.create_augroup(auname, { clear = true })
        meths.create_autocmd("FileType", { group = auname, command = 'echo "1"' })
        meths.create_autocmd("FileType", { group = auname, command = 'echo "2"' })

        local aus = meths.get_autocmds { group = auname }
        eq(2, #aus)

        local aus2 = meths.get_autocmds { group = auname, event = "InsertEnter" }
        eq(0, #aus2)
      end)

      it('should respect nested', function()
        local bufs = exec_lua [[
          local count = 0
          vim.api.nvim_create_autocmd("BufNew", {
            once = false,
            nested = true,
            callback = function()
              count = count + 1
              if count > 5 then
                return true
              end

              vim.cmd(string.format("new README_%s.md", count))
            end
          })

          vim.cmd "new First.md"

          return vim.api.nvim_list_bufs()
        ]]

        -- 1 for the first buffer
        -- 2 for First.md
        -- 3-7 for the 5 we make in the autocmd
        eq({1, 2, 3, 4, 5, 6, 7}, bufs)
      end)

      it('can retrieve a callback from an autocmd', function()
        local content = 'I Am A Callback'
        meths.set_var('content', content)

        local result = exec_lua([[
          local cb = function() return vim.g.content end
          vim.api.nvim_create_autocmd("User", {
            pattern = "TestTrigger",
            desc = "A test autocommand with a callback",
            callback = cb,
          })
          local aus = vim.api.nvim_get_autocmds({ event = 'User', pattern = 'TestTrigger'})
          local first = aus[1]
          return {
            cb = {
              type = type(first.callback),
              can_retrieve = first.callback() == vim.g.content
            }
          }
        ]])

        eq("function", result.cb.type)
        eq(true, result.cb.can_retrieve)
      end)

      it('will return an empty string as the command for an autocmd that uses a callback', function()
        local result = exec_lua([[
          local callback = function() print 'I Am A Callback' end
          vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = "*.py",
            callback = callback,
          })
          local aus = vim.api.nvim_get_autocmds({ event = 'BufWritePost' })
          local first = aus[1]
          return {
            command = first.command,
            cbtype = type(first.callback)
          }
        ]])

        eq({ command = "", cbtype = 'function' }, result)
      end)
    end)

    describe('groups', function()
      before_each(function()
        command [[au! InsertEnter]]

        command [[au InsertEnter * :echo "No Group"]]

        command [[augroup GroupOne]]
        command [[  au InsertEnter * :echo "GroupOne:1"]]
        command [[augroup END]]

        command [[augroup GroupTwo]]
        command [[  au InsertEnter * :echo "GroupTwo:2"]]
        command [[  au InsertEnter * :echo "GroupTwo:3"]]
        command [[augroup END]]
      end)

      it('returns all groups if no group is specified', function()
        local aus = meths.get_autocmds { event = "InsertEnter" }
        if #aus ~= 4 then
          eq({}, aus)
        end

        eq(4, #aus)
      end)

      it('returns only the group specified', function()
        local aus = meths.get_autocmds {
          event = "InsertEnter",
          group = "GroupOne",
        }

        eq(1, #aus)
        eq([[:echo "GroupOne:1"]], aus[1].command)
        eq("GroupOne", aus[1].group_name)
      end)

      it('returns only the group specified, multiple values', function()
        local aus = meths.get_autocmds {
          event = "InsertEnter",
          group = "GroupTwo",
        }

        eq(2, #aus)
        eq([[:echo "GroupTwo:2"]], aus[1].command)
        eq("GroupTwo", aus[1].group_name)
        eq([[:echo "GroupTwo:3"]], aus[2].command)
        eq("GroupTwo", aus[2].group_name)
      end)
    end)

    describe('groups: 2', function()
      it('raises error for undefined augroup name', function()
        local success, code = unpack(meths.exec_lua([[
          return {pcall(function()
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "*",
              group = "NotDefined",
              command = "echo 'hello'",
            })
          end)}
        ]], {}))

        eq(false, success)
        matches("Invalid 'group': 'NotDefined'", code)
      end)

      it('raises error for undefined augroup id', function()
        local success, code = unpack(meths.exec_lua([[
          return {pcall(function()
            -- Make sure the augroup is deleted
            vim.api.nvim_del_augroup_by_id(1)

            vim.api.nvim_create_autocmd("FileType", {
              pattern = "*",
              group = 1,
              command = "echo 'hello'",
            })
          end)}
        ]], {}))

        eq(false, success)
        matches("Invalid 'group': 1", code)
      end)

      it('raises error for invalid group type', function()
        local success, code = unpack(meths.exec_lua([[
          return {pcall(function()
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "*",
              group = true,
              command = "echo 'hello'",
            })
          end)}
        ]], {}))

        eq(false, success)
        matches("Invalid 'group': expected String or Integer, got Boolean", code)
      end)

      it('raises error for invalid pattern array', function()
        local success, code = unpack(meths.exec_lua([[
          return {pcall(function()
            vim.api.nvim_create_autocmd("FileType", {
              pattern = {{}},
              command = "echo 'hello'",
            })
          end)}
        ]], {}))

        eq(false, success)
        matches("Invalid 'pattern' item: expected String, got Array", code)
      end)
    end)

    describe('patterns', function()
      before_each(function()
        command [[au! InsertEnter]]

        command [[au InsertEnter *        :echo "No Group"]]
        command [[au InsertEnter *.one    :echo "GroupOne:1"]]
        command [[au InsertEnter *.two    :echo "GroupTwo:2"]]
        command [[au InsertEnter *.two    :echo "GroupTwo:3"]]
        command [[au InsertEnter <buffer> :echo "Buffer"]]
      end)

      it('returns for literal match', function()
        local aus = meths.get_autocmds {
          event = "InsertEnter",
          pattern = "*"
        }

        eq(1, #aus)
        eq([[:echo "No Group"]], aus[1].command)
      end)

      it('returns for multiple matches', function()
        -- vim.api.nvim_get_autocmds
        local aus = meths.get_autocmds {
          event = "InsertEnter",
          pattern = { "*.one", "*.two" },
        }

        eq(3, #aus)
        eq([[:echo "GroupOne:1"]], aus[1].command)
        eq([[:echo "GroupTwo:2"]], aus[2].command)
        eq([[:echo "GroupTwo:3"]], aus[3].command)
      end)

      it('should work for buffer autocmds', function()
        local normalized_aus = meths.get_autocmds {
          event = "InsertEnter",
          pattern = "<buffer=1>",
        }

        local raw_aus = meths.get_autocmds {
          event = "InsertEnter",
          pattern = "<buffer>",
        }

        local zero_aus = meths.get_autocmds {
          event = "InsertEnter",
          pattern = "<buffer=0>",
        }

        eq(normalized_aus, raw_aus)
        eq(normalized_aus, zero_aus)
        eq([[:echo "Buffer"]], normalized_aus[1].command)
      end)
    end)
  end)

  describe('nvim_exec_autocmds', function()
    it('validation', function()
      eq("Invalid 'group': 9997999", pcall_err(meths.exec_autocmds, 'FileType', {
        group = 9997999,
      }))
      eq("Invalid 'group': 'bogus'", pcall_err(meths.exec_autocmds, 'FileType', {
        group = 'bogus',
      }))
      eq("Invalid 'group': expected String or Integer, got Array", pcall_err(meths.exec_autocmds, 'FileType', {
        group = {},
      }))
      eq("Invalid 'group': 0", pcall_err(meths.exec_autocmds, 'FileType', {
        group = 0,
      }))
      eq("Invalid 'buffer': expected Integer, got Array", pcall_err(meths.exec_autocmds, 'FileType', {
        buffer = {},
      }))
      eq("Invalid 'event' item: expected String, got Array", pcall_err(meths.exec_autocmds,
        {'FileType', {}}, {}))
    end)

    it("can trigger builtin autocmds", function()
      meths.set_var("autocmd_executed", false)

      meths.create_autocmd("BufReadPost", {
        pattern = "*",
        command = "let g:autocmd_executed = v:true",
      })

      eq(false, meths.get_var("autocmd_executed"))
      meths.exec_autocmds("BufReadPost", {})
      eq(true, meths.get_var("autocmd_executed"))
    end)

    it("can trigger multiple patterns", function()
      meths.set_var("autocmd_executed", 0)

      meths.create_autocmd("BufReadPost", {
        pattern = "*",
        command = "let g:autocmd_executed += 1",
      })

      meths.exec_autocmds("BufReadPost", { pattern = { "*.lua", "*.vim" } })
      eq(2, meths.get_var("autocmd_executed"))

      meths.create_autocmd("BufReadPre", {
        pattern = { "bar", "foo" },
        command = "let g:autocmd_executed += 10",
      })

      meths.exec_autocmds("BufReadPre", { pattern = { "foo", "bar", "baz", "frederick" }})
      eq(22, meths.get_var("autocmd_executed"))
    end)

    it("can pass the buffer", function()
      meths.set_var("buffer_executed", -1)
      eq(-1, meths.get_var("buffer_executed"))

      meths.create_autocmd("BufLeave", {
        pattern = "*",
        command = 'let g:buffer_executed = +expand("<abuf>")',
      })

      -- Doesn't execute for other non-matching events
      meths.exec_autocmds("CursorHold", { buffer = 1 })
      eq(-1, meths.get_var("buffer_executed"))

      meths.exec_autocmds("BufLeave", { buffer = 1 })
      eq(1, meths.get_var("buffer_executed"))
    end)

    it("can pass the filename, pattern match", function()
      meths.set_var("filename_executed", 'none')
      eq('none', meths.get_var("filename_executed"))

      meths.create_autocmd("BufEnter", {
        pattern = "*.py",
        command = 'let g:filename_executed = expand("<afile>")',
      })

      -- Doesn't execute for other non-matching events
      meths.exec_autocmds("CursorHold", { buffer = 1 })
      eq('none', meths.get_var("filename_executed"))

      meths.command('edit __init__.py')
      eq('__init__.py', meths.get_var("filename_executed"))
    end)

    it('cannot pass buf and fname', function()
      local ok = pcall(meths.exec_autocmds, "BufReadPre", { pattern = "literally_cannot_error.rs", buffer = 1 })
      eq(false, ok)
    end)

    it("can pass the filename, exact match", function()
      meths.set_var("filename_executed", 'none')
      eq('none', meths.get_var("filename_executed"))

      meths.command('edit other_file.txt')
      meths.command('edit __init__.py')
      eq('none', meths.get_var("filename_executed"))

      meths.create_autocmd("CursorHoldI", {
        pattern = "__init__.py",
        command = 'let g:filename_executed = expand("<afile>")',
      })

      -- Doesn't execute for other non-matching events
      meths.exec_autocmds("CursorHoldI", { buffer = 1 })
      eq('none', meths.get_var("filename_executed"))

      meths.exec_autocmds("CursorHoldI", { buffer = meths.get_current_buf() })
      eq('__init__.py', meths.get_var("filename_executed"))

      -- Reset filename
      meths.set_var("filename_executed", 'none')

      meths.exec_autocmds("CursorHoldI", { pattern = '__init__.py' })
      eq('__init__.py', meths.get_var("filename_executed"))
    end)

    it("works with user autocmds", function()
      meths.set_var("matched", 'none')

      meths.create_autocmd("User", {
        pattern = "TestCommand",
        command = 'let g:matched = "matched"'
      })

      meths.exec_autocmds("User", { pattern = "OtherCommand" })
      eq('none', meths.get_var('matched'))
      meths.exec_autocmds("User", { pattern = "TestCommand" })
      eq('matched', meths.get_var('matched'))
    end)

    it('can pass group by id', function()
      meths.set_var("group_executed", false)

      local auid = meths.create_augroup("nvim_test_augroup", { clear = true })
      meths.create_autocmd("FileType", {
        group = auid,
        command = 'let g:group_executed = v:true',
      })

      eq(false, meths.get_var("group_executed"))
      meths.exec_autocmds("FileType", { group = auid })
      eq(true, meths.get_var("group_executed"))
    end)

    it('can pass group by name', function()
      meths.set_var("group_executed", false)

      local auname = "nvim_test_augroup"
      meths.create_augroup(auname, { clear = true })
      meths.create_autocmd("FileType", {
        group = auname,
        command = 'let g:group_executed = v:true',
      })

      eq(false, meths.get_var("group_executed"))
      meths.exec_autocmds("FileType", { group = auname })
      eq(true, meths.get_var("group_executed"))
    end)
  end)

  describe('nvim_create_augroup', function()
    before_each(function()
      clear()

      meths.set_var('executed', 0)
    end)

    local make_counting_autocmd = function(opts)
      opts = opts or {}

      local resulting = {
        pattern = "*",
        command = "let g:executed = g:executed + 1",
      }

      resulting.group = opts.group
      resulting.once = opts.once

      meths.create_autocmd("FileType", resulting)
    end

    local set_ft = function(ft)
      ft = ft or "txt"
      source(string.format("set filetype=%s", ft))
    end

    local get_executed_count = function()
      return meths.get_var('executed')
    end

    it('can be added in a group', function()
      local augroup = "TestGroup"
      meths.create_augroup(augroup, { clear = true })
      make_counting_autocmd { group = augroup }

      set_ft("txt")
      set_ft("python")

      eq(2, get_executed_count())
    end)

    it('works getting called multiple times', function()
      make_counting_autocmd()
      set_ft()
      set_ft()
      set_ft()

      eq(3, get_executed_count())
    end)

    it('handles ++once', function()
      make_counting_autocmd {once = true}
      set_ft('txt')
      set_ft('help')
      set_ft('txt')
      set_ft('help')

      eq(1, get_executed_count())
    end)

    it('errors on unexpected keys', function()
      local success, code = pcall(meths.create_autocmd, "FileType", {
        pattern = "*",
        not_a_valid_key = "NotDefined",
      })

      eq(false, success)
      matches('not_a_valid_key', code)
    end)

    it('can execute simple callback', function()
      exec_lua([[
        vim.g.executed = false

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "*",
          callback = function() vim.g.executed = true end,
        })
      ]], {})


      eq(true, exec_lua([[
        vim.cmd "set filetype=txt"
        return vim.g.executed
      ]], {}))
    end)

    it('calls multiple lua callbacks for the same autocmd execution', function()
      eq(4, exec_lua([[
        local count = 0
        local counter = function()
          count = count + 1
        end

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "*",
          callback = counter,
        })

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "*",
          callback = counter,
        })

        vim.cmd "set filetype=txt"
        vim.cmd "set filetype=txt"

        return count
      ]], {}))
    end)

    it('properly releases functions with ++once', function()
      exec_lua([[
        WeakTable = setmetatable({}, { __mode = "k" })

        OnceCount = 0

        MyVal = {}
        WeakTable[MyVal] = true

        vim.api.nvim_create_autocmd("FileType", {
          pattern = "*",
          callback = function()
            OnceCount = OnceCount + 1
            MyVal = {}
          end,
          once = true
        })
      ]])

      command [[set filetype=txt]]
      eq(1, exec_lua([[return OnceCount]], {}))

      exec_lua([[collectgarbage()]], {})

      command [[set filetype=txt]]
      eq(1, exec_lua([[return OnceCount]], {}))

      eq(0, exec_lua([[
        local count = 0
        for _ in pairs(WeakTable) do
          count = count + 1
        end

        return count
      ]]), "Should have no keys remaining")
    end)

    it('groups can be cleared', function()
      local augroup = "TestGroup"
      meths.create_augroup(augroup, { clear = true })
      meths.create_autocmd("FileType", {
        group = augroup,
        command = "let g:executed = g:executed + 1"
      })

      set_ft("txt")
      set_ft("txt")
      eq(2, get_executed_count(), "should only count twice")

      meths.create_augroup(augroup, { clear = true })
      eq({}, meths.get_autocmds { group = augroup })

      set_ft("txt")
      set_ft("txt")
      eq(2, get_executed_count(), "No additional counts")
    end)

    it('can delete non-existent groups with pcall', function()
      eq(false, exec_lua[[return pcall(vim.api.nvim_del_augroup_by_name, 'noexist')]])
      eq('Vim:E367: No such group: "noexist"', pcall_err(meths.del_augroup_by_name, 'noexist'))

      eq(false, exec_lua[[return pcall(vim.api.nvim_del_augroup_by_id, -12342)]])
      eq('Vim:E367: No such group: "--Deleted--"', pcall_err(meths.del_augroup_by_id, -12312))

      eq(false, exec_lua[[return pcall(vim.api.nvim_del_augroup_by_id, 0)]])
      eq('Vim:E367: No such group: "[NULL]"', pcall_err(meths.del_augroup_by_id, 0))

      eq(false, exec_lua[[return pcall(vim.api.nvim_del_augroup_by_id, 12342)]])
      eq('Vim:E367: No such group: "[NULL]"', pcall_err(meths.del_augroup_by_id, 12312))
    end)

    it('groups work with once', function()
      local augroup = "TestGroup"

      meths.create_augroup(augroup, { clear = true })
      make_counting_autocmd { group = augroup, once = true }

      set_ft("txt")
      set_ft("python")

      eq(1, get_executed_count())
    end)

    it('autocmds can be registered multiple times.', function()
      local augroup = "TestGroup"

      meths.create_augroup(augroup, { clear = true })
      make_counting_autocmd { group = augroup, once = false }
      make_counting_autocmd { group = augroup, once = false }
      make_counting_autocmd { group = augroup, once = false }

      set_ft("txt")
      set_ft("python")

      eq(3 * 2, get_executed_count())
    end)

    it('can be deleted', function()
      local augroup = "WillBeDeleted"

      meths.create_augroup(augroup, { clear = true })
      meths.create_autocmd({"FileType"}, {
        pattern = "*",
        command = "echo 'does not matter'",
      })

      -- Clears the augroup from before, which erases the autocmd
      meths.create_augroup(augroup, { clear = true })

      local result = #meths.get_autocmds { group = augroup }

      eq(0, result)
    end)

    it('can be used for buffer local autocmds', function()
      local augroup = "WillBeDeleted"

      meths.set_var("value_set", false)

      meths.create_augroup(augroup, { clear = true })
      meths.create_autocmd("FileType", {
        pattern = "<buffer>",
        command = "let g:value_set = v:true",
      })

      command "new"
      command "set filetype=python"

      eq(false, meths.get_var("value_set"))
    end)

    it('can accept vimscript functions', function()
      source [[
        let g:vimscript_executed = 0

        function! MyVimscriptFunction() abort
          let g:vimscript_executed = g:vimscript_executed + 1
        endfunction

        call nvim_create_autocmd("FileType", #{
          \ pattern: ["python", "javascript"],
          \ callback: "MyVimscriptFunction",
          \ })

        set filetype=txt
        set filetype=python
        set filetype=txt
        set filetype=javascript
        set filetype=txt
      ]]

      eq(2, meths.get_var("vimscript_executed"))
    end)
  end)

  describe('augroup!', function()
    it('legacy: should clear and not return any autocmds for delete groups', function()
       command('augroup TEMP_A')
       command('    autocmd! BufReadPost *.py :echo "Hello"')
       command('augroup END')

       command('augroup! TEMP_A')

       eq(false, pcall(meths.get_autocmds, { group = 'TEMP_A' }))

       -- For some reason, augroup! doesn't clear the autocmds themselves, which is just wild
       -- but we managed to keep this behavior.
       eq(1, #meths.get_autocmds { event = 'BufReadPost' })
    end)

    it('legacy: remove augroups that have no autocmds', function()
       command('augroup TEMP_AB')
       command('augroup END')

       command('augroup! TEMP_AB')

       eq(false, pcall(meths.get_autocmds, { group = 'TEMP_AB' }))
       eq(0, #meths.get_autocmds { event = 'BufReadPost' })
    end)

    it('legacy: multiple remove and add augroup', function()
       command('augroup TEMP_ABC')
       command('    au!')
       command('    autocmd BufReadPost *.py echo "Hello"')
       command('augroup END')

       command('augroup! TEMP_ABC')

       -- Should still have one autocmd :'(
       local aus = meths.get_autocmds { event = 'BufReadPost' }
       eq(1, #aus, aus)

       command('augroup TEMP_ABC')
       command('    au!')
       command('    autocmd BufReadPost *.py echo "Hello"')
       command('augroup END')

       -- Should now have two autocmds :'(
       aus = meths.get_autocmds { event = 'BufReadPost' }
       eq(2, #aus, aus)

       command('augroup! TEMP_ABC')

       eq(false, pcall(meths.get_autocmds, { group = 'TEMP_ABC' }))
       eq(2, #meths.get_autocmds { event = 'BufReadPost' })
    end)

    it('api: should clear and not return any autocmds for delete groups by id', function()
       command('augroup TEMP_ABCD')
       command('autocmd! BufReadPost *.py :echo "Hello"')
       command('augroup END')

       local augroup_id = meths.create_augroup("TEMP_ABCD", { clear = false })
       meths.del_augroup_by_id(augroup_id)

       -- For good reason, we kill all the autocmds from del_augroup,
       -- so now this works as expected
       eq(false, pcall(meths.get_autocmds, { group = 'TEMP_ABCD' }))
       eq(0, #meths.get_autocmds { event = 'BufReadPost' })
    end)

    it('api: should clear and not return any autocmds for delete groups by name', function()
       command('augroup TEMP_ABCDE')
       command('autocmd! BufReadPost *.py :echo "Hello"')
       command('augroup END')

       meths.del_augroup_by_name("TEMP_ABCDE")

       -- For good reason, we kill all the autocmds from del_augroup,
       -- so now this works as expected
       eq(false, pcall(meths.get_autocmds, { group = 'TEMP_ABCDE' }))
       eq(0, #meths.get_autocmds { event = 'BufReadPost' })
    end)
  end)

  describe('nvim_clear_autocmds', function()
    it('validation', function()
      eq("Cannot use both 'pattern' and 'buffer'", pcall_err(meths.clear_autocmds, {
        pattern = '*',
        buffer = 42,
      }))
      eq("Invalid 'event' item: expected String, got Array", pcall_err(meths.clear_autocmds, {
        event = {'FileType', {}}
      }))
      eq("Invalid 'group': 0", pcall_err(meths.clear_autocmds, {group = 0}))
    end)

    it('should clear based on event + pattern', function()
      command('autocmd InsertEnter *.py  :echo "Python can be cool sometimes"')
      command('autocmd InsertEnter *.txt :echo "Text Files Are Cool"')

      local search = { event = "InsertEnter", pattern = "*.txt" }
      local before_delete = meths.get_autocmds(search)
      eq(1, #before_delete)

      local before_delete_all = meths.get_autocmds { event = search.event }
      eq(2, #before_delete_all)

      meths.clear_autocmds(search)
      local after_delete = meths.get_autocmds(search)
      eq(0, #after_delete)

      local after_delete_all = meths.get_autocmds { event = search.event }
      eq(1, #after_delete_all)
    end)

    it('should clear based on event', function()
      command('autocmd InsertEnter *.py  :echo "Python can be cool sometimes"')
      command('autocmd InsertEnter *.txt :echo "Text Files Are Cool"')

      local search = { event = "InsertEnter"}
      local before_delete = meths.get_autocmds(search)
      eq(2, #before_delete)

      meths.clear_autocmds(search)
      local after_delete = meths.get_autocmds(search)
      eq(0, #after_delete)
    end)

    it('should clear based on pattern', function()
      command('autocmd InsertEnter *.TestPat1 :echo "Enter 1"')
      command('autocmd InsertLeave *.TestPat1 :echo "Leave 1"')
      command('autocmd InsertEnter *.TestPat2 :echo "Enter 2"')
      command('autocmd InsertLeave *.TestPat2 :echo "Leave 2"')

      local search = { pattern = "*.TestPat1"}
      local before_delete = meths.get_autocmds(search)
      eq(2, #before_delete)
      local before_delete_events = meths.get_autocmds { event = { "InsertEnter", "InsertLeave" } }
      eq(4, #before_delete_events)

      meths.clear_autocmds(search)
      local after_delete = meths.get_autocmds(search)
      eq(0, #after_delete)

      local after_delete_events = meths.get_autocmds { event = { "InsertEnter", "InsertLeave" } }
      eq(2, #after_delete_events)
    end)

    it('should allow clearing by buffer', function()
      command('autocmd! InsertEnter')
      command('autocmd InsertEnter <buffer> :echo "Enter Buffer"')
      command('autocmd InsertEnter *.TestPat1 :echo "Enter Pattern"')

      local search = { event = "InsertEnter" }
      local before_delete = meths.get_autocmds(search)
      eq(2, #before_delete)

      meths.clear_autocmds { buffer = 0 }
      local after_delete = meths.get_autocmds(search)
      eq(1, #after_delete)
      eq("*.TestPat1", after_delete[1].pattern)
    end)

    it('should allow clearing by buffer and group', function()
      command('augroup TestNvimClearAutocmds')
      command('  au!')
      command('  autocmd InsertEnter <buffer> :echo "Enter Buffer"')
      command('  autocmd InsertEnter *.TestPat1 :echo "Enter Pattern"')
      command('augroup END')

      local search = { event = "InsertEnter", group = "TestNvimClearAutocmds" }
      local before_delete = meths.get_autocmds(search)
      eq(2, #before_delete)

      -- Doesn't clear without passing group.
      meths.clear_autocmds { buffer = 0 }
      local without_group = meths.get_autocmds(search)
      eq(2, #without_group)

      -- Doest clear with passing group.
      meths.clear_autocmds { buffer = 0, group = search.group }
      local with_group = meths.get_autocmds(search)
      eq(1, #with_group)
    end)
  end)
end)
