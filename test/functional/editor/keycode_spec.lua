local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear

describe('vim.keycode() detailed info', function()
  before_each(clear)

  local function parse(key, simplify)
    local parsed = exec_lua([[return select(2,vim.keycode(...,true))]], key)
    return vim.tbl_map(function(tbl)
      if simplify == 1 then
        return { tbl.mod, tbl.key }
      elseif simplify == 2 then
        return { tbl.mod, tbl.key, tbl.key_raw }
      end
      return tbl
    end, parsed)
  end

  it('works', function()
    eq({ { mod = { 'M' }, key = 'f', key_raw = '<M-f>' } }, parse('<A-f>'))
    eq({ { { 'M' }, 'Home' } }, parse('<A-Home>', 1))
    eq({ { { 'M' }, 'f' }, { {}, 'b' }, { {}, 'c' } }, parse('<A-f>b<char-99>', 1))

    eq({ { { 'M' }, '>' } }, parse('<A->>', 1))
    eq({ { { 'M' }, 't_>>' } }, parse('<A-t_>>>', 1))
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

    eq({ { mod = {}, key = '<', key_raw = '<lt>', key_orig = 'lt' } }, parse('<'))
  end)

  it('handles utf8-chars', function()
    eq({ { {}, 'ö' }, { { 'M' }, 'ó' }, { {}, 'ú' }, { {}, 'ü' } }, parse('ö<A-ó>úü', 1))
    eq({ { {}, 'a' }, { {}, '\226\129\129' }, { {}, 'b' } }, parse('a\226\129\129b', 1))
    eq({ { {}, 'a' }, { {}, '\242\129\129\129' }, { {}, 'b' } }, parse('a\242\129\129\129b', 1))
  end)
end)
