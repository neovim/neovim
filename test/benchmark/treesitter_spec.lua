local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua

describe('treesitter perf', function()
  setup(function()
    clear()
  end)

  it('can handle large folds', function()
    n.command 'edit ./src/nvim/eval.c'
    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c", {})
      vim.treesitter.highlighter.new(parser)

      local function keys(k)
        vim.api.nvim_feedkeys(k, 't', true)
      end

      vim.opt.foldmethod = "manual"
      vim.opt.lazyredraw = false

      vim.cmd '1000,7000fold'
      vim.cmd '999'

      local function mk_keys(n)
        local acc = ""
        for _ = 1, n do
          acc = acc .. "j"
        end
        for _ = 1, n do
          acc = acc .. "k"
        end

        return "qq" .. acc .. "q"
      end

      local start = vim.uv.hrtime()
      keys(mk_keys(10))

      for _ = 1, 100 do
        keys "@q"
        vim.cmd'redraw!'
      end

      return vim.uv.hrtime() - start
    ]]
  end)

  it('editing a large file with injection query', function()
    local total_ns = exec_lua(function()
      vim.cmd('enew')

      local src_lines = {
        'int main() {',
        'int a = func(12, 32, 43);',
        'int b = 7;',
        'if (a > b) {',
        'printf("local a = 5");',
        '}',
        'else if (a == b) {',
        'rintf("local a = 6");',
        '}',
        '}',
      }
      local lines = {}
      for _ = 1, 500 do
        for _, line in ipairs(src_lines) do
          table.insert(lines, line)
        end
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)

      local parser = vim.treesitter.get_parser(0, 'c', {
        injections = {
          c = [=[
            ((call_expression
              function: (identifier) @_function
              arguments: (argument_list
                .
                (string_literal
                  (string_content) @injection.content)
                )) @_root
              (#eq? @_function "printf")
              (#set! nvim.injection-root @_root)
              (#set! injection.language "lua"))

            ((call_expression
              function: (identifier) @_function
              arguments: (argument_list
                (_)
                .
                  (string_literal
                    (string_content) @injection.content)
                )) @_root
              (#eq? @_function "fprintf")
              (#set! nvim.injection-root @_root)
              (#set! injection.language "printf"))

            ((preproc_arg) @injection.content
              (#set! nvim.injection-root @injection.content)
              (#set! injection.language "c"))

            ((comment) @injection.content
              (#set! nvim.injection-root @injection.content)
              (#set! injection.language "comment"))

            ((comment) @injection.content
              (#set! nvim.injection-root @injection.content)
              (#match? @injection.content "/\\*!([a-zA-Z]+:)?re2c")
              (#set! injection.language "re2c"))

            ((comment) @injection.content
              (#set! nvim.injection-root @injection.content)
              (#lua-match? @injection.content "/[*\/][!*\/]<?[^a-zA-Z]")
              (#set! injection.language "doxygen"))
          ]=],
          lua = [=[
            ((function_call
              name: [
                (identifier) @_cdef_identifier
                (_ _ (identifier) @_cdef_identifier)
              ]
              arguments: (arguments (string content: _ @injection.content))) @_root
              (#set! nvim.injection-root @_root)
              (#set! injection.language "c")
              (#eq? @_cdef_identifier "cdef"))

            ((function_call
              name: (_) @_vimcmd_identifier
              arguments: (arguments
                (string content: _ @injection.content))) @_root
              (#set! nvim.injection-root @_root)
              (#set! injection.language "vim")
              (#eq? @_vimcmd_identifier "vim.cmd" "vim.api.nvim_command"))

            ((function_call
              name: (_) @_vimcmd_identifier
              arguments: (arguments (string content: _ @injection.content) .)) @_root
              (#set! nvim.injection-root @_root)
              (#set! injection.language "query")
              (#eq? @_vimcmd_identifier "vim.treesitter.query.set"))

            ((function_call
              name: (_) @_vimcmd_identifier
              arguments: (arguments
                . (_) . (string content: _ @_method) .
                (string content: _ @injection.content))) @_root
              (#any-of? @_vimcmd_identifier "vim.rpcrequest" "vim.rpcnotify")
              (#eq? @_method "nvim_exec_lua")
              (#set! nvim.injection-root @_root)
              (#set! injection.language "lua"))

            ; exec_lua [[ ... ]] in functionaltests
            ((function_call
              name: (identifier) @_function
              arguments: (arguments
                (string content: (string_content) @injection.content))) @_root
              (#eq? @_function "exec_lua")
              (#set! nvim.injection-root @_root)
              (#set! injection.language "lua"))
          ]=],
        },
      })
      parser:parse(true)

      local btime = vim.uv.hrtime()
      for i = 0, 99 do
        local off = i * 10
        vim.api.nvim_buf_set_text(0, off + 2, 8, off + 2, 8, { '12' })
        parser:parse(true)
        vim.api.nvim_buf_set_text(0, off + 7, 0, off + 7, 5, { 'test' })
        parser:parse(true)
      end
      local etime = vim.uv.hrtime()

      return etime - btime
    end)

    print('total (ms): ' .. string.format('%.2f', total_ns * 0.001 * 0.001))
  end)
end)
