-- Normal mode tests.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local feed = n.feed
local fn = n.fn
local command = n.command
local eq = t.eq
local api = n.api

describe('Normal mode', function()
  before_each(clear)

  it('setting &winhighlight or &winblend does not change curswant #27470', function()
    fn.setline(1, { 'long long lone line', 'short line' })
    feed('ggfi')
    local pos = fn.getcurpos()
    feed('j')
    command('setlocal winblend=10 winhighlight=Visual:Search')
    feed('k')
    eq(pos, fn.getcurpos())
  end)

  it('&showcmd does not crash with :startinsert #28419', function()
    local screen = Screen.new(60, 17)
    fn.jobstart({ n.nvim_prog, '--clean', '--cmd', 'startinsert' }, {
      term = true,
      env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
    })
    screen:expect({
      grid = [[
        ^                                                            |
        ~                                                           |*13
        [No Name]                                 0,1            All|
        -- INSERT --                                                |
                                                                    |
      ]],
      attr_ids = {},
    })
  end)

  it('replacing with ZWJ emoji sequences', function()
    local screen = Screen.new(30, 8)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcdefg' })
    feed('05r🧑‍🌾') -- ZWJ
    screen:expect([[
      🧑‍🌾🧑‍🌾🧑‍🌾🧑‍🌾^🧑‍🌾fg                  |
      {1:~                             }|*6
                                    |
    ]])

    feed('2r🏳️‍⚧️') -- ZWJ and variant selectors
    screen:expect([[
      🧑‍🌾🧑‍🌾🧑‍🌾🧑‍🌾🏳️‍⚧️^🏳️‍⚧️g                 |
      {1:~                             }|*6
                                    |
    ]])
  end)

  it('"gk" does not crash with signcolumn=yes in narrow window #31274', function()
    feed('o<Esc>')
    command('1vsplit | setlocal signcolumn=yes')
    feed('gk')
    n.assert_alive()
  end)

  it('keeps viewports valid across folds during queued navigation', function()
    Screen.new(40, 10)
    command('set nowrap laststatus=0 scrolloff=0 foldmethod=manual')
    fn.setline(1, fn.range(1, 80))
    command('10,20fold')
    command('normal! gg0zt')
    feed(('j'):rep(31))
    eq({ 42, 34 }, { fn.line('.'), fn.line('w0') })

    command('normal! gg0zt')
    command('setlocal cursorbind')
    local other = api.nvim_get_current_win()
    command('vsplit')
    command('normal! zE')
    feed(('j'):rep(31))
    eq({ 32, 24 }, { fn.line('.'), fn.line('w0') })
    eq({ 32, 24 }, { api.nvim_win_get_cursor(other)[1], fn.getwininfo(other)[1].topline })
  end)

  it('does not flush intermediate frames for a short navigation burst after idle', function()
    local screen = Screen.new(40, 10)
    fn.setline(1, fn.range(1, 80))
    command('normal! gg')
    screen:expect({ any = '%^1 +' })
    -- Sleep in the test runner so the editor remains idle.
    vim.uv.sleep(20)
    feed('jjgg')
    screen:expect_unchanged()
  end)

  for _, input in ipairs({ '<ScrollWheelDown>', '<C-E>' }) do
    it('flushes intermediate frames while ' .. input .. ' remains queued', function()
      local screen = Screen.new(40, 10)
      command('set mouse=a mousescroll=ver:1,hor:1 nowrap scrolloff=0')
      fn.setline(1, fn.range(1, 200))
      command('normal! gg')
      n.exec_lua(function(next_key)
        local count = 0
        vim.on_key(function(key)
          if key == vim.keycode(next_key) then
            count = count + 1
            if count == 8 or count == 24 then
              -- Cross the redraw budget without yielding or inserting another key.
              vim.uv.sleep(20)
            end
          end
        end)
      end, input)
      feed((input .. (input == '<ScrollWheelDown>' and '<0,0>' or '')):rep(32))
      local seen = {}
      screen:expect(function()
        local view = screen.win_viewport[2]
        if view then
          seen[view.topline] = true
        end
        eq(true, seen[8])
        eq(true, seen[24])
        eq(32, view.topline)
      end)
    end)
  end
end)
