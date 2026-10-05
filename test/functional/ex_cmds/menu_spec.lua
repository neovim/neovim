local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, command = n.clear, n.command
local expect, feed = n.expect, n.feed
local eq, eval = t.eq, n.eval
local fn = n.fn

describe(':emenu', function()
  before_each(function()
    clear()
    command('nnoremenu Test.Test inormal<ESC>')
    command('inoremenu Test.Test insert')
    command('vnoremenu Test.Test x')
    command('cnoremenu Test.Test cmdmode')

    command('nnoremenu Edit.Paste p')
    command('cnoremenu Edit.Paste <C-R>"')
  end)

  it('executes correct bindings in normal mode without using API', function()
    command('emenu Test.Test')
    expect('normal')
  end)

  it('executes correct bindings in normal mode', function()
    command('emenu Test.Test')
    expect('normal')
  end)

  it('executes correct bindings in insert mode', function()
    feed('i')
    command('emenu Test.Test')
    expect('insert')
  end)

  it('executes correct bindings in visual mode', function()
    feed('iabcde<ESC>0lvll')
    command('emenu Test.Test')
    expect('ae')
  end)

  it('executes correct bindings in command mode', function()
    feed('ithis is a sentence<esc>^yiwo<esc>')

    -- Invoke "Edit.Paste" in normal-mode.
    command('emenu Edit.Paste')

    -- Invoke "Edit.Paste" and "Test.Test" in command-mode.
    feed(':')
    command('emenu Edit.Paste')
    command('emenu Test.Test')

    expect([[
        this is a sentence
        this]])
    -- Assert that Edit.Paste pasted @" into the commandline.
    eq('thiscmdmode', eval('getcmdline()'))
  end)

  it('popup menu in visual mode via <C-o> from insert mode #19473', function()
    n.exec([[
      aunmenu *
      source $VIMRUNTIME/menu.vim
    ]])
    feed('itext<C-o>V')
    command('emenu PopUp.Cut')
    eq('', fn.getline(1))
    eq('text\n', fn.getreg('"'))
    eq('', n.api.nvim_get_vvar('errmsg'))
  end)
end)

local test_menus_cmd = [=[
  aunmenu *

  nnoremenu &Test.Test inormal<ESC>
  inoremenu Test.Test insert
  vnoremenu Test.Test x
  cnoremenu Test.Test cmdmode
  menu Test.Nested.test level1
  menu Test.Nested.Nested2 level2

  nnoremenu <script> Export.Script p
  tmenu Export.Script This is the tooltip
  menu ]Export.hidden thisoneshouldbehidden

  nnoremenu Edit.Paste p
  cnoremenu Edit.Paste <C-R>"
]=]

