-- Tests for folding.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, clear, execute, expect =
  helpers.feed, helpers.insert, helpers.clear, helpers.execute, helpers.expect

describe('folding', function()
  before_each(clear)

  it('is working', function()
    insert([[
      1 aa
      2 bb
      3 cc
      4 dd {{{
      5 ee {{{ }}}
      6 ff }}}
      7 gg
      8 hh
      9 ii
      a jj
      b kk
      last]])

    -- Basic test if a fold can be created, opened, moving to the end and
    -- closed.
    execute('/^1')
    feed('zf2j')
    execute('call append("$", "manual " . getline(foldclosed(".")))')
    feed('zo')
    execute('call append("$", foldclosed("."))')
    feed(']z')
    execute('call append("$", getline("."))')
    feed('zc')
    execute('call append("$", getline(foldclosed(".")))')
    -- Test folding with markers.
    execute('set fdm=marker fdl=1 fdc=3')
    execute('/^5')
    execute('call append("$", "marker " . foldlevel("."))')
    feed('[z')
    execute('call append("$", foldlevel("."))')
    feed('jo{{ <esc>r{jj')
    execute('call append("$", foldlevel("."))')
    feed('kYpj')
    execute('call append("$", foldlevel("."))')
    -- Test folding with indent.
    execute('set fdm=indent sw=2')
    execute('/^2 b')
    feed('i  <esc>jI    <esc>')
    execute('call append("$", "indent " . foldlevel("."))')
    feed('k')
    execute('call append("$", foldlevel("."))')
    -- Test syntax folding.
    execute('set fdm=syntax fdl=0')
    execute('syn region Hup start="dd" end="ii" fold contains=Fd1,Fd2,Fd3')
    execute('syn region Fd1 start="ee" end="ff" fold contained')
    execute('syn region Fd2 start="gg" end="hh" fold contained')
    execute('syn region Fd3 start="commentstart" end="commentend" fold contained')
    feed('Gzk')
    execute('call append("$", "folding " . getline("."))')
    feed('k')
    execute('call append("$", getline("."))')
    feed('jAcommentstart  <esc>Acommentend<esc>')
    execute('set fdl=1')
    feed('3j')
    execute('call append("$", getline("."))')
    execute('set fdl=0')
    feed('zO<C-L>j')
    execute('call append("$", getline("."))')
    -- Test expression folding.
    execute('fun Flvl()')
    execute('  let l = getline(v:lnum)')
    execute('  if l =~ "bb$"')
    execute('    return 2')
    execute('  elseif l =~ "gg$"')
    execute('    return "s1"')
    execute('  elseif l =~ "ii$"')
    execute('    return ">2"')
    execute('  elseif l =~ "kk$"')
    execute('    return "0"')
    execute('  endif')
    execute('  return "="')
    execute('endfun')
    execute('set fdm=expr fde=Flvl()')
    execute('/bb$')
    execute('call append("$", "expr " . foldlevel("."))')
    execute('/hh$')
    execute('call append("$", foldlevel("."))')
    execute('/ii$')
    execute('call append("$", foldlevel("."))')
    execute('/kk$')
    execute('call append("$", foldlevel("."))')
    execute('0,/^last/delete')
    execute('delfun Flvl')

    -- Assert buffer contents.
    expect([[
      manual 1 aa
      -1
      3 cc
      1 aa
      marker 2
      1
      1
      0
      indent 2
      1
      folding 9 ii
          3 cc
      7 gg
      8 hh
      expr 2
      1
      2
      0]])
  end)

  it('can open after :move', function()
    insert([[
      Test fdm=indent and :move bug END
      line2
      	Test fdm=indent START
      	line3
      	line4]])

    execute('set noai nosta')
    execute('set fdm=indent')
    execute('1m1')
    feed('2jzc')
    execute('m0')

    expect([[
      	Test fdm=indent START
      	line3
      	line4
      Test fdm=indent and :move bug END
      line2]])
  end)
end)
