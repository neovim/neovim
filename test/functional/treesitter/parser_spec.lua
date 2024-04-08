local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local dedent = t.dedent
local eq = t.eq
local insert = t.insert
local exec_lua = t.exec_lua
local pcall_err = t.pcall_err
local feed = t.feed

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
        table.insert(res, { node:type(), field })
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
        table.insert(res, { node:type(), node:range() })
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

  it('supports getting text where start of node is one past EOF', function()
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

  it('supports getting empty text if node range is zero width', function()
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

    eq({ { { 0, 0, 0, 17, 1, 508 } } }, range_tbl)
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
        local query = vim.treesitter.query.parse("c", '((identifier) @id (#eq? @id "foo"))')

        for _, node in query:iter_captures(parser:parse()[1]:root(), str) do
          table.insert(nodes, { node:range() })
        end

        return nodes
      ]],
      txt
    )

    eq({ { 0, 10, 0, 13 } }, ret)
  end)

  describe('when creating a language tree', function()
    local function get_ranges()
      return exec_lua [[
        local result = {}
        parser:for_each_tree(function(tree) table.insert(result, {tree:root():range()}) end)
        return result
      ]]
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
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) ' ..
                '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
              )
            }})
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

        t.feed('ggo<esc>')
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
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined)) ' ..
                '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined))'
              )
            }})
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

        t.feed('ggo<esc>')
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

        t.feed('7ggI//<esc>')
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
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.self)) ' ..
                '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.self))'
              )
            }})
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

        t.feed('ggo<esc>')
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
              c = (
                '(preproc_def ((preproc_arg) @injection.content (#set! injection.language "c") (#offset! @injection.content 0 2 0 -1))) ' ..
                '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
              )
            }})
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
          injections = {
            c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c"))'
          }
        })
        parser:parse(true)

        local sub_tree = parser:language_for_range({1, 18, 1, 19})

        return sub_tree == parser:children().c
      ]])

      eq(true, result)
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

        eq('value', result)
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

          eq('value', result)
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

    t.command 'normal ggO'
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

  describe('languagetree is_valid()', function()
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
