local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local meths = helpers.meths
local funcs = helpers.funcs

local exec = function(str)
  meths.exec2(str, { output = false })
end

describe('oldtests', function()
  before_each(clear)

  local exec_lines = function(str)
    return funcs.split(funcs.execute(str), "\n")
  end

  local add_an_autocmd = function()
    exec [[
      augroup vimBarTest
        au BufReadCmd * echo 'hello'
      augroup END
    ]]

    eq(3, #exec_lines('au vimBarTest'))
    eq(1, #meths.get_autocmds({ group = 'vimBarTest' }))
  end

  it('should recognize a bar before the {event}', function()
    -- Good spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest | au! | augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))
    eq({}, meths.get_autocmds({ group = 'vimBarTest' }))

    -- Sad spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))


    -- test that a bar is recognized after the {event}
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!BufReadCmd| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))

    add_an_autocmd()
    exec [[ au! vimBarTest|echo 'hello' ]]
    eq(1, #exec_lines('au vimBarTest'))
  end)

  it('should fire on unload buf', function()
    funcs.writefile({'Test file Xxx1'}, 'Xxx1')
    funcs.writefile({'Test file Xxx2'}, 'Xxx2')

    local content = [[
      func UnloadAllBufs()
        let i = 1
        while i <= bufnr('$')
          if i != bufnr('%') && bufloaded(i)
            exe  i . 'bunload'
          endif
          let i += 1
        endwhile
      endfunc
      au BufUnload * call UnloadAllBufs()
      au VimLeave * call writefile(['Test Finished'], 'Xout')
      set nohidden
      edit Xxx1
      split Xxx2
      q
    ]]

    funcs.writefile(funcs.split(content, "\n"), 'Xtest')

    funcs.delete('Xout')
    funcs.system(meths.get_vvar('progpath') .. ' -u NORC -i NONE -N -S Xtest')
    eq(1, funcs.filereadable('Xout'))

    funcs.delete('Xxx1')
    funcs.delete('Xxx2')
    funcs.delete('Xtest')
    funcs.delete('Xout')
  end)
end)
