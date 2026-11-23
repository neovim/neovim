local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local eq = t.eq
local eval = n.eval
local source_vim = n.source

describe('RecordingEnter', function()
  before_each(clear)
  it('works', function()
    source_vim [[
      let g:recorded = 0
      autocmd RecordingEnter * let g:recorded += 1
      call feedkeys("qqyyq", 'xt')
    ]]
    eq(1, eval('g:recorded'))
  end)

  it('gives a correct reg_recording()', function()
    source_vim [[
      let g:recording = ''
      autocmd RecordingEnter * let g:recording = reg_recording()
      call feedkeys("qqyyq", 'xt')
    ]]
    eq('q', eval('g:recording'))
  end)

  it('runs before the recording message is displayed', function()
    local screen = Screen.new(25, 4)
    n.command(
      'autocmd RecordingEnter * let g:recording_message = screenstring(&lines, 1)'
        .. ' | highlight ModeMsg guifg=Red gui=NONE'
    )
    n.feed('qa')
    eq(' ', eval('g:recording_message'))
    screen:expect([[
      ^                         |
      {1:~                        }|*2
      {19:recording @a}             |
    ]])
  end)
end)

describe('RecordingLeave', function()
  before_each(clear)
  it('works', function()
    source_vim [[
      let g:recorded = 0
      autocmd RecordingLeave * let g:recorded += 1
      call feedkeys("qqyyq", 'xt')
    ]]
    eq(1, eval('g:recorded'))
  end)

  it('gives the correct reg_recorded()', function()
    source_vim [[
      let g:recorded = 'a'
      let g:recording = ''
      autocmd RecordingLeave * let g:recording = reg_recording()
      autocmd RecordingLeave * let g:recorded = reg_recorded()
      call feedkeys("qqyyq", 'xt')
    ]]
    eq('q', eval 'g:recording')
    eq('', eval 'g:recorded')
    eq('q', eval 'reg_recorded()')
  end)

  it('populates v:event', function()
    source_vim [[
      let g:regname = ''
      let g:regcontents = ''
      autocmd RecordingLeave * let g:regname = v:event.regname
      autocmd RecordingLeave * let g:regcontents = v:event.regcontents
      call feedkeys("qqyyq", 'xt')
    ]]
    eq('q', eval 'g:regname')
    eq('yy', eval 'g:regcontents')
  end)

  it('resets v:event', function()
    source_vim [[
      autocmd RecordingLeave * let g:event = v:event
      call feedkeys("qqyyq", 'xt')
    ]]
    eq(0, eval 'len(v:event)')
  end)
end)
