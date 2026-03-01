local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local fn = n.fn
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local feed = n.feed

local function get_selected()
  return table.concat(fn.getregion(fn.getpos('v'), fn.getpos('.')), '\n')
end

local function set_lines(lines)
  if type(lines) == 'string' then
    lines = vim.split(lines, '\n')
  end
  api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local function set_filetype(ft)
  api.nvim_set_option_value('filetype', ft, { buf = 0 })
end

local function treeselect(cmd_, ...)
  if cmd_ == 'select_node' then
    cmd_ = 'select_child'
  end

  exec_lua(function(cmd, ...)
    require 'vim.treesitter._select'[cmd](...)
  end, cmd_, ...)
end

describe('incremental treesitter selection', function()
  before_each(function()
    clear()

    local code = {
      '',
      'foo(1)',
      'bar(2)',
      '',
    }

    set_lines(code)
    set_filetype('lua')
    feed('G')
  end)

  it('works', function()
    treeselect('select_node')
    eq('foo(1)\nbar(2)\n', get_selected())

    treeselect('select_child')
    eq('foo(1)', get_selected())

    treeselect('select_next')
    eq('bar(2)', get_selected())

    treeselect('select_prev')
    eq('foo(1)', get_selected())

    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
  end)

  it('repeate works', function()
    set_lines('foo(1,2,3,4)')
    treeselect('select_node')
    eq('foo', get_selected())
    treeselect('select_next')
    eq('(1,2,3,4)', get_selected())
    treeselect('select_parent')
    eq('foo(1,2,3,4)', get_selected())

    treeselect('select_child', 2)
    eq('1', get_selected())

    treeselect('select_next', 3)
    eq('4', get_selected())

    treeselect('select_prev', 2)
    eq('2', get_selected())

    treeselect('select_parent', 2)
    eq('foo(1,2,3,4)', get_selected())

    treeselect('select_child', 2)
    eq('2', get_selected())
  end)

  it('has history', function()
    treeselect('select_node')
    treeselect('select_child')
    treeselect('select_next')

    eq('bar(2)', get_selected())
    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
    treeselect('select_child')
    eq('bar(2)', get_selected())

    treeselect('select_prev')

    eq('foo(1)', get_selected())
    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
    treeselect('select_child')
    eq('foo(1)', get_selected())
  end)

  it('correctly selects node as parent when node half selected', function()
    feed('kkl', 'v', 'l')
    eq('oo', get_selected())

    treeselect('select_parent')
    eq('foo', get_selected())
  end)

  it('correctly selects node as child when node half selected', function()
    feed('kkl', 'v', 'l')
    eq('oo', get_selected())

    treeselect('select_child')
    eq('foo', get_selected())
  end)

  it('correctly find child node when node half selected', function()
    feed('kkl', 'v', 'j')
    eq('oo(1)\nba', get_selected())

    treeselect('select_child')
    eq('(1)', get_selected())
  end)

  it('maintainse cursor selection-end-pos', function()
    feed('kk')
    treeselect('select_node')
    eq('foo', get_selected())

    treeselect('select_parent')
    feed('h')
    eq('foo(1', get_selected())

    treeselect('select_child')
    eq('foo', get_selected())

    feed('o')
    treeselect('select_parent')
    feed('l')
    eq('oo(1)', get_selected())
  end)

  it('handles outside root node', function()
    feed('gg', 'v')
    eq('', get_selected())

    treeselect('select_node')
    eq('foo(1)\nbar(2)\n', get_selected())

    feed('<esc>gg', 'v')
    eq('', get_selected())

    treeselect('select_child')
    eq('foo(1)\nbar(2)\n', get_selected())

    feed('<esc>gg', 'v')
    eq('', get_selected())

    treeselect('select_parent')
    eq('foo(1)\nbar(2)\n', get_selected())
  end)
end)

