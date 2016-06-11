local helpers = require('test.functional.helpers')(after_each)
local call = helpers.call
local clear = helpers.clear
local execute = helpers.execute
local expect = helpers.expect
local source = helpers.source

describe('Text object', function()
  before_each(function()
    clear()
    execute('set shada=')
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
    execute('set cpo-=M')
    call('SelectionOut', '(red \\(blue) green)')

    expect([[
      (red \(blue) green)
      red \(blue
      red \(blue
      ]])
  end)

  it('Test for vi) with cpo-M #1', function()
    execute('set cpo+=M')
    call('SelectionOut', '(red \\(blue) green)')

    expect([[
      (red \(blue) green)
      red \(blue) green
      blue
      red \(blue) green]])
  end)

  it('Test for vi) with cpo-M #2', function()
    execute('set cpo+=M')
    call('SelectionOut', '(red (blue\\) green)')

    expect([[
      (red (blue\) green)
      red (blue\) green
      blue\
      red (blue\) green]])
  end)
end)
