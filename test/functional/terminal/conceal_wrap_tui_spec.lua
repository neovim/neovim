-- Exercise TUI scrolling and redraw, which RPC screen grids do not cover.
local n = require('test.functional.testnvim')()
local t = require('test.testutil')
local tt = require('test.functional.testterm')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local feed_data = tt.feed_data

local function start_conceal(opts, code)
  local script = t.tmpname() .. '.lua'
  t.write_file(script, code)
  t.finally(function()
    os.remove(script)
  end)
  return tt.setup_child_nvim({
    '--clean',
    '--cmd',
    'set wrap conceallevel=2 laststatus=0 noshowmode noshowcmd noruler ' .. opts,
    '-S',
    script,
  }, {
    cols = 20,
    env = { COLORTERM = 'xterm-256color' },
  })
end

describe('conceal-aware wrapping (#14409): real terminal', function()
  before_each(clear)

  it('redraws a scrolled line when its cursor reveals another row', function()
    local screen = start_conceal(
      'concealcursor= scrolloff=0',
      [[
      local lines = {}
      for i = 1, 20 do
        lines[i] = ('L%02d'):format(i)
      end
      lines[8] = ('A'):rep(10) .. 'HIDDEN' .. ('B'):rep(9)
      vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
      vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace('conceal'), 7, 10, {
        end_col = 16, conceal = '',
      })
      vim.cmd('normal! 8Gzt')
    ]]
    )
    local revealed = [[
      ^AAAAAAAAAAHIDDENBBBB|
      BBBBB               |
      L09                 |
      L10                 |
      L11                 |
                          |
      {5:-- TERMINAL --}      |
    ]]
    screen:expect(revealed)
    feed_data('j')
    screen:expect([[
      AAAAAAAAAABBBBBBBBB |
      ^L09                 |
      L10                 |
      L11                 |
      L12                 |
                          |
      {5:-- TERMINAL --}      |
    ]])
    feed_data('k')
    screen:expect(revealed)
  end)

  it('redraws all rows when resizing a concealed line', function()
    local screen = start_conceal(
      'concealcursor=nvic',
      [[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, { ('A'):rep(10) .. 'HIDDEN' .. ('B'):rep(9), 'END' })
      vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace('conceal'), 0, 10, {
        end_col = 16, conceal = '',
      })
    ]]
    )
    local wide = [[
      ^AAAAAAAAAABBBBBBBBB |
      END                 |
      ~                   |*3
                          |
      {5:-- TERMINAL --}      |
    ]]
    screen:expect(wide)
    screen:try_resize(14, 7)
    screen:expect([[
      ^AAAAAAAAAABBBB|
      BBBBB         |
      END           |
      ~             |*2
                    |
      {5:-- TERMINAL --}|
    ]])
    screen:try_resize(20, 7)
    screen:expect(wide)
  end)

  it('redraws a wrapped Tree-sitter line after editing and undo', function()
    local screen = start_conceal(
      'concealcursor=nvic scrolloff=0 shortmess+=u',
      [[
      local lines = {}
      for i = 1, 24 do
        lines[i] = ('int HIDDENIDENTIFIER = %d;'):format(i)
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
      vim.treesitter.query.set('c', 'highlights', [=[
        ((identifier) @conceal (#eq? @conceal "HIDDENIDENTIFIER") (#set! conceal ""))
      ]=])
      vim.treesitter.start(0, 'c')
      vim.treesitter.get_parser():parse(true)
      vim.cmd('normal! 15Gzt')
    ]]
    )
    local concealed = [[
      ^int  = 15;          |
      int  = 16;          |
      int  = 17;          |
      int  = 18;          |
      int  = 19;          |
                          |
      {5:-- TERMINAL --}      |
    ]]
    screen:expect(concealed)
    feed_data('wciwVISIBLEIDENTIFIE\0270')
    screen:expect([[
      ^int VISIBLEIDENTIFIE|
       = 15;              |
      int  = 16;          |
      int  = 17;          |
      int  = 18;          |
                          |
      {5:-- TERMINAL --}      |
    ]])
    feed_data('u0')
    screen:expect(concealed)
  end)
end)
