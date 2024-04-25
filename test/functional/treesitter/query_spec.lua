local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local dedent = t.dedent
local eq = t.eq
local insert = n.insert
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local api = n.api
local fn = n.fn

local get_query_result_code = [[
  function get_query_result(query_text)
    cquery = vim.treesitter.query.parse("c", query_text)
    parser = vim.treesitter.get_parser(0, "c")
    tree = parser:parse()[1]
    res = {}
    for cid, node in cquery:iter_captures(tree:root(), 0) do
      -- can't transmit node over RPC. just check the name, range, and text
      local text = vim.treesitter.get_node_text(node, 0)
      local range = {node:range()}
      table.insert(res, { cquery.captures[cid], node:type(), range, text })
    end
    return res
  end
]]

describe('treesitter query API', function()
  before_each(function()
    clear()
    exec_lua [[
      vim.g.__ts_debug = 1
    ]]
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

  local test_query = [[
    ((call_expression
      function: (identifier) @minfunc
      (argument_list (identifier) @min_id))
      (#eq? @minfunc "MIN")
    )

    "for" @keyword

    (primitive_type) @type

    (field_expression argument: (identifier) @fieldarg)
  ]]

  it('supports runtime queries', function()
    ---@type string[]
    local ret = exec_lua [[
      return vim.treesitter.query.get("c", "highlights").captures
    ]]

    -- see $VIMRUNTIME/queries/c/highlights.scm
    eq('variable', ret[1])
    eq('keyword', ret[2])
  end)

  it('supports caching queries', function()
    local long_query = test_query:rep(100)
    ---@return number
    local function q(_n)
      return exec_lua(
        [[
          local query, n = ...
          local before = vim.api.nvim__stats().ts_query_parse_count
          collectgarbage("stop")
          for i=1, n, 1 do
            cquery = vim.treesitter.query.parse("c", ...)
          end
          collectgarbage("restart")
          collectgarbage("collect")
          local after = vim.api.nvim__stats().ts_query_parse_count
          return after - before
        ]],
        long_query,
        _n
      )
    end

    eq(1, q(1))
    -- cache is cleared by garbage collection even if valid "cquery" reference is kept around
    eq(1, q(100))
  end)

  it('supports query and iter by capture (iter_captures)', function()
    insert(test_text)

    local res = exec_lua(
      [[
        cquery = vim.treesitter.query.parse("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for cid, node in cquery:iter_captures(tree:root(), 0, 7, 14) do
          -- can't transmit node over RPC. just check the name and range
          table.insert(res, { '@' .. cquery.captures[cid], node:type(), node:range() })
        end
        return res
      ]],
      test_query
    )

    eq({
      { '@type', 'primitive_type', 8, 2, 8, 6 }, -- bool
      { '@keyword', 'for', 9, 2, 9, 5 }, -- for
      { '@type', 'primitive_type', 9, 7, 9, 13 }, -- size_t
      { '@minfunc', 'identifier', 11, 12, 11, 15 }, -- "MIN"(ui->width, width);
      { '@fieldarg', 'identifier', 11, 16, 11, 18 }, --      ui
      { '@min_id', 'identifier', 11, 27, 11, 32 }, -- width
      { '@minfunc', 'identifier', 12, 13, 12, 16 }, -- "MIN"(ui->height, height);
      { '@fieldarg', 'identifier', 12, 17, 12, 19 }, --      ui
      { '@min_id', 'identifier', 12, 29, 12, 35 }, -- height
      { '@fieldarg', 'identifier', 13, 14, 13, 16 }, -- ui   ; in BAR(..)
    }, res)
  end)

  it('supports query and iter by match (iter_matches)', function()
    insert(test_text)

    ---@type table
    local res = exec_lua(
      [[
        cquery = vim.treesitter.query.parse("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for pattern, match in cquery:iter_matches(tree:root(), 0, 7, 14, { all = true }) do
          -- can't transmit node over RPC. just check the name and range
          local mrepr = {}
          for cid, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
              table.insert(mrepr, { '@' .. cquery.captures[cid], node:type(), node:range() })
            end
          end
          table.insert(res, { pattern, mrepr })
        end
        return res
      ]],
      test_query
    )

    eq({
      { 3, { { '@type', 'primitive_type', 8, 2, 8, 6 } } },
      { 2, { { '@keyword', 'for', 9, 2, 9, 5 } } },
      { 3, { { '@type', 'primitive_type', 9, 7, 9, 13 } } },
      { 4, { { '@fieldarg', 'identifier', 11, 16, 11, 18 } } },
      {
        1,
        {
          { '@minfunc', 'identifier', 11, 12, 11, 15 },
          { '@min_id', 'identifier', 11, 27, 11, 32 },
        },
      },
      { 4, { { '@fieldarg', 'identifier', 12, 17, 12, 19 } } },
      {
        1,
        {
          { '@minfunc', 'identifier', 12, 13, 12, 16 },
          { '@min_id', 'identifier', 12, 29, 12, 35 },
        },
      },
      { 4, { { '@fieldarg', 'identifier', 13, 14, 13, 16 } } },
    }, res)
  end)

  it('supports query and iter by capture for quantifiers', function()
    insert(test_text)

    local res = exec_lua(
      [[
        cquery = vim.treesitter.query.parse("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for cid, node in cquery:iter_captures(tree:root(), 0, 7, 14) do
          -- can't transmit node over RPC. just check the name and range
          table.insert(res, { '@' .. cquery.captures[cid], node:type(), node:range() })
        end
        return res
      ]],
      '(expression_statement (assignment_expression (call_expression)))+ @funccall'
    )

    eq({
      { '@funccall', 'expression_statement', 11, 4, 11, 34 },
      { '@funccall', 'expression_statement', 12, 4, 12, 37 },
      { '@funccall', 'expression_statement', 13, 4, 13, 34 },
    }, res)
  end)

  it('supports query and iter by match for quantifiers', function()
    insert(test_text)

    local res = exec_lua(
      [[
        cquery = vim.treesitter.query.parse("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for pattern, match in cquery:iter_matches(tree:root(), 0, 7, 14, { all = true }) do
          -- can't transmit node over RPC. just check the name and range
          local mrepr = {}
          for cid, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
              table.insert(mrepr, { '@' .. cquery.captures[cid], node:type(), node:range() })
            end
          end
          table.insert(res, {pattern, mrepr})
        end
        return res
      ]],
      '(expression_statement (assignment_expression (call_expression)))+ @funccall'
    )

    eq({
      {
        1,
        {
          { '@funccall', 'expression_statement', 11, 4, 11, 34 },
          { '@funccall', 'expression_statement', 12, 4, 12, 37 },
          { '@funccall', 'expression_statement', 13, 4, 13, 34 },
        },
      },
    }, res)
  end)

  it('can match special regex characters like \\ * + ( with `vim-match?`', function()
    insert('char* astring = "\\n"; (1 + 1) * 2 != 2;')

    ---@type table
    local res = exec_lua([[
      query = (
        '([_] @plus (#vim-match? @plus "^\\\\+$"))' ..
        '([_] @times (#vim-match? @times "^\\\\*$"))' ..
        '([_] @paren (#vim-match? @paren "^\\\\($"))' ..
        '([_] @escape (#vim-match? @escape "^\\\\\\\\n$"))' ..
        '([_] @string (#vim-match? @string "^\\"\\\\\\\\n\\"$"))'
      )
      cquery = vim.treesitter.query.parse("c", query)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0, 0, -1, { all = true }) do
        -- can't transmit node over RPC. just check the name and range
        local mrepr = {}
        for cid, nodes in pairs(match) do
          for _, node in ipairs(nodes) do
            table.insert(mrepr, { '@' .. cquery.captures[cid], node:type(), node:range() })
          end
        end
        table.insert(res, { pattern, mrepr })
      end
      return res
    ]])

    eq({
      { 2, { { '@times', '*', 0, 4, 0, 5 } } },
      { 5, { { '@string', 'string_literal', 0, 16, 0, 20 } } },
      { 4, { { '@escape', 'escape_sequence', 0, 17, 0, 19 } } },
      { 3, { { '@paren', '(', 0, 22, 0, 23 } } },
      { 1, { { '@plus', '+', 0, 25, 0, 26 } } },
      { 2, { { '@times', '*', 0, 30, 0, 31 } } },
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
    exec_lua(get_query_result_code)

    local res0 = exec_lua(
      [[return get_query_result(...)]],
      [[((primitive_type) @c-keyword (#any-of? @c-keyword "int" "float"))]]
    )
    eq({
      { 'c-keyword', 'primitive_type', { 2, 2, 2, 5 }, 'int' },
      { 'c-keyword', 'primitive_type', { 3, 4, 3, 7 }, 'int' },
    }, res0)

    local res1 = exec_lua(
      [[return get_query_result(...)]],
      [[
        ((string_literal) @fizzbuzz-strings (#any-of? @fizzbuzz-strings
          "\"number= %d FizzBuzz\\n\""
          "\"number= %d Fizz\\n\""
          "\"number= %d Buzz\\n\""
        ))
      ]]
    )
    eq({
      { 'fizzbuzz-strings', 'string_literal', { 6, 15, 6, 38 }, '"number= %d FizzBuzz\\n"' },
      { 'fizzbuzz-strings', 'string_literal', { 8, 15, 8, 34 }, '"number= %d Fizz\\n"' },
      { 'fizzbuzz-strings', 'string_literal', { 10, 15, 10, 34 }, '"number= %d Buzz\\n"' },
    }, res1)
  end)

  it('supports builtin predicate has-ancestor?', function()
    insert([[
      int x = 123;
      enum C { y = 124 };
      int main() { int z = 125; }]])
    exec_lua(get_query_result_code)

    local result = exec_lua(
      [[return get_query_result(...)]],
      [[((number_literal) @literal (#has-ancestor? @literal "function_definition"))]]
    )
    eq({ { 'literal', 'number_literal', { 2, 21, 2, 24 }, '125' } }, result)

    result = exec_lua(
      [[return get_query_result(...)]],
      [[((number_literal) @literal (#has-ancestor? @literal "function_definition" "enum_specifier"))]]
    )
    eq({
      { 'literal', 'number_literal', { 1, 13, 1, 16 }, '124' },
      { 'literal', 'number_literal', { 2, 21, 2, 24 }, '125' },
    }, result)

    result = exec_lua(
      [[return get_query_result(...)]],
      [[((number_literal) @literal (#not-has-ancestor? @literal "enum_specifier"))]]
    )
    eq({
      { 'literal', 'number_literal', { 0, 8, 0, 11 }, '123' },
      { 'literal', 'number_literal', { 2, 21, 2, 24 }, '125' },
    }, result)
  end)

  it('allows loading query with escaped quotes and capture them `#{lua,vim}-match`?', function()
    insert('char* astring = "Hello World!";')

    local res = exec_lua([[
      cquery = vim.treesitter.query.parse("c", '([_] @quote (#vim-match? @quote "^\\"$")) ([_] @quote (#lua-match? @quote "^\\"$"))')
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0, 0, -1, { all = true }) do
        -- can't transmit node over RPC. just check the name and range
        local mrepr = {}
        for cid, nodes in pairs(match) do
          for _, node in ipairs(nodes) do
            table.insert(mrepr, { '@' .. cquery.captures[cid], node:type(), node:range() })
          end
        end
        table.insert(res, { pattern, mrepr })
      end
      return res
    ]])

    eq({
      { 1, { { '@quote', '"', 0, 16, 0, 17 } } },
      { 2, { { '@quote', '"', 0, 16, 0, 17 } } },
      { 1, { { '@quote', '"', 0, 29, 0, 30 } } },
      { 2, { { '@quote', '"', 0, 29, 0, 30 } } },
    }, res)
  end)

  it('allows to add predicates', function()
    insert([[
    int main(void) {
      return 0;
    }
    ]])

    local custom_query = '((identifier) @main (#is-main? @main))'

    do
      local res = exec_lua(
        [[
          local query = vim.treesitter.query

          local function is_main(match, pattern, bufnr, predicate)
            local nodes = match[ predicate[2] ]
            for _, node in ipairs(nodes) do
              if vim.treesitter.get_node_text(node, bufnr) == 'main' then
                return true
              end
            end
            return false
          end

          local parser = vim.treesitter.get_parser(0, "c")

          -- Time bomb: update this in 0.12
          if vim.fn.has('nvim-0.12') == 1 then
            return 'Update this test to remove this message and { all = true } from add_predicate'
          end
          query.add_predicate("is-main?", is_main, { all = true })

          local query = query.parse("c", ...)

          local nodes = {}
          for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
            table.insert(nodes, {node:range()})
          end

          return nodes
        ]],
        custom_query
      )

      eq({ { 0, 4, 0, 8 } }, res)
    end

    -- Once with the old API. Remove this whole 'do' block in 0.12
    do
      local res = exec_lua(
        [[
          local query = vim.treesitter.query

          local function is_main(match, pattern, bufnr, predicate)
            local node = match[ predicate[2] ]

            return vim.treesitter.get_node_text(node, bufnr) == 'main'
          end

          local parser = vim.treesitter.get_parser(0, "c")

          query.add_predicate("is-main?", is_main, true)

          local query = query.parse("c", ...)

          local nodes = {}
          for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
            table.insert(nodes, {node:range()})
          end

          return nodes
        ]],
        custom_query
      )

      -- Remove this 'do' block in 0.12
      eq(0, fn.has('nvim-0.12'))
      eq({ { 0, 4, 0, 8 } }, res)
    end

    do
      local res = exec_lua [[
        local query = vim.treesitter.query

        local t = {}
        for _, v in ipairs(query.list_predicates()) do
          t[v] = true
        end

        return t
      ]]

      eq(true, res['is-main?'])
    end
  end)

  it('supports "all" and "any" semantics for predicates on quantified captures #24738', function()
    local query_all = [[
      (((comment (comment_content))+) @bar
        (#lua-match? @bar "Yes"))
    ]]

    local query_any = [[
      (((comment (comment_content))+) @bar
        (#any-lua-match? @bar "Yes"))
    ]]

    local function test(input, query)
      api.nvim_buf_set_lines(0, 0, -1, true, vim.split(dedent(input), '\n'))
      return exec_lua(
        [[
          local parser = vim.treesitter.get_parser(0, "lua")
          local query = vim.treesitter.query.parse("lua", ...)
          local nodes = {}
          for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
            nodes[#nodes+1] = { node:range() }
          end
          return nodes
        ]],
        query
      )
    end

    eq(
      {},
      test(
        [[
      -- Yes
      -- No
      -- Yes
    ]],
        query_all
      )
    )

    eq(
      {
        { 0, 2, 0, 8 },
        { 1, 2, 1, 8 },
        { 2, 2, 2, 8 },
      },
      test(
        [[
      -- Yes
      -- Yes
      -- Yes
    ]],
        query_all
      )
    )

    eq(
      {},
      test(
        [[
      -- No
      -- No
      -- No
    ]],
        query_any
      )
    )

    eq(
      {
        { 0, 2, 0, 7 },
        { 1, 2, 1, 8 },
        { 2, 2, 2, 7 },
      },
      test(
        [[
      -- No
      -- Yes
      -- No
    ]],
        query_any
      )
    )
  end)

  it('supports any- prefix to match any capture when using quantifiers #24738', function()
    insert([[
      -- Comment
      -- Comment
      -- Comment
    ]])

    local query = [[
      (((comment (comment_content))+) @bar
        (#lua-match? @bar "Comment"))
    ]]

    local result = exec_lua(
      [[
        local parser = vim.treesitter.get_parser(0, "lua")
        local query = vim.treesitter.query.parse("lua", ...)
        local nodes = {}
        for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
          nodes[#nodes+1] = { node:range() }
        end
        return nodes
      ]],
      query
    )

    eq({
      { 0, 2, 0, 12 },
      { 1, 2, 1, 12 },
      { 2, 2, 2, 12 },
    }, result)
  end)

  it('supports the old broken version of iter_matches #24738', function()
    -- Delete this test in 0.12 when iter_matches is removed
    eq(0, fn.has('nvim-0.12'))

    insert(test_text)
    local res = exec_lua(
      [[
        cquery = vim.treesitter.query.parse("c", ...)
        parser = vim.treesitter.get_parser(0, "c")
        tree = parser:parse()[1]
        res = {}
        for pattern, match in cquery:iter_matches(tree:root(), 0, 7, 14) do
          local mrepr = {}
          for cid, node in pairs(match) do
            table.insert(mrepr, { '@' .. cquery.captures[cid], node:type(), node:range() })
          end
          table.insert(res, { pattern, mrepr })
        end
        return res
      ]],
      test_query
    )

    eq({
      { 3, { { '@type', 'primitive_type', 8, 2, 8, 6 } } },
      { 2, { { '@keyword', 'for', 9, 2, 9, 5 } } },
      { 3, { { '@type', 'primitive_type', 9, 7, 9, 13 } } },
      { 4, { { '@fieldarg', 'identifier', 11, 16, 11, 18 } } },
      {
        1,
        {
          { '@minfunc', 'identifier', 11, 12, 11, 15 },
          { '@min_id', 'identifier', 11, 27, 11, 32 },
        },
      },
      { 4, { { '@fieldarg', 'identifier', 12, 17, 12, 19 } } },
      {
        1,
        {
          { '@minfunc', 'identifier', 12, 13, 12, 16 },
          { '@min_id', 'identifier', 12, 29, 12, 35 },
        },
      },
      { 4, { { '@fieldarg', 'identifier', 13, 14, 13, 16 } } },
    }, res)
  end)

  it('should use node range when omitted', function()
    local txt = [[
      int foo = 42;
      int bar = 13;
    ]]

    local ret = exec_lua(
      [[
        local str = ...
        local parser = vim.treesitter.get_string_parser(str, "c")

        local nodes = {}
        local query = vim.treesitter.query.parse("c", '((identifier) @foo)')
        local first_child = parser:parse()[1]:root():child(1)

        for _, node in query:iter_captures(first_child, str) do
          table.insert(nodes, { node:range() })
        end

        return nodes
      ]],
      txt
    )

    eq({ { 1, 10, 1, 13 } }, ret)
  end)

  it('fails to load queries', function()
    local function test(exp, cquery)
      eq(exp, pcall_err(exec_lua, "vim.treesitter.query.parse('c', ...)", cquery))
    end

    -- Invalid node type
    test(
      '.../query.lua:0: Query error at 1:2. Invalid node type "dentifier":\n'
        .. '(dentifier) @variable\n'
        .. ' ^',
      '(dentifier) @variable'
    )

    -- Impossible pattern
    test(
      '.../query.lua:0: Query error at 1:13. Impossible pattern:\n'
        .. '(identifier (identifier) @variable)\n'
        .. '            ^',
      '(identifier (identifier) @variable)'
    )

    -- Invalid syntax
    test(
      '.../query.lua:0: Query error at 1:13. Invalid syntax:\n'
        .. '(identifier @variable\n'
        .. '            ^',
      '(identifier @variable'
    )

    -- Invalid field name
    test(
      '.../query.lua:0: Query error at 1:15. Invalid field name "invalid_field":\n'
        .. '((identifier) invalid_field: (identifier))\n'
        .. '              ^',
      '((identifier) invalid_field: (identifier))'
    )

    -- Invalid capture name
    test(
      '.../query.lua:0: Query error at 3:2. Invalid capture name "ok.capture":\n'
        .. '@ok.capture\n'
        .. ' ^',
      '((identifier) @id \n(#eq? @id\n@ok.capture\n))'
    )
  end)

  describe('Query:iter_captures', function()
    it('includes metadata for all captured nodes #23664', function()
      insert([[
        const char *sql = "SELECT * FROM Students WHERE name = 'Robert'); DROP TABLE Students;--";
      ]])

      local query = [[
        (declaration
          type: (_)
          declarator: (init_declarator
            declarator: (pointer_declarator
              declarator: (identifier)) @_id
            value: (string_literal
              (string_content) @injection.content))
          (#set! injection.language "sql")
          (#contains? @_id "sql"))
      ]]

      local result = exec_lua(
        [=[
        local query = vim.treesitter.query.parse("c", ...)
        local parser = vim.treesitter.get_parser(0, "c")
        local root = parser:parse()[1]:root()
        local t = {}
        for id, node, metadata in query:iter_captures(root, 0) do
          t[query.captures[id]] = metadata
        end
        return t
      ]=],
        query
      )

      eq({
        ['_id'] = { ['injection.language'] = 'sql' },
        ['injection.content'] = { ['injection.language'] = 'sql' },
      }, result)
    end)

    it('only evaluates predicates once per match', function()
      insert([[
        void foo(int x, int y);
      ]])
      local query = [[
        (declaration
          type: (_)
          declarator: (function_declarator
            declarator: (identifier) @function.name
            parameters: (parameter_list
              (parameter_declaration
                type: (_)
                declarator: (identifier) @argument)))
          (#eq? @function.name "foo"))
      ]]

      local result = exec_lua(
        [[
        local query = vim.treesitter.query.parse("c", ...)
        local match_preds = query.match_preds
        local called = 0
        function query:match_preds(...)
          called = called + 1
          return match_preds(self, ...)
        end
        local parser = vim.treesitter.get_parser(0, "c")
        local root = parser:parse()[1]:root()
        local captures = {}
        for id, node in query:iter_captures(root, 0) do
          captures[#captures + 1] = id
        end
        return { called, captures }
      ]],
        query
      )

      eq({ 2, { 1, 1, 2, 2 } }, result)
    end)
  end)
end)