describe('incremental treesitter selection with injections', function()
  before_each(function()
    clear({ args_rm = { '--cmd' }, args = { '--clean', '--cmd', n.runtime_set } })
  end)

  it('works', function()
    set_lines('```lua\ndo foo() end\n```')
    set_filetype('markdown')
    feed('gg0')
    treeselect('select_node')
    treeselect('select_parent')
    eq('```lua\ndo foo() end\n```', get_selected())

    treeselect('select_child')
    treeselect('select_next')
    treeselect('select_next')
    treeselect('select_child')
    treeselect('select_child')
    treeselect('select_child')

    eq('foo', get_selected())

    treeselect('select_parent')
    treeselect('select_parent')
    treeselect('select_parent')
    treeselect('select_prev')

    eq('lua', get_selected())

    treeselect('select_next')
    treeselect('select_next')

    eq('```', get_selected())
  end)

  it('ignores overlapping nodes', function()
    do
      -- Check that, if injections are disabled, there are nodes overlapping the injection
      exec_lua(function()
        vim.treesitter.query.set('vimdoc', 'injections', '')
        vim.cmd.enew()
      end)

      set_filetype('help')
      set_lines('>lua\n \n foo(\n )')

      feed('G0')
      treeselect('select_node')
      eq(' )', get_selected())
      treeselect('select_prev')
      eq(' foo(', get_selected())

      exec_lua(function()
        vim.treesitter.query.set('vimdoc', 'injections', ';; extends')
        vim.cmd.enew()
      end)
    end

    set_filetype('help')
    set_lines('>lua\n \n foo(\n )')

    feed('G0')
    treeselect('select_node')
    eq('(\n )', get_selected())
    treeselect('select_parent')
    treeselect('select_parent')
    eq('foo(\n )', get_selected())

    -- There will be one out of the siblings that wont be covered:
    treeselect('select_prev')
    eq(' ', get_selected())
  end)

  it('ignores overlapping injections', function()
    exec_lua(function()
      vim.treesitter.query.set(
        'lua',
        'injections',
        [[
      (comment
        content: (_) @injection.content
        (#set! injection.language "vim")
        (#offset! @injection.content 0 1 0 -3))
      (comment
        content: (_) @injection.content
        (#set! injection.language "c")
        (#offset! @injection.content 0 2 0 0))
      ]]
      )
      vim.cmd.enew()
    end)

    -- What the above query does is create the injections as follows (v=vim, c=c):
    --             vvvv
    --              cccccc
    --          -- edit();

    set_filetype('lua')
    set_lines({ '-- edit();' })
    feed('gg0lll')
    treeselect('select_node')
    if get_selected() == 'edit' then
      -- It is random which injection gets higher priority,
      --   as the priority uses the treesitter-node's id as a priority
      --  So reverse the priority if not favorable
      exec_lua("require'vim.treesitter._select'.TEST_SWITCH_PRIORITY=true")
    end

    feed('<esc>gg0lll')
    treeselect('select_node')
    eq(' edit();', get_selected())
    treeselect('select_child')
    eq('dit();', get_selected())
    treeselect('select_prev') -- should do nothing
    eq('dit();', get_selected())

    exec_lua(
      "require'vim.treesitter._select'.TEST_SWITCH_PRIORITY=not require'vim.treesitter._select'.TEST_SWITCH_PRIORITY"
    )
    feed('<esc>gg0lll')
    treeselect('select_node')
    eq('edit', get_selected())
    treeselect('select_next') -- should do nothing
    eq('edit', get_selected())
  end)

  it('handles disjointed trees', function()
    exec_lua(function()
      vim.treesitter.query.set(
        'lua',
        'injections',
        [[
      (comment
        content: (_) @injection.content
        (#set! injection.language "c")
        (#set! injection.combined))
      ]]
      )
      vim.cmd.enew()
    end)

    set_filetype('lua')
    set_lines({ '--int foo={', '--1};' })
    feed('gg$')

    treeselect('select_node')
    eq('{', get_selected())
    treeselect('select_parent')
    treeselect('select_parent')
    treeselect('select_parent')
    eq('--int foo={', get_selected())

    treeselect('select_next')
    eq('--1};', get_selected())
    treeselect('select_child')
    treeselect('select_child')
    eq('1}', get_selected())
    treeselect('select_prev') -- should do nothing
    eq('1}', get_selected())
  end)
end)
