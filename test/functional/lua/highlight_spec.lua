local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local exec_lua = n.exec_lua
local eq = t.eq
local neq = t.neq
local eval = n.eval
local command = n.command
local clear = n.clear
local api = n.api

describe('vim.highlight.range', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 6)
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.Blue, background = Screen.colors.Yellow, bold = true },
    })
    screen:attach()
    api.nvim_set_option_value('list', true, {})
    api.nvim_set_option_value('listchars', 'eol:$', {})
    api.nvim_buf_set_lines(0, 0, -1, true, {
      'asdfghjkl',
      '«口=口»',
      'qwertyuiop',
      '口口=口口',
      'zxcvbnm',
    })
  end)

  it('works with charwise selection', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.highlight.range(0, ns, 'Search', { 1, 5 }, { 3, 10 })
    ]])
    screen:expect([[
      ^asdfghjkl{1:$}                                                  |
      «口{10:=口»}{100:$}                                                    |
      {10:qwertyuiop}{100:$}                                                 |
      {10:口口=口}口{1:$}                                                  |
      zxcvbnm{1:$}                                                    |
                                                                  |
    ]])
  end)

  it('works with linewise selection', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.highlight.range(0, ns, 'Search', { 0, 0 }, { 4, 0 }, { regtype = 'V' })
    ]])
    screen:expect([[
      {10:^asdfghjkl}{100:$}                                                  |
      {10:«口=口»}{100:$}                                                    |
      {10:qwertyuiop}{100:$}                                                 |
      {10:口口=口口}{100:$}                                                  |
      {10:zxcvbnm}{100:$}                                                    |
                                                                  |
    ]])
  end)

  it('works with blockwise selection', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.highlight.range(0, ns, 'Search', { 0, 0 }, { 4, 4 }, { regtype = '\022' })
    ]])
    screen:expect([[
      {10:^asdf}ghjkl{1:$}                                                  |
      {10:«口=}口»{1:$}                                                    |
      {10:qwer}tyuiop{1:$}                                                 |
      {10:口口}=口口{1:$}                                                  |
      {10:zxcv}bnm{1:$}                                                    |
                                                                  |
    ]])
  end)

  it('works with blockwise selection with width', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.highlight.range(0, ns, 'Search', { 0, 4 }, { 4, 7 }, { regtype = '\0226' })
    ]])
    screen:expect([[
      ^asdf{10:ghjkl}{1:$}                                                  |
      «口={10:口»}{1:$}                                                    |
      qwer{10:tyuiop}{1:$}                                                 |
      口口{10:=口口}{1:$}                                                  |
      zxcv{10:bnm}{1:$}                                                    |
                                                                  |
    ]])
  end)

  it('can use -1 or v:maxcol to indicate end of line', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.highlight.range(0, ns, 'Search', { 0, 4 }, { 1, -1 }, {})
      vim.highlight.range(0, ns, 'Search', { 2, 6 }, { 3, vim.v.maxcol }, {})
    ]])
    screen:expect([[
      ^asdf{10:ghjkl}{100:$}                                                  |
      {10:«口=口»}{100:$}                                                    |
      qwerty{10:uiop}{100:$}                                                 |
      {10:口口=口口}{1:$}                                                  |
      zxcvbnm{1:$}                                                    |
                                                                  |
    ]])
  end)
end)

describe('vim.highlight.on_yank', function()
  before_each(function()
    clear()
  end)

  it('does not show errors even if buffer is wiped before timeout', function()
    command('new')
    exec_lua([[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y", regtype = "v"}})
      vim.cmd('bwipeout!')
    ]])
    vim.uv.sleep(10)
    n.feed('<cr>') -- avoid hang if error message exists
    eq('', eval('v:errmsg'))
  end)

  it('does not close timer twice', function()
    exec_lua([[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y"}})
      vim.uv.sleep(10)
      vim.schedule(function()
        vim.highlight.on_yank({timeout = 0, on_macro = true, event = {operator = "y"}})
      end)
    ]])
    eq('', eval('v:errmsg'))
  end)

  it('does not show in another window', function()
    command('vsplit')
    exec_lua([[
      vim.api.nvim_buf_set_mark(0,"[",1,1,{})
      vim.api.nvim_buf_set_mark(0,"]",1,1,{})
      vim.highlight.on_yank({timeout = math.huge, on_macro = true, event = {operator = "y"}})
    ]])
    neq({}, api.nvim__win_get_ns(0))
    command('wincmd w')
    eq({}, api.nvim__win_get_ns(0))
  end)

  it('removes old highlight if new one is created before old one times out', function()
    command('vnew')
    exec_lua([[
      vim.api.nvim_buf_set_mark(0,"[",1,1,{})
      vim.api.nvim_buf_set_mark(0,"]",1,1,{})
      vim.highlight.on_yank({timeout = math.huge, on_macro = true, event = {operator = "y"}})
    ]])
    neq({}, api.nvim__win_get_ns(0))
    command('wincmd w')
    exec_lua([[
      vim.api.nvim_buf_set_mark(0,"[",1,1,{})
      vim.api.nvim_buf_set_mark(0,"]",1,1,{})
      vim.highlight.on_yank({timeout = math.huge, on_macro = true, event = {operator = "y"}})
    ]])
    command('wincmd w')
    eq({}, api.nvim__win_get_ns(0))
  end)
end)
