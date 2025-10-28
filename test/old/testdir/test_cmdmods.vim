" Test for all command modifiers in

let s:luaeval_cmdmods =<< trim END
  vim.iter(loadfile('../../../src/nvim/ex_cmds.lua')()):map(function(cmd)
    if cmd.func == 'ex_wrongmodifier' or cmd.command == 'hide' then
      return cmd.command
    else
      return nil
    end
  end):totable()
END
let s:cmdmods = []

func s:get_cmdmods()
  if empty(s:cmdmods)
    let s:cmdmods = luaeval(s:luaeval_cmdmods->join("\n"))
  endif
  return s:cmdmods
endfunc

func Test_keep_cmdmods_names()
  call assert_equal('k', fullcommand(':k'))
  call assert_equal('k', fullcommand(':ke'))
  call assert_equal('keepmarks', fullcommand(':kee'))
  call assert_equal('keepmarks', fullcommand(':keep'))
  call assert_equal('keepmarks', fullcommand(':keepm'))
  call assert_equal('keepmarks', fullcommand(':keepma'))
  call assert_equal('keepmarks', fullcommand(':keepmar'))
  call assert_equal('keepmarks', fullcommand(':keepmark'))
  call assert_equal('keepmarks', fullcommand(':keepmarks'))
  call assert_equal('keepalt', fullcommand(':keepa'))
  call assert_equal('keepalt', fullcommand(':keepal'))
  call assert_equal('keepalt', fullcommand(':keepalt'))
  call assert_equal('keepjumps', fullcommand(':keepj'))
  call assert_equal('keepjumps', fullcommand(':keepju'))
  call assert_equal('keepjumps', fullcommand(':keepjum'))
  call assert_equal('keepjumps', fullcommand(':keepjump'))
  call assert_equal('keepjumps', fullcommand(':keepjumps'))
  call assert_equal('keeppatterns', fullcommand(':keepp'))
  call assert_equal('keeppatterns', fullcommand(':keeppa'))
  call assert_equal('keeppatterns', fullcommand(':keeppat'))
  call assert_equal('keeppatterns', fullcommand(':keeppatt'))
  call assert_equal('keeppatterns', fullcommand(':keeppatte'))
  call assert_equal('keeppatterns', fullcommand(':keeppatter'))
  call assert_equal('keeppatterns', fullcommand(':keeppattern'))
  call assert_equal('keeppatterns', fullcommand(':keeppatterns'))
endfunc

func Test_cmdmod_completion()
  for mod in s:get_cmdmods()
    let cmd = $'{mod} ed'
    if mod == 'filter'
      let cmd = $'{mod} /pattern/ ed'
    endif
    call assert_equal('edit', getcompletion(cmd, 'cmdline')[0])
  endfor
endfunc

" vim: shiftwidth=2 sts=2 expandtab
