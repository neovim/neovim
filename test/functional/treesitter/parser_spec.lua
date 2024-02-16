local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local dedent = helpers.dedent
local eq = helpers.eq
local insert = helpers.insert
local exec_lua = helpers.exec_lua
local pcall_err = helpers.pcall_err
local feed = helpers.feed
local is_os = helpers.is_os
local api = helpers.api
local fn = helpers.fn

describe('treesitter parser API', function()
  before_each(function()
    clear()
    exec_lua [[
      vim.g.__ts_debug = 1
    ]]
  end)

  it('parses buffer', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      root = tree:root()
      lang = vim.treesitter.language.inspect('c')
    ]])

    eq('<tree>', exec_lua('return tostring(tree)'))
    eq('<node translation_unit>', exec_lua('return tostring(root)'))
    eq({ 0, 0, 3, 0 }, exec_lua('return {root:range()}'))

    eq(1, exec_lua('return root:child_count()'))
    exec_lua('child = root:child(0)')
    eq('<node function_definition>', exec_lua('return tostring(child)'))
    eq({ 0, 0, 2, 1 }, exec_lua('return {child:range()}'))

    eq('function_definition', exec_lua('return child:type()'))
    eq(true, exec_lua('return child:named()'))
    eq('number', type(exec_lua('return child:symbol()')))
    eq({ 'function_definition', true }, exec_lua('return lang.symbols[child:symbol()]'))

    exec_lua('anon = root:descendant_for_range(0,8,0,9)')
    eq('(', exec_lua('return anon:type()'))
    eq(false, exec_lua('return anon:named()'))
    eq('number', type(exec_lua('return anon:symbol()')))
    eq({ '(', false }, exec_lua('return lang.symbols[anon:symbol()]'))

    exec_lua('descendant = root:descendant_for_range(1,2,1,12)')
    eq('<node declaration>', exec_lua('return tostring(descendant)'))
    eq({ 1, 2, 1, 12 }, exec_lua('return {descendant:range()}'))
    eq(
      '(declaration type: (primitive_type) declarator: (init_declarator declarator: (identifier) value: (number_literal)))',
      exec_lua('return descendant:sexpr()')
    )

    feed('2G7|ay')
    exec_lua([[
      tree2 = parser:parse()[1]
      root2 = tree2:root()
      descendant2 = root2:descendant_for_range(1,2,1,13)
    ]])
    eq(false, exec_lua('return tree2 == tree1'))
    eq(false, exec_lua('return root2 == root'))
    eq('<node declaration>', exec_lua('return tostring(descendant2)'))
    eq({ 1, 2, 1, 13 }, exec_lua('return {descendant2:range()}'))

    eq(true, exec_lua('return child == child'))
    -- separate lua object, but represents same node
    eq(true, exec_lua('return child == root:child(0)'))
    eq(false, exec_lua('return child == descendant2'))
    eq(false, exec_lua('return child == nil'))
    eq(false, exec_lua('return child == tree'))

    eq('string', exec_lua('return type(child:id())'))
    eq(true, exec_lua('return child:id() == child:id()'))
    -- separate lua object, but represents same node
    eq(true, exec_lua('return child:id() == root:child(0):id()'))
    eq(false, exec_lua('return child:id() == descendant2:id()'))
    eq(false, exec_lua('return child:id() == nil'))
    eq(false, exec_lua('return child:id() == tree'))

    -- unchanged buffer: return the same tree
    eq(true, exec_lua('return parser:parse()[1] == tree2'))
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
    insert(test_text)

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
      { 'primitive_type', 'type' },
      { 'function_declarator', 'declarator' },
      { 'compound_statement', 'body' },
    }, res)
  end)

  it('does not get parser for empty filetype', function()
    insert(test_text)

    eq(
      '.../treesitter.lua:0: There is no parser available for buffer 1 and one'
        .. ' could not be created because lang could not be determined. Either'
        .. ' pass lang or set the buffer filetype',
      pcall_err(exec_lua, 'vim.treesitter.get_parser(0)')
    )

    -- Must provide language for buffers with an empty filetype
    exec_lua("vim.treesitter.get_parser(0, 'c')")
  end)

  it('allows to get a child by field', function()
    insert(test_text)

    local res = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      func_node = parser:parse()[1]:root():child(0)

      local res = {}
      for _, node in ipairs(func_node:field("type")) do
        table.insert(res, {node:type(), node:range()})
      end
      return res
    ]])

    eq({ { 'primitive_type', 0, 0, 0, 4 } }, res)

    local res_fail = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c")

      return #func_node:field("foo") == 0
    ]])

    assert(res_fail)
  end)

  local test_query = [[
    ((call_expression function: (identifier) @minfunc (argument_list (identifier) @min_id)) (eq? @minfunc "MIN"))
    "for" @keyword
    (primitive_type) @type
    (field_expression argument: (identifier) @fieldarg)
  ]]

  it('supports runtime queries', function()
    local ret = exec_lua [[
      return vim.treesitter.query.get("c", "highlights").captures[1]
    ]]

    eq('variable', ret)
  end)

  it('supports caching queries', function()
    local long_query = test_query:rep(100)
    local function q(n)
      return exec_lua(
        [[
        local query, n = ...
        local before = vim.uv.hrtime()
        for i=1,n,1 do
          cquery = vim.treesitter.query.parse("c", ...)
        end
        local after = vim.uv.hrtime()
        return after - before
      ]],
        long_query,
        n
      )
    end

    local firstrun = q(1)
    local manyruns = q(100)

    -- First run should be at least 200x slower than an 100 subsequent runs.
    local factor = is_os('win') and 100 or 200
    assert(
      factor * manyruns < firstrun,
      ('firstrun: %f ms, manyruns: %f ms'):format(firstrun / 1e6, manyruns / 1e6)
    )
  end)

  it('support query and iter by capture', function()
    insert(test_text)

    local res = exec_lua(
      [[
      cquery = vim.treesitter.query.parse("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for cid, node in cquery:iter_captures(tree:root(), 0, 7, 14) do
        -- can't transmit node over RPC. just check the name and range
        table.insert(res, {cquery.captures[cid], node:type(), node:range()})
      end
      return res
    ]],
      test_query
    )

    eq({
      { 'type', 'primitive_type', 8, 2, 8, 6 },
      { 'keyword', 'for', 9, 2, 9, 5 },
      { 'type', 'primitive_type', 9, 7, 9, 13 },
      { 'minfunc', 'identifier', 11, 12, 11, 15 },
      { 'fieldarg', 'identifier', 11, 16, 11, 18 },
      { 'min_id', 'identifier', 11, 27, 11, 32 },
      { 'minfunc', 'identifier', 12, 13, 12, 16 },
      { 'fieldarg', 'identifier', 12, 17, 12, 19 },
      { 'min_id', 'identifier', 12, 29, 12, 35 },
      { 'fieldarg', 'identifier', 13, 14, 13, 16 },
    }, res)
  end)

  it('support query and iter by match', function()
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
            table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
          end
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]],
      test_query
    )

    eq({
      { 3, { { 'type', 'primitive_type', 8, 2, 8, 6 } } },
      { 2, { { 'keyword', 'for', 9, 2, 9, 5 } } },
      { 3, { { 'type', 'primitive_type', 9, 7, 9, 13 } } },
      { 4, { { 'fieldarg', 'identifier', 11, 16, 11, 18 } } },
      {
        1,
        { { 'minfunc', 'identifier', 11, 12, 11, 15 }, { 'min_id', 'identifier', 11, 27, 11, 32 } },
      },
      { 4, { { 'fieldarg', 'identifier', 12, 17, 12, 19 } } },
      {
        1,
        { { 'minfunc', 'identifier', 12, 13, 12, 16 }, { 'min_id', 'identifier', 12, 29, 12, 35 } },
      },
      { 4, { { 'fieldarg', 'identifier', 13, 14, 13, 16 } } },
    }, res)
  end)

  it('support query and iter by capture for quantifiers', function()
    insert(test_text)

    local res = exec_lua(
      [[
      cquery = vim.treesitter.query.parse("c", ...)
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for cid, node in cquery:iter_captures(tree:root(), 0, 7, 14) do
        -- can't transmit node over RPC. just check the name and range
        table.insert(res, {cquery.captures[cid], node:type(), node:range()})
      end
      return res
    ]],
      '(expression_statement (assignment_expression (call_expression)))+ @funccall'
    )

    eq({
      { 'funccall', 'expression_statement', 11, 4, 11, 34 },
      { 'funccall', 'expression_statement', 12, 4, 12, 37 },
      { 'funccall', 'expression_statement', 13, 4, 13, 34 },
    }, res)
  end)

  it('support query and iter by match for quantifiers', function()
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
            table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
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
          { 'funccall', 'expression_statement', 11, 4, 11, 34 },
          { 'funccall', 'expression_statement', 12, 4, 12, 37 },
          { 'funccall', 'expression_statement', 13, 4, 13, 34 },
        },
      },
    }, res)
  end)

  it('supports getting text of multiline node', function()
    insert(test_text)
    local res = exec_lua([[
      local parser = vim.treesitter.get_parser(0, "c")
      local tree = parser:parse()[1]
      return vim.treesitter.get_node_text(tree:root(), 0)
    ]])
    eq(test_text, res)

    local res2 = exec_lua([[
      local parser = vim.treesitter.get_parser(0, "c")
      local root = parser:parse()[1]:root()
      return vim.treesitter.get_node_text(root:child(0):child(0), 0)
    ]])
    eq('void', res2)
  end)

  it('support getting text where start of node is one past EOF', function()
    local text = [[
def run
  a = <<~E
end]]
    insert(text)
    eq(
      '',
      exec_lua [[
      local fake_node = {}
      function fake_node:start()
        return 3, 0, 23
      end
      function fake_node:end_()
        return 3, 0, 23
      end
      function fake_node:range(bytes)
        if bytes then
          return 3, 0, 23, 3, 0, 23
        end
        return 3, 0, 3, 0
      end
      return vim.treesitter.get_node_text(fake_node, 0)
    ]]
    )
  end)

  it('support getting empty text if node range is zero width', function()
    local text = [[
```lua
{}
```]]
    insert(text)
    local result = exec_lua([[
      local fake_node = {}
      function fake_node:start()
        return 1, 0, 7
      end
      function fake_node:end_()
        return 1, 0, 7
      end
      function fake_node:range()
        return 1, 0, 1, 0
      end
      return vim.treesitter.get_node_text(fake_node, 0) == ''
    ]])
    eq(true, result)
  end)

  it('can match special regex characters like \\ * + ( with `vim-match?`', function()
    insert('char* astring = "\\n"; (1 + 1) * 2 != 2;')

    local res = exec_lua([[
      cquery = vim.treesitter.query.parse("c", '([_] @plus (#vim-match? @plus "^\\\\+$"))'..
                                               '([_] @times (#vim-match? @times "^\\\\*$"))'..
                                               '([_] @paren (#vim-match? @paren "^\\\\($"))'..
                                               '([_] @escape (#vim-match? @escape "^\\\\\\\\n$"))'..
                                               '([_] @string (#vim-match? @string "^\\"\\\\\\\\n\\"$"))')
      parser = vim.treesitter.get_parser(0, "c")
      tree = parser:parse()[1]
      res = {}
      for pattern, match in cquery:iter_matches(tree:root(), 0, 0, -1, { all = true }) do
        -- can't transmit node over RPC. just check the name and range
        local mrepr = {}
        for cid, nodes in pairs(match) do
          for _, node in ipairs(nodes) do
            table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
          end
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]])

    eq({
      { 2, { { 'times', '*', 0, 4, 0, 5 } } },
      { 5, { { 'string', 'string_literal', 0, 16, 0, 20 } } },
      { 4, { { 'escape', 'escape_sequence', 0, 17, 0, 19 } } },
      { 3, { { 'paren', '(', 0, 22, 0, 23 } } },
      { 1, { { 'plus', '+', 0, 25, 0, 26 } } },
      { 2, { { 'times', '*', 0, 30, 0, 31 } } },
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
        cquery = vim.treesitter.query.parse("c", query_text)
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

  it(
    'allow loading query with escaped quotes and capture them with `lua-match?` and `vim-match?`',
    function()
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
            table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
          end
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]])

      eq({
        { 1, { { 'quote', '"', 0, 16, 0, 17 } } },
        { 2, { { 'quote', '"', 0, 16, 0, 17 } } },
        { 1, { { 'quote', '"', 0, 29, 0, 30 } } },
        { 2, { { 'quote', '"', 0, 29, 0, 30 } } },
      }, res)
    end
  )

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
          if query.get_node_text(node, bufnr) == 'main' then
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

        return query.get_node_text(node, bufnr) == 'main'
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
          table.insert(mrepr, {cquery.captures[cid], node:type(), node:range()})
        end
        table.insert(res, {pattern, mrepr})
      end
      return res
    ]],
      test_query
    )

    eq({
      { 3, { { 'type', 'primitive_type', 8, 2, 8, 6 } } },
      { 2, { { 'keyword', 'for', 9, 2, 9, 5 } } },
      { 3, { { 'type', 'primitive_type', 9, 7, 9, 13 } } },
      { 4, { { 'fieldarg', 'identifier', 11, 16, 11, 18 } } },
      {
        1,
        { { 'minfunc', 'identifier', 11, 12, 11, 15 }, { 'min_id', 'identifier', 11, 27, 11, 32 } },
      },
      { 4, { { 'fieldarg', 'identifier', 12, 17, 12, 19 } } },
      {
        1,
        { { 'minfunc', 'identifier', 12, 13, 12, 16 }, { 'min_id', 'identifier', 12, 29, 12, 35 } },
      },
      { 4, { { 'fieldarg', 'identifier', 13, 14, 13, 16 } } },
    }, res)
  end)

  it('allows to set simple ranges', function()
    insert(test_text)

    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    return { parser:parse()[1]:root():range() }
    ]]

    eq({ 0, 0, 19, 0 }, res)

    -- The following sets the included ranges for the current parser
    -- As stated here, this only includes the function (thus the whole buffer, without the last line)
    local res2 = exec_lua [[
    local root = parser:parse()[1]:root()
    parser:set_included_regions({{root:child(0)}})
    parser:invalidate()
    return { parser:parse(true)[1]:root():range() }
    ]]

    eq({ 0, 0, 18, 1 }, res2)

    eq({ { { 0, 0, 0, 18, 1, 512 } } }, exec_lua [[ return parser:included_regions() ]])

    local range_tbl = exec_lua [[
      parser:set_included_regions { { { 0, 0, 17, 1 } } }
      parser:parse()
      return parser:included_regions()
    ]]

    eq(range_tbl, { { { 0, 0, 0, 17, 1, 508 } } })
  end)

  it('allows to set complex ranges', function()
    insert(test_text)

    local res = exec_lua [[
    parser = vim.treesitter.get_parser(0, "c")
    query = vim.treesitter.query.parse("c", "(declaration) @decl")

    local nodes = {}
    for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
      table.insert(nodes, node)
    end

    parser:set_included_regions({nodes})

    local root = parser:parse(true)[1]:root()

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
      { 14, 9, 14, 27 },
    }, res)
  end)

  it('allows to create string parsers', function()
    local ret = exec_lua [[
      local parser = vim.treesitter.get_string_parser("int foo = 42;", "c")
      return { parser:parse()[1]:root():range() }
    ]]

    eq({ 0, 0, 0, 13 }, ret)
  end)

  it('allows to run queries with string parsers', function()
    local txt = [[
      int foo = 42;
      int bar = 13;
    ]]

    local ret = exec_lua(
      [[
    local str = ...
    local parser = vim.treesitter.get_string_parser(str, "c")

    local nodes = {}
    local query = vim.treesitter.query.parse("c", '((identifier) @id (eq? @id "foo"))')

    for _, node in query:iter_captures(parser:parse()[1]:root(), str) do
      table.insert(nodes, { node:range() })
    end

    return nodes]],
      txt
    )

    eq({ { 0, 10, 0, 13 } }, ret)
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

    return nodes]],
      txt
    )

    eq({ { 1, 10, 1, 13 } }, ret)
  end)

  describe('when creating a language tree', function()
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
#define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
#define READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
#define VALUE 123
#define VALUE1 123
#define VALUE2 123
      ]])
    end)

    describe('when parsing regions independently', function()
      it('should inject a language', function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'}})
        parser:parse(true)
        ]])

        eq('table', exec_lua('return type(parser:children().c)'))
        eq(5, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 7, 0 }, -- root tree
          { 3, 14, 3, 17 }, -- VALUE 123
          { 4, 15, 4, 18 }, -- VALUE1 123
          { 5, 15, 5, 18 }, -- VALUE2 123
          { 1, 26, 1, 63 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          { 2, 29, 2, 66 }, -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())

        helpers.feed('ggo<esc>')
        eq(5, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 8, 0 }, -- root tree
          { 4, 14, 4, 17 }, -- VALUE 123
          { 5, 15, 5, 18 }, -- VALUE1 123
          { 6, 15, 6, 18 }, -- VALUE2 123
          { 2, 26, 2, 63 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          { 3, 29, 3, 66 }, -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe('when parsing regions combined', function()
      it('should inject a language', function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined)) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined))'}})
        parser:parse(true)
        ]])

        eq('table', exec_lua('return type(parser:children().c)'))
        eq(2, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 7, 0 }, -- root tree
          { 3, 14, 5, 18 }, -- VALUE 123
          -- VALUE1 123
          -- VALUE2 123
          { 1, 26, 2, 66 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())

        helpers.feed('ggo<esc>')
        eq('table', exec_lua('return type(parser:children().c)'))
        eq(2, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 8, 0 }, -- root tree
          { 4, 14, 6, 18 }, -- VALUE 123
          -- VALUE1 123
          -- VALUE2 123
          { 2, 26, 3, 66 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())

        helpers.feed('7ggI//<esc>')
        exec_lua([[parser:parse({6, 7})]])
        eq('table', exec_lua('return type(parser:children().c)'))
        eq(2, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 8, 0 }, -- root tree
          { 4, 14, 5, 18 }, -- VALUE 123
          -- VALUE1 123
          { 2, 26, 3, 66 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe('when using injection.self', function()
      it('should inject the source language', function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = '(preproc_def (preproc_arg) @injection.content (#set! injection.self)) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.self))'}})
        parser:parse(true)
        ]])

        eq('table', exec_lua('return type(parser:children().c)'))
        eq(5, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 7, 0 }, -- root tree
          { 3, 14, 3, 17 }, -- VALUE 123
          { 4, 15, 4, 18 }, -- VALUE1 123
          { 5, 15, 5, 18 }, -- VALUE2 123
          { 1, 26, 1, 63 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          { 2, 29, 2, 66 }, -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())

        helpers.feed('ggo<esc>')
        eq(5, exec_lua('return #parser:children().c:trees()'))
        eq({
          { 0, 0, 8, 0 }, -- root tree
          { 4, 14, 4, 17 }, -- VALUE 123
          { 5, 15, 5, 18 }, -- VALUE1 123
          { 6, 15, 6, 18 }, -- VALUE2 123
          { 2, 26, 2, 63 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          { 3, 29, 3, 66 }, -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
    end)

    describe('when using the offset directive', function()
      it('should shift the range by the directive amount', function()
        exec_lua([[
        parser = vim.treesitter.get_parser(0, "c", {
          injections = {
            c = '(preproc_def ((preproc_arg) @injection.content (#set! injection.language "c") (#offset! @injection.content 0 2 0 -1))) (preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'}})
        parser:parse(true)
        ]])

        eq('table', exec_lua('return type(parser:children().c)'))
        eq({
          { 0, 0, 7, 0 }, -- root tree
          { 3, 16, 3, 16 }, -- VALUE 123
          { 4, 17, 4, 17 }, -- VALUE1 123
          { 5, 17, 5, 17 }, -- VALUE2 123
          { 1, 26, 1, 63 }, -- READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
          { 2, 29, 2, 66 }, -- READ_STRING_OK(x, y) (char *)read_string((x), (size_t)(y))
        }, get_ranges())
      end)
      it('should list all directives', function()
        local res_list = exec_lua [[
        local query = vim.treesitter.query

        local list = query.list_directives()

        table.sort(list)

        return list
        ]]

        eq({ 'gsub!', 'offset!', 'set!', 'trim!' }, res_list)
      end)
    end)
  end)

  describe('when getting the language for a range', function()
    before_each(function()
      insert([[
int x = INT_MAX;
#define VALUE 123456789
      ]])
    end)

    it('should return the correct language tree', function()
      local result = exec_lua([[
      parser = vim.treesitter.get_parser(0, "c", {
        injections = { c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c"))'}})
      parser:parse(true)

      local sub_tree = parser:language_for_range({1, 18, 1, 19})

      return sub_tree == parser:children().c
      ]])

      eq(result, true)
    end)
  end)

  describe('when getting/setting match data', function()
    describe('when setting for the whole match', function()
      it('should set/get the data correctly', function()
        insert([[
          int x = 3;
        ]])

        local result = exec_lua([[
        local result

        query = vim.treesitter.query.parse("c", '((number_literal) @number (#set! "key" "value"))')
        parser = vim.treesitter.get_parser(0, "c")

        for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0, 0, -1, { all = true }) do
          result = metadata.key
        end

        return result
        ]])

        eq(result, 'value')
      end)

      describe('when setting a key on a capture', function()
        it('it should create the nested table', function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua([[
          local query = vim.treesitter.query
          local value

          query = vim.treesitter.query.parse("c", '((number_literal) @number (#set! @number "key" "value"))')
          parser = vim.treesitter.get_parser(0, "c")

          for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0, 0, -1, { all = true }) do
            for _, nested_tbl in pairs(metadata) do
              return nested_tbl.key
            end
          end
          ]])

          eq(result, 'value')
        end)

        it('it should not overwrite the nested table', function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua([[
          local query = vim.treesitter.query
          local result

          query = vim.treesitter.query.parse("c", '((number_literal) @number (#set! @number "key" "value") (#set! @number "key2" "value2"))')
          parser = vim.treesitter.get_parser(0, "c")

          for pattern, match, metadata in query:iter_matches(parser:parse()[1]:root(), 0, 0, -1, { all = true }) do
            for _, nested_tbl in pairs(metadata) do
              return nested_tbl
            end
          end
          ]])
          local expected = {
            ['key'] = 'value',
            ['key2'] = 'value2',
          }

          eq(expected, result)
        end)
      end)
    end)
  end)

  it('tracks the root range properly (#22911)', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    local query0 = [[
      (declaration) @declaration
      (function_definition) @function
    ]]

    exec_lua([[
      vim.treesitter.start(0, 'c')
    ]])

    local function run_query()
      return exec_lua(
        [[
      local query = vim.treesitter.query.parse("c", ...)
      parser = vim.treesitter.get_parser()
      tree = parser:parse()[1]
      res = {}
      for id, node in query:iter_captures(tree:root()) do
        table.insert(res, {query.captures[id], node:range()})
      end
      return res
      ]],
        query0
      )
    end

    eq({
      { 'function', 0, 0, 2, 1 },
      { 'declaration', 1, 2, 1, 12 },
    }, run_query())

    helpers.command 'normal ggO'
    insert('int a;')

    eq({
      { 'declaration', 0, 0, 0, 6 },
      { 'function', 1, 0, 3, 1 },
      { 'declaration', 2, 2, 2, 12 },
    }, run_query())
  end)

  it('handles ranges when source is a multiline string (#20419)', function()
    local source = [==[
      vim.cmd[[
        set number
        set cmdheight=2
        set lastsatus=2
      ]]

      set query = [[;; query
        ((function_call
          name: [
            (identifier) @_cdef_identifier
            (_ _ (identifier) @_cdef_identifier)
          ]
          arguments: (arguments (string content: _ @injection.content)))
          (#set! injection.language "c")
          (#eq? @_cdef_identifier "cdef"))
      ]]
    ]==]

    local r = exec_lua(
      [[
      local parser = vim.treesitter.get_string_parser(..., 'lua')
      parser:parse(true)
      local ranges = {}
      parser:for_each_tree(function(tstree, tree)
        ranges[tree:lang()] = { tstree:root():range(true) }
      end)
      return ranges
    ]],
      source
    )

    eq({
      lua = { 0, 6, 6, 16, 4, 438 },
      query = { 6, 20, 113, 15, 6, 431 },
      vim = { 1, 0, 16, 4, 6, 89 },
    }, r)

    -- The above ranges are provided directly from treesitter, however query directives may mutate
    -- the ranges but only provide a Range4. Strip the byte entries from the ranges and make sure
    -- add_bytes() produces the same result.

    local rb = exec_lua(
      [[
      local r, source = ...
      local add_bytes = require('vim.treesitter._range').add_bytes
      for lang, range in pairs(r) do
        r[lang] = {range[1], range[2], range[4], range[5]}
        r[lang] = add_bytes(source, r[lang])
      end
      return r
    ]],
      r,
      source
    )

    eq(rb, r)
  end)

  it('does not produce empty injection ranges (#23409)', function()
    insert [[
      Examples: >lua
        local a = {}
<
    ]]

    -- This is not a valid injection since (code) has children and include-children is not set
    exec_lua [[
      parser1 = require('vim.treesitter.languagetree').new(0, "vimdoc", {
        injections = {
          vimdoc = "((codeblock (language) @injection.language (code) @injection.content))"
        }
      })
      parser1:parse(true)
    ]]

    eq(0, exec_lua('return #vim.tbl_keys(parser1:children())'))

    exec_lua [[
      parser2 = require('vim.treesitter.languagetree').new(0, "vimdoc", {
        injections = {
          vimdoc = "((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))"
        }
      })
      parser2:parse(true)
    ]]

    eq(1, exec_lua('return #vim.tbl_keys(parser2:children())'))
    eq({ { { 1, 0, 21, 2, 0, 42 } } }, exec_lua('return parser2:children().lua:included_regions()'))
  end)

  it('parsers injections incrementally', function()
    insert(dedent [[
      >lua
        local a = {}
      <

      >lua
        local b = {}
      <

      >lua
        local c = {}
      <

      >lua
        local d = {}
      <

      >lua
        local e = {}
      <

      >lua
        local f = {}
      <

      >lua
        local g = {}
      <
    ]])

    exec_lua [[
      parser = require('vim.treesitter.languagetree').new(0, "vimdoc", {
        injections = {
          vimdoc = "((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))"
        }
      })
    ]]

    --- Do not parse injections by default
    eq(
      0,
      exec_lua [[
      parser:parse()
      return #vim.tbl_keys(parser:children())
    ]]
    )

    --- Only parse injections between lines 0, 2
    eq(
      1,
      exec_lua [[
      parser:parse({0, 2})
      return #parser:children().lua:trees()
    ]]
    )

    eq(
      2,
      exec_lua [[
      parser:parse({2, 6})
      return #parser:children().lua:trees()
    ]]
    )

    eq(
      7,
      exec_lua [[
      parser:parse(true)
      return #parser:children().lua:trees()
    ]]
    )
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

  describe('is_valid()', function()
    before_each(function()
      insert(dedent [[
        Treesitter integration                                 *treesitter*

        Nvim integrates the `tree-sitter` library for incremental parsing of buffers:
        https://tree-sitter.github.io/tree-sitter/

      ]])

      feed(':set ft=help<cr>')

      exec_lua [[
        vim.treesitter.get_parser(0, "vimdoc", {
          injections = {
            vimdoc = "((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))"
          }
        })
      ]]
    end)

    it('is valid excluding, invalid including children initially', function()
      eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
      eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
    end)

    it('is fully valid after a full parse', function()
      exec_lua('vim.treesitter.get_parser():parse(true)')
      eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
      eq(true, exec_lua('return vim.treesitter.get_parser():is_valid()'))
    end)

    it('is fully valid after a parsing a range on parsed tree', function()
      exec_lua('vim.treesitter.get_parser():parse({5, 7})')
      eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
      eq(true, exec_lua('return vim.treesitter.get_parser():is_valid()'))
    end)

    describe('when adding content with injections', function()
      before_each(function()
        feed('G')
        insert(dedent [[
          >lua
            local a = {}
          <

        ]])
      end)

      it('is fully invalid after changes', function()
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
      end)

      it('is valid excluding, invalid including children after a rangeless parse', function()
        exec_lua('vim.treesitter.get_parser():parse()')
        eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
      end)

      it(
        'is fully valid after a range parse that leads to parsing not parsed injections',
        function()
          exec_lua('vim.treesitter.get_parser():parse({5, 7})')
          eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
          eq(true, exec_lua('return vim.treesitter.get_parser():is_valid()'))
        end
      )

      it(
        'is valid excluding, invalid including children after a range parse that does not lead to parsing not parsed injections',
        function()
          exec_lua('vim.treesitter.get_parser():parse({2, 4})')
          eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
          eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
        end
      )
    end)

    describe('when removing content with injections', function()
      before_each(function()
        feed('G')
        insert(dedent [[
          >lua
            local a = {}
          <

          >lua
            local a = {}
          <

        ]])

        exec_lua('vim.treesitter.get_parser():parse(true)')

        feed('Gd3k')
      end)

      it('is fully invalid after changes', function()
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
      end)

      it('is valid excluding, invalid including children after a rangeless parse', function()
        exec_lua('vim.treesitter.get_parser():parse()')
        eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
        eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
      end)

      it('is fully valid after a range parse that leads to parsing modified child tree', function()
        exec_lua('vim.treesitter.get_parser():parse({5, 7})')
        eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
        eq(true, exec_lua('return vim.treesitter.get_parser():is_valid()'))
      end)

      it(
        'is valid excluding, invalid including children after a range parse that does not lead to parsing modified child tree',
        function()
          exec_lua('vim.treesitter.get_parser():parse({2, 4})')
          eq(true, exec_lua('return vim.treesitter.get_parser():is_valid(true)'))
          eq(false, exec_lua('return vim.treesitter.get_parser():is_valid()'))
        end
      )
    end)
  end)
end)
