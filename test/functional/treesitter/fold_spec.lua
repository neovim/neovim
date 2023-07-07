local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local command = helpers.command
local feed = helpers.feed
local Screen = require('test.functional.ui.screen')

before_each(clear)

describe('treesitter foldexpr', function()
  clear()

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

  local function get_fold_levels()
    return exec_lua([[
    local res = {}
    for i = 1, vim.api.nvim_buf_line_count(0) do
      res[i] = vim.treesitter.foldexpr(i)
    end
    return res
    ]])
  end

  it("can compute fold levels", function()
    insert(test_text)

    exec_lua([[vim.treesitter.get_parser(0, "c")]])

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
      [19] = '1' }, get_fold_levels())

  end)

  it("recomputes fold levels after lines are added/removed", function()
    insert(test_text)

    exec_lua([[vim.treesitter.get_parser(0, "c")]])

    command('1,2d')

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
      [17] = '0' }, get_fold_levels())

    command('1put!')

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
      [19] = '1' }, get_fold_levels())
  end)

  it("updates folds in all windows", function()
    local screen = Screen.new(60, 48)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue};
      [2] = {bold = true, foreground = Screen.colors.Blue1};
      [3] = {bold = true, reverse = true};
      [4] = {reverse = true};
    })

    exec_lua([[vim.treesitter.get_parser(0, "c")]])
    command([[set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr() foldcolumn=1 foldlevel=9]])
    command('split')

    insert(test_text)

    screen:expect{grid=[[
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {4:[No Name] [+]                                               }|
                                                                  |
    ]]}

    command('1,2d')

    screen:expect{grid=[[
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {4:[No Name] [+]                                               }|
                                                                  |
    ]]}


    feed([[O<C-u><C-r>"<BS><Esc>]])

    screen:expect{grid=[[
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
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
      {2:~                                                           }|
      {2:~                                                           }|
      {2:~                                                           }|
      {4:[No Name] [+]                                               }|
                                                                  |
    ]]}

  end)

  it("doesn't open folds in diff mode", function()
    local screen = Screen.new(60, 36)
    screen:attach()

    exec_lua([[vim.treesitter.get_parser(0, "c")]])
    command([[set foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr() foldcolumn=1 foldlevel=9]])
    insert(test_text)
    command('16d')

    command('new')
    insert(test_text)

    command('windo diffthis')
    feed('do')

    screen:expect{grid=[[
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
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
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
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {5:[No Name] [+]                                               }|
                                                                  |
    ]], attr_ids={
      [1] = {background = Screen.colors.Grey, foreground = Screen.colors.Blue4};
      [2] = {background = Screen.colors.LightGrey, foreground = Screen.colors.Blue4};
      [3] = {foreground = Screen.colors.Blue, bold = true};
      [4] = {reverse = true};
      [5] = {reverse = true, bold = true};
    }}
  end)

end)