describe(':menu listing', function()
  before_each(function()
    clear()
    command(test_menus_cmd)
  end)

  it('matches by path argument', function()
    eq(
      [[
--- Menus ---
500 Edit
  500 Paste
      c*   <C-R>"]],
      n.exec_capture('cmenu Edit')
    )
    eq(
      [[
--- Menus ---
500 &Test
  500 Test
      n*   inormal<Esc>
  500 Nested
    500 test
        n    level1
    500 Nested2
        n    level2]],
      n.exec_capture('nmenu Test')
    )
    eq(
      [[
--- Menus ---
500 Nested
  500 test
      o    level1
  500 Nested2
      o    level2]],
      n.exec_capture('omenu Test.Nested')
    )
    eq(
      [[
--- Menus ---
500 Test
    n*   inormal<Esc>
    v*   x
    s*   x
    i*   insert
    c*   cmdmode]],
      n.exec_capture('amenu Test.Test')
    )
  end)
end)

local function menu_mapping(overrides)
  return vim.tbl_extend('force', {
    enabled = 1,
    sid = 0,
    silent = 0,
  }, overrides)
end

describe('menu_get', function()
  before_each(function()
    clear()
    command(test_menus_cmd)
  end)

  it("path='', modes='a'", function()
    local m = fn.menu_get('', 'a')
    -- HINT: To print the expected table and regenerate the tests:
    -- print(require('vim.inspect')(m))
    local expected = {
      {
        shortcut = 'T',
        hidden = 0,
        submenus = {
          {
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = 'insert' }),
              s = menu_mapping({ noremap = 1, rhs = 'x' }),
              n = menu_mapping({ noremap = 1, rhs = 'inormal<Esc>' }),
              v = menu_mapping({ noremap = 1, rhs = 'x' }),
              c = menu_mapping({ noremap = 1, rhs = 'cmdmode' }),
            },
            priority = 500,
            name = 'Test',
            hidden = 0,
          },
          {
            priority = 500,
            name = 'Nested',
            submenus = {
              {
                mappings = {
                  o = menu_mapping({ noremap = 0, rhs = 'level1' }),
                  v = menu_mapping({ noremap = 0, rhs = 'level1' }),
                  s = menu_mapping({ noremap = 0, rhs = 'level1' }),
                  n = menu_mapping({ noremap = 0, rhs = 'level1' }),
                },
                priority = 500,
                name = 'test',
                hidden = 0,
              },
              {
                mappings = {
                  o = menu_mapping({ noremap = 0, rhs = 'level2' }),
                  v = menu_mapping({ noremap = 0, rhs = 'level2' }),
                  s = menu_mapping({ noremap = 0, rhs = 'level2' }),
                  n = menu_mapping({ noremap = 0, rhs = 'level2' }),
                },
                priority = 500,
                name = 'Nested2',
                hidden = 0,
              },
            },
            hidden = 0,
          },
        },
        priority = 500,
        name = 'Test',
      },
      {
        priority = 500,
        name = 'Export',
        submenus = {
          {
            tooltip = 'This is the tooltip',
            hidden = 0,
            name = 'Script',
            priority = 500,
            mappings = {
              n = menu_mapping({ sid = 1, noremap = 0, rhs = 'p' }),
            },
          },
        },
        hidden = 0,
      },
      {
        priority = 500,
        name = 'Edit',
        submenus = {
          {
            mappings = {
              c = menu_mapping({ noremap = 1, rhs = '<C-R>"' }),
              n = menu_mapping({ noremap = 1, rhs = 'p' }),
            },
            priority = 500,
            name = 'Paste',
            hidden = 0,
          },
        },
        hidden = 0,
      },
      {
        priority = 500,
        name = ']Export',
        submenus = {
          {
            mappings = {
              o = menu_mapping({ noremap = 0, rhs = 'thisoneshouldbehidden' }),
              v = menu_mapping({ noremap = 0, rhs = 'thisoneshouldbehidden' }),
              s = menu_mapping({ noremap = 0, rhs = 'thisoneshouldbehidden' }),
              n = menu_mapping({ noremap = 0, rhs = 'thisoneshouldbehidden' }),
            },
            priority = 500,
            name = 'hidden',
            hidden = 0,
          },
        },
        hidden = 1,
      },
    }
    eq(expected, m)
  end)

  it('matching path, all modes', function()
    local m = fn.menu_get('Export', 'a')
    local expected = {
      {
        hidden = 0,
        name = 'Export',
        priority = 500,
        submenus = {
          {
            tooltip = 'This is the tooltip',
            hidden = 0,
            name = 'Script',
            priority = 500,
            mappings = {
              n = menu_mapping({ sid = 1, noremap = 0, rhs = 'p' }),
            },
          },
        },
      },
    }
    eq(expected, m)
  end)

  it('no path, matching modes', function()
    local m = fn.menu_get('', 'i')
    local expected = {
      {
        shortcut = 'T',
        hidden = 0,
        submenus = {
          {
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = 'insert' }),
            },
            priority = 500,
            name = 'Test',
            hidden = 0,
          },
        },
        priority = 500,
        name = 'Test',
      },
    }
    eq(expected, m)
  end)

  it('matching path and modes', function()
    local m = fn.menu_get('Test', 'i')
    local expected = {
      {
        shortcut = 'T',
        submenus = {
          {
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = 'insert' }),
            },
            priority = 500,
            name = 'Test',
            hidden = 0,
          },
        },
        priority = 500,
        name = 'Test',
        hidden = 0,
      },
    }
    eq(expected, m)
  end)
