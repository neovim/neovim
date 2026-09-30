local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local exec_lua = n.exec_lua
local eq = t.eq
local eval = n.eval
local clear = n.clear

local function inspect(row, col, opts)
  return exec_lua(function(...)
    return vim.inspect_pos(0, ...)
  end, row, col, opts)
end

describe('vim.inspect_pos', function()
  before_each(function()
    clear()
  end)

  it('it returns items', function()
    local buf, ns1, ns2 = exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      _G.buf1 = vim.api.nvim_create_buf(true, false)
      local ns1 = vim.api.nvim_create_namespace('ns1')
      local ns2 = vim.api.nvim_create_namespace('')
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local a = 123' })
      vim.api.nvim_buf_set_lines(_G.buf1, 0, -1, false, { '--commentline' })
      vim.bo[buf].filetype = 'lua'
      vim.bo[_G.buf1].filetype = 'lua'
      vim.api.nvim_buf_set_extmark(buf, ns1, 0, 10, { hl_group = 'Normal' })
      vim.api.nvim_buf_set_extmark(buf, ns1, 0, 10, { hl_group = 'Normal', end_col = 10 })
      vim.api.nvim_buf_set_extmark(buf, ns2, 0, 10, { hl_group = 'Normal', end_col = 11 })
      vim.cmd('syntax on')
      return buf, ns1, ns2
    end)

    eq('', eval('v:errmsg'))
    local syntax = {
      {
        hl_group = 'luaNumber',
        hl_group_link = 'Constant',
        row = 0,
        col = 10,
        end_row = 0,
        end_col = 11,
      },
    }
    -- Only visible highlights with `filter.extmarks == true`
    eq({
      buffer = buf,
      col = 10,
      row = 0,
      extmarks = {
        {
          col = 10,
          end_col = 11,
          end_row = 0,
          hl_group = 'Normal',
          hl_group_link = 'Normal',
          id = 1,
          ns = '',
          ns_id = ns2,
          opts = {
            end_row = 0,
            end_col = 11,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns2,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
      },
      treesitter = {},
      semantic_tokens = {},
      syntax = syntax,
    }, exec_lua('return vim.inspect_pos(0, 0, 10)'))
    -- All extmarks with `filters.extmarks == 'all'`
    eq({
      buffer = buf,
      col = 10,
      row = 0,
      extmarks = {
        {
          col = 10,
          end_col = 10,
          end_row = 0,
          hl_group = 'Normal',
          hl_group_link = 'Normal',
          id = 1,
          ns = 'ns1',
          ns_id = ns1,
          opts = {
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns1,
            priority = 4096,
            right_gravity = true,
          },
          row = 0,
        },
        {
          col = 10,
          end_col = 11,
          end_row = 0,
          hl_group = 'Normal',
          hl_group_link = 'Normal',
          id = 1,
          ns = '',
          ns_id = ns2,
          opts = {
            end_row = 0,
            end_col = 11,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns2,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
        {
          col = 10,
          end_col = 10,
          end_row = 0,
          hl_group = 'Normal',
          hl_group_link = 'Normal',
          id = 2,
          ns = 'ns1',
          ns_id = ns1,
          opts = {
            end_row = 0,
            end_col = 10,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns1,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
      },
      treesitter = {},
      semantic_tokens = {},
      syntax = syntax,
    }, exec_lua('return vim.inspect_pos(0, 0, 10, { extmarks = "all" })'))
    -- Syntax from other buffer.
    eq({
      {
        hl_group = 'luaComment',
        hl_group_link = 'Comment',
        row = 0,
        col = 10,
        end_row = 0,
        end_col = 11,
      },
    }, exec_lua('return vim.inspect_pos(_G.buf1, 0, 10).syntax'))
  end)

  it('returns overlapping extmarks and semantic tokens with exclusive ends', function()
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'abcdef', 'abcdef', 'abcdef' })
      for _, name in ipairs({ 'range_test', 'nvim.lsp.semantic_tokens:range_test' }) do
        local ns = vim.api.nvim_create_namespace(name)
        local ranges = {
          { 0, 0, 0, 2 }, -- touches the start
          { 0, 1, 0, 4 }, -- overlaps the start
          { 0, 2, 0, 6 }, -- inside
          { 0, 1, 2, 1 }, -- contains the query
          { 1, 0, 1, 2 }, -- inside
          { 1, 2, 2, 2 }, -- overlaps the end
          { 2, 0, 2, 1 }, -- touches the end
          { 0, 3 }, -- unpaired mark
          { 1, 1, 1, 1 }, -- empty range
        }
        for id, range in ipairs(ranges) do
          vim.api.nvim_buf_set_extmark(0, ns, range[1], range[2], {
            id = id,
            end_row = range[3],
            end_col = range[4],
            hl_group = 'Number',
          })
        end
      end
    end)

    local function check(expected, row, col, opts)
      local result = inspect(row, col, opts)
      for _, kind in ipairs({ 'extmarks', 'semantic_tokens' }) do
        local ids = vim.tbl_map(function(mark)
          return mark.id
        end, result[kind])
        table.sort(ids)
        eq(expected, ids)
      end
    end

    check({ 2, 3, 4, 5, 6 }, 0, 2, { end_row = 2, end_col = 0 })
    check({ 2, 3, 4, 5, 6, 8, 9 }, 0, 2, { end_row = 2, end_col = 0, extmarks = 'all' })
    check({ 2, 3, 4 }, 0, 2, { end_row = 0, end_col = 3 })
    check({}, 0, 2, { end_row = 0, end_col = 2, extmarks = 'all' })
    -- A mark ending on a previous row must not appear just because its column is larger.
    check({ 4, 5 }, 1, 0)
  end)

  it('returns Tree-sitter highlights overlapping a range', function()
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local abc = 123' })
      vim.treesitter.query.set('lua', 'highlights', '(identifier) @variable (number) @number')
      vim.treesitter.start(0, 'lua')
    end)
    local result = inspect(0, 7, { end_row = 0, end_col = 13 })
    eq(
      { '@variable.lua', '@number.lua' },
      vim.tbl_map(function(item)
        return item.hl_group
      end, result.treesitter)
    )
  end)

  it('collects and joins custom syntax even when the syntax option is empty', function()
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa  bb', 'ccc', '', 'ddd' })
      vim.cmd('syntax match InspectWord /[a-z]\\+/')
      vim.cmd('highlight link InspectWord Identifier')
      assert(vim.bo.syntax == '')
    end)
    local function syntax(end_row, end_col)
      return vim.tbl_map(function(item)
        return { item.row, item.col, item.end_row, item.end_col }
      end, inspect(0, 1, { end_row = end_row, end_col = end_col }).syntax)
    end
    eq({ { 0, 1, 0, 3 }, { 0, 5, 0, 7 }, { 1, 0, 1, 2 } }, syntax(1, 2))
    eq({ { 0, 1, 0, 3 }, { 0, 5, 0, 7 }, { 1, 0, 1, 3 } }, syntax(3, 0))
    eq({ { 0, 1, 0, 2 } }, syntax())
    eq({}, syntax(0, 1))
  end)

  it('inspects syntax regions at end of line and across empty lines', function()
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', '', 'bbb' })
      vim.cmd('syntax region InspectRegion start=/aaa/ end=/bbb/')
      vim.cmd('syntax sync fromstart')
      vim.cmd('highlight link InspectRegion String')
    end)
    for _, pos in ipairs({ { 0, 3 }, { 1, 0 } }) do
      eq('Constant', inspect(unpack(pos)).syntax[1].hl_group_link)
      eq({
        {
          hl_group = 'InspectRegion',
          hl_group_link = 'Constant',
          row = pos[1],
          col = pos[2],
          end_row = 2,
          end_col = 0,
        },
      }, inspect(pos[1], pos[2], { end_row = 2, end_col = 0 }).syntax)
    end
    eq({}, inspect(1, 0, { end_row = 1, end_col = 0 }).syntax)
  end)
