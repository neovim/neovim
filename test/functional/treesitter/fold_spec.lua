local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local insert = n.insert
local exec_lua = n.exec_lua
local command = n.command
local feed = n.feed
local poke_eventloop = n.poke_eventloop

before_each(clear)

describe('treesitter foldexpr', function()
  clear()

  before_each(function()
    -- open folds to avoid deleting entire folded region
    exec_lua([[vim.opt.foldlevel = 9]])
  end)

  local test_text = [[
void ui_refresh(void)
{
  int width = INT_MAX, height = INT_MAX;
  bool ext_widgets[kUIExtCount];
  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {
    ext_widgets[i] = true;
  }

  bool inclusive = ui_override();
  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    width = MIN(ui->width, width);
    height = MIN(ui->height, height);
    foo = BAR(ui->bazaar, bazaar);
    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {
      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);
    }
  }
}]]

  local function parse(lang)
    exec_lua(
      ([[vim.treesitter.get_parser(0, %s):parse()]]):format(lang and '"' .. lang .. '"' or 'nil')
    )
  end

  local function get_fold_levels()
    return exec_lua([[
    local res = {}
    for i = 1, vim.api.nvim_buf_line_count(0) do
      res[i] = vim.treesitter.foldexpr(i)
    end
    return res
    ]])
  end

  it('can compute fold levels', function()
    insert(test_text)

    parse('c')

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '>2',
      [6] = '2',
      [7] = '2',
      [8] = '1',
      [9] = '1',
      [10] = '>2',
      [11] = '2',
      [12] = '2',
      [13] = '2',
      [14] = '2',
      [15] = '>3',
      [16] = '3',
      [17] = '3',
      [18] = '2',
      [19] = '1',
    }, get_fold_levels())
  end)

  it('recomputes fold levels after lines are added/removed', function()
    insert(test_text)

    parse('c')

    command('1,2d')
    poke_eventloop()

    eq({
      [1] = '0',
      [2] = '0',
      [3] = '>1',
      [4] = '1',
      [5] = '1',
      [6] = '0',
      [7] = '0',
      [8] = '>1',
      [9] = '1',
      [10] = '1',
      [11] = '1',
      [12] = '1',
      [13] = '>2',
      [14] = '2',
      [15] = '2',
      [16] = '1',
      [17] = '0',
    }, get_fold_levels())

    command('1put!')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '>2',
      [6] = '2',
      [7] = '2',
      [8] = '1',
      [9] = '1',
      [10] = '>2',
      [11] = '2',
      [12] = '2',
      [13] = '2',
      [14] = '2',
      [15] = '>3',
      [16] = '3',
      [17] = '3',
      [18] = '2',
      [19] = '1',
    }, get_fold_levels())
  end)

  it('handles changes close to start/end of folds', function()
    insert([[
# h1
t1
# h2
t2]])

    exec_lua([[vim.treesitter.query.set('markdown', 'folds', '(section) @fold')]])
    parse('markdown')

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>1',
      [4] = '1',
    }, get_fold_levels())

    feed('2ggo<Esc>')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '>1',
      [5] = '1',
    }, get_fold_levels())

    feed('dd')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>1',
      [4] = '1',
    }, get_fold_levels())

    feed('2ggdd')
    poke_eventloop()

    eq({
      [1] = '0',
      [2] = '>1',
      [3] = '1',
    }, get_fold_levels())

    feed('u')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>1',
      [4] = '1',
    }, get_fold_levels())

    feed('3ggdd')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
    }, get_fold_levels())

    feed('u')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>1',
      [4] = '1',
    }, get_fold_levels())

    feed('3ggI#<Esc>')
    parse()
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>2',
      [4] = '2',
    }, get_fold_levels())

    feed('x')
    parse()
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>1',
      [4] = '1',
    }, get_fold_levels())
  end)

  it('handles changes that trigger multiple on_bytes', function()
    insert([[
function f()
  asdf()
  asdf()
end
-- comment]])

    exec_lua(
      [[vim.treesitter.query.set('lua', 'folds', '[(function_declaration) (parameters) (arguments)] @fold')]]
    )
    parse('lua')

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '0',
    }, get_fold_levels())

    command('1,4join')
    poke_eventloop()

    eq({
      [1] = '0',
      [2] = '0',
    }, get_fold_levels())

    feed('u')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '0',
    }, get_fold_levels())
  end)

  it('handles multiple folds that overlap at the end and start', function()
    insert([[
function f()
  g(
    function()
      asdf()
    end, function()
    end
  )
end]])

    exec_lua(
      [[vim.treesitter.query.set('lua', 'folds', '[(function_declaration) (function_definition) (parameters) (arguments)] @fold')]]
    )
    parse('lua')

    -- If fold1.stop = fold2.start, then move fold1's stop up so that fold2.start gets proper level.
    eq({
      [1] = '>1',
      [2] = '>2',
      [3] = '>3',
      [4] = '3',
      [5] = '>3',
      [6] = '3',
      [7] = '2',
      [8] = '1',
    }, get_fold_levels())

    command('1,8join')
    feed('u')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '>2',
      [3] = '>3',
      [4] = '3',
      [5] = '>3',
      [6] = '3',
      [7] = '2',
      [8] = '1',
    }, get_fold_levels())
  end)

  it('handles multiple folds that start at the same line', function()
    insert([[
function f(a)
  if #(g({
    k = v,
  })) > 0 then
    return
  end
end]])

    exec_lua(
      [[vim.treesitter.query.set('lua', 'folds', '[(if_statement) (function_declaration) (parameters) (arguments) (table_constructor)] @fold')]]
    )
    parse('lua')

    eq({
      [1] = '>1',
      [2] = '>3',
      [3] = '3',
      [4] = '3',
      [5] = '2',
      [6] = '2',
      [7] = '1',
    }, get_fold_levels())

    command('2,6join')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
    }, get_fold_levels())

    feed('u')
    poke_eventloop()

    eq({
      [1] = '>1',
      [2] = '>3',
      [3] = '3',
      [4] = '3',
      [5] = '2',
      [6] = '2',
      [7] = '1',
    }, get_fold_levels())
  end)

  it('takes account of relevant options', function()
    insert([[
# h1
t1
## h2
t2
### h3
t3]])

    exec_lua([[vim.treesitter.query.set('markdown', 'folds', '(section) @fold')]])
    parse('markdown')

    command([[set foldminlines=2]])

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '>2',
      [4] = '2',
      [5] = '2',
      [6] = '2',
    }, get_fold_levels())

    command([[set foldminlines=1 foldnestmax=1]])

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '1',
      [6] = '1',
    }, get_fold_levels())
  end)

  it('handles quantified patterns', function()
    insert([[
import hello
import hello
import hello
import hello
import hello
import hello]])

    exec_lua([[vim.treesitter.query.set('python', 'folds', '(import_statement)+ @fold')]])
    parse('python')

    eq({
      [1] = '>1',
      [2] = '1',
      [3] = '1',
      [4] = '1',
      [5] = '1',
      [6] = '1',
    }, get_fold_levels())
  end)

  it('updates folds in all windows', function()
    local screen = Screen.new(60, 48)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue },
      [2] = { bold = true, foreground = Screen.colors.Blue1 },
      [3] = { bold = true, reverse = true },
      [4] = { reverse = true },
    })

    parse('c')
    command([[set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr() foldcolumn=1]])
    command('split')

    insert(test_text)

    screen:expect {
      grid = [[
      {1:-}void ui_refresh(void)                                      |
      {1:│}{                                                          |
      {1:│}  int width = INT_MAX, height = INT_MAX;                   |
      {1:│}  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:2}    ext_widgets[i] = true;                                 |
      {1:2}  }                                                        |
      {1:│}                                                           |
      {1:│}  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:2}    UI *ui = uis[i];                                       |
      {1:2}    width = MIN(ui->width, width);                         |
      {1:2}    height = MIN(ui->height, height);                      |
      {1:2}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:3}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:3}    }                                                      |
      {1:2}  }                                                        |
      {1:│}^}                                                          |
      {2:~                                                           }|*4
      {3:[No Name] [+]                                               }|
      {1:-}void ui_refresh(void)                                      |
      {1:│}{                                                          |
      {1:│}  int width = INT_MAX, height = INT_MAX;                   |
      {1:│}  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:2}    ext_widgets[i] = true;                                 |
      {1:2}  }                                                        |
      {1:│}                                                           |
      {1:│}  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:2}    UI *ui = uis[i];                                       |
      {1:2}    width = MIN(ui->width, width);                         |
      {1:2}    height = MIN(ui->height, height);                      |
      {1:2}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:3}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:3}    }                                                      |
      {1:2}  }                                                        |
      {1:│}}                                                          |
      {2:~                                                           }|*3
      {4:[No Name] [+]                                               }|
                                                                  |
    ]],
    }

    command('1,2d')

    screen:expect {
      grid = [[
      {1: }  ^int width = INT_MAX, height = INT_MAX;                   |
      {1: }  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:│}    ext_widgets[i] = true;                                 |
      {1:│}  }                                                        |
      {1: }                                                           |
      {1: }  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:│}    UI *ui = uis[i];                                       |
      {1:│}    width = MIN(ui->width, width);                         |
      {1:│}    height = MIN(ui->height, height);                      |
      {1:│}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:2}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:2}    }                                                      |
      {1:│}  }                                                        |
      {1: }}                                                          |
      {2:~                                                           }|*6
      {3:[No Name] [+]                                               }|
      {1: }  int width = INT_MAX, height = INT_MAX;                   |
      {1: }  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:│}    ext_widgets[i] = true;                                 |
      {1:│}  }                                                        |
      {1: }                                                           |
      {1: }  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:│}    UI *ui = uis[i];                                       |
      {1:│}    width = MIN(ui->width, width);                         |
      {1:│}    height = MIN(ui->height, height);                      |
      {1:│}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:2}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:2}    }                                                      |
      {1:│}  }                                                        |
      {1: }}                                                          |
      {2:~                                                           }|*5
      {4:[No Name] [+]                                               }|
                                                                  |
    ]],
    }

    feed([[O<C-u><C-r>"<BS><Esc>]])

    screen:expect {
      grid = [[
      {1:-}void ui_refresh(void)                                      |
      {1:│}^{                                                          |
      {1:│}  int width = INT_MAX, height = INT_MAX;                   |
      {1:│}  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:2}    ext_widgets[i] = true;                                 |
      {1:2}  }                                                        |
      {1:│}                                                           |
      {1:│}  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:2}    UI *ui = uis[i];                                       |
      {1:2}    width = MIN(ui->width, width);                         |
      {1:2}    height = MIN(ui->height, height);                      |
      {1:2}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:3}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:3}    }                                                      |
      {1:2}  }                                                        |
      {1:│}}                                                          |
      {2:~                                                           }|*4
      {3:[No Name] [+]                                               }|
      {1:-}void ui_refresh(void)                                      |
      {1:│}{                                                          |
      {1:│}  int width = INT_MAX, height = INT_MAX;                   |
      {1:│}  bool ext_widgets[kUIExtCount];                           |
      {1:-}  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {     |
      {1:2}    ext_widgets[i] = true;                                 |
      {1:2}  }                                                        |
      {1:│}                                                           |
      {1:│}  bool inclusive = ui_override();                          |
      {1:-}  for (size_t i = 0; i < ui_count; i++) {                  |
      {1:2}    UI *ui = uis[i];                                       |
      {1:2}    width = MIN(ui->width, width);                         |
      {1:2}    height = MIN(ui->height, height);                      |
      {1:2}    foo = BAR(ui->bazaar, bazaar);                         |
      {1:-}    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {   |
      {1:3}      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);      |
      {1:3}    }                                                      |
      {1:2}  }                                                        |
      {1:│}}                                                          |
      {2:~                                                           }|*3
      {4:[No Name] [+]                                               }|
                                                                  |
    ]],
    }
  end)

  it("doesn't open folds in diff mode", function()
    local screen = Screen.new(60, 36)
    screen:attach()

    parse('c')
    command(
      [[set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr() foldcolumn=1 foldlevel=9]]
    )
    insert(test_text)
    command('16d')

    command('new')
    insert(test_text)

    command('windo diffthis')
    feed('do')

    screen:expect {
      grid = [[
      {1:+ }{2:+--  9 lines: void ui_refresh(void)·······················}|
      {1:  }  for (size_t i = 0; i < ui_count; i++) {                 |
      {1:  }    UI *ui = uis[i];                                      |
      {1:  }    width = MIN(ui->width, width);                        |
      {1:  }    height = MIN(ui->height, height);                     |
      {1:  }    foo = BAR(ui->bazaar, bazaar);                        |
      {1:  }    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {  |
      {1:  }      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);     |
      {1:  }    }                                                     |
      {1:  }  }                                                       |
      {1:  }}                                                         |
      {3:~                                                           }|*6
      {4:[No Name] [+]                                               }|
      {1:+ }{2:+--  9 lines: void ui_refresh(void)·······················}|
      {1:  }  for (size_t i = 0; i < ui_count; i++) {                 |
      {1:  }    UI *ui = uis[i];                                      |
      {1:  }    width = MIN(ui->width, width);                        |
      {1:  }    height = MIN(ui->height, height);                     |
      {1:  }    foo = BAR(ui->bazaar, bazaar);                        |
      {1:  }    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {  |
      {1:  }      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);     |
      {1:  }    ^}                                                     |
      {1:  }  }                                                       |
      {1:  }}                                                         |
      {3:~                                                           }|*5
      {5:[No Name] [+]                                               }|
                                                                  |
    ]],
      attr_ids = {
        [1] = { background = Screen.colors.Grey, foreground = Screen.colors.Blue4 },
        [2] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Blue4 },
        [3] = { foreground = Screen.colors.Blue, bold = true },
        [4] = { reverse = true },
        [5] = { reverse = true, bold = true },
      },
    }
  end)

  it("doesn't open folds that are not touched", function()
    local screen = Screen.new(40, 8)
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Gray },
      [2] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGray },
      [3] = { foreground = Screen.colors.Blue1, bold = true },
      [4] = { bold = true },
    })
    screen:attach()

    insert([[
# h1
t1
# h2
t2]])
    exec_lua([[vim.treesitter.query.set('markdown', 'folds', '(section) @fold')]])
    parse('markdown')
    command(
      [[set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr() foldcolumn=1 foldlevel=0]]
    )

    feed('ggzojo')
    poke_eventloop()

    screen:expect {
      grid = [[
      {1:-}# h1                                   |
      {1:│}t1                                     |
      {1:│}^                                       |
      {1:+}{2:+--  2 lines: # h2·····················}|
      {3:~                                       }|*3
      {4:-- INSERT --}                            |
    ]],
    }

    feed('<Esc>u')
    -- TODO(tomtomjhj): `u` spuriously opens the fold (#26499).
    feed('zMggzo')

    feed('dd')
    poke_eventloop()

    screen:expect {
      grid = [[
      {1:-}^t1                                     |
      {1:-}# h2                                   |
      {1:│}t2                                     |
      {3:~                                       }|*4
      1 line less; before #2  {MATCH:.*}|
    ]],
    }
  end)
end)
