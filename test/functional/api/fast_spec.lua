local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua

describe('|api-fast| functions', function()
  before_each(clear)

  it('callable in a fast event', function()
    local out = exec_lua(function()
      local result
      local timer = assert(vim.uv.new_timer())
      timer:start(0, 0, function()
        timer:close()
        local ok
        ok, result = pcall(function()
          return {
            byteidx = vim.fn.byteidx('héllo', 2),
            char2nr = vim.fn.char2nr('A'),
            charidx = vim.fn.charidx('héllo', 3),
            in_fast = vim.in_fast_event(),
            keycode = vim.keycode('<C-a>'),
            keytrans = vim.fn.keytrans(vim.keycode('<C-Home>')),
            nr2char = vim.fn.nr2char(65),
            nvim_create_autocmd = vim.api.nvim_create_autocmd('User', {
              pattern = 'Fast',
              callback = function() end,
            }) > 0,
            nvim_replace_termcodes = vim.api.nvim_replace_termcodes('<Esc>', true, true, true),
            str2list = vim.fn.str2list('AB'),
            strcharlen = vim.fn.strcharlen('abc'),
            strcharpart = vim.fn.strcharpart('héllo', 1, 2),
            strchars = vim.fn.strchars('abc'),
            strdisplaywidth = vim.fn.strdisplaywidth('ab'),
            strgetchar = vim.fn.strgetchar('abc', 1),
            strlen = vim.fn.strlen('abc'),
            strpart = vim.fn.strpart('abcdef', 1, 3),
            strtrans = vim.fn.strtrans('a\001b'),
            tr = vim.fn.tr('abc', 'ab', 'AB'),
            trim = vim.fn.trim('  x  '),
            utf16idx = vim.fn.utf16idx('abc', 2),
          }
        end)
      end)
      vim.wait(2000, function()
        return result ~= nil
      end)
      return result
    end)
    eq({
      byteidx = 3,
      char2nr = 65,
      charidx = 2,
      in_fast = true,
      keycode = '\1', -- <C-a>
      keytrans = '<C-Home>',
      nr2char = 'A',
      nvim_create_autocmd = true,
      nvim_replace_termcodes = '\27', -- <Esc>
      str2list = { 65, 66 },
      strcharlen = 3,
      strcharpart = 'él',
      strchars = 3,
      strdisplaywidth = 2,
      strgetchar = 98,
      strlen = 3,
      strpart = 'bcd',
      strtrans = 'a^Ab',
      tr = 'ABc',
      trim = 'x',
      utf16idx = 2,
    }, out)
  end)

  it('do not trigger os_breakcheck()', function()
    local res = exec_lua(function()
      local polls = 0
      -- os_breakcheck() polls the event loop (loop_poll_events), which fires a uv_check handle.
      local chk = assert(vim.uv.new_check())
      chk:start(function()
        polls = polls + 1
      end)
      local function polled(fn)
        polls = 0
        fn()
        return polls ~= 0
      end

      -- Big (multibyte) input => per-char breakcheck would exceed BREAKCHECK_SKIP (1000, or 100_000
      -- for `veryfast_breakcheck`). Small input could pass (false negative).
      local big = ('héllo wörld '):rep(100000) -- 1.2M chars.

      local aupat = ('a'):rep(80000) -- Must stay under the "E339: Pattern too long" limit.
      vim.api.nvim_create_autocmd('User', { pattern = aupat, callback = function() end })

      local cases = {
        byteidx = function()
          vim.fn.byteidx(big, 500000)
        end,
        char2nr = function()
          vim.fn.char2nr('A')
        end,
        charidx = function()
          vim.fn.charidx(big, 500000)
        end,
        keycode = function()
          vim.keycode('<C-a>')
        end,
        keytrans = function()
          vim.fn.keytrans(vim.keycode('<C-Home>'))
        end,
        nr2char = function()
          vim.fn.nr2char(65)
        end,
        nvim_create_autocmd = function()
          vim.api.nvim_exec_autocmds('User', { pattern = aupat })
        end,
        nvim_replace_termcodes = function()
          vim.api.nvim_replace_termcodes('<Esc>', true, true, true)
        end,
        str2list = function()
          vim.fn.str2list(big)
        end,
        strcharlen = function()
          vim.fn.strcharlen(big)
        end,
        strcharpart = function()
          vim.fn.strcharpart(big, 1, 2)
        end,
        strchars = function()
          vim.fn.strchars(big)
        end,
        strdisplaywidth = function()
          vim.fn.strdisplaywidth(big)
        end,
        strgetchar = function()
          vim.fn.strgetchar(big, 500000)
        end,
        strlen = function()
          vim.fn.strlen(big)
        end,
        strpart = function()
          vim.fn.strpart(big, 1, 3)
        end,
        strtrans = function()
          vim.fn.strtrans(big)
        end,
        tr = function()
          vim.fn.tr(big, 'ho', 'HO')
        end,
        trim = function()
          vim.fn.trim(big)
        end,
        utf16idx = function()
          vim.fn.utf16idx(big, 500000)
        end,
      }

      local bad = {}
      for name, fn in pairs(cases) do
        if polled(fn) then
          bad[#bad + 1] = name
        end
      end
      table.sort(bad)

      -- Positive control: a big Vimscript loop calls line_breakcheck() every iteration.
      local control = polled(function()
        vim.api.nvim_exec2('for i in range(1500000)|endfor', {})
      end)

      chk:stop()
      chk:close()
      return { bad = bad, control = control }
    end)

    eq(true, res.control) -- Confirm our detector actually works: breakcheck was seen.
    eq({}, res.bad) -- No api-fast function polled the event-loop.
  end)
end)
