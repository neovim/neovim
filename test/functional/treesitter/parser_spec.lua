local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local ts_t = require('test.functional.treesitter.testutil')

local clear = n.clear
local dedent = t.dedent
local eq = t.eq
local insert = n.insert
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local feed = n.feed
local run_query = ts_t.run_query
local assert_alive = n.assert_alive

describe('treesitter parser API', function()
  before_each(function()
    clear()
    exec_lua(function()
      vim.g.__ts_debug = 1
    end)
  end)

  it('parses buffer', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'c')
      _G.tree = _G.parser:parse()[1]
      _G.root = _G.tree:root()
      _G.lang = vim.treesitter.language.inspect('c')
    end)

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
    eq(true, exec_lua('return lang.symbols[child:type()]'))

    exec_lua('anon = root:descendant_for_range(0,8,0,9)')
    eq('(', exec_lua('return anon:type()'))
    eq(false, exec_lua('return anon:named()'))
    eq('number', type(exec_lua('return anon:symbol()')))
    eq(false, exec_lua([=[return lang.symbols[string.format('"%s"', anon:type())]]=]))

    exec_lua('descendant = root:descendant_for_range(1,2,1,12)')
    eq('<node declaration>', exec_lua('return tostring(descendant)'))
    eq({ 1, 2, 1, 12 }, exec_lua('return {descendant:range()}'))
    eq(
      '(declaration type: (primitive_type) declarator: (init_declarator declarator: (identifier) value: (number_literal)))',
      exec_lua('return descendant:sexpr()')
    )

    feed('2G7|ay')
    exec_lua(function()
      _G.tree2 = _G.parser:parse()[1]
      _G.root2 = _G.tree2:root()
      _G.descendant2 = _G.root2:descendant_for_range(1, 2, 1, 13)
    end)
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

  it('parses buffer asynchronously', function()
    insert([[
      int main() {
        int x = 3;
      }]])

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'c')
      _G.lang = vim.treesitter.language.inspect('c')
      _G.parser:parse(nil, function(_, trees)
        _G.tree = trees[1]
        _G.root = _G.tree:root()
      end)
      vim.wait(100, function() end)
    end)

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
    eq(true, exec_lua('return lang.symbols[child:type()]'))

    exec_lua('anon = root:descendant_for_range(0,8,0,9)')
    eq('(', exec_lua('return anon:type()'))
    eq(false, exec_lua('return anon:named()'))
    eq('number', type(exec_lua('return anon:symbol()')))
    eq(false, exec_lua([=[return lang.symbols[string.format('"%s"', anon:type())]]=]))

    exec_lua('descendant = root:descendant_for_range(1,2,1,12)')
    eq('<node declaration>', exec_lua('return tostring(descendant)'))
    eq({ 1, 2, 1, 12 }, exec_lua('return {descendant:range()}'))
    eq(
      '(declaration type: (primitive_type) declarator: (init_declarator declarator: (identifier) value: (number_literal)))',
      exec_lua('return descendant:sexpr()')
    )

    feed('2G7|ay')
    exec_lua(function()
      _G.parser:parse(nil, function(_, trees)
        _G.tree2 = trees[1]
        _G.root2 = _G.tree2:root()
        _G.descendant2 = _G.root2:descendant_for_range(1, 2, 1, 13)
      end)
      vim.wait(100, function() end)
    end)
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

  it('does not crash when editing large files', function()
    insert([[printf("%s", "some text");]])
    feed('yy49999p')

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'c')
      _G.done = false
      vim.treesitter.start(0, 'c')
      _G.parser:parse(nil, function()
        _G.done = true
      end)
      while not _G.done do
        -- Busy wait until async parsing has completed
        vim.wait(100, function() end)
      end
    end)

    eq(true, exec_lua([[return done]]))
    exec_lua(function()
      vim.api.nvim_input('Lxj')
    end)
    exec_lua(function()
      vim.api.nvim_input('xj')
    end)
    exec_lua(function()
      vim.api.nvim_input('xj')
    end)
    assert_alive()
  end)

  it('resets parsing state on tree changes', function()
    insert([[vim.api.nvim_set_hl(0, 'test2', { bg = 'green' })]])
    feed('yy1000p')

    exec_lua(function()
      vim.cmd('set ft=lua')

      vim.treesitter.start(0)
      local parser = assert(vim.treesitter.get_parser(0))

      parser:parse(true, function() end)
      vim.api.nvim_buf_set_lines(0, 1, -1, false, {})
      parser:parse(true)
    end)
  end)

  it('resets when buffer was editing during an async parse', function()
    insert([[printf("%s", "some text");]])
    feed('yy49999p')
    feed('gg4jO// Comment<Esc>')

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'c')
      _G.done = false
      vim.treesitter.start(0, 'c')
      _G.parser:parse(nil, function()
        _G.done = true
      end)
    end)

    exec_lua(function()
      vim.api.nvim_input('ggdj')
    end)

    eq(false, exec_lua([[return done]]))
    exec_lua(function()
      while not _G.done do
        -- Busy wait until async parsing finishes
        vim.wait(100, function() end)
      end
    end)
    eq(true, exec_lua([[return done]]))
    eq('comment', exec_lua([[return parser:parse()[1]:root():named_child(2):type()]]))
    eq({ 2, 0, 2, 10 }, exec_lua([[return {parser:parse()[1]:root():named_child(2):range()}]]))
  end)

  it('handles multiple async parse calls', function()
    insert([[printf("%s", "some text");]])
    feed('yy49999p')

    exec_lua(function()
      -- Spy on vim.schedule
      local schedule = vim.schedule
      vim.schedule = function(fn)
        _G.schedules = _G.schedules + 1
        schedule(fn)
      end
      _G.schedules = 0
      _G.parser = vim.treesitter.get_parser(0, 'c')
      for i = 1, 5 do
        _G['done' .. i] = false
        _G.parser:parse(nil, function()
          _G['done' .. i] = true
        end)
      end
      schedule(function()
        _G.schedules_snapshot = _G.schedules
      end)
    end)

    eq(2, exec_lua([[return schedules_snapshot]]))
    eq(
      { false, false, false, false, false },
      exec_lua([[return { done1, done2, done3, done4, done5 }]])
    )
    exec_lua(function()
      while not _G.done1 do
        -- Busy wait until async parsing finishes
        vim.wait(100, function() end)
      end
    end)
    eq({ true, true, true, true, true }, exec_lua([[return { done1, done2, done3, done4, done5 }]]))
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

    local res = exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')

      local func_node = parser:parse()[1]:root():child(0)

      local res = {}
      for node, field in func_node:iter_children() do
        table.insert(res, { node:type(), field })
      end
      return res
    end)

    eq({
      { 'primitive_type', 'type' },
      { 'function_declarator', 'declarator' },
      { 'compound_statement', 'body' },
    }, res)
  end)

  it('does not get parser for empty filetype', function()
    insert(test_text)

    eq(
      '.../treesitter.lua:0: Parser not found for buffer 1: language could not be determined',
      pcall_err(exec_lua, 'vim.treesitter.get_parser(0)')
    )

    -- Must provide language for buffers with an empty filetype
    exec_lua("vim.treesitter.get_parser(0, 'c')")
  end)

  it('allows to get a child by field', function()
    insert(test_text)

    local res = exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')

      _G.func_node = parser:parse()[1]:root():child(0)

      local res = {}
      for _, node in ipairs(_G.func_node:field('type')) do
        table.insert(res, { node:type(), node:range() })
      end
      return res
    end)

    eq({ { 'primitive_type', 0, 0, 0, 4 } }, res)

    local res_fail = exec_lua(function()
      vim.treesitter.get_parser(0, 'c')

      return #_G.func_node:field('foo') == 0
    end)

    assert(res_fail)
  end)

  it('supports getting text of multiline node', function()
    insert(test_text)
    local res = exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local tree = parser:parse()[1]
      return vim.treesitter.get_node_text(tree:root(), 0)
    end)
    eq(test_text, res)

    local res2 = exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local root = parser:parse()[1]:root()
      return vim.treesitter.get_node_text(root:child(0):child(0), 0)
    end)
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
      exec_lua(function()
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
      end)
    )
  end)

  it('supports getting empty text if node range is zero width', function()
    local text = [[
```lua
{}
```]]
    insert(text)
    local result = exec_lua(function()
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
    end)
    eq(true, result)
  end)

  it('allows to set simple ranges', function()
    insert(test_text)

    local res = exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'c')
      return { _G.parser:parse()[1]:root():range() }
    end)

    eq({ 0, 0, 19, 0 }, res)

    -- The following sets the included ranges for the current parser
    -- As stated here, this only includes the function (thus the whole buffer, without the last line)
    local res2 = exec_lua(function()
      local root = _G.parser:parse()[1]:root()
      _G.parser:set_included_regions({ { root:child(0) } })
      _G.parser:invalidate()
      local _, tree = next(_G.parser:parse(true))
      return { tree:root():range() }
    end)

    eq({ 0, 0, 18, 1 }, res2)

    eq(
      { { { 0, 0, 0, 18, 1, 512 } } },
      exec_lua [[return vim.tbl_values(_G.parser:included_regions())]]
    )

    eq(
      { { { 0, 0, 0, 17, 1, 508 } } },
      exec_lua(function()
        _G.parser:set_included_regions { { { 0, 0, 17, 1 } } }
        _G.parser:parse()
        return vim.tbl_values(_G.parser:included_regions())
      end)
    )
  end)

  it('allows to set complex ranges', function()
    insert(test_text)

    local res = exec_lua(function()
      local parser = vim.treesitter.get_parser(0, 'c')
      local query = vim.treesitter.query.parse('c', '(declaration) @decl')

      local nodes = {}
      for _, node in query:iter_captures(parser:parse()[1]:root(), 0) do
        table.insert(nodes, node)
      end

      parser:set_included_regions({ nodes })

      local _, tree = next(parser:parse(true))
      local root = tree:root()

      local res = {}
      for i = 0, (root:named_child_count() - 1) do
        table.insert(res, { root:named_child(i):range() })
      end
      return res
    end)

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
    local ret = exec_lua(function()
      local parser = vim.treesitter.get_string_parser('int foo = 42;', 'c')
      return { parser:parse()[1]:root():range() }
    end)

    eq({ 0, 0, 0, 13 }, ret)
  end)

  it('allows to run queries with string parsers', function()
    local txt = [[
      int foo = 42;
      int bar = 13;
    ]]

    local ret = exec_lua(function(str)
      local parser = vim.treesitter.get_string_parser(str, 'c')

      local nodes = {}
      local query = vim.treesitter.query.parse('c', '((identifier) @id (#eq? @id "foo"))')

      for _, node in query:iter_captures(parser:parse()[1]:root(), str) do
        table.insert(nodes, { node:range() })
      end

      return nodes
    end, txt)

    eq({ { 0, 10, 0, 13 } }, ret)
  end)

  describe('when creating a language tree', function()
    local function get_ranges()
      return exec_lua(function()
        local result = {}
        _G.parser:for_each_tree(function(tree)
          table.insert(result, { tree:root():range() })
        end)
        return result
      end)
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
        exec_lua(function()
          _G.parser = vim.treesitter.get_parser(0, 'c', {
            injections = {
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c")) '
                .. '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
              ),
            },
          })
          _G.parser:parse(true)
        end)

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

        n.feed('ggo<esc>')
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
        exec_lua(function()
          _G.parser = vim.treesitter.get_parser(0, 'c', {
            injections = {
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined)) '
                .. '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c") (#set! injection.combined))'
              ),
            },
          })
          _G.parser:parse(true)
        end)

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

        n.feed('ggo<esc>')
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

        n.feed('7ggI//<esc>')
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
        exec_lua(function()
          _G.parser = vim.treesitter.get_parser(0, 'c', {
            injections = {
              c = (
                '(preproc_def (preproc_arg) @injection.content (#set! injection.self)) '
                .. '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.self))'
              ),
            },
          })
          _G.parser:parse(true)
        end)

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

        n.feed('ggo<esc>')
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
        exec_lua(function()
          _G.parser = vim.treesitter.get_parser(0, 'c', {
            injections = {
              c = (
                '(preproc_def ((preproc_arg) @injection.content (#set! injection.language "c") (#offset! @injection.content 0 2 0 -1))) '
                .. '(preproc_function_def value: (preproc_arg) @injection.content (#set! injection.language "c"))'
              ),
            },
          })
          _G.parser:parse(true)
        end)

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
        local res_list = exec_lua(function()
          local query = vim.treesitter.query

          local list = query.list_directives()

          table.sort(list)

          return list
        end)

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
      local result = exec_lua(function()
        local parser = vim.treesitter.get_parser(0, 'c', {
          injections = {
            c = '(preproc_def (preproc_arg) @injection.content (#set! injection.language "c"))',
          },
        })
        parser:parse(true)

        local sub_tree = parser:language_for_range({ 1, 18, 1, 19 })

        return sub_tree == parser:children().c
      end)

      eq(true, result)
    end)
  end)

  describe('when setting the node for an injection', function()
    before_each(function()
      insert([[
print()
      ]])
    end)

    it('ignores optional captures #23100', function()
      local result = exec_lua(function()
        local parser = vim.treesitter.get_parser(0, 'lua', {
          injections = {
            lua = (
              '(function_call '
              .. '(arguments '
              .. '(string)? @injection.content '
              .. '(number)? @injection.content '
              .. '(#offset! @injection.content 0 1 0 -1) '
              .. '(#set! injection.language "c")))'
            ),
          },
        })
        parser:parse(true)

        return parser:is_valid()
      end)

      eq(true, result)
    end)
  end)

  describe('when getting/setting match data', function()
    describe('when setting for the whole match', function()
      it('should set/get the data correctly', function()
        insert([[
          int x = 3;
        ]])

        local result = exec_lua(function()
          local query =
            vim.treesitter.query.parse('c', '((number_literal) @number (#set! "key" "value"))')
          local parser = vim.treesitter.get_parser(0, 'c')

          local _, _, metadata = query:iter_matches(parser:parse()[1]:root(), 0, 0, -1)()
          return metadata.key
        end)

        eq('value', result)
      end)

      describe('when setting a key on a capture', function()
        it('it should create the nested table', function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua(function()
            local query = vim.treesitter.query.parse(
              'c',
              '((number_literal) @number (#set! @number "key" "value"))'
            )
            local parser = vim.treesitter.get_parser(0, 'c')

            local _, _, metadata = query:iter_matches(parser:parse()[1]:root(), 0, 0, -1)()
            local _, nested_tbl = next(metadata)
            return nested_tbl.key
          end)

          eq('value', result)
        end)

        it('it should not overwrite the nested table', function()
          insert([[
            int x = 3;
          ]])

          local result = exec_lua(function()
            local query = vim.treesitter.query.parse(
              'c',
              '((number_literal) @number (#set! @number "key" "value") (#set! @number "key2" "value2"))'
            )
            local parser = vim.treesitter.get_parser(0, 'c')

            local _, _, metadata = query:iter_matches(parser:parse()[1]:root(), 0, 0, -1)()
            local _, nested_tbl = next(metadata)
            return nested_tbl
          end)
          local expected = {
            ['key'] = 'value',
            ['key2'] = 'value2',
          }

          eq(expected, result)
        end)
      end)
    end)
  end)

  describe('trim! directive', function()
    it('can trim all whitespace', function()
      -- luacheck: push ignore 611 613
      insert([=[
        print([[

                  f
           helllo
        there
        asdf
        asdfassd   



        ]])
        print([[
              
              
              
        ]])

        print([[]])

        print([[
        ]])

        print([[     hello 😃    ]])
      ]=])
      -- luacheck: pop

      local query_text = [[
        ; query
        ((string_content) @str
          (#trim! @str 1 1 1 1))
      ]]

      exec_lua(function()
        vim.treesitter.start(0, 'lua')
      end)

      eq({
        { 'str', { 2, 12, 6, 10 } },
        { 'str', { 11, 10, 11, 10 } },
        { 'str', { 17, 10, 17, 10 } },
        { 'str', { 19, 10, 19, 10 } },
        { 'str', { 22, 15, 22, 25 } },
      }, run_query('lua', query_text))
    end)

    it('trims only empty lines by default (backwards compatible)', function()
      insert(dedent [[
      ## Heading

      With some text

      ## And another

      With some more here]])

      local query_text = [[
        ; query
        ((section) @fold
          (#trim! @fold))
      ]]

      exec_lua(function()
        vim.treesitter.start(0, 'markdown')
      end)

      eq({
        { 'fold', { 0, 0, 2, 14 } },
        { 'fold', { 4, 0, 6, 19 } },
      }, run_query('markdown', query_text))
    end)

    it('can trim lines', function()
      insert(dedent [[
      - Fold list
        - Fold list
          - Fold list
          - Fold list
        - Fold list
      - Fold list
      ]])

      local query_text = [[
        ; query
        ((list_item
          (list)) @fold
          (#trim! @fold 1 1 1 1))
      ]]

      exec_lua(function()
        vim.treesitter.start(0, 'markdown')
      end)

      eq({
        { 'fold', { 0, 0, 4, 13 } },
        { 'fold', { 1, 2, 3, 15 } },
      }, run_query('markdown', query_text))
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

    exec_lua(function()
      vim.treesitter.start(0, 'c')
    end)

    eq({
      { 'function', { 0, 0, 2, 1 } },
      { 'declaration', { 1, 2, 1, 12 } },
    }, run_query('c', query0))

    n.command 'normal ggO'
    insert('int a;')

    eq({
      { 'declaration', { 0, 0, 0, 6 } },
      { 'function', { 1, 0, 3, 1 } },
      { 'declaration', { 2, 2, 2, 12 } },
    }, run_query('c', query0))
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

    local r = exec_lua(function()
      local parser = vim.treesitter.get_string_parser(source, 'lua')
      parser:parse(true)
      local ranges = {}
      parser:for_each_tree(function(tstree, tree)
        ranges[tree:lang()] = { tstree:root():range(true) }
      end)
      return ranges
    end)

    eq({
      lua = { 0, 6, 6, 16, 4, 438 },
      query = { 6, 20, 113, 15, 6, 431 },
      vim = { 1, 0, 16, 4, 6, 89 },
    }, r)

    -- The above ranges are provided directly from treesitter, however query directives may mutate
    -- the ranges but only provide a Range4. Strip the byte entries from the ranges and make sure
    -- add_bytes() produces the same result.

    local rb = exec_lua(function()
      local add_bytes = require('vim.treesitter._range').add_bytes
      for lang, range in pairs(r) do
        r[lang] = { range[1], range[2], range[4], range[5] }
        r[lang] = add_bytes(source, r[lang])
      end
      return r
    end)

    eq(rb, r)
  end)

  it('does not produce empty injection ranges (#23409)', function()
    insert [[
      Examples: >lua
        local a = {}
<
    ]]

    -- This is not a valid injection since (code) has children and include-children is not set
    exec_lua(function()
      _G.parser1 = require('vim.treesitter.languagetree').new(0, 'vimdoc', {
        injections = {
          vimdoc = '((codeblock (language) @injection.language (code) @injection.content))',
        },
      })
      _G.parser1:parse(true)
    end)

    eq(0, exec_lua('return #vim.tbl_keys(parser1:children())'))

    exec_lua(function()
      _G.parser2 = require('vim.treesitter.languagetree').new(0, 'vimdoc', {
        injections = {
          vimdoc = '((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))',
        },
      })
      _G.parser2:parse(true)
    end)

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

    exec_lua(function()
      _G.parser = require('vim.treesitter.languagetree').new(0, 'vimdoc', {
        injections = {
          vimdoc = '((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))',
        },
      })
    end)

    --- Do not parse injections by default
    eq(
      0,
      exec_lua(function()
        _G.parser:parse()
        return #vim.tbl_keys(_G.parser:children())
      end)
    )

    --- Only parse injections between lines 0, 2
    eq(
      1,
      exec_lua(function()
        _G.parser:parse({ 0, 2 })
        return vim.tbl_count(_G.parser:children().lua:trees())
      end)
    )

    -- Regions outside the given range are discarded.
    eq(
      1,
      exec_lua(function()
        _G.parser:parse({ 2, 6 })
        return vim.tbl_count(_G.parser:children().lua:trees())
      end)
    )

    eq(
      2,
      exec_lua [[
      parser:invalidate()
      parser:parse({{0, 2}, {2,6}})
      return vim.tbl_count(parser:children().lua:trees())
    ]]
    )

    eq(
      2,
      exec_lua [[
      parser:parse({{0, 5}, {2, 6}})
      return vim.tbl_count(parser:children().lua:trees())
    ]]
    )

    eq(
      7,
      exec_lua(function()
        _G.parser:parse(true)
        return vim.tbl_count(_G.parser:children().lua:trees())
      end)
    )
  end)

  it('reuses similar existing regions', function()
    insert(dedent [[
      * line1
        line2]])

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'markdown', {
        injections = {
          markdown = '((inline) @injection.content (#set! injection.language "markdown_inline"))',
        },
      })
    end)

    local function get_regions()
      return exec_lua(function()
        _G.parser:parse(true)
        local result = {}
        for i, tree in pairs(_G.parser:children().markdown_inline:trees()) do
          result[i] = tree:included_ranges()
        end
        return result
      end)
    end

    eq({
      [1] = { { 0, 2, 1, 0 }, { 1, 2, 1, 7 } },
    }, get_regions())

    feed('2ggyyp')
    -- region index does not change
    eq({
      [1] = { { 0, 2, 1, 0 }, { 1, 2, 2, 0 }, { 2, 2, 2, 7 } },
    }, get_regions())

    feed('2ggdd')
    eq({
      [1] = { { 0, 2, 1, 0 }, { 1, 2, 1, 7 } },
    }, get_regions())

    feed('ggyGP')
    -- the old region moves while maintaining its index
    eq({
      [1] = { { 2, 2, 3, 0 }, { 3, 2, 3, 7 } },
      [2] = { { 0, 2, 1, 0 }, { 1, 2, 1, 7 } },
    }, get_regions())
  end)

  it("recursively discards children's regions contained in a parent's discarded region", function()
    insert(dedent [[
      `return`

      ```
      line 4
      ```
      line 6 `return`
      ```]])

    exec_lua(function()
      _G.parser = vim.treesitter.get_parser(0, 'markdown', {
        injections = {
          -- inject code span to lua
          markdown_inline = '((code_span) @injection.content (#offset! @injection.content 0 1 0 -1) (#set! injection.language "lua"))',
        },
      })
    end)

    local function get_regions()
      return exec_lua(function()
        _G.parser:parse(true)
        local result = {}
        for i, tree in pairs(_G.parser:children().markdown_inline:children().lua:trees()) do
          result[i] = tree:included_ranges()
        end
        return result
      end)
    end

    -- Initially, "line 4" is in the fenced code block, and "line 6 `return`" is a normal paragraph
    -- with a inline code span.
    eq({
      [1] = { { 0, 1, 0, 7 } },
      [2] = { { 5, 8, 5, 14 } },
    }, get_regions())

    -- Extend the code block to "line 6 `return`". Note that the only effect to markdown_inline
    -- parser is removing a region, so it does not parse anything in markdown_inline parser.
    feed('5ggD')
    -- Despite not parsing at the parent (markdown_inline) parser, the regions in children (lua)
    -- parser that are included in the parent's removed region should be removed as well.
    -- The "`return`" at the first line is just for preventing the lua parser from being removed.
    eq({
      [1] = { { 0, 1, 0, 7 } },
    }, get_regions())
  end)

  describe('languagetree is_valid()', function()
    before_each(function()
      insert(dedent [[
        Treesitter integration                                 *treesitter*

        Nvim integrates the `tree-sitter` library for incremental parsing of buffers:
        https://tree-sitter.github.io/tree-sitter/

      ]])

      exec_lua(function()
        _G.parser = vim.treesitter.get_parser(0, 'vimdoc', {
          injections = {
            vimdoc = '((codeblock (language) @injection.language (code) @injection.content) (#set! injection.include-children))',
          },
        })
        _G.parser:parse()
      end)
    end)

    local function get_regions()
      return exec_lua(function()
        if not _G.parser:children().lua then
          return nil
        end
        local result = {}
        for i, tree in pairs(_G.parser:children().lua:trees()) do
          result[i] = tree:included_ranges()
        end
        return result
      end)
    end

    it('is valid including children since it does not have one', function()
      eq(true, exec_lua('return parser:is_valid(true)'))
      eq(true, exec_lua('return parser:is_valid()'))
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
        eq(false, exec_lua('return parser:is_valid(true)'))
        eq(false, exec_lua('return parser:is_valid()'))
      end)

      it('is valid excluding, invalid including children after a rangeless parse', function()
        exec_lua('parser:parse()')
        eq(true, exec_lua('return parser:is_valid(true)'))
        eq(false, exec_lua('return parser:is_valid()'))
      end)

      it(
        'is fully valid after a range parse that leads to parsing not parsed injections',
        function()
          exec_lua('parser:parse({5, 7})')
          eq(true, exec_lua('return parser:is_valid(true)'))
          eq(true, exec_lua('return parser:is_valid()'))
        end
      )

      it(
        'is valid excluding, invalid including children after a range parse that does not lead to parsing not parsed injections',
        function()
          exec_lua('parser:parse({2, 4})')
          eq(true, exec_lua('return parser:is_valid(true)'))
          eq(false, exec_lua('return parser:is_valid()'))
        end
      )
    end)

    describe('when removing an injection region', function()
      before_each(function()
        feed('G')
        insert(dedent [[
          >lua
            local a = {}
          <

          >lua
            local b = {}
          <

        ]])

        exec_lua('parser:parse(true)')
        eq({ [1] = { { 6, 0, 7, 0 } }, [2] = { { 10, 0, 11, 0 } } }, get_regions())

        feed('Gd3k')
        -- the empty region is pruned
        eq({ [1] = { { 6, 0, 7, 0 } } }, get_regions())
      end)

      it('is fully invalid after changes', function()
        eq(false, exec_lua('return parser:is_valid(true)'))
        eq(false, exec_lua('return parser:is_valid()'))
      end)

      it(
        'is fully valid after a rangeless parse, since the only change to the children was removing a region',
        function()
          exec_lua('parser:parse()')
          eq(true, exec_lua('return parser:is_valid(true)'))
          eq(true, exec_lua('return parser:is_valid()'))
        end
      )

      it('is fully valid after a range parse that includes injection region', function()
        exec_lua('parser:parse({5, 7})')
        eq(true, exec_lua('return parser:is_valid(true)'))
        eq(true, exec_lua('return parser:is_valid()'))
      end)

      it(
        'is valid excluding, invalid including children after a range parse that does not include injection region',
        function()
          exec_lua('parser:parse({2, 4})')
          eq(nil, get_regions())
          eq(true, exec_lua('return parser:is_valid(true)'))
          eq(false, exec_lua('return parser:is_valid()'))
        end
      )
    end)

    describe('when editing an injection region', function()
      before_each(function()
        feed('G')
        insert(dedent [[
          >lua
            local a = 1
          <
        ]])

        exec_lua('parser:parse(true)')

        feed('G2kA<BS>2<ESC>') -- 1 → 2
      end)

      it('is fully invalid after changes', function()
        eq(false, exec_lua('return parser:is_valid(true)'))
        eq(false, exec_lua('return parser:is_valid()'))
      end)

      it('is valid excluding, invalid including children after a rangeless parse', function()
        exec_lua('parser:parse()')
        eq(true, exec_lua('return parser:is_valid(true)'))
        eq(false, exec_lua('return parser:is_valid()'))
      end)

      it('is fully valid after a range parse that includes modified region', function()
        exec_lua('parser:parse({5, 7})')
        eq(true, exec_lua('return parser:is_valid(true)'))
        eq(true, exec_lua('return parser:is_valid()'))
      end)
    end)
  end)
end)