end)

describe('menu_get', function()
  before_each(function()
    clear()
    command('aunmenu *')
  end)

  it('returns <keycode> representation of special keys', function()
    command('nnoremenu &Test.Test inormal<ESC>')
    command('inoremenu &Test.Test2 <Tab><Esc>')
    command('vnoremenu &Test.Test3 yA<C-R>0<Tab>xyz<Esc>')
    command('inoremenu &Test.Test4 <c-r>*')
    command('inoremenu &Test.Test5 <c-R>+')
    command('nnoremenu &Test.Test6 <Nop>')
    command('nnoremenu &Test.Test7 <NOP>')
    command('nnoremenu &Test.Test8 <NoP>')
    command('nnoremenu &Test.Test9 ""')

    local m = fn.menu_get('')
    local expected = {
      {
        shortcut = 'T',
        hidden = 0,
        submenus = {
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = 'inormal<Esc>' }),
            },
            name = 'Test',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = '<Tab><Esc>' }),
            },
            name = 'Test2',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              s = menu_mapping({ noremap = 1, rhs = 'yA<C-R>0<Tab>xyz<Esc>' }),
              v = menu_mapping({ noremap = 1, rhs = 'yA<C-R>0<Tab>xyz<Esc>' }),
            },
            name = 'Test3',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = '<C-R>*' }),
            },
            name = 'Test4',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              i = menu_mapping({ noremap = 1, rhs = '<C-R>+' }),
            },
            name = 'Test5',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = '' }),
            },
            name = 'Test6',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = '' }),
            },
            name = 'Test7',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = '' }),
            },
            name = 'Test8',
            hidden = 0,
          },
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = '""' }),
            },
            name = 'Test9',
            hidden = 0,
          },
        },
        priority = 500,
        name = 'Test',
      },
    }

    eq(expected, m)
  end)

  it('works with right-aligned text and spaces', function()
    command('nnoremenu &Test<Tab>Y.Test<Tab>X\\ x inormal<Alt-j>')
    command('nnoremenu &Test\\ 1.Test\\ 2 Wargl')
    command('nnoremenu &Test4.Test<Tab>3 i space<Esc>')

    local m = fn.menu_get('')
    local expected = {
      {
        shortcut = 'T',
        hidden = 0,
        actext = 'Y',
        submenus = {
          {
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = 'inormal<Alt-j>' }),
            },
            hidden = 0,
            actext = 'X x',
            priority = 500,
            name = 'Test',
          },
        },
        priority = 500,
        name = 'Test',
      },
      {
        shortcut = 'T',
        hidden = 0,
        submenus = {
          {
            priority = 500,
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = 'Wargl' }),
            },
            name = 'Test 2',
            hidden = 0,
          },
        },
        priority = 500,
        name = 'Test 1',
      },
      {
        shortcut = 'T',
        hidden = 0,
        submenus = {
          {
            mappings = {
              n = menu_mapping({ noremap = 1, rhs = 'i space<Esc>' }),
            },
            hidden = 0,
            actext = '3',
            priority = 500,
            name = 'Test',
          },
        },
        priority = 500,
        name = 'Test4',
      },
    }

    eq(expected, m)
  end)

  it('stores terminal-mode mappings in `tl`', function()
    command('tlnoremenu &Test.Test bar')
    local mappings = fn.menu_get('', 'tl')[1].submenus[1].mappings
    -- "tl" is the mode designator for terminal mode, "t" is the one for a
    -- tooltip, so a terminal mapping must not land under "t".
    eq('bar', mappings.tl.rhs)
    eq(nil, mappings.t)
  end)
end)
