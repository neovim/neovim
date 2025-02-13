local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local insert = n.insert
local exec_lua = n.exec_lua
local feed = n.feed
local command = n.command
local api = n.api
local fn = n.fn
local eq = t.eq

local hl_query_c = [[
  ; query
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

local hl_grid_legacy_c = [[
  {18:^/// Schedule Lua callback on main loop's event queue}             |
  {6:static} {6:int} nlua_schedule(lua_State *{6:const} lstate)                |
  {                                                                |
    {15:if} (lua_type(lstate, {26:1}) != LUA_TFUNCTION                       |
        || lstate != lstate) {                                     |
      lua_pushliteral(lstate, {26:"vim.schedule: expected function"});  |
      {15:return} lua_error(lstate);                                    |
    }                                                              |
                                                                   |
    LuaRef cb = nlua_ref(lstate, {26:1});                               |
                                                                   |
    multiqueue_put(main_loop.events, nlua_schedule_event,          |
                   {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
    {15:return} {26:0};                                                      |
  }                                                                |
  {1:~                                                                }|*2
                                                                   |
]]

local hl_grid_ts_c = [[
  {18:^/// Schedule Lua callback on main loop's event queue}             |
  {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
  {                                                                |
    {15:if} ({25:lua_type}(lstate, {26:1}) != {26:LUA_TFUNCTION}                       |
        || {19:lstate} != {19:lstate}) {                                     |
      {25:lua_pushliteral}(lstate, {26:"vim.schedule: expected function"});  |
      {15:return} {25:lua_error}(lstate);                                    |
    }                                                              |
                                                                   |
    {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                   |
    multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                   {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
    {15:return} {26:0};                                                      |
  }                                                                |
  {1:~                                                                }|*2
                                                                   |
]]

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
  {6:int} x = {26:INT_MAX};                                                 |
  #define {26:READ_STRING}(x, y) ({6:char} *)read_string((x), ({6:size_t})(y))  |
  #define foo {6:void} main() { \                                      |
                {15:return} {26:42};  \                                      |
              }                                                    |
  ^                                                                 |
  {1:~                                                                }|*11
                                                                   |
]]

describe('treesitter highlighting (C)', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear()
    screen = Screen.new(65, 18)
    command [[ hi link @error ErrorMsg ]]
    command [[ hi link @warning WarningMsg ]]
  end)

  it('starting and stopping treesitter highlight works', function()
    command('setfiletype c | syntax on')
    fn.setreg('r', hl_text_c)
    feed('i<C-R><C-O>r<Esc>gg')
    -- legacy syntax highlighting is used by default
    screen:expect(hl_grid_legacy_c)

    exec_lua(function()
      vim.treesitter.query.set('c', 'highlights', hl_query_c)
      vim.treesitter.start()
    end)
    -- treesitter highlighting is used
    screen:expect(hl_grid_ts_c)

    exec_lua(function()
      vim.treesitter.stop()
    end)
    -- legacy syntax highlighting is used
    screen:expect(hl_grid_legacy_c)

    exec_lua(function()
      vim.treesitter.start()
    end)
    -- treesitter highlighting is used
    screen:expect(hl_grid_ts_c)

    exec_lua(function()
      vim.treesitter.stop()
    end)
    -- legacy syntax highlighting is used
    screen:expect(hl_grid_legacy_c)
  end)

  it('is updated with edits', function()
    insert(hl_text_c)
    feed('gg')
    screen:expect {
      grid = [[
      ^/// Schedule Lua callback on main loop's event queue             |
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
      }                                                                |
      {1:~                                                                }|*2
                                                                       |
    ]],
    }

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local highlighter = vim.treesitter.highlighter
      highlighter.new(parser, { queries = { c = hl_query_c } })
    end)
    screen:expect(hl_grid_ts_c)

    feed('5Goc<esc>dd')

    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queue}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
          {15:if} ({25:lua_type}(lstate, {26:1}) != {26:LUA_TFUNCTION}                       |
              || {19:lstate} != {19:lstate}) {                                     |
            {25:^lua_pushliteral}(lstate, {26:"vim.schedule: expected function"});  |
            {15:return} {25:lua_error}(lstate);                                    |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        }                                                                |
        {1:~                                                                }|*2
                                                                         |
      ]],
    })

    feed('7Go*/<esc>')
    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queue}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
          {15:if} ({25:lua_type}(lstate, {26:1}) != {26:LUA_TFUNCTION}                       |
              || {19:lstate} != {19:lstate}) {                                     |
            {25:lua_pushliteral}(lstate, {26:"vim.schedule: expected function"});  |
            {15:return} {25:lua_error}(lstate);                                    |
        {9:*^/}                                                               |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        }                                                                |
        {1:~                                                                }|
                                                                         |
      ]],
    })

    feed('3Go/*<esc>')
    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queue}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
        {18:/^*}                                                               |
        {18:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
        {18:      || lstate != lstate) {}                                     |
        {18:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
        {18:    return lua_error(lstate);}                                    |
        {18:*/}                                                               |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        {9:}}                                                                |
                                                                         |
      ]],
    })

    feed('gg$')
    feed('~')
    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queu^E}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
        {18:/*}                                                               |
        {18:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
        {18:      || lstate != lstate) {}                                     |
        {18:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
        {18:    return lua_error(lstate);}                                    |
        {18:*/}                                                               |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        {9:}}                                                                |
                                                                         |
      ]],
    })

    feed('re')
    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queu^e}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
        {18:/*}                                                               |
        {18:  if (lua_type(lstate, 1) != LUA_TFUNCTION}                       |
        {18:      || lstate != lstate) {}                                     |
        {18:    lua_pushliteral(lstate, "vim.schedule: expected function");}  |
        {18:    return lua_error(lstate);}                                    |
        {18:*/}                                                               |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        {9:}}                                                                |
                                                                         |
      ]],
    })
  end)

  it('is updated with :sort', function()
    insert(test_text_c)
    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      vim.treesitter.highlighter.new(parser, { queries = { c = hl_query_c } })
    end)
    screen:expect({
      grid = [[
          {6:int} width = {26:INT_MAX}, height = {26:INT_MAX};                         |
          {6:bool} ext_widgets[kUIExtCount];                                 |
          {15:for} ({6:UIExtension} i = {26:0}; ({6:int})i < kUIExtCount; i++) {           |
            ext_widgets[i] = true;                                       |
          }                                                              |
                                                                         |
          {6:bool} inclusive = ui_override();                                |
          {15:for} ({6:size_t} i = {26:0}; i < ui_count; i++) {                        |
            {6:UI} *ui = uis[i];                                             |
            width = {26:MIN}(ui->width, width);                               |
            height = {26:MIN}(ui->height, height);                            |
            foo = {26:BAR}(ui->bazaar, bazaar);                               |
            {15:for} ({6:UIExtension} j = {26:0}; ({6:int})j < kUIExtCount; j++) {         |
              ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
            }                                                            |
          }                                                              |
        ^}                                                                |
                                                                         |
      ]],
    })

    feed ':sort<cr>'
    screen:expect({
      grid = [[
        ^                                                                 |
              ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
            {6:UI} *ui = uis[i];                                             |
            ext_widgets[i] = true;                                       |
            foo = {26:BAR}(ui->bazaar, bazaar);                               |
            {15:for} ({6:UIExtension} j = {26:0}; ({6:int})j < kUIExtCount; j++) {         |
            height = {26:MIN}(ui->height, height);                            |
            width = {26:MIN}(ui->width, width);                               |
            }                                                            |
          {6:bool} ext_widgets[kUIExtCount];                                 |
          {6:bool} inclusive = ui_override();                                |
          {15:for} ({6:UIExtension} i = {26:0}; ({6:int})i < kUIExtCount; i++) {           |
          {15:for} ({6:size_t} i = {26:0}; i < ui_count; i++) {                        |
          {6:int} width = {26:INT_MAX}, height = {26:INT_MAX};                         |
          }                                                              |*2
        {6:void} ui_refresh({6:void})                                            |
        :sort                                                            |
      ]],
    })

    feed 'u:<esc>'

    screen:expect({
      grid = [[
          {6:int} width = {26:INT_MAX}, height = {26:INT_MAX};                         |
          {6:bool} ext_widgets[kUIExtCount];                                 |
          {15:for} ({6:UIExtension} i = {26:0}; ({6:int})i < kUIExtCount; i++) {           |
            ext_widgets[i] = true;                                       |
          }                                                              |
                                                                         |
          {6:bool} inclusive = ui_override();                                |
          {15:for} ({6:size_t} i = {26:0}; i < ui_count; i++) {                        |
            {6:UI} *ui = uis[i];                                             |
            width = {26:MIN}(ui->width, width);                               |
            height = {26:MIN}(ui->height, height);                            |
            foo = {26:BAR}(ui->bazaar, bazaar);                               |
            {15:for} ({6:UIExtension} j = {26:0}; ({6:int})j < kUIExtCount; j++) {         |
              ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
            }                                                            |
          }                                                              |
        ^}                                                                |
                                                                         |
      ]],
    })
  end)

  it('supports with custom parser', function()
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

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local query = vim.treesitter.query.parse('c', '(declaration) @decl')

      local nodes = {}
      for _, node in query:iter_captures(parser:parse()[1]:root(), 0, 0, 19) do
        table.insert(nodes, node)
      end

      parser:set_included_regions({ nodes })

      vim.treesitter.highlighter.new(parser, { queries = { c = '(identifier) @type' } })
    end)

    screen:expect({
      grid = [[
          int {6:width} = {6:INT_MAX}, {6:height} = {6:INT_MAX};                         |
          bool {6:ext_widgets}[{6:kUIExtCount}];                                 |
          for (UIExtension {6:i} = 0; (int)i < kUIExtCount; i++) {           |
            ext_widgets[i] = true;                                       |
          }                                                              |
                                                                         |
          bool {6:inclusive} = {6:ui_override}();                                |
          for (size_t {6:i} = 0; i < ui_count; i++) {                        |
            UI *{6:ui} = {6:uis}[{6:i}];                                             |
            width = MIN(ui->width, width);                               |
            height = MIN(ui->height, height);                            |
            foo = BAR(ui->bazaar, bazaar);                               |
            for (UIExtension {6:j} = 0; (int)j < kUIExtCount; j++) {         |
              ext_widgets[j] &= (ui->ui_ext[j] || inclusive);            |
            }                                                            |
          }                                                              |
        ^}                                                                |
                                                                         |
      ]],
    })
  end)

  it('supports injected languages', function()
    insert(injection_text_c)

    screen:expect { grid = injection_grid_c }

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c', {
        injections = {
          c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))',
        },
      })
      local highlighter = vim.treesitter.highlighter
      highlighter.new(parser, { queries = { c = hl_query_c } })
    end)

    screen:expect { grid = injection_grid_expected_c }
  end)

  it("supports injecting by ft name in metadata['injection.language']", function()
    insert(injection_text_c)

    screen:expect { grid = injection_grid_c }

    exec_lua(function()
      vim.treesitter.language.register('c', 'foo')
      local parser = vim.treesitter.get_parser(0, 'c', {
        injections = {
          c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "foo")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "foo"))',
        },
      })
      local highlighter = vim.treesitter.highlighter
      highlighter.new(parser, { queries = { c = hl_query_c } })
    end)

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

    exec_lua(function()
      local injection_query =
        '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
      vim.treesitter.query.set('c', 'highlights', hl_query_c)
      vim.treesitter.query.set('c', 'injections', injection_query)

      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    end)

    screen:expect({
      grid = [[
        {6:int} x = {26:INT_MAX};                                                 |
        #define {26:READ_STRING}(x, y) ({6:char} *)read_string((x), ({6:size_t})(y))  |
        #define foo {6:void} main() { \                                      |
                      {15:return} {26:42};  \                                      |
                    }                                                    |
        ^                                                                 |
        {1:~                                                                }|*11
                                                                         |
      ]],
    })
  end)

  it('supports highlighting with custom highlight groups', function()
    insert(hl_text_c)
    feed('gg')

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      vim.treesitter.highlighter.new(parser, { queries = { c = hl_query_c } })
    end)

    screen:expect(hl_grid_ts_c)

    -- This will change ONLY the literal strings to look like comments
    -- The only literal string is the "vim.schedule: expected function" in this test.
    exec_lua [[vim.cmd("highlight link @string.nonexistent_specializer comment")]]
    screen:expect({
      grid = [[
        {18:^/// Schedule Lua callback on main loop's event queue}             |
        {6:static} {6:int} {25:nlua_schedule}({6:lua_State} *{6:const} lstate)                |
        {                                                                |
          {15:if} ({25:lua_type}(lstate, {26:1}) != {26:LUA_TFUNCTION}                       |
              || {19:lstate} != {19:lstate}) {                                     |
            {25:lua_pushliteral}(lstate, {18:"vim.schedule: expected function"});  |
            {15:return} {25:lua_error}(lstate);                                    |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        }                                                                |
        {1:~                                                                }|*2
                                                                         |
      ]],
    })
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

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      vim.treesitter.highlighter.new(parser, {
        queries = {
          c = hl_query_c .. '\n((translation_unit) @constant (#set! "priority" 101))\n',
        },
      })
    end)
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
      { capture = 'constant', metadata = { priority = '101' }, lang = 'c', id = 14 },
      { capture = 'type', metadata = {}, lang = 'c', id = 3 },
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
      exec_lua(function()
        local parser = vim.treesitter.get_parser(0, 'c', {})
        local highlighter = vim.treesitter.highlighter
        highlighter.new(
          parser,
          { queries = { c = '(primitive_type) @foo.bar (string_literal) @foo' } }
        )
      end)

      screen:expect({
        grid = [[
          {6:char}* x = {26:"Will somebody ever read this?"};                       |
          ^                                                                 |
          {1:~                                                                }|*15
                                                                           |
        ]],
      })

      -- clearing specialization reactivates fallback
      command [[ hi clear @foo.bar ]]
      screen:expect({
        grid = [[
          {26:char}* x = {26:"Will somebody ever read this?"};                       |
          ^                                                                 |
          {1:~                                                                }|*15
                                                                           |
        ]],
      })
    end
  )

  it('supports conceal attribute', function()
    insert(hl_text_c)

    -- conceal can be empty or a single cchar.
    exec_lua(function()
      vim.opt.cole = 2
      local parser = vim.treesitter.get_parser(0, 'c')
      vim.treesitter.highlighter.new(parser, {
        queries = {
          c = [[
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
      ]],
        },
      })
    end)

    screen:expect({
      grid = [[
        /// Schedule Lua callback on main loop's event queue             |
        {15:R} int nlua_schedule(lua_State *const )                           |
        {                                                                |
          if (lua_type(, 1) != LUA_TFUNCTION                             |
              ||  != ) {                                                 |
            lua_pushliteral(, "vim.schedule: expected function");        |
            return lua_error();                                          |
          }                                                              |
                                                                         |
          LuaRef cb = nlua_ref(, 1);                                     |
                                                                         |
          {25:V}(main_loop.events, nlua_schedule_event,                       |
                         1, (void *)(ptrdiff_t)cb);                      |
          return 0;                                                      |
        ^}                                                                |
        {1:~                                                                }|*2
                                                                         |
      ]],
    })
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

    exec_lua(function()
      local query = '((declaration)+ @string)'
      vim.treesitter.query.set('c', 'highlights', query)
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    end)

    screen:expect({
      grid = [[
          {26:int x = 4;}                                                     |
          {26:int y = 5;}                                                     |
          {26:int z = 6;}                                                     |
        ^                                                                 |
        {1:~                                                                }|*13
                                                                         |
      ]],
    })
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

    exec_lua(function()
      vim.treesitter.query.set('c', 'highlights', query)
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    end)

    screen:expect({
      grid = [[
          void foo(int {15:*}{25:bar});                                            |
        ^                                                                 |
        {1:~                                                                }|*15
                                                                         |
      ]],
    })
  end)

  it('highlights applied to first line of closed fold', function()
    insert(hl_text_c)
    exec_lua(function()
      vim.treesitter.query.set('c', 'highlights', hl_query_c)
      vim.treesitter.highlighter.new(vim.treesitter.get_parser(0, 'c'))
    end)
    feed('ggjzfj')
    command('set foldtext=')
    screen:add_extra_attr_ids({
      [100] = {
        bold = true,
        background = Screen.colors.LightGray,
        foreground = Screen.colors.SeaGreen4,
      },
      [101] = { background = Screen.colors.LightGray, foreground = Screen.colors.DarkCyan },
    })
    screen:expect({
      grid = [[
        {18:/// Schedule Lua callback on main loop's event queue}             |
        {100:^static}{13: }{100:int}{13: }{101:nlua_schedule}{13:(}{100:lua_State}{13: *}{100:const}{13: lstate)················}|
          {15:if} ({25:lua_type}(lstate, {26:1}) != {26:LUA_TFUNCTION}                       |
              || {19:lstate} != {19:lstate}) {                                     |
            {25:lua_pushliteral}(lstate, {26:"vim.schedule: expected function"});  |
            {15:return} {25:lua_error}(lstate);                                    |
          }                                                              |
                                                                         |
          {29:LuaRef} cb = {25:nlua_ref}(lstate, {26:1});                               |
                                                                         |
          multiqueue_put(main_loop.events, {25:nlua_schedule_event},          |
                         {26:1}, ({6:void} *)({6:ptrdiff_t})cb);                      |
          {15:return} {26:0};                                                      |
        }                                                                |
        {1:~                                                                }|*3
                                                                         |
      ]],
    })
  end)
