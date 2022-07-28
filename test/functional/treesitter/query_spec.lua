local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local pending_c_parser = helpers.pending_c_parser

before_each(clear)

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

describe('treesitter query', function()
  clear()
  if pending_c_parser(pending) then return end

  local query = [[
    ((call_expression function: (identifier) @minfunc (argument_list (identifier) @min_id)) (eq? @minfunc "MIN"))
    "for" @keyword
    (primitive_type) @type
    (field_expression argument: (identifier) @fieldarg)
  ]]

  it("supports runtime", function()
    local ret = exec_lua [[
      return require"vim.treesitter.query".get_query("c", "highlights").captures[1]
    ]]

    eq('variable', ret)
  end)

  it("supports caching", function()
    local long_query = query:rep(100)
    local function q(n)
      return exec_lua([[
        local query, n = ...
        local before = vim.loop.hrtime()
        for i=1,n,1 do
          cquery = vim.treesitter.parse_query("c", ...)
        end
        local after = vim.loop.hrtime()
        return after - before
      ]], long_query, n)
    end

    local firstrun = q(1)
    local manyruns = q(100)

    -- First run should be at least 4x slower.
    assert(400 * manyruns < firstrun,
      ('firstrun: %d ms, manyruns: %d ms'):format(firstrun / 1000, manyruns / 1000))
  end)

  it('support iter by capture', function()
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

  it('support iter by match', function()
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
      { 1,
        { { "minfunc", "identifier", 11, 12, 11, 15 }, { "min_id", "identifier", 11, 27, 11, 32 } } },
      { 4, { { "fieldarg", "identifier", 12, 17, 12, 19 } } },
      { 1,
        { { "minfunc", "identifier", 12, 13, 12, 16 }, { "min_id", "identifier", 12, 29, 12, 35 } } },
      { 4, { { "fieldarg", "identifier", 13, 14, 13, 16 } } }
    }, res)
  end)

  it('can match special regex characters like \\ * + ( with `vim-match?`', function()
    insert('char* astring = "\\n"; (1 + 1) * 2 != 2;')

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", '([_] @plus (#vim-match? @plus "^\\\\+$"))'..
                                               '([_] @times (#vim-match? @times "^\\\\*$"))'..
                                               '([_] @paren (#vim-match? @paren "^\\\\($"))'..
                                               '([_] @escape (#vim-match? @escape "^\\\\\\\\n$"))'..
                                               '([_] @string (#vim-match? @string "^\\"\\\\\\\\n\\"$"))')
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

  it('supports builtin predicate any-of?', function()
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
      { "fizzbuzz-strings", "string_literal", { 6, 15, 6, 38 }, "\"number= %d FizzBuzz\\n\"" },
      { "fizzbuzz-strings", "string_literal", { 8, 15, 8, 34 }, "\"number= %d Fizz\\n\"" },
      { "fizzbuzz-strings", "string_literal", { 10, 15, 10, 34 }, "\"number= %d Buzz\\n\"" },
    }, res1)
  end)

  it('allows escaped quotes and capturing them with `lua-match?` and `vim-match?`', function()
    insert('char* astring = "Hello World!";')

    local res = exec_lua([[
      cquery = vim.treesitter.parse_query("c", '([_] @quote (#vim-match? @quote "^\\"$")) ([_] @quote (#lua-match? @quote "^\\"$"))')
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

    eq({ { 0, 4, 0, 8 } }, res)

    local res_list = exec_lua [[
    local query = require'vim.treesitter.query'

    local list = query.list_predicates()

    table.sort(list)

    return list
    ]]

    eq({ 'any-of?', 'contains?', 'eq?', 'is-main?', 'lua-match?', 'match?', 'vim-match?' }, res_list)
  end)

  describe('supports query quantifiers', function()

    local quant_query = [[
      (declaration (init_declarator)+ @test)
    ]]

    before_each(function()
      insert(test_text)
    end)

    it('with iter_captures', function()
      pending("TODO")
      local res = exec_lua([[
        cquery = vim.treesitter.parse_query("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for cid, tbl in cquery:iter_captures(tree:root(), 0, 0, 7) do
          -- can't transmit node over RPC. just check the name and range
          for _,node in ipairs(tbl) do
            table.insert(res, {cquery.captures[cid], node:type(), node:range()})
          end
        end
        return res
      ]], quant_query)

      eq({
        {
          'test',
          'init_declarator',
          2,
          6,
          2,
          21
        },
        {
          'test',
          'init_declarator',
          2,
          24,
          2,
          39
        },
      }, res)
    end)
    it('with iter_matches', function()
      local res = exec_lua([[
        cquery = vim.treesitter.parse_query("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for pid,match in cquery:iter_matches(tree:root(), 0, 0, 7) do
          for cid, tbl in match do
            -- can't transmit node over RPC. just check the name and range
            for _,node in ipairs(tbl) do
              table.insert(res, {cquery.captures[cid], node:type(), node:range()})
            end
          end
        end
        return res
      ]], quant_query)

      eq({
        {
          'test',
          'init_declarator',
          2,
          6,
          2,
          21
        },
        {
          'test',
          'init_declarator',
          2,
          24,
          2,
          39
        },
      }, res)
    end)
  end)
end)