end)

describe('vim.show_pos', function()
  before_each(function()
    clear()
  end)

  it('it does not error', function()
    exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local a = 123' })
      vim.bo[buf].filetype = 'lua'
      vim.cmd('syntax on')
      return { buf, vim.show_pos(0, 0, 10) }
    end)
    eq('', eval('v:errmsg'))
  end)

  it('shows positions of unhighlighted extmarks in a range', function()
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'bbb', 'ccc' })
      local ns = vim.api.nvim_create_namespace('inspect')
      vim.api.nvim_buf_set_extmark(0, ns, 0, 1, {})
      vim.api.nvim_buf_set_extmark(0, ns, 2, 1, { end_col = 2 })
    end)
    eq(
      'Extmarks\n  - inspect\n\n',
      n.exec_capture('lua vim.show_pos(0, 0, 1, { extmarks = "all" })')
    )
    eq(
      'Extmarks\n  - [0:1 - 0:1]   inspect\n  - [2:1 - 2:2]   inspect\n\n',
      n.exec_capture('lua vim.show_pos(0, 0, 0, { extmarks = "all", end_row = 3, end_col = 0 })')
    )
  end)
end)

it(':Inspect respects line ranges and Visual selections', function()
  clear({ args_rm = { '--cmd' }, args = { '--clean', '--cmd', n.runtime_set } })
  exec_lua(function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'aaa', 'å界', 'ccc' })
    local ns = vim.api.nvim_create_namespace('inspect_command')
    for row = 0, 2 do
      vim.api.nvim_buf_set_extmark(0, ns, row, 0, { end_col = 1, hl_group = 'Normal' })
    end
  end)
  t.matches('col = 0,\n  end_col = 0,\n  end_row = 2', n.exec_capture('2Inspect!'))
  for _, selection in ipairs({ 'gg0vj', 'ggVj' }) do
    n.command('redir => g:inspect_output')
    n.feed(selection .. ':Inspect<CR><CR>')
    n.command('redir END')
    t.matches('%[0:0 %- 0:1%].*%[1:0 %- 1:1%]', eval('g:inspect_output'))
    -- Explicit addresses must ignore the previous Visual selection.
    local output = n.exec_capture('3Inspect')
    t.matches('%[2:0 %- 2:1%]', output)
    eq(nil, output:find('[0:0', 1, true))
    eq(nil, output:find('[1:0', 1, true))
  end
end)
