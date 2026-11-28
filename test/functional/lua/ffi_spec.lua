local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each, pending = t.describe, t.it, t.before_each, t.pending
local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear

before_each(clear)

describe('ffi.cdef', function()
  it('nvim_strwidth respects the String length #33836', function()
    if not exec_lua("return pcall(require, 'ffi')") then
      pending('N/A: missing LuaJIT FFI')
    end

    eq(
      {},
      exec_lua(function()
        local ffi = require('ffi')
        ffi.cdef [[
        typedef struct { char *data; size_t size; } String;
        typedef struct {} Error;
        int64_t nvim_strwidth(String text, Error *err);
      ]]
        local failures = {}
        for _, text in ipairs({
          'abcd',
          'aのb',
          'éx',
          '❤️x',
          '🏳️‍⚧️x',
          '🧑‍🌾x',
          'a\0bc',
          '\t\n',
        }) do
          local data = ffi.new('char[?]', #text + 1, text)
          for size = 0, #text do
            local expected = vim.api.nvim_strwidth(text:sub(1, size))
            local actual = tonumber(ffi.C.nvim_strwidth(ffi.new('String', { data, size }), nil))
            if actual ~= expected then
              failures[#failures + 1] = { text, size, expected, actual }
            end
          end
        end
        return failures
      end)
    )

    eq(
      { 1, 0 },
      exec_lua(function()
        local ffi = require('ffi')
        local data = ffi.new('char[1]', { string.byte('a') })
        return {
          tonumber(ffi.C.nvim_strwidth(ffi.new('String', { data, 1 }), nil)),
          tonumber(ffi.C.nvim_strwidth(ffi.new('String', { nil, 0 }), nil)),
        }
      end)
    )
  end)

  it('can use Neovim core functions', function()
    if not exec_lua("return pcall(require, 'ffi')") then
      pending('N/A: missing LuaJIT FFI')
    end

    eq(
      12,
      exec_lua(function()
        local ffi = require('ffi')

        ffi.cdef [[
        typedef struct window_S win_T;
        int win_col_off(win_T *wp);
        extern win_T *curwin;
      ]]

        vim.cmd('set number numberwidth=4 signcolumn=yes:4')

        return ffi.C.win_col_off(ffi.C.curwin)
      end)
    )

    eq(
      20,
      exec_lua(function()
        local ffi = require('ffi')

        ffi.cdef [[
        typedef struct {} stl_hlrec_t;
        typedef struct {} StlClickRecord;
        typedef struct {} statuscol_T;
        typedef struct {} Error;
        typedef struct {
          char *data;
          size_t size;
        } CharBuf;

        win_T *find_window_by_handle(int Window, Error *err);

        int build_stl_str_hl(
          win_T *wp,
          CharBuf out,
          char *fmt,
          int opt_idx,
          int opt_scope,
          int fillchar,
          int maxwidth,
          stl_hlrec_t **hltab,
          size_t *hltab_len,
          StlClickRecord **tabtab,
          statuscol_T *scp
        );
      ]]

        local out = ffi.new('char[1024]')
        return ffi.C.build_stl_str_hl(
          ffi.C.find_window_by_handle(0, ffi.new('Error')),
          ffi.new('CharBuf', { out, ffi.sizeof(out) }),
          ffi.cast('char*', 'StatusLineOfLength20'),
          -1,
          0,
          0,
          0,
          nil,
          nil,
          nil,
          nil
        )
      end)
    )

    -- Check that extern symbols are exported and accessible
    eq(
      true,
      exec_lua(function()
        local ffi = require('ffi')

        ffi.cdef('uint64_t display_tick;')

        return ffi.C.display_tick >= 0
      end)
    )
  end)
end)
