local t = require('test.functional.testutil')()
local call = t.call
local clear = t.clear
local command = t.command
local expect = t.expect
local source = t.source

describe('Text object', function()
  before_each(function()
    clear()
    command('set shada=')
    source([[
      function SelectionOut(data)
        new
        call setline(1, a:data)
        call setreg('"', '')
        normal! ggfrmavi)y
        $put =getreg('\"')
        call setreg('"', '')
        normal! `afbmavi)y
        $put =getreg('\"')
        call setreg('"', '')
        normal! `afgmavi)y
        $put =getreg('\"')
      endfunction
      ]])
  end)

  it('Test for vi) without cpo-M', function()
    command('set cpo-=M')
    call('SelectionOut', '(red \\(blue) green)')

    expect([[
      (red \(blue) green)
      red \(blue
      red \(blue
      ]])
  end)

  it('Test for vi) with cpo-M #1', function()
    command('set cpo+=M')
    call('SelectionOut', '(red \\(blue) green)')

    expect([[
      (red \(blue) green)
      red \(blue) green
      blue
      red \(blue) green]])
  end)

  it('Test for vi) with cpo-M #2', function()
    command('set cpo+=M')
    call('SelectionOut', '(red (blue\\) green)')

    expect([[
      (red (blue\) green)
      red (blue\) green
      blue\
      red (blue\) green]])
  end)
end)
