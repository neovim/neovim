-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local pcall_err = helpers.pcall_err
local matches = helpers.matches

before_each(clear)

describe('treesitter API', function()
  -- error tests not requiring a parser library
  it('handles missing language', function()
    eq("Error executing lua: .../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
       pcall_err(exec_lua, "parser = vim.treesitter.get_parser(0, 'borklang')"))

    -- actual message depends on platform
    matches("Error executing lua: Failed to load parser: uv_dlopen: .+",
       pcall_err(exec_lua, "parser = vim.treesitter.require_language('borklang', 'borkbork.so')"))

    eq("Error executing lua: .../language.lua:0: no parser for 'borklang' language, see :help treesitter-parsers",
       pcall_err(exec_lua, "parser = vim.treesitter.inspect_language('borklang')"))
  end)
end)

describe('treesitter API with C parser', function()
  local function check_parser()
    local status, msg = unpack(exec_lua([[ return {pcall(vim.treesitter.require_language, 'c')} ]]))
    if not status then
      if helpers.isCI() then
        error("treesitter C parser not found, required on CI: " .. msg)
      else
        pending('no C parser, skipping')
      end
    end
    return status
  end

  it('parses buffer', function()
    if helpers.pending_win32(pending) or not check_parser() then return end

    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()
      root = tree:root()
      lang = vim.treesitter.inspect_language('c')
    ]])

    eq("<tree>", exec_lua("return tostring(tree)"))
    eq("<node translation_unit>", exec_lua("return tostring(root)"))
    eq({0,0,3,0}, exec_lua("return {root:range()}"))

    eq(1, exec_lua("return root:child_count()"))
    exec_lua("child = root:child(0)")
    eq("<node function_definition>", exec_lua("return tostring(child)"))
    eq({0,0,2,1}, exec_lua("return {child:range()}"))

    eq("function_definition", exec_lua("return child:type()"))
    eq(true, exec_lua("return child:named()"))
    eq("number", type(exec_lua("return child:symbol()")))
    eq({'function_definition', true}, exec_lua("return lang.symbols[child:symbol()]"))

    exec_lua("anon = root:descendant_for_range(0,8,0,9)")
    eq("(", exec_lua("return anon:type()"))
    eq(false, exec_lua("return anon:named()"))
    eq("number", type(exec_lua("return anon:symbol()")))
    eq({'(', false}, exec_lua("return lang.symbols[anon:symbol()]"))

    exec_lua("descendant = root:descendant_for_range(1,2,1,12)")
    eq("<node declaration>", exec_lua("return tostring(descendant)"))
    eq({1,2,1,12}, exec_lua("return {descendant:range()}"))
    eq("(declaration type: (primitive_type) declarator: (init_declarator declarator: (identifier) value: (number_literal)))", exec_lua("return descendant:sexpr()"))

    feed("2G7|ay")
    exec_lua([[
      tree2 = parser:parse()
      root2 = tree2:root()
      descendant2 = root2:descendant_for_range(1,2,1,13)
    ]])
    eq(false, exec_lua("return tree2 == tree1"))
    eq(false, exec_lua("return root2 == root"))
    eq("<node declaration>", exec_lua("return tostring(descendant2)"))
    eq({1,2,1,13}, exec_lua("return {descendant2:range()}"))

    eq(true, exec_lua("return child == child"))
    -- separate lua object, but represents same node
    eq(true, exec_lua("return child == root:child(0)"))
    eq(false, exec_lua("return child == descendant2"))
    eq(false, exec_lua("return child == nil"))
    eq(false, exec_lua("return child == tree"))

    eq("string", exec_lua("return type(child:id())"))
    eq(true, exec_lua("return child:id() == child:id()"))
    -- separate lua object, but represents same node
    eq(true, exec_lua("return child:id() == root:child(0):id()"))
    eq(false, exec_lua("return child:id() == descendant2:id()"))
    eq(false, exec_lua("return child:id() == nil"))
    eq(false, exec_lua("return child:id() == tree"))

    -- orginal tree did not change
    eq({1,2,1,12}, exec_lua("return {descendant:range()}"))

    -- unchanged buffer: return the same tree
    eq(true, exec_lua("return parser:parse() == tree2"))
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

  it('allows to iterate over nodes children', function()
    if not check_parser() then return end

    insert(test_text);

    local res = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      func_node = parser:parse():root():child(0)

      res = {}
      for node, field in func_node:iter_children() do
        table.insert(res, {node:type(), field})
      end
      return res
    ]])

    eq({
      {"primitive_type", "type"},
      {"function_declarator", "declarator"},
      {"compound_statement", "body"}
    }, res)
  end)

  it('allows to get a child by field', function()
    if not check_parser() then return end

    insert(test_text);

    local res = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      func_node = parser:parse():root():child(0)

      local res = {}
      for _, node in ipairs(func_node:field("type")) do
        table.insert(res, {node:type(), node:range()})
      end
      return res
    ]])

    eq({{ "primitive_type", 0, 0, 0, 4 }}, res)

    local res_fail = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      return #func_node:field("foo") == 0
    ]])

    assert(res_fail)
  end)

  local query = [[
    ((call_expression function: (identifier) @minfunc (argument_list (identifier) @min_id)) (eq? @minfunc "MIN"))
    "for" @keyword
    (primitive_type) @type
    (field_expression argument: (identifier) @fieldarg)
  ]]

  it("supports runtime queries", function()
    if not check_parser() then return end

    local ret = exec_lua [[
      return require"vim.treesitter.query".get_query("c", "highlights").captures[1]
    ]]

    eq('variable', ret)
  end)

  it('support query and iter by capture', function()
    if not check_parser() then return end

    insert(test_text)

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()
      res = {}
      for cid, node in cquery:iter_captures(tree:root(), 0, 7, 14) do
        -- can't transmit node over RPC. just check the name and range
        table.insert(res, {cquery.captures[cid], node:type(), node:range()})
      end
      return res
    ]], query)

    eq({
      { "type", "primitive_type", 8, 2, 8, 6 },
      { "keyword", "for", 9, 2, 9, 5 },
      { "type", "primitive_type", 9, 7, 9, 13 },
      { "minfunc", "identifier", 11, 12, 11, 15 },
      { "fieldarg", "identifier", 11, 16, 11, 18 },
      { "min_id", "identifier", 11, 27, 11, 32 },
      { "minfunc", "identifier", 12, 13, 12, 16 },
      { "fieldarg", "identifier", 12, 17, 12, 19 },
      { "min_id", "identifier", 12, 29, 12, 35 },
      { "fieldarg", "identifier", 13, 14, 13, 16 }
    }, res)
  end)

  it('support query and iter by match', function()
    if not check_parser() then return end

    insert(test_text)

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0, 7, 14) do
        -- can't transmit node over RPC. just check the name and range
        local mrepr = {}
        for cid,node in pairs(match) do
          table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]], query)

    eq({
      { 3, { { "type", "primitive_type", 8, 2, 8, 6 } } },
      { 2, { { "keyword", "for", 9, 2, 9, 5 } } },
      { 3, { { "type", "primitive_type", 9, 7, 9, 13 } } },
      { 4, { { "fieldarg", "identifier", 11, 16, 11, 18 } } },
      { 1, { { "minfunc", "identifier", 11, 12, 11, 15 }, { "min_id", "identifier", 11, 27, 11, 32 } } },
      { 4, { { "fieldarg", "identifier", 12, 17, 12, 19 } } },
      { 1, { { "minfunc", "identifier", 12, 13, 12, 16 }, { "min_id", "identifier", 12, 29, 12, 35 } } },
      { 4, { { "fieldarg", "identifier", 13, 14, 13, 16 } } }
    }, res)
  end)

  it('allow loading query with escaped quotes and capture them with `lua-match?` and `vim-match?`', function()
    if not check_parser() then return end

    insert('char* astring = "Hello World!";')

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", '((_) @quote (vim-match? @quote "^\\"$")) ((_) @quote (lua-match? @quote "^\\"$"))')
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0, 0, 1) do
        -- can't transmit node over RPC. just check the name and range
        local mrepr = {}
        for cid,node in pairs(match) do
          table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]])

    eq({
      { 1, { { "quote", '"', 0, 16, 0, 17 } } },
      { 2, { { "quote", '"', 0, 16, 0, 17 } } },
      { 1, { { "quote", '"', 0, 29, 0, 30 } } },
      { 2, { { "quote", '"', 0, 29, 0, 30 } } },
    }, res)
  end)

  it('allows to add predicates', function()
    insert([[
    int main(void) {
      return 0;
    }
    ]])

    local custom_query = "((identifier) @main (#is-main? @main))"

    local res = exec_lua([[
    local query = require"vim.treesitter.query"

    local function is_main(match, pattern, bufnr, predicate)
      local node = match[ predicate[2] ]

      return query.get_node_text(node, bufnr)
    end

    local parser = vim.treesitter.get_parser(0, "c")

    query.add_predicate("is-main?", is_main)

    local query = query.parse_query("c", ...)

    local nodes = {}
    for _, node in query:iter_captures(parser:parse():root(), 0, 0, 19) do
      table.insert(nodes, {node:range()})
    end

    return nodes
    ]], custom_query)

    eq({{0, 4, 0, 8}}, res)

    local res_list = exec_lua[[
    local query = require'vim.treesitter.query'

    local list = query.list_predicates()

    table.sort(list)

    return list
    ]]

    eq({ 'contains?', 'eq?', 'is-main?', 'lua-match?', 'match?', 'vim-match?' }, res_list)
  end)

  it('supports highlighting', function()
    if not check_parser() then return end

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

    local screen = Screen.new(65, 18)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Blue1},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [4] = {bold = true, foreground = Screen.colors.Brown},
      [5] = {foreground = Screen.colors.Magenta},
      [6] = {foreground = Screen.colors.Red},
      [7] = {bold = true, foreground = Screen.colors.SlateBlue},
      [8] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [9] = {foreground = Screen.colors.Magenta, background = Screen.colors.Red},
      [10] = {foreground = Screen.colors.Red, background = Screen.colors.Red},
      [11] = {foreground = Screen.colors.Cyan4},
    })

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

    exec_lua([[
      local parser = vim.treesitter.get_parser(0, "c")
      local highlighter = vim.treesitter.highlighter
      local query = ...
      test_hl = highlighter.new(parser, query)
    ]], hl_query)
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

  it("supports highlighting with custom parser", function()
    if not check_parser() then return end

    local screen = Screen.new(65, 18)
    screen:attach()
    screen:set_default_attr_ids({ {bold = true, foreground = Screen.colors.SeaGreen4} })

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

    exec_lua([[
    parser = vim.treesitter.get_parser(0, "c")
    query = vim.treesitter.parse_query("c", "(declaration) @decl")

    local nodes = {}
    for _, node in query:iter_captures(parser:parse():root(), 0, 0, 19) do
      table.insert(nodes, node)
    end

    parser:set_included_ranges(nodes)

    local hl = vim.treesitter.highlighter.new(parser, "(identifier) @type")
    ]])

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

  it('inspects language', function()
    if not check_parser() then return end

    local keys, fields, symbols = unpack(exec_lua([[
      local lang = vim.treesitter.inspect_language('c')
      local keys, symbols = {}, {}
      for k,_ in pairs(lang) do
        keys[k] = true
      end

      -- symbols array can have "holes" and is thus not a valid msgpack array
      -- but we don't care about the numbers here (checked in the parser test)
      for _, v in pairs(lang.symbols) do
        table.insert(symbols, v)
      end
      return {keys, lang.fields, symbols}
    ]]))

    eq({fields=true, symbols=true}, keys)

    local fset = {}
    for _,f in pairs(fields) do
      eq("string", type(f))
      fset[f] = true
    end
    eq(true, fset["directive"])
    eq(true, fset["initializer"])

    local has_named, has_anonymous
    for _,s in pairs(symbols) do
      eq("string", type(s[1]))
      eq("boolean", type(s[2]))
      if s[1] == "for_statement" and s[2] == true then
        has_named = true
      elseif s[1] == "|=" and s[2] == false then
        has_anonymous = true
      end
    end
    eq({true,true}, {has_named,has_anonymous})
  end)
  it('allows to set simple ranges', function()
    if not check_parser() then return end

    insert(test_text)

    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    return { parser:parse():root():range() }
    ]]

    eq({0, 0, 19, 0}, res)

    -- The following sets the included ranges for the current parser
    -- As stated here, this only includes the function (thus the whole buffer, without the last line)
    local res2 = exec_lua [[
    local root = parser:parse():root()
    parser:set_included_ranges({root:child(0)})
    parser.valid = false
    return { parser:parse():root():range() }
    ]]

    eq({0, 0, 18, 1}, res2)

    local range = exec_lua [[
      return parser:included_ranges()
    ]]

    eq(range, { { 0, 0, 18, 1 } })
  end)
  it("allows to set complex ranges", function()
    if not check_parser() then return end

    insert(test_text)


    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    query = vim.treesitter.parse_query("c", "(declaration) @decl")

    local nodes = {}
    for _, node in query:iter_captures(parser:parse():root(), 0, 0, 19) do
      table.insert(nodes, node)
    end

    parser:set_included_ranges(nodes)

    local root = parser:parse():root()

    local res = {}
    for i=0,(root:named_child_count() - 1) do
      table.insert(res, { root:named_child(i):range() })
    end
    return res
    ]]

    eq({
      { 2, 2, 2, 40 },
      { 3, 3, 3, 32 },
      { 4, 7, 4, 8 },
      { 4, 8, 4, 25 },
      { 8, 2, 8, 6 },
      { 8, 7, 8, 33 },
      { 9, 8, 9, 20 },
      { 10, 4, 10, 5 },
      { 10, 5, 10, 20 },
      { 14, 9, 14, 27 } }, res)
  end)

  it("allows to create string parsers", function()
    local ret = exec_lua [[
      local parser = vim.treesitter.get_string_parser("int foo = 42;", "c")
      return { parser:parse():root():range() }
    ]]

    eq({ 0, 0, 0, 13 }, ret)
  end)

  it("allows to run queries with string parsers", function()
    local txt = [[
      int foo = 42;
      int bar = 13;
    ]]

    local ret = exec_lua([[
    local str = ...
    local parser = vim.treesitter.get_string_parser(str, "c")

    local nodes = {}
    local query = vim.treesitter.parse_query("c", '((identifier) @id (eq? @id "foo"))')

    for _, node in query:iter_captures(parser:parse():root(), str, 0, 2) do
      table.insert(nodes, { node:range() })
    end

    return nodes]], txt)

    eq({ {0, 10, 0, 13} }, ret)
  end)
end)
