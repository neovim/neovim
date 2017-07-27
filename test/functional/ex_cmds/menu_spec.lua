local helpers = require('test.functional.helpers')(after_each)
local clear, command, nvim = helpers.clear, helpers.command, helpers.nvim
local expect, feed = helpers.expect, helpers.feed
local eq, eval = helpers.eq, helpers.eval
local funcs = helpers.funcs


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
      nvim('command', 'emenu Edit.Paste')

      -- Invoke "Edit.Paste" and "Test.Test" in command-mode.
      feed(':')
      nvim('command', 'emenu Edit.Paste')
      nvim('command', 'emenu Test.Test')

      expect([[
        this is a sentence
        this]])
      -- Assert that Edit.Paste pasted @" into the commandline.
      eq('thiscmdmode', eval('getcmdline()'))
  end)
end)

describe('menu_get', function()

  before_each(function()
    clear()
    command('nnoremenu &Test.Test inormal<ESC>')
    command('inoremenu Test.Test insert')
    command('vnoremenu Test.Test x')
    command('cnoremenu Test.Test cmdmode')
    command('menu Test.Nested.test level1')
    command('menu Test.Nested.Nested2 level2')

    command('nnoremenu <script> Export.Script p')
    command('tmenu Export.Script This is the tooltip')
    command('menu ]Export.hidden thisoneshouldbehidden')

    command('nnoremenu Edit.Paste p')
    command('cnoremenu Edit.Paste <C-R>"')
  end)

  it('no path, all modes', function()
    local m = funcs.menu_get("","a");
    -- You can use the following to print the expected table
    -- and regenerate the tests:
    -- local pretty = require('pl.pretty');
    -- print(pretty.dump(m))
    local expected = {
      {
        shortcut = "T",
        hidden = 0,
        submenus = {
          {
            mappings = {
              i = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "insert",
                silent = 0
              },
              s = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "x",
                silent = 0
              },
              n = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "inormal\27",
                silent = 0
              },
              v = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "x",
                silent = 0
              },
              c = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "cmdmode",
                silent = 0
              }
            },
            priority = 500,
            name = "Test",
            hidden = 0
          },
          {
            priority = 500,
            name = "Nested",
            submenus = {
              {
                mappings = {
                  o = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level1",
                    silent = 0
                  },
                  v = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level1",
                    silent = 0
                  },
                  s = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level1",
                    silent = 0
                  },
                  n = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level1",
                    silent = 0
                  }
                },
                priority = 500,
                name = "test",
                hidden = 0
              },
              {
                mappings = {
                  o = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level2",
                    silent = 0
                  },
                  v = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level2",
                    silent = 0
                  },
                  s = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level2",
                    silent = 0
                  },
                  n = {
                    sid = 0,
                    noremap = 0,
                    enabled = 1,
                    rhs = "level2",
                    silent = 0
                  }
                },
                priority = 500,
                name = "Nested2",
                hidden = 0
              }
            },
            hidden = 0
          }
        },
        priority = 500,
        name = "Test"
      },
      {
        priority = 500,
        name = "Export",
        submenus = {
          {
            tooltip = "This is the tooltip",
            hidden = 0,
            name = "Script",
            priority = 500,
            mappings = {
              n = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "p",
                silent = 0
              }
            }
          }
        },
        hidden = 0
      },
      {
        priority = 500,
        name = "Edit",
        submenus = {
          {
            mappings = {
              c = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "\18\"",
                silent = 0
              },
              n = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "p",
                silent = 0
              }
            },
            priority = 500,
            name = "Paste",
            hidden = 0
          }
        },
        hidden = 0
      },
      {
        priority = 500,
        name = "]Export",
        submenus = {
          {
            mappings = {
              o = {
                sid = 0,
                noremap = 0,
                enabled = 1,
                rhs = "thisoneshouldbehidden",
                silent = 0
              },
              v = {
                sid = 0,
                noremap = 0,
                enabled = 1,
                rhs = "thisoneshouldbehidden",
                silent = 0
              },
              s = {
                sid = 0,
                noremap = 0,
                enabled = 1,
                rhs = "thisoneshouldbehidden",
                silent = 0
              },
              n = {
                sid = 0,
                noremap = 0,
                enabled = 1,
                rhs = "thisoneshouldbehidden",
                silent = 0
              }
            },
            priority = 500,
            name = "hidden",
            hidden = 0
          }
        },
        hidden = 1
      }
    }
    eq(expected, m)
  end)

  it('matching path, default modes', function()
    local m = funcs.menu_get("Export", "a")
    local expected = {
      {
        tooltip = "This is the tooltip",
        hidden = 0,
        name = "Script",
        priority = 500,
        mappings = {
          n = {
            sid = 1,
            noremap = 1,
            enabled = 1,
            rhs = "p",
            silent = 0
          }
        }
      }
    }
    eq(expected, m)
  end)

  it('no path, matching modes', function()
    local m = funcs.menu_get("","i")
    local expected = {
      {
        shortcut = "T",
        hidden = 0,
        submenus = {
          {
            mappings = {
              i = {
                sid = 1,
                noremap = 1,
                enabled = 1,
                rhs = "insert",
                silent = 0
              }
            },
            priority = 500,
            name = "Test",
            hidden = 0
          },
          {
          }
        },
        priority = 500,
        name = "Test"
      }
    }
    eq(expected, m)
  end)

  it('matching path and modes', function()
    local m = funcs.menu_get("Test","i")
    local expected = {
      {
        mappings = {
          i = {
            sid = 1,
            noremap = 1,
            enabled = 1,
            rhs = "insert",
            silent = 0
          }
        },
        priority = 500,
        name = "Test",
        hidden = 0
      }
    }
    eq(expected, m)
  end)

end)
