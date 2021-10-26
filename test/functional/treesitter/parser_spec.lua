local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local feed = helpers.feed
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

describe('treesitter parser API', function()
  clear()
  if pending_c_parser(pending) then return end

  it('parses buffer', function()
    if helpers.pending_win32(pending) then return end

    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
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
      tree2 = parser:parse()[1]
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

    -- unchanged buffer: return the same tree
    eq(true, exec_lua("return parser:parse()[1] == tree2"))
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
    insert(test_text);

    local res = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      func_node = parser:parse()[1]:root():child(0)

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
    insert(test_text);

    local res = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      func_node = parser:parse()[1]:root():child(0)

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
    local ret = exec_lua [[
      return require"vim.treesitter.query".get_query("c", "highlights").captures[1]
    ]]

    eq('variable', ret)
  end)

  it('support query and iter by capture', function()
    insert(test_text)

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
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
    insert(test_text)

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
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

  it('can match special regex characters like \\ * + ( with `vim-match?`', function()
    insert('char* astring = "\\n"; (1 + 1) * 2 != 2;')

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", '((_) @plus (vim-match? @plus "^\\\\+$"))'..
                                               '((_) @times (vim-match? @times "^\\\\*$"))'..
                                               '((_) @paren (vim-match? @paren "^\\\\($"))'..
                                               '((_) @escape (vim-match? @escape "^\\\\\\\\n$"))'..
                                               '((_) @string (vim-match? @string "^\\"\\\\\\\\n\\"$"))')
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0) do
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
      { 2, { { "times", '*', 0, 4, 0, 5 } } },
      { 5, { { "string", 'string_literal', 0, 16, 0, 20 } } },
      { 4, { { "escape", 'escape_sequence', 0, 17, 0, 19 } } },
      { 3, { { "paren", '(', 0, 22, 0, 23 } } },
      { 1, { { "plus", '+', 0, 25, 0, 26 } } },
      { 2, { { "times", '*', 0, 30, 0, 31 } } },
    }, res)
  end)

  it('supports builtin query predicate any-of?', function()
    insert([[
      #include <stdio.h>

      int main(void) {
        int i;
        for(i=1; i<=100; i++) {
          if(((i%3)||(i%5))== 0)
            printf("number= %d FizzBuzz\n", i);
          else if((i%3)==0)
            printf("number= %d Fizz\n", i);
          else if((i%5)==0)
            printf("number= %d Buzz\n", i);
          else
            printf("number= %d\n",i);
        }
        return 0;
      }
    ]])
    exec_lua([[
      function get_query_result(query_text)
        cquery = vim.treesitter.parse_query("c", query_text)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for cid, node in cquery:iter_captures(tree:root(), 0) do
          -- can't transmit node over RPC. just check the name, range, and text
          local text = vim.treesitter.get_node_text(node, 0)
          local range = {node:range()}
          table.insert(res, {cquery.captures[cid], node:type(), range, text})
        end
        return res
      end
    ]])

    local res0 = exec_lua([[return get_query_result(...)]],
      [[((primitive_type) @c-keyword (#any-of? @c-keyword "int" "float"))]])
    eq({
      { "c-keyword", "primitive_type", { 2, 2, 2, 5 }, "int" },
      { "c-keyword", "primitive_type", { 3, 4, 3, 7 }, "int" },
    }, res0)

    local res1 = exec_lua([[return get_query_result(...)]],
      [[
        ((string_literal) @fizzbuzz-strings (#any-of? @fizzbuzz-strings
          "\"number= %d FizzBuzz\\n\""
          "\"number= %d Fizz\\n\""
          "\"number= %d Buzz\\n\""
        ))
      ]])
    eq({
      { "fizzbuzz-strings", "string_literal", { 6, 15, 6, 38 }, "\"number= %d FizzBuzz\\n\""},
      { "fizzbuzz-strings", "string_literal", { 8, 15, 8, 34 }, "\"number= %d Fizz\\n\""},
      { "fizzbuzz-strings", "string_literal", { 10, 15, 10, 34 }, "\"number= %d Buzz\\n\""},
    }, res1)
  end)

  it('allow loading query with escaped quotes and capture them with `lua-match?` and `vim-match?`', function()
    insert('char* astring = "Hello World!";')

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", '((_) @quote (vim-match? @quote "^\\"$")) ((_) @quote (lua-match? @quote "^\\"$"))')
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0) do
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
    for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
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

    eq({ 'any-of?', 'contains?', 'eq?', 'is-main?', 'lua-match?', 'match?', 'vim-match?' }, res_list)
  end)


  it('allows to set simple ranges', function()
    insert(test_text)

    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    return { parser:parse()[1]:root():range() }
    ]]

    eq({0, 0, 19, 0}, res)

    -- The following sets the included ranges for the current parser
    -- As stated here, this only includes the function (thus the whole buffer, without the last line)
    local res2 = exec_lua [[
    local root = parser:parse()[1]:root()
    parser:set_included_regions({{root:child(0)}})
    parser:invalidate()
    return { parser:parse()[1]:root():range() }
    ]]

    eq({0, 0, 18, 1}, res2)

    local range = exec_lua [[
      local res = {}
      for _, region in ipairs(parser:included_regions()) do
        for _, node in ipairs(region) do
          table.insert(res, {node:range()})
        end
      end
      return res
    ]]

    eq(range, { { 0, 0, 18, 1 } })

    local range_tbl = exec_lua [[
      parser:set_included_regions { { { 0, 0, 17, 1 } } }
      parser:parse()
      return parser:included_regions()
    ]]

    eq(range_tbl, { { { 0, 0, 0, 17, 1, 508 } } })
  end)
  it("allows to set complex ranges", function()
    insert(test_text)

    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    query = vim.treesitter.parse_query("c", "(declaration) @decl")

    local nodes = {}
    for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
      table.insert(nodes, node)
    end

    parser:set_included_regions({nodes})

    local root = parser:parse()[1]:root()

    local res = {}
    for i=0,(root:named_child_count() - 1) do
      table.insert(res, { root:named_child(i):range() })
    end
    return res
    ]]

    eq({
      { 2, 2, 2, 40 },
      { 3, 2, 3, 32 },
      { 4, 7, 4, 25 },
      { 8, 2, 8, 33 },
      { 9, 7, 9, 20 },
      { 10, 4, 10, 20 },
      { 14, 9, 14, 27 } }, res)
  end)

  it("allows to create string parsers", function()
    local ret = exec_lua [[
      local parser = vim.treesitter.get_string_parser("int foo = 42;", "c")
      return { parser:parse()[1]:root():range() }
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

    for _, node in query:iter_captures(parser:parse()[1]:root(), str) do
      table.insert(nodes, { node:range() })
    end

    return nodes]], txt)

    eq({ {0, 10, 0, 13} }, ret)
  end)

  it("should use node range when omitted", function()
    local txt = [[
      int foo = 42;
      int bar = 13;
    ]]

    local ret = exec_lua([[
    local str = ...
    local parser = vim.treesitter.get_string_parser(str, "c")

    local nodes = {}
    local query = vim.treesitter.parse_query("c", '((identifier) @foo)')
    local first_child = parser:parse()[1]:root():child(1)

    for _, node in query:iter_captures(first_child, str) do
      table.insert(nodes, { node:range() })
    end

    return nodes]], txt)

    eq({ {1, 10, 1, 13} }, ret)
  end)

  describe("when creating a language tree", function()
    local function get_ranges()
      return exec_lua([[
      local result = {}
      parser:for_each_tree(function(tree) table.insert(result, {tree:root():range()}) end)
      return result
      ]])
    end

    before_each(function()
      insert([[
int x = INT_MAX;
#define READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
#define READ_STRING_OK(x, y) (char_u *)read_string((x), (size_t)(y))
#define VALUE 123
#define VALUE1 123
#define VALUE2 123
      ]])
    end)

    describe("when parsing regions independently", function()
      it("should inject a language", function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = "(preproc_def (preproc_arg) @c) (preproc_function_def value: (preproc_arg) @c)"}})
        ]])

        eq("table", exec_lua("return type(parser:children().c)"))
        eq(5, exec_lua("return #parser:children().c:trees()"))
        eq({
          {0, 0, 7, 0},   -- root tree
          {3, 14, 3, 17}, -- VALUE 123
          {4, 15, 4, 18}, -- VALUE1 123
          {5, 15, 5, 18}, -- VALUE2 123
          {1, 26, 1, 65}, -- READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
          {2, 29, 2, 68}  -- READ_STRING_OK(x, y) (char_u *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe("when parsing regions combined", function()
      it("should inject a language", function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = "(preproc_def (preproc_arg) @c @combined) (preproc_function_def value: (preproc_arg) @c @combined)"}})
        ]])

        eq("table", exec_lua("return type(parser:children().c)"))
        eq(2, exec_lua("return #parser:children().c:trees()"))
        eq({
          {0, 0, 7, 0},   -- root tree
          {3, 14, 5, 18}, -- VALUE 123
                          -- VALUE1 123
                          -- VALUE2 123
          {1, 26, 2, 68}  -- READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
                          -- READ_STRING_OK(x, y) (char_u *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe("when providing parsing information through a directive", function()
      it("should inject a language", function()
        exec_lua([=[
        vim.treesitter.add_directive("inject-clang!", function(match, _, _, pred, metadata)
          metadata.language = "c"
          metadata.combined = true
          metadata.content = pred[2]
        end)

        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = "(preproc_def ((preproc_arg) @_c (#inject-clang! @_c)))" ..
                "(preproc_function_def value: ((preproc_arg) @_a (#inject-clang! @_a)))"}})
        ]=])

        eq("table", exec_lua("return type(parser:children().c)"))
        eq(2, exec_lua("return #parser:children().c:trees()"))
        eq({
          {0, 0, 7, 0},   -- root tree
          {3, 14, 5, 18}, -- VALUE 123
                          -- VALUE1 123
                          -- VALUE2 123
          {1, 26, 2, 68}  -- READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
                          -- READ_STRING_OK(x, y) (char_u *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe("when using the offset directive", function()
      it("should shift the range by the directive amount", function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = "(preproc_def ((preproc_arg) @c (#offset! @c 0 2 0 -1))) (preproc_function_def value: (preproc_arg) @c)"}})
        ]])

        eq("table", exec_lua("return type(parser:children().c)"))
        eq({
          {0, 0, 7, 0},   -- root tree
          {3, 15, 3, 16}, -- VALUE 123
          {4, 16, 4, 17}, -- VALUE1 123
          {5, 16, 5, 17}, -- VALUE2 123
          {1, 26, 1, 65}, -- READ_STRING(x, y) (char_u *)read_string((x), (size_t)(y))
          {2, 29, 2, 68}  -- READ_STRING_OK(x, y) (char_u *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
      it("should list all directives", function()
        local res_list = exec_lua[[
        local query = require'vim.treesitter.query'

        local list = query.list_directives()

        table.sort(list)

        return list
        ]]

        eq({ 'offset!', 'set!' }, res_list)
      end)
    end)
  end)

  describe("when getting the language for a range", function()
    before_each(function()
      insert([[
int x = INT_MAX;
#define VALUE 123456789
      ]])
    end)

    it("should return the correct language tree", function()
      local result = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c", {
        injections = { c = "(preproc_def (preproc_arg) @c)"}})

      local sub_tree = parser:language_for_range({1, 18, 1, 19})

      return sub_tree == parser:children().c
      ]])

      eq(result, true)
    end)
  end)

  describe("when getting/setting match data", function()
    describe("when setting for the whole match", function()
      it("should set/get the data correctly", function()
        insert([[
          int x = 3;
        ]])

        local result = exec_lua([[
        local result

        query = vim.treesitter.parse_query("c", '((number_literal) @number (#set! "key" "value"))')
        parser = vim.treesitter.get_parser(0, "c")

        for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0) do
          result = metadata.key
        end

        return result
        ]])

        eq(result, "value")
      end)

      describe("when setting a key on a capture", function()
        it("it should create the nested table", function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua([[
          local query = require("vim.treesitter.query")
          local value

          query = vim.treesitter.parse_query("c", '((number_literal) @number (#set! @number "key" "value"))')
          parser = vim.treesitter.get_parser(0, "c")

          for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0) do
            for _, nested_tbl in pairs(metadata) do
              return nested_tbl.key
            end
          end
          ]])

          eq(result, "value")
        end)

        it("it should not overwrite the nested table", function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua([[
          local query = require("vim.treesitter.query")
          local result

          query = vim.treesitter.parse_query("c", '((number_literal) @number (#set! @number "key" "value") (#set! @number "key2" "value2"))')
          parser = vim.treesitter.get_parser(0, "c")

          for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0) do
            for _, nested_tbl in pairs(metadata) do
              return nested_tbl
            end
          end
          ]])
          local expected = {
            ["key"] = "value",
            ["key2"] = "value2",
          }

          eq(expected, result)
        end)
      end)
    end)
  end)
end)
