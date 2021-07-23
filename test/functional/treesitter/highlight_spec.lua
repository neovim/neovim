local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

local hl_query = [[
  (ERROR) @ErrorMsg

  "if" @keyword
  "else" @keyword
  "for" @keyword
  "return" @keyword

  "const" @type
  "static" @type
  "struct" @type
  "enum" @type
  "extern" @type

  (string_literal) @string

  (number_literal) @number
  (char_literal) @string

  (type_identifier) @type
  ((type_identifier) @Special (#eq? @Special "LuaRef"))

  (primitive_type) @type
  (sized_type_specifier) @type

  ; Use lua regexes
  ((identifier) @Identifier (#contains? @Identifier "lua_"))
  ((identifier) @Constant (#lua-match? @Constant "^[A-Z_]+$"))
  ((identifier) @Normal (#vim-match? @Constant "^lstate$"))

  ((binary_expression left: (identifier) @WarningMsg.left right: (identifier) @WarningMsg.right) (#eq? @WarningMsg.left @WarningMsg.right))

  (comment) @comment
]]

local hl_text = [[
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

describe('treesitter highlighting', function()
  local screen

  before_each(function()
    screen = Screen.new(65, 18)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold = true, foreground = Screen.colors.Blue1};
      [2] = {foreground = Screen.colors.Blue1};
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4};
      [4] = {bold = true, foreground = Screen.colors.Brown};
      [5] = {foreground = Screen.colors.Magenta};
      [6] = {foreground = Screen.colors.Red};
      [7] = {bold = true, foreground = Screen.colors.SlateBlue};
      [8] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red};
      [9] = {foreground = Screen.colors.Magenta, background = Screen.colors.Red};
      [10] = {foreground = Screen.colors.Red, background = Screen.colors.Red};
      [11] = {foreground = Screen.colors.Cyan4};
    }

    exec_lua([[ hl_query = ... ]], hl_query)
  end)

  it('is updated with edits', function()
    if pending_c_parser(pending) then return end

    insert(hl_text)
    screen:expect{grid=[[
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
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = hl_query}})
    ]]
    screen:expect{grid=[[
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
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}

    feed("5Goc<esc>dd")

    screen:expect{grid=[[
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
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}

    feed('7Go*/<esc>')
    screen:expect{grid=[[
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
    ]]}

    feed('3Go/*<esc>')
    screen:expect{grid=[[
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
    ]]}

    feed("gg$")
    feed("~")
    screen:expect{grid=[[
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
    ]]}


    feed("re")
    screen:expect{grid=[[
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
    ]]}
  end)

  it('is updated with :sort', function()
    if pending_c_parser(pending) then return end

    insert(test_text)
    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query}})
    ]]
    screen:expect{grid=[[
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
    ]]}

    feed ":sort<cr>"
    screen:expect{grid=[[
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
        }                                                              |
        }                                                              |
      {3:void} ui_refresh({3:void})                                            |
      :sort                                                            |
    ]]}

    feed "u"

    screen:expect{grid=[[
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
    ]]}
  end)

  it("supports with custom parser", function()
    if pending_c_parser(pending) then return end

    screen:set_default_attr_ids {
      [1] = {bold = true, foreground = Screen.colors.SeaGreen4};
    }

    insert(test_text)

    screen:expect{ grid= [[
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
    ]] }

    exec_lua [[
      parser = vim.treesitter.get_parser(0, "c")
      query = vim.treesitter.parse_query("c", "(declaration) @decl")

      local nodes = {}
      for _, node in query:iter_captures(parser:parse()[1]:root(), 0, 0, 19) do
        table.insert(nodes, node)
      end

      parser:set_included_regions({nodes})

      local hl = vim.treesitter.highlighter.new(parser, {queries = {c = "(identifier) @type"}})
    ]]

    screen:expect{ grid = [[
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
    ]] }
  end)

  it("supports injected languages", function()
    if pending_c_parser(pending) then return end

    insert([[
    int x = INT_MAX;
    #define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
    #define foo void main() { \
                  return 42;  \
                }
    ]])

    screen:expect{grid=[[
      int x = INT_MAX;                                                 |
      #define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))|
      #define foo void main() { \                                      |
                    return 42;  \                                      |
                  }                                                    |
      ^                                                                 |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c", {
        injections = {c = "(preproc_def (preproc_arg) @c) (preproc_function_def value: (preproc_arg) @c)"}
      })
      local highlighter = vim.treesitter.highlighter
      test_hl = highlighter.new(parser, {queries = {c = hl_query}})
    ]]

    screen:expect{grid=[[
      {3:int} x = {5:INT_MAX};                                                 |
      #define {5:READ_STRING}(x, y) ({3:char_u} *)read_string((x), ({3:size_t})(y))|
      #define foo {3:void} main() { \                                      |
                    {4:return} {5:42};  \                                      |
                  }                                                    |
      ^                                                                 |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}
  end)

  it("supports overriding queries, like ", function()
    if pending_c_parser(pending) then return end

    insert([[
    int x = INT_MAX;
    #define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
    #define foo void main() { \
                  return 42;  \
                }
    ]])

    exec_lua [[
      local injection_query = "(preproc_def (preproc_arg) @c) (preproc_function_def value: (preproc_arg) @c)"
      require('vim.treesitter.query').set_query("c", "highlights", hl_query)
      require('vim.treesitter.query').set_query("c", "injections", injection_query)

      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, "c"))
    ]]

    screen:expect{grid=[[
      {3:int} x = {5:INT_MAX};                                                 |
      #define {5:READ_STRING}(x, y) ({3:char_u} *)read_string((x), ({3:size_t})(y))|
      #define foo {3:void} main() { \                                      |
                    {4:return} {5:42};  \                                      |
                  }                                                    |
      ^                                                                 |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}
  end)

  it("supports highlighting with custom highlight groups", function()
    if pending_c_parser(pending) then return end

    insert(hl_text)

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query}})
    ]]

    screen:expect{grid=[[
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
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}

    -- This will change ONLY the literal strings to look like comments
    -- The only literal string is the "vim.schedule: expected function" in this test.
    exec_lua [[vim.cmd("highlight link cString comment")]]
    screen:expect{grid=[[
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
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]]}
    screen:expect{ unchanged=true }
  end)

  it("supports highlighting with priority", function()
    if pending_c_parser(pending) then return end

    insert([[
    int x = INT_MAX;
    #define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
    #define foo void main() { \
                  return 42;  \
                }
    ]])

    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c")
      test_hl = vim.treesitter.highlighter.new(parser, {queries = {c = hl_query..'\n((translation_unit) @Error (set! "priority" 101))\n'}})
    ]]
    -- expect everything to have Error highlight
    screen:expect{grid=[[
      {12:int}{8: x = INT_MAX;}                                                 |
      {8:#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))}|
      {8:#define foo void main() { \}                                      |
      {8:              return 42;  \}                                      |
      {8:            }}                                                    |
      ^                                                                 |
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
      {1:~                                                                }|
                                                                       |
    ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1};
      [8] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red};
      -- bold will not be overwritten at the moment
      [12] = {background = Screen.colors.Red, bold = true, foreground = Screen.colors.Grey100};
    }}
    end)
end)
