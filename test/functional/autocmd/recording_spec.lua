local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local eq = t.eq
local eval = t.eval
local source_vim = t.source

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