end)

describe('treesitter highlighting (lua)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(65, 18)
  end)

  it('supports language injections', function()
    insert [[
      local ffi = require('ffi')
      ffi.cdef("int (*fun)(int, char *);")
    ]]

    exec_lua(function()
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    end)

    screen:expect({
      grid = [[
          {15:local} {25:ffi} {15:=} {16:require(}{26:'ffi'}{16:)}                                     |
          {25:ffi}{16:.}{25:cdef}{16:(}{26:"}{16:int}{26: }{16:(}{15:*}{26:fun}{16:)(int,}{26: }{16:char}{26: }{15:*}{16:);}{26:"}{16:)}                           |
        ^                                                                 |
        {1:~                                                                }|*14
                                                                         |
      ]],
    })
  end)

  it('removes outdated highlights', function()
    insert('-- int main() {}' .. string.rep("\nprint('test')", 20) .. '\n-- int other() {}')

    exec_lua(function()
      vim.cmd.norm('gg')
      vim.treesitter.query.set(
        'lua',
        'injections',
        [[((comment_content) @injection.content
            (#set! injection.combined)
            (#set! injection.language "c"))]]
      )
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    end)

    screen:expect([[
      {18:^-- }{16:int}{18: }{25:main}{16:()}{18: }{16:{}}                                                 |
      {16:print(}{26:'test'}{16:)}                                                    |*16
                                                                       |
    ]])

    exec_lua(function()
      vim.cmd.norm('gg0dw')
    end)

    screen:expect([[
      {25:^int} {25:main}{16:()} {16:{}}                                                    |
      {16:print(}{26:'test'}{16:)}                                                    |*16
                                                                       |
    ]])
  end)
end)

describe('treesitter highlighting (help)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 6)
  end)

  it('defaults in vimdoc/highlights.scm', function()
    -- Avoid regressions when syncing upstream vimdoc queries.

    insert [[
    ==============================================================================
    NVIM DOCUMENTATION

    ------------------------------------------------------------------------------
    ABOUT NVIM                                                     *tag-1* *tag-2*

    |news|			News
    |nvim|			NVim
    ]]

    feed('gg')
    exec_lua(function()
      vim.wo.wrap = false
      vim.bo.filetype = 'help'
      vim.treesitter.start()
    end)

    screen:add_extra_attr_ids({
      [100] = { nocombine = true, underdouble = true },
      [101] = { foreground = Screen.colors.Fuchsia, bold = true },
      [102] = { underline = true, nocombine = true },
    })
    screen:expect({
      grid = [[
        {100:^========================================}|
        {101:NVIM DOCUMENTATION}                      |
                                                |
        {102:----------------------------------------}|
        {101:ABOUT NVIM}                              |
                                                |
      ]],
    })
  end)

  it('correctly redraws added/removed injections', function()
    insert [[
    >ruby
      -- comment
      local this_is = 'actually_lua'
    <
    ]]

    exec_lua(function()
      vim.bo.filetype = 'help'
      vim.treesitter.start()
    end)

    screen:expect({
      grid = [[
        {18:>}{15:ruby}                                   |
        {18:  -- comment}                            |
        {18:  local this_is = 'actually_lua'}        |
        {18:<}                                       |
        ^                                        |
                                                |
      ]],
    })

    n.api.nvim_buf_set_text(0, 0, 1, 0, 5, { 'lua' })

    screen:expect({
      grid = [[
        {18:>}{15:lua}                                    |
        {18:  -- comment}                            |
        {18:  }{15:local}{18: }{25:this_is}{18: }{15:=}{18: }{26:'actually_lua'}        |
        {18:<}                                       |
        ^                                        |
                                                |
      ]],
    })

    n.api.nvim_buf_set_text(0, 0, 1, 0, 4, { 'ruby' })

    screen:expect({
      grid = [[
        {18:>}{15:ruby}                                   |
        {18:  -- comment}                            |
        {18:  local this_is = 'actually_lua'}        |
        {18:<}                                       |
        ^                                        |
                                                |
      ]],
    })
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

    exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'lua', {
        injections = {
          lua = '(string content: (_) @injection.content (#set! injection.language lua))',
        },
      })

      vim.treesitter.highlighter.new(parser)
    end)

    screen:expect({
      grid = [=[
        {15:local} {25:s} {15:=} {26:[[}                            |
        {26:  }{15:local}{26: }{25:also}{26: }{15:=}{26: }{25:lua}                      |
        {26:]]}                                      |
        ^                                        |
        {1:~                                       }|
                                                |
      ]=],
    })
  end)
end)

describe('treesitter highlighting (nested injections)', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear()
    screen = Screen.new(80, 7)
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

    exec_lua(function()
      vim.opt.scrolloff = 0
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    end)

    -- invalidate the language tree
    feed('ggi--[[<ESC>04x')

    screen:expect({
      grid = [[
        {15:^function} {25:foo}{16:()} {16:print(}{26:"Lua!"}{16:)} {15:end}                                                |
                                                                                        |
        {15:local} {25:lorem} {15:=} {16:{}                                                                 |
            {25:ipsum} {15:=} {16:{},}                                                                 |
            {25:bar} {15:=} {16:{},}                                                                   |
        {16:}}                                                                               |
                                                                                        |
      ]],
    })

    -- spam newline insert/delete to invalidate Lua > Vim > Lua region
    feed('3jo<ESC>ddko<ESC>ddko<ESC>ddko<ESC>ddk0')

    screen:expect({
      grid = [[
        {15:function} {25:foo}{16:()} {16:print(}{26:"Lua!"}{16:)} {15:end}                                                |
                                                                                        |
        {15:local} {25:lorem} {15:=} {16:{}                                                                 |
        ^    {25:ipsum} {15:=} {16:{},}                                                                 |
            {25:bar} {15:=} {16:{},}                                                                   |
        {16:}}                                                                               |
                                                                                        |
      ]],
    })
  end)
end)

