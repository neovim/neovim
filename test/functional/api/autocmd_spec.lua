local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local meths = helpers.meths
local source = helpers.source

before_each(clear)

describe('nvim_get_autocmds', function()
  describe('events', function()
    it('should return one autocmd when there is only one for an event', function()
      command [[au! InsertEnter]]
      command [[au InsertEnter * :echo "1"]]

      local aus = meths.get_autocmds { events = "InsertEnter" }
      eq(1, #aus)
    end)

    it('should return two autocmds when there are two for an event', function()
      command [[au! InsertEnter]]
      command [[au InsertEnter * :echo "1"]]
      command [[au InsertEnter * :echo "2"]]

      local aus = meths.get_autocmds { events = "InsertEnter" }
      eq(2, #aus)
    end)

    it('should return the same thing if you use string or list', function()
      command [[au! InsertEnter]]
      command [[au InsertEnter * :echo "1"]]
      command [[au InsertEnter * :echo "2"]]

      local string_aus = meths.get_autocmds { events = "InsertEnter" }
      local array_aus = meths.get_autocmds { events = { "InsertEnter" } }
      eq(string_aus, array_aus)
    end)

    it('should return two autocmds when there are two for an event', function()
      command [[au! InsertEnter]]
      command [[au! InsertLeave]]
      command [[au InsertEnter * :echo "1"]]
      command [[au InsertEnter * :echo "2"]]

      local aus = meths.get_autocmds { events = { "InsertEnter", "InsertLeave" } }
      eq(2, #aus)
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

    it('should return all groups if no group is specified', function()
      local aus = meths.get_autocmds { events = "InsertEnter" }
      eq(4, #aus)
    end)

    it('should return only the group specified', function()
      local aus = meths.get_autocmds {
        events = "InsertEnter",
        augroup = "GroupOne",
      }

      eq(1, #aus)
      eq([[:echo "GroupOne:1"]], aus[1].command)
    end)

    it('should return only the group specified, multiple values', function()
      local aus = meths.get_autocmds {
        events = "InsertEnter",
        augroup = "GroupTwo",
      }

      eq(2, #aus)
      eq([[:echo "GroupTwo:2"]], aus[1].command)
      eq([[:echo "GroupTwo:3"]], aus[2].command)
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

    it('should should return for literal match', function()
      local aus = meths.get_autocmds {
        events = "InsertEnter",
        patterns = "*"
      }

      eq(1, #aus)
      eq([[:echo "No Group"]], aus[1].command)
    end)

    it('should return for multiple matches', function()
      -- vim.api.nvim_get_autocmds
      local aus = meths.get_autocmds {
        events = "InsertEnter",
        patterns = { "*.one", "*.two" },
      }

      eq(3, #aus)
      eq([[:echo "GroupOne:1"]], aus[1].command)
      eq([[:echo "GroupTwo:2"]], aus[2].command)
      eq([[:echo "GroupTwo:3"]], aus[3].command)
    end)

    it('should work for buffer autocmds', function()
      local normalized_aus = meths.get_autocmds {
        events = "InsertEnter",
        patterns = "<buffer=1>",
      }

      local raw_aus = meths.get_autocmds {
        events = "InsertEnter",
        patterns = "<buffer>",
      }

      local zero_aus = meths.get_autocmds {
        events = "InsertEnter",
        patterns = "<buffer=0>",
      }

      eq(normalized_aus, raw_aus)
      eq(normalized_aus, zero_aus)
      eq([[:echo "Buffer"]], normalized_aus[1].command)
    end)
  end)
end)

pending('nvim_autocmd', function()
  describe('_define and _group_define', function()
    before_each(function()
      clear()

      exec_lua [[
        vim.g.executed = 0

        make_counting_autocmd = function(opts)
          local callback = function()
            vim.g.executed = vim.g.executed + 1
          end

          local defaults = {
            event = "FileType",
            pattern = "*",
            callback = callback,
          }
          opts = opts or {}
          local resulting = vim.tbl_extend("force", defaults, opts)
          vim.api.nvim_autocmd_define(resulting)
        end

        do_counting = function(ft)
          ft = ft or "txt"
          vim.cmd(string.format("set filetype=%s", ft))
        end

        get_count = function()
          return vim.g.executed
        end
      ]]
    end)

    it('CURRENT TEST', function()
      eq(true, exec_lua([[
        vim.g.executed = false

        vim.api.nvim_autocmd_define {
          event = "FileType",
          pattern = "*",
          callback = function() vim.g.executed = true end,
        }

        vim.cmd "set filetype=txt"

        -- _ = (function() vim.g.executed = true end)()

        return vim.g.executed
      ]], {}))
    end)

    it('works getting called twice', function()
      eq(2, meths.exec_lua([[
        make_counting_autocmd()
        do_counting()
        do_counting()

        return vim.g.executed
      ]], {}))
    end)

    it('handles ++once', function()
      eq(1, meths.exec_lua([[
        make_counting_autocmd({once = true})
        do_counting('txt')
        do_counting('help')
        do_counting('txt')
        do_counting('help')

        return vim.g.executed
      ]], {}))
    end)

    it('raises error for undefined augroup', function()
      local success, code = unpack(meths.exec_lua([[
        return {pcall(function()
          vim.api.nvim_autocmd_define {
            event = "FileType",
            pattern = "*",
            callback = function()
              return true
            end,
            group = "NotDefined",
          }
        end)}
      ]], {}))

      eq(false, success)
      matches('invalid augroup: NotDefined', code)
    end)

    it('errors on unexpect keys', function()
      local success, code = unpack(meths.exec_lua([[
        return {pcall(function()
          vim.api.nvim_autocmd_define {
            event = "FileType",
            pattern = "*",
            callback = function()
              return true
            end,
            not_a_valid_key = "NotDefined",
          }
        end)}
      ]], {}))

      eq(false, success)
      matches('unexpected key: not_a_valid_key', code)
    end)

    pending('can use tables as the callback', function()
      local success  = exec_lua [[
        vim.g.count_of_event = 0
        local callback_table = setmetatable({}, {__call = function(...) vim.g.count_of_event = vim.g.count_of_event + 1 end})

        vim.api.nvim_autocmd_define {
          event = {"FileType"},
          pattern = "*",
          callback = callback_table,
        }

        vim.cmd "set filetype=txt"

        return vim.g.count_of_event
      ]]

      eq(1, success)
    end)

    pending('can use tables as the callback', function()
      local success  = exec_lua [[
        vim.g.set_value = 0

        local callback_table = setmetatable({
          inner_value = 7
        }, {
          __call = function(t, ...)
            vim.g.set_value = t.inner_value
          end
        })

        vim.api.nvim_autocmd_define {
          event = "FileType",
          pattern = "*",
          callback = callback_table,
        }

        vim.cmd "set filetype=txt"

        return vim.g.set_value
      ]]

      eq(7, success)
    end)

    pending('can use tables as the callback, even when table changes', function()
      local success, msg  = exec_lua [[
        vim.g.set_value = 0

        local orig_table = { inner_value = 7 }
        local callback_table = setmetatable(orig_table, {
          __call = function(t, ...)
            vim.g.set_value = t.inner_value
          end
        })

        orig_table.inner_value = 12

        vim.api.nvim_autocmd_define {
          event = "FileType",
          pattern = "*",
          callback = callback_table,
        }

        vim.cmd "set filetype=txt"

        return vim.g.set_value
      ]]

      eq(nil, msg)
      eq(12, success)
    end)

    it('can be added in a group', function()
      local count = exec_lua [[
        local augroup = "TestGroup"

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        make_counting_autocmd { group = augroup }

        do_counting()
        do_counting()

        return get_count()
      ]]

      eq(count, 2)
    end)

    it('groups can be cleared', function()
      local count = exec_lua [[
        local augroup = "TestGroup"

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        make_counting_autocmd { group = augroup }

        do_counting()
        do_counting()

        -- Clear the augroup, this means no more counting
        vim.api.nvim_autocmd_group_define(augroup, { clear = true })

        do_counting()
        do_counting()

        return get_count()
      ]]

      eq(count, 2)
    end)

    it('groups work with once', function()
      local count = exec_lua [[
        local augroup = "TestGroup"

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        make_counting_autocmd { group = augroup, once = true }

        do_counting()
        do_counting()

        return get_count()
      ]]

      eq(count, 1)
    end)

    it('autocmds can be registered multiple times.', function()
      local count = exec_lua [[
        local augroup = "TestGroup"

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        make_counting_autocmd { group = augroup, once = false }
        make_counting_autocmd { group = augroup, once = false }
        make_counting_autocmd { group = augroup, once = false }

        do_counting()
        do_counting()

        return get_count()
      ]]

      eq(count, 3 * 2)
    end)

    it('can be deleted', function()
      local result = exec_lua [[
        local augroup = "WillBeDeleted"

        local func_ref = function()
          return 5
        end

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        vim.api.nvim_autocmd_define {
          event = {"Filetype"},
          pattern = "*",
          callback = func_ref,
        }

        -- Clears the augroup from before, which erases the autocmd
        vim.api.nvim_autocmd_group_define(augroup, { clear = true })

        return func_ref()
      ]]

      eq(5, result)
    end)

    it('can be used for buffer local autocmds', function()
      local result = exec_lua [[
        local augroup = "WillBeDeleted"

        vim.g.value_set = false

        local func_ref = function()
          vim.g.value_set = true
        end

        vim.api.nvim_autocmd_group_define(augroup, { clear = true })
        vim.api.nvim_autocmd_define {
          event = {"Filetype"},
          pattern = "<buffer>",
          callback = func_ref,
        }

        vim.cmd "new"
        vim.cmd "set filetype=python"

        return vim.g.value_set
      ]]

      eq(false, result)
    end)

    it('can accept vimscript functions', function()
      meths.set_var("vimscript_executed", false)

      source [[
        function! MyVimscriptFunction() abort
          let g:vimscript_executed = v:true
        endfunction

        call nvim_autocmd_define(#{
          \ event: "VimEnter",
          \ vim_func: "MyVimscriptFunction",
          \ })
      ]]

      eq(true, meths.get_var("vimscript_executed"))
    end)
  end)

  describe("nvim_autocmd_do", function()
    it("can trigger builtin autocmds", function()
      meths.set_var("autocmd_executed", false)

      meths.autocmd_define({
        event = "BufReadPost",
        pattern = "*",
        command = "let g:autocmd_executed = v:true",
      })

      eq(false, meths.get_var("autocmd_executed"))
      meths.autocmd_do { event = "BufReadPost" }
      eq(true, meths.get_var("autocmd_executed"))
    end)

    it("can pass the buffer", function()
      meths.set_var("buffer_executed", -1)
      eq(-1, meths.get_var("buffer_executed"))

      meths.autocmd_define({
        event = "CursorMoved",
        pattern = "*",
        command = 'let g:buffer_executed = +expand("<abuf>")',
      })

      meths.autocmd_do { event = "BufReadPost", bufnr = 1 }
      eq(1, meths.get_var("buffer_executed"))
    end)
  end)
end)
