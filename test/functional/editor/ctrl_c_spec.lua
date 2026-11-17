local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, feed, source = n.clear, n.feed, n.source
local command = n.command
local poke_eventloop = n.poke_eventloop
local sleep = vim.uv.sleep

describe('CTRL-C (mapped)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(52, 6)
  end)

  it('interrupts :global', function()
    -- Crashes luajit.
    if t.skip_fragile(t.pending) then
      return
    end

    source([[
      set nomore nohlsearch undolevels=-1
      nnoremap <C-C> <NOP>
    ]])

    command('silent edit! test/functional/fixtures/bigfile.txt')

    screen:expect([[
      ^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;               |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;   |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;      |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;        |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;|
                                                          |
    ]])

    -- Sends CTRL-C during :global. The timer fires when :global first checks for input.
    n.exec_lua(function()
      function _G.ctrl_c_soon()
        local timer = assert(vim.uv.new_timer())
        timer:start(0, 0, function()
          timer:close()
          vim.api.nvim_input('<C-C>')
        end)
      end
    end)

    -- Interrupts even if the cmd never checks for input, within ~20ms (line 2 at 10ms/line).
    t.eq(
      'Keyboard interrupt',
      t.pcall_err(
        command,
        '1,1000global/^/lua _G.n = (_G.n or 0) + 1; if _G.n == 1 then _G.ctrl_c_soon() end; vim.uv.sleep(10)'
      )
    )
    t.ok(n.exec_lua('return _G.n') < 5)

    feed(':call v:lua.ctrl_c_soon() | global/^/p<CR>')
    screen:expect({ any = 'Interrupt' })
  end)

  it('interrupts :sleep', function()
    command('nnoremap <C-C> <Nop>')
    feed(':sleep 100<CR>')
    poke_eventloop() -- wait for :sleep to start
    feed('foo<C-C>')
    poke_eventloop() -- wait for input buffer to be flushed
    feed('i')
    screen:expect([[
      ^                                                    |
      {1:~                                                   }|*4
      {5:-- INSERT --}                                        |
    ]])
  end)

  it('interrupts recursive mapping', function()
    command('nnoremap <C-C> <Nop>')
    command('nmap <F2> <Ignore><F2>')
    feed('<F2>')
    sleep(10) -- wait for the key to enter typeahead
    feed('foo<C-C>')
    poke_eventloop() -- wait for input buffer to be flushed
    feed('i')
    screen:expect([[
      ^                                                    |
      {1:~                                                   }|*4
      {5:-- INSERT --}                                        |
    ]])
  end)
end)
