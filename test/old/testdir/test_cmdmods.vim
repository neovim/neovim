" Test for all command modifiers in

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
  call assert_equal('edit', getcompletion('keepalt ed',      'cmdline')[0])
  call assert_equal('edit', getcompletion('keepjumps ed',    'cmdline')[0])
  call assert_equal('edit', getcompletion('keepmarks ed',    'cmdline')[0])
  call assert_equal('edit', getcompletion('keeppatterns ed', 'cmdline')[0])
endfunc

" vim: shiftwidth=2 sts=2 expandtab
