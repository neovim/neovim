local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local source_vim = helpers.source

describe('RecordingEnter', function()
  before_each(clear)
  it('works', function()
    source_vim [[
      let g:recorded = 0
      autocmd RecordingEnter * let g:recorded += 1
      execute "normal! qqyyq"
    ]]
    eq(1, eval('g:recorded'))
  end)

  it('gives a correct reg_recording()', function()
    source_vim [[
      let g:recording = ''
      autocmd RecordingEnter * let g:recording = reg_recording()
      execute "normal! qqyyq"
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
      execute "normal! qqyyq"
    ]]
    eq(1, eval('g:recorded'))
  end)

  it('gives the correct reg_recorded()', function()
    source_vim [[
      let g:recorded = 'a'
      let g:recording = ''
      autocmd RecordingLeave * let g:recording = reg_recording()
      autocmd RecordingLeave * let g:recorded = reg_recorded()
      execute "normal! qqyyq"
    ]]
    eq('q', eval 'g:recording')
    eq('', eval 'g:recorded')
    eq('q', eval 'reg_recorded()')
  end)
end)
