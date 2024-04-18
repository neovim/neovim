local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')

local clear = t.clear
local insert = t.insert
local exec_lua = t.exec_lua
local feed = t.feed
local command = t.command
local api = t.api
local eq = t.eq

before_each(clear)

local hl_query_c = [[
  (ERROR) @error

  "if" @keyword
  "else" @keyword
  "for" @keyword
  "return" @keyword

  "const" @type
  "static" @type
  "struct" @type
  "enum" @type
  "extern" @type

  ; nonexistent specializer for string should fallback to string
  (string_literal) @string.nonexistent_specializer

  (number_literal) @number
  (char_literal) @string

  (type_identifier) @type
  ((type_identifier) @constant.builtin (#eq? @constant.builtin "LuaRef"))

  (primitive_type) @type
  (sized_type_specifier) @type

  ; Use lua regexes
  ((identifier) @function (#contains? @function "lua_"))
  ((identifier) @Constant (#lua-match? @Constant "^[A-Z_]+$"))
  ((identifier) @Normal (#vim-match? @Normal "^lstate$"))

  ((binary_expression left: (identifier) @warning.left right: (identifier) @warning.right) (#eq? @warning.left @warning.right))

  (comment) @comment
]]

local hl_text_c = [[
/// Schedule Lua callback on main loop's event queue
static int nlua_schedule(lua_State *const lstate)
{
  if (lua_type(lstate, 1) != LUA_TFUNCTION
      || lstate != lstate) {
    lua_pushliteral(lstate, "vim.schedule: expected function");
    return lua_error(lstate);
  }

  LuaRef cb = nlua_ref(lstate, 1);

  multiqueue_put(main_loop.events, nlua_schedule_event,
                 1, (void *)(ptrdiff_t)cb);
  return 0;
}]]

local test_text_c = [[
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

local injection_text_c = [[
int x = INT_MAX;
#define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
#define foo void main() { \
              return 42;  \
            }
]]

local injection_grid_c = [[
  int x = INT_MAX;                                                 |
  #define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))  |
  #define foo void main() { \                                      |
                return 42;  \                                      |
              }                                                    |
  ^                                                                 |
  {1:~                                                                }|*11
                                                                   |
]]

local injection_grid_expected_c = [[
  {3:int} x = {5:INT_MAX};                                                 |
  #define {5:READ_STRING}(x, y) ({3:char} *)read_string((x), ({3:size_t})(y))  |
  #define foo {3:void} main() { \                                      |
                {4:return} {5:42};  \                                      |
              }                                                    |
  ^                                                                 |
  {1:~                                                                }|*11
                                                                   |
]]

describe('treesitter highlighting (C)', function()
  local screen

  before_each(function()
    screen = Screen.new(65, 18)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Blue1 },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [4] = { bold = true, foreground = Screen.colors.Brown },
      [5] = { foreground = Screen.colors.Magenta },
      [6] = { foreground = Screen.colors.Red },
      [7] = { bold = true, foreground = Screen.colors.SlateBlue },
      [8] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [9] = { foreground = Screen.colors.Magenta, background = Screen.colors.Red },
      [10] = { foreground = Screen.colors.Red, background = Screen.colors.Red },
      [11] = { foreground = Screen.colors.Cyan4 },
    }

    exec_lua([[ hl_query = ... ]], hl_query_c)
    command [[ hi link @error ErrorMsg ]]
    command [[ hi link @warning WarningMsg ]]
  end)

  it('is updated with edits', function()
    insert(hl_text_c)
    screen:expect {
      grid = [[
      /// Schedule Lua callback on main loop's event queue             |
      static int nlua_schedule(lua_State *const lstate)                |
      {                                                                |
        if (lua_type(lstate, 1) != LUA_TFUNCTION                       |
            || lstate != lstate) {                                     |
          lua_pushliteral(lstate, "vim.schedule: expected function");  |
          return lua_error(lstate);                                    |
        }                                                              |
                                                                       |
        LuaRef cb = nlua_ref(lstate, 1);                               |
                                                                       |
        multiqueue_put(main_loop.events, nlua_schedule_event,          |
                       1, (void *)(ptrdiff_t)cb);                      |
        return 0;                                                      |
      ^}                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = hl_query}})
    ]]
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
        {4:if} ({11:lua_type}(lstate, {5:1}) != {5:LUA_TFUNCTION}                       |
            || {6:lstate} != {6:lstate}) {                                     |
          {11:lua_pushliteral}(lstate, {5:"vim.schedule: expected function"});  |
          {4:return} {11:lua_error}(lstate);                                    |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      ^}                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }

    feed('5Goc<esc>dd')

    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
        {4:if} ({11:lua_type}(lstate, {5:1}) != {5:LUA_TFUNCTION}                       |
            || {6:lstate} != {6:lstate}) {                                     |
          {11:^lua_pushliteral}(lstate, {5:"vim.schedule: expected function"});  |
          {4:return} {11:lua_error}(lstate);                                    |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      }                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }

    feed('7Go*/<esc>')
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
        {4:if} ({11:lua_type}(lstate, {5:1}) != {5:LUA_TFUNCTION}                       |
            || {6:lstate} != {6:lstate}) {                                     |
          {11:lua_pushliteral}(lstate, {5:"vim.schedule: expected function"});  |
          {4:return} {11:lua_error}(lstate);                                    |
      {8:*^/}                                                               |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      }                                                                |
      {1:~                                                                }|
                                                                       |
    ]],
    }

    feed('3Go/*<esc>')
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
      {2:/^*}                                                               |
      {2:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
      {2:      || lstate != lstate) {}                                     |
      {2:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
      {2:    return lua_error(lstate);}                                    |
      {2:*/}                                                               |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      {8:}}                                                                |
                                                                       |
    ]],
    }

    feed('gg$')
    feed('~')
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queu^E}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
      {2:/*}                                                               |
      {2:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
      {2:      || lstate != lstate) {}                                     |
      {2:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
      {2:    return lua_error(lstate);}                                    |
      {2:*/}                                                               |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      {8:}}                                                                |
                                                                       |
    ]],
    }

    feed('re')
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queu^e}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
      {2:/*}                                                               |
      {2:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
      {2:      || lstate != lstate) {}                                     |
      {2:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
      {2:    return lua_error(lstate);}                                    |
      {2:*/}                                                               |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      {8:}}                                                                |
                                                                       |
    ]],
    }
  end)

  it('is updated with :sort', function()
    insert(test_text_c)
    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query}})
    ]]
    screen:expect {
      grid = [[
        {3:int} width = {5:INT_MAX}, height = {5:INT_MAX};                         |
        {3:bool} ext_widgets[kUIExtCount];                                 |
        {4:for} ({3:UIExtension} i = {5:0}; ({3:int})i < kUIExtCount; i++) {           |
          ext_widgets[i] = true;                                       |
        }                                                              |
                                                                       |
        {3:bool} inclusive = ui_override();                                |
        {4:for} ({3:size_t} i = {5:0}; i < ui_count; i++) {                        |
          {3:UI} *ui = uis[i];                                             |
          width = {5:MIN}(ui->width, width);                               |
          height = {5:MIN}(ui->height, height);                            |
          foo = {5:BAR}(ui->bazaar, bazaar);                               |
          {4:for} ({3:UIExtension} j = {5:0}; ({3:int})j < kUIExtCount; j++) {         |
            ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
          }                                                            |
        }                                                              |
      ^}                                                                |
                                                                       |
    ]],
    }

    feed ':sort<cr>'
    screen:expect {
      grid = [[
      ^                                                                 |
            ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
          {3:UI} *ui = uis[i];                                             |
          ext_widgets[i] = true;                                       |
          foo = {5:BAR}(ui->bazaar, bazaar);                               |
          {4:for} ({3:UIExtension} j = {5:0}; ({3:int})j < kUIExtCount; j++) {         |
          height = {5:MIN}(ui->height, height);                            |
          width = {5:MIN}(ui->width, width);                               |
          }                                                            |
        {3:bool} ext_widgets[kUIExtCount];                                 |
        {3:bool} inclusive = ui_override();                                |
        {4:for} ({3:UIExtension} i = {5:0}; ({3:int})i < kUIExtCount; i++) {           |
        {4:for} ({3:size_t} i = {5:0}; i < ui_count; i++) {                        |
        {3:int} width = {5:INT_MAX}, height = {5:INT_MAX};                         |
        }                                                              |*2
      {3:void} ui_refresh({3:void})                                            |
      :sort                                                            |
    ]],
    }

    feed 'u'

    screen:expect {
      grid = [[
        {3:int} width = {5:INT_MAX}, height = {5:INT_MAX};                         |
        {3:bool} ext_widgets[kUIExtCount];                                 |
        {4:for} ({3:UIExtension} i = {5:0}; ({3:int})i < kUIExtCount; i++) {           |
          ext_widgets[i] = true;                                       |
        }                                                              |
                                                                       |
        {3:bool} inclusive = ui_override();                                |
        {4:for} ({3:size_t} i = {5:0}; i < ui_count; i++) {                        |
          {3:UI} *ui = uis[i];                                             |
          width = {5:MIN}(ui->width, width);                               |
          height = {5:MIN}(ui->height, height);                            |
          foo = {5:BAR}(ui->bazaar, bazaar);                               |
          {4:for} ({3:UIExtension} j = {5:0}; ({3:int})j < kUIExtCount; j++) {         |
            ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
          }                                                            |
        }                                                              |
      ^}                                                                |
      19 changes; before #2  {MATCH:.*}|
    ]],
    }
  end)

  it('supports with custom parser', function()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    }

    insert(test_text_c)

    screen:expect {
      grid = [[
      int width = INT_MAX, height = INT_MAX;                         |
      bool ext_widgets[kUIExtCount];                                 |
      for (UIExtension i = 0; (int)i < kUIExtCount; i++) {           |
        ext_widgets[i] = true;                                       |
      }                                                              |
                                                                     |
      bool inclusive = ui_override();                                |
      for (size_t i = 0; i < ui_count; i++) {                        |
        UI *ui = uis[i];                                             |
        width = MIN(ui->width, width);                               |
        height = MIN(ui->height, height);                            |
        foo = BAR(ui->bazaar, bazaar);                               |
        for (UIExtension j = 0; (int)j < kUIExtCount; j++) {         |
          ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
        }                                                            |
      }                                                              |
    ^}                                                                |
                                                                     |
    ]],
    }

    exec_lua [[
      parser = vim.treesitter.get_parser(0, "c")
      query = vim.treesitter.query.parse("c", "(declaration) @decl")

      local nodes = {}
      for _, node in query:iter_captures(parser:parse()[1]:root(), 0, 0, 19) do
        table.insert(nodes, node)
      end

      parser:set_included_regions({nodes})

      local hl = vim.treesitter.highlighter.new(parser, {queries = {c = "(identifier) @type"}})
    ]]

    screen:expect {
      grid = [[
      int {1:width} = {1:INT_MAX}, {1:height} = {1:INT_MAX};                         |
      bool {1:ext_widgets}[{1:kUIExtCount}];                                 |
      for (UIExtension {1:i} = 0; (int)i < kUIExtCount; i++) {           |
        ext_widgets[i] = true;                                       |
      }                                                              |
                                                                     |
      bool {1:inclusive} = {1:ui_override}();                                |
      for (size_t {1:i} = 0; i < ui_count; i++) {                        |
        UI *{1:ui} = {1:uis}[{1:i}];                                             |
        width = MIN(ui->width, width);                               |
        height = MIN(ui->height, height);                            |
        foo = BAR(ui->bazaar, bazaar);                               |
        for (UIExtension {1:j} = 0; (int)j < kUIExtCount; j++) {         |
          ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
        }                                                            |
      }                                                              |
    ^}                                                                |
                                                                     |
    ]],
    }
  end)

  it('supports injected languages', function()
    insert(injection_text_c)

    screen:expect { grid = injection_grid_c }

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c", {
        injections = {c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'}
      })
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = hl_query}})
    ]]

    screen:expect { grid = injection_grid_expected_c }
  end)

  it("supports injecting by ft name in metadata['injection.language']", function()
    insert(injection_text_c)

    screen:expect { grid = injection_grid_c }

    exec_lua [[
      vim.treesitter.language.register("c", "foo")
      local parser = vim.treesitter.get_parser(0, "c", {
        injections = {c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "fOO")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "fOO"))'}
      })
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = hl_query}})
    ]]

    screen:expect { grid = injection_grid_expected_c }
  end)

  it('supports overriding queries, like ', function()
    insert([[
    int x = INT_MAX;
    #define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
    #define foo void main() { \
                  return 42;  \
                }
    ]])

    exec_lua [[
      local injection_query = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
      vim.treesitter.query.set("c", "highlights", hl_query)
      vim.treesitter.query.set("c", "injections", injection_query)

      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, "c"))
    ]]

    screen:expect {
      grid = [[
      {3:int} x = {5:INT_MAX};                                                 |
      #define {5:READ_STRING}(x, y) ({3:char} *)read_string((x), ({3:size_t})(y))  |
      #define foo {3:void} main() { \                                      |
                    {4:return} {5:42};  \                                      |
                  }                                                    |
      ^                                                                 |
      {1:~                                                                }|*11
                                                                       |
    ]],
    }
  end)

  it('supports highlighting with custom highlight groups', function()
    insert(hl_text_c)

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query}})
    ]]

    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
        {4:if} ({11:lua_type}(lstate, {5:1}) != {5:LUA_TFUNCTION}                       |
            || {6:lstate} != {6:lstate}) {                                     |
          {11:lua_pushliteral}(lstate, {5:"vim.schedule: expected function"});  |
          {4:return} {11:lua_error}(lstate);                                    |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      ^}                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }

    -- This will change ONLY the literal strings to look like comments
    -- The only literal string is the "vim.schedule: expected function" in this test.
    exec_lua [[vim.cmd("highlight link @string.nonexistent_specializer comment")]]
    screen:expect {
      grid = [[
      {2:/// Schedule Lua callback on main loop's event queue}             |
      {3:static} {3:int} {11:nlua_schedule}({3:lua_State} *{3:const} lstate)                |
      {                                                                |
        {4:if} ({11:lua_type}(lstate, {5:1}) != {5:LUA_TFUNCTION}                       |
            || {6:lstate} != {6:lstate}) {                                     |
          {11:lua_pushliteral}(lstate, {2:"vim.schedule: expected function"});  |
          {4:return} {11:lua_error}(lstate);                                    |
        }                                                              |
                                                                       |
        {7:LuaRef} cb = {11:nlua_ref}(lstate, {5:1});                               |
                                                                       |
        multiqueue_put(main_loop.events, {11:nlua_schedule_event},          |
                       {5:1}, ({3:void} *)({3:ptrdiff_t})cb);                      |
        {4:return} {5:0};                                                      |
      ^}                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }
    screen:expect { unchanged = true }
  end)

  it('supports highlighting with priority', function()
    insert([[
    int x = INT_MAX;
    #define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
    #define foo void main() { \
                  return 42;  \
                }
    ]])

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query..'\n((translation_unit) @constant (#set! "priority" 101))\n'}})
    ]]
    -- expect everything to have Constant highlight
    screen:expect {
      grid = [[
      {12:int}{8: x = INT_MAX;}                                                 |
      {8:#define READ_STRING(x, y) (}{12:char}{8: *)read_string((x), (}{12:size_t}{8:)(y))}  |
      {8:#define foo }{12:void}{8: main() { \}                                      |
      {8:              }{12:return}{8: 42;  \}                                      |
      {8:            }}                                                    |
      ^                                                                 |
      {1:~                                                                }|*11
                                                                       |
    ]],
      attr_ids = {
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [8] = { foreground = Screen.colors.Magenta1 },
        -- bold will not be overwritten at the moment
        [12] = { bold = true, foreground = Screen.colors.Magenta1 },
      },
    }

    eq({
      { capture = 'constant', metadata = { priority = '101' }, lang = 'c' },
      { capture = 'type', metadata = {}, lang = 'c' },
    }, exec_lua [[ return vim.treesitter.get_captures_at_pos(0, 0, 2) ]])
  end)

  it(
    "allows to use captures with dots (don't use fallback when specialization of foo exists)",
    function()
      insert([[
    char* x = "Will somebody ever read this?";
    ]])

      screen:expect {
        grid = [[
      char* x = "Will somebody ever read this?";                       |
      ^                                                                 |
      {1:~                                                                }|*15
                                                                       |
    ]],
      }

      command [[
      hi link @foo.bar Type
      hi link @foo String
    ]]
      exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c", {})
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = "(primitive_type) @foo.bar (string_literal) @foo"}})
    ]]

      screen:expect {
        grid = [[
      {3:char}* x = {5:"Will somebody ever read this?"};                       |
      ^                                                                 |
      {1:~                                                                }|*15
                                                                       |
    ]],
      }

      -- clearing specialization reactivates fallback
      command [[ hi clear @foo.bar ]]
      screen:expect {
        grid = [[
      {5:char}* x = {5:"Will somebody ever read this?"};                       |
      ^                                                                 |
      {1:~                                                                }|*15
                                                                       |
    ]],
      }
    end
  )

  it('supports conceal attribute', function()
    insert(hl_text_c)

    -- conceal can be empty or a single cchar.
    exec_lua [=[
      vim.opt.cole = 2
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = [[
        ("static" @keyword
         (#set! conceal "R"))

        ((identifier) @Identifier
         (#set! conceal "")
         (#eq? @Identifier "lstate"))

        ((call_expression
            function: (identifier) @function
            arguments: (argument_list) @arguments)
         (#eq? @function "multiqueue_put")
         (#set! @function conceal "V"))
      ]]}})
    ]=]

    screen:expect {
      grid = [[
      /// Schedule Lua callback on main loop's event queue             |
      {4:R} int nlua_schedule(lua_State *const )                           |
      {                                                                |
        if (lua_type(, 1) != LUA_TFUNCTION                             |
            ||  != ) {                                                 |
          lua_pushliteral(, "vim.schedule: expected function");        |
          return lua_error();                                          |
        }                                                              |
                                                                       |
        LuaRef cb = nlua_ref(, 1);                                     |
                                                                       |
        {11:V}(main_loop.events, nlua_schedule_event,                       |
                       1, (void *)(ptrdiff_t)cb);                      |
        return 0;                                                      |
      ^}                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }
  end)

  it('@foo.bar groups has the correct fallback behavior', function()
    local get_hl = function(name)
      return api.nvim_get_hl_by_name(name, 1).foreground
    end
    api.nvim_set_hl(0, '@foo', { fg = 1 })
    api.nvim_set_hl(0, '@foo.bar', { fg = 2 })
    api.nvim_set_hl(0, '@foo.bar.baz', { fg = 3 })

    eq(1, get_hl '@foo')
    eq(1, get_hl '@foo.a.b.c.d')
    eq(2, get_hl '@foo.bar')
    eq(2, get_hl '@foo.bar.a.b.c.d')
    eq(3, get_hl '@foo.bar.baz')
    eq(3, get_hl '@foo.bar.baz.d')

    -- lookup is case insensitive
    eq(2, get_hl '@FOO.BAR.SPAM')

    api.nvim_set_hl(0, '@foo.missing.exists', { fg = 3 })
    eq(1, get_hl '@foo.missing')
    eq(3, get_hl '@foo.missing.exists')
    eq(3, get_hl '@foo.missing.exists.bar')
    eq(nil, get_hl '@total.nonsense.but.a.lot.of.dots')
  end)

  it('supports multiple nodes assigned to the same capture #17060', function()
    insert([[
      int x = 4;
      int y = 5;
      int z = 6;
    ]])

    exec_lua([[
      local query = '((declaration)+ @string)'
      vim.treesitter.query.set('c', 'highlights', query)
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    ]])

    screen:expect {
      grid = [[
        {5:int x = 4;}                                                     |
        {5:int y = 5;}                                                     |
        {5:int z = 6;}                                                     |
      ^                                                                 |
      {1:~                                                                }|*13
                                                                       |
    ]],
    }
  end)

  it('gives higher priority to more specific captures #27895', function()
    insert([[
      void foo(int *bar);
    ]])

    local query = [[
      "*" @operator

      (parameter_declaration
        declarator: (pointer_declarator) @variable.parameter)
    ]]

    exec_lua(
      [[
      local query = ...
      vim.treesitter.query.set('c', 'highlights', query)
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    ]],
      query
    )

    screen:expect {
      grid = [[
        void foo(int {4:*}{11:bar});                                            |
      ^                                                                 |
      {1:~                                                                }|*15
                                                                       |
    ]],
    }
  end)
end)

describe('treesitter highlighting (lua)', function()
  local screen

  before_each(function()
    screen = Screen.new(65, 18)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { foreground = Screen.colors.DarkCyan },
      [3] = { foreground = Screen.colors.Magenta },
      [4] = { foreground = Screen.colors.SlateBlue },
      [5] = { bold = true, foreground = Screen.colors.Brown },
    }
  end)

  it('supports language injections', function()
    insert [[
      local ffi = require('ffi')
      ffi.cdef("int (*fun)(int, char *);")
    ]]

    exec_lua [[
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    ]]

    screen:expect {
      grid = [[
        {5:local} {2:ffi} {5:=} {4:require(}{3:'ffi'}{4:)}                                     |
        {2:ffi}{4:.}{2:cdef}{4:(}{3:"}{4:int}{3: }{4:(}{5:*}{3:fun}{4:)(int,}{3: }{4:char}{3: }{5:*}{4:);}{3:"}{4:)}                           |
      ^                                                                 |
      {1:~                                                                }|*14
                                                                       |
    ]],
    }
  end)
end)

describe('treesitter highlighting (help)', function()
  local screen

  before_each(function()
    screen = Screen.new(40, 6)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.Blue1 },
      [2] = { bold = true, foreground = Screen.colors.Blue1 },
      [3] = { bold = true, foreground = Screen.colors.Brown },
      [4] = { foreground = Screen.colors.Cyan4 },
      [5] = { foreground = Screen.colors.Magenta1 },
    }
  end)

  it('correctly redraws added/removed injections', function()
    insert [[
    >ruby
      -- comment
      local this_is = 'actually_lua'
    <
    ]]

    exec_lua [[
      vim.bo.filetype = 'help'
      vim.treesitter.start()
    ]]

    screen:expect {
      grid = [[
      {1:>}{3:ruby}                                   |
      {1:  -- comment}                            |
      {1:  local this_is = 'actually_lua'}        |
      {1:<}                                       |
      ^                                        |
                                              |
    ]],
    }

    t.api.nvim_buf_set_text(0, 0, 1, 0, 5, { 'lua' })

    screen:expect {
      grid = [[
      {1:>}{3:lua}                                    |
      {1:  -- comment}                            |
      {1:  }{3:local}{1: }{4:this_is}{1: }{3:=}{1: }{5:'actually_lua'}        |
      {1:<}                                       |
      ^                                        |
                                              |
    ]],
    }

    t.api.nvim_buf_set_text(0, 0, 1, 0, 4, { 'ruby' })

    screen:expect {
      grid = [[
      {1:>}{3:ruby}                                   |
      {1:  -- comment}                            |
      {1:  local this_is = 'actually_lua'}        |
      {1:<}                                       |
      ^                                        |
                                              |
    ]],
    }
  end)

  it('correctly redraws injections subpriorities', function()
    -- The top level string node will be highlighted first
    -- with an extmark spanning multiple lines.
    -- When the next line is drawn, which includes an injection,
    -- make sure the highlight appears above the base tree highlight

    insert([=[
    local s = [[
      local also = lua
    ]]
    ]=])

    exec_lua [[
      parser = vim.treesitter.get_parser(0, "lua", {
        injections = {
          lua = '(string content: (_) @injection.content (#set! injection.language lua))'
        }
      })

      vim.treesitter.highlighter.new(parser)
    ]]

    screen:expect {
      grid = [=[
      {3:local} {4:s} {3:=} {5:[[}                            |
      {5:  }{3:local}{5: }{4:also}{5: }{3:=}{5: }{4:lua}                      |
      {5:]]}                                      |
      ^                                        |
      {2:~                                       }|
                                              |
    ]=],
    }
  end)
end)

describe('treesitter highlighting (nested injections)', function()
  local screen

  before_each(function()
    screen = Screen.new(80, 7)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.SlateBlue },
      [2] = { bold = true, foreground = Screen.colors.Brown },
      [3] = { foreground = Screen.colors.Cyan4 },
      [4] = { foreground = Screen.colors.Fuchsia },
    }
  end)

  it('correctly redraws nested injections (GitHub #25252)', function()
    insert [=[
function foo() print("Lua!") end

local lorem = {
    ipsum = {},
    bar = {},
}
vim.cmd([[
    augroup RustLSP
    autocmd CursorHold silent! lua vim.lsp.buf.document_highlight()
    augroup END
]])
    ]=]

    exec_lua [[
      vim.opt.scrolloff = 0
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    ]]

    -- invalidate the language tree
    feed('ggi--[[<ESC>04x')

    screen:expect {
      grid = [[
      {2:^function} {3:foo}{1:()} {1:print(}{4:"Lua!"}{1:)} {2:end}                                                |
                                                                                      |
      {2:local} {3:lorem} {2:=} {1:{}                                                                 |
          {3:ipsum} {2:=} {1:{},}                                                                 |
          {3:bar} {2:=} {1:{},}                                                                   |
      {1:}}                                                                               |
                                                                                      |
    ]],
    }

    -- spam newline insert/delete to invalidate Lua > Vim > Lua region
    feed('3jo<ESC>ddko<ESC>ddko<ESC>ddko<ESC>ddk0')

    screen:expect {
      grid = [[
      {2:function} {3:foo}{1:()} {1:print(}{4:"Lua!"}{1:)} {2:end}                                                |
                                                                                      |
      {2:local} {3:lorem} {2:=} {1:{}                                                                 |
      ^    {3:ipsum} {2:=} {1:{},}                                                                 |
          {3:bar} {2:=} {1:{},}                                                                   |
      {1:}}                                                                               |
                                                                                      |
    ]],
    }
  end)
end)

describe('treesitter highlighting (markdown)', function()
  local screen

  before_each(function()
    screen = Screen.new(40, 6)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.Blue1 },
      [2] = { bold = true, foreground = Screen.colors.Blue1 },
      [3] = { bold = true, foreground = Screen.colors.Brown },
      [4] = { foreground = Screen.colors.Cyan4 },
      [5] = { foreground = Screen.colors.Magenta1 },
    }
  end)

  it('supports hyperlinks', function()
    local url = 'https://example.com'
    insert(string.format('[This link text](%s) is a hyperlink.', url))
    exec_lua([[
      vim.bo.filetype = 'markdown'
      vim.treesitter.start()
    ]])

    screen:expect {
      grid = [[
      {4:[}{6:This link text}{4:](}{7:https://example.com}{4:)} is|
       a hyperlink^.                           |
      {2:~                                       }|*3
                                              |
    ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.Blue1 },
        [2] = { bold = true, foreground = Screen.colors.Blue1 },
        [3] = { bold = true, foreground = Screen.colors.Brown },
        [4] = { foreground = Screen.colors.Cyan4 },
        [5] = { foreground = Screen.colors.Magenta },
        [6] = { foreground = Screen.colors.Cyan4, url = url },
        [7] = { underline = true, foreground = Screen.colors.SlateBlue },
      },
    }
  end)
end)