describe('treesitter highlighting (markdown)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 6)
    exec_lua(function()
      vim.bo.filetype = 'markdown'
      vim.treesitter.start()
    end)
  end)

  it('supports hyperlinks', function()
    local url = 'https://example.com'
    insert(string.format('[This link text](%s) is a hyperlink.', url))
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.DarkCyan, url = 'https://example.com' },
      [101] = {
        foreground = Screen.colors.SlateBlue,
        url = 'https://example.com',
        underline = true,
      },
    })
    screen:expect({
      grid = [[
        {100:[This link text](}{101:https://example.com}{100:)} is|
         a hyperlink^.                           |
        {1:~                                       }|*3
                                                |
      ]],
    })
  end)

  local code_block = [[
- $f(0)=\sum_{k=1}^{\infty}\frac{2}{\pi^{2}k^{2}}+\lim_{w \to 0}x$.

```c
printf('Hello World!');
```
    ]]

  it('works with spellchecked and smoothscrolled topline', function()
    insert(code_block)
    command('set spell smoothscroll')
    feed('gg<C-E>')
    screen:add_extra_attr_ids({ [100] = { undercurl = true, special = Screen.colors.Red } })
    screen:expect({
      grid = [[
        {1:<<<}k^{2}}+\{100:lim}_{w \to 0}x$^.             |
                                                |
        {18:```}{15:c}                                    |
        {25:printf}{16:(}{26:'Hello World!'}{16:);}                 |
        {18:```}                                     |
                                                |
      ]],
    })
  end)

  it('works with concealed lines', function()
    insert(code_block)
    screen:expect({
      grid = [[
                                                |
        {18:```}{15:c}                                    |
        {25:printf}{16:(}{26:'Hello World!'}{16:);}                 |
        {18:```}                                     |
           ^                                     |
                                                |
      ]],
    })
    feed('ggj')
    command('set number conceallevel=3')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }^                                    |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  6 }                                    |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  3 }{18:^```}{15:c}                                |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  4 }{25:^printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  6 }                                    |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  5 }{18:^```}                                 |
                                                |
      ]],
    })
    -- Concealed lines highlight until changed botline
    screen:try_resize(screen._width, 16)
    feed('y3k30P:<Esc><C-F><C-B>')
    screen:expect([[
      {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
      {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
      {8:  2 }                                    |
      {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:  6 }                                    |
      {8:  8 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 10 }                                    |
      {8: 12 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 14 }                                    |
      {8: 16 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 18 }                                    |
      {8: 20 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 22 }                                    |
      {8: 24 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 25 }{18:^```}                                 |
                                              |
    ]])
    feed('G')
    screen:expect([[
      {8: 98 }                                    |
      {8:100 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:102 }                                    |
      {8:104 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:106 }                                    |
      {8:108 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:110 }                                    |
      {8:112 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:114 }                                    |
      {8:116 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:118 }                                    |
      {8:120 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:122 }                                    |
      {8:124 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:126 }   ^                                 |
                                              |
    ]])
  end)
end)

it('starting and stopping treesitter highlight in init.lua works #29541', function()
  t.write_file(
    'Xinit.lua',
    [[
      vim.bo.ft = 'c'
      vim.treesitter.start()
      vim.treesitter.stop()
    ]]
  )
  finally(function()
    os.remove('Xinit.lua')
  end)
  clear({ args = { '-u', 'Xinit.lua' } })
  eq('', api.nvim_get_vvar('errmsg'))

  local screen = Screen.new(65, 18)
  fn.setreg('r', hl_text_c)
  feed('i<C-R><C-O>r<Esc>gg')
  -- legacy syntax highlighting is used
  screen:expect(hl_grid_legacy_c)
end)
