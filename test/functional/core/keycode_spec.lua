local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear

before_each(clear)

describe('vim.keycode()', function()
  local function parse(key, simplify)
    local parsed = exec_lua([[return select(2,vim.keycode(...,true))]], key)
    return vim.tbl_map(function(tbl)
      if simplify == 1 then
        return { tbl.mod, tbl.key }
      elseif simplify == 2 then
        return { tbl.mod, tbl.key, tbl.keys }
      end
      return tbl
    end, parsed)
  end

  it('gets structured keychord info', function()
    eq({ { mod = { 'M' }, key = 'f', keys = '<M-f>' } }, parse('<A-f>'))
    eq({ { { 'M' }, 'Home' } }, parse('<A-Home>', 1))
    eq({ { { 'M' }, 'f' }, { {}, 'b' }, { {}, 'c' } }, parse('<A-f>b<char-99>', 1))

    eq({ { { 'M' }, '>' } }, parse('<A->>', 1))
    eq({ { { 'M' }, 't_>>' } }, parse('<A-t_>>>', 1))

    -- Multiple modifiers, normalized to canonical order (mod_mask_table): M, T, C, S, …
    eq({ { mod = { 'C', 'S' }, key = 'Home', keys = '<C-S-Home>' } }, parse('<C-S-Home>'))
    eq({ { { 'M', 'C' }, 'x', '<M-C-X>' } }, parse('<M-C-x>', 2))
    eq({ { { 'M', 'C', 'S' }, 'F1', '<M-C-S-F1>' } }, parse('<C-A-S-F1>', 2))
  end)

  it('normalizes', function()
    -- stylua: ignore start
    eq({ { {},      '\\',   '<Bslash>'   } }, parse('\\', 2))
    eq({ { { 'M' }, '\\',   '<M-Bslash>' } }, parse('<A-\\>', 2))
    eq({ { { 'C' }, '\\',   '<C-\\>'     } }, parse('<C-\\>', 2))
    eq({ { {},      '|',    '<Bar>'      } }, parse('|', 2))
    eq({ { { 'M' }, '|',    '<M-Bar>'    } }, parse('<A-|>', 2))
    eq({ { { 'C' }, '|',    '<C-Bar>'    } }, parse('<C-|>', 2))
    eq({ { {},      '\127', '\127'       } }, parse('\127', 2))
    eq({ { { 'M' }, '\127', '<M-^?>'     } }, parse('<A-\127>', 2))
    eq({ { { 'C' }, '\127', '<C-^?>'     } }, parse('<C-\127>', 2))

    eq({ { {}, '<',    '<lt>'    } }, parse('<', 2))
    eq({ { {}, '\t',   '<Tab>'   } }, parse('\t', 2))
    eq({ { {}, '\r',   '<CR>'    } }, parse('\r', 2))
    eq({ { {}, '\n',   '<NL>'    } }, parse('\n', 2))
    eq({ { {}, '\27',  '<Esc>'   } }, parse('\27', 2))
    eq({ { {}, ' ',    '<Space>' } }, parse(' ', 2))

    eq({ { { 'S' }, 'a', 'A'     } }, parse('A', 2))
    eq({ { { 'C' }, 'a', '<C-A>' } }, parse('<C-a>', 2))
    -- stylua: ignore end

    eq({ { mod = {}, key = '<', keys = '<lt>', key_alt = 'lt' } }, parse('<'))
  end)

  it('utf8', function()
    eq({ { {}, 'ö' }, { { 'M' }, 'ó' }, { {}, 'ú' }, { {}, 'ü' } }, parse('ö<A-ó>úü', 1))
    eq({ { {}, 'a' }, { {}, '\226\129\129' }, { {}, 'b' } }, parse('a\226\129\129b', 1))
    eq({ { {}, 'a' }, { {}, '\242\129\129\129' }, { {}, 'b' } }, parse('a\242\129\129\129b', 1))
  end)

  -- Canonical notation: concatenating each chord's `keys` must equal keytrans(vim.keycode(…)).
  it('keys concatenate to keytrans()', function()
    for _, s in ipairs({
      '|',
      '\\',
      '<',
      '<A-|>',
      '<C-\\>',
      'A',
      '<C-a>',
      '<C-S-Home>ab',
      ' \t',
      'ö<A-ó>',
    }) do
      local concat, keytrans = exec_lua(function(k)
        local enc, chords = vim.keycode(k, true)
        local parts = vim.tbl_map(function(c)
          return c.keys
        end, chords)
        return table.concat(parts), vim.fn.keytrans(enc)
      end, s)
      eq(keytrans, concat)
    end
  end)
end)

describe('nvim_replace_termcodes', function()
  it('escapes K_SPECIAL as K_SPECIAL KS_SPECIAL KE_FILLER', function()
    eq('\128\254X', n.api.nvim_replace_termcodes('\128', true, true, true))
  end)

  it('leaves non-K_SPECIAL string unchanged', function()
    eq('abc', n.api.nvim_replace_termcodes('abc', true, true, true))
  end)

  it('converts <expressions>', function()
    eq('\\', n.api.nvim_replace_termcodes('<Leader>', true, true, true))
  end)

  it('converts <LeftMouse> to K_SPECIAL KS_EXTRA KE_LEFTMOUSE', function()
    -- K_SPECIAL KS_EXTRA KE_LEFTMOUSE
    -- 0x80      0xfd     0x2c
    -- 128       253      44
    eq('\128\253\44', n.api.nvim_replace_termcodes('<LeftMouse>', true, true, true))
  end)

  it('converts keycodes', function()
    eq('\nx\27x\rx<x', n.api.nvim_replace_termcodes('<NL>x<Esc>x<CR>x<lt>x', true, true, true))
  end)

  it('does not convert keycodes if special=false', function()
    eq(
      '<NL>x<Esc>x<CR>x<lt>x',
      n.api.nvim_replace_termcodes('<NL>x<Esc>x<CR>x<lt>x', true, true, false)
    )
  end)

  it('does not crash when transforming an empty string', function()
    -- Actually does not test anything, because current code will use NULL for
    -- an empty string.
    --
    -- Problem here is that if String argument has .data in allocated memory
    -- then `return str` in vim_replace_termcodes body will make Neovim free
    -- `str.data` twice: once when freeing arguments, then when freeing return
    -- value.
    eq('', n.api.nvim_replace_termcodes('', true, true, true))
  end)

  -- Not exactly the case, as nvim_replace_termcodes() escapes K_SPECIAL in Unicode
  it('translates the result of keytrans() on string with 0x80 byte back', function()
    local s = 'ff\128\253\097tt'
    eq(s, n.api.nvim_replace_termcodes(n.fn.keytrans(s), true, true, true))
  end)
end)
