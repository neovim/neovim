" Test spell checking
" Note: this file uses latin1 encoding, but is used with utf-8 encoding.

source check.vim
CheckFeature spell

source screendump.vim

func TearDown()
  set nospell
  call delete('Xtest.aff')
  call delete('Xtest.dic')
  call delete('Xtest.latin1.add')
  call delete('Xtest.latin1.add.spl')
  call delete('Xtest.latin1.spl')
  call delete('Xtest.latin1.sug')
  " set 'encoding' to clear the word list
  set encoding=utf-8
endfunc

func Test_wrap_search()
  new
  call setline(1, ['The', '', 'A plong line with two zpelling mistakes', '', 'End'])
  set spell wrapscan
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  normal ]s
  call assert_equal('zpelling', expand('<cword>'))
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  bwipe!
  set nospell
endfunc

func Test_curswant()
  new
  call setline(1, ['Another plong line', 'abcdefghijklmnopq'])
  set spell wrapscan
  normal 0]s
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])
  normal 0[s
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])

  normal 0]S
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])
  normal 0[S
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])

  normal 1G0
  call assert_equal('plong', spellbadword()[0])
  normal j
  call assert_equal(9, getcurpos()[2])

  bwipe!
  set nospell
endfunc

func Test_z_equal_on_invalid_utf8_word()
  split
  set spell
  call setline(1, "\xff")
  norm z=
  set nospell
  bwipe!
endfunc

func Test_z_equal_on_single_character()
  " this was decrementing the index below zero
  new
  norm a0\Ê
  norm zW
  norm z=

  bwipe!
endfunc

" Test spellbadword() with argument
func Test_spellbadword()
  set spell

  call assert_equal(['bycycle', 'bad'],  spellbadword('My bycycle.'))
  call assert_equal(['another', 'caps'], 'A sentence. another sentence'->spellbadword())

  call assert_equal(['TheCamelWord', 'bad'], spellbadword('TheCamelWord asdf'))
  set spelloptions=camel
  call assert_equal(['asdf', 'bad'], spellbadword('TheCamelWord asdf'))
  set spelloptions=

  set spelllang=en
  call assert_equal(['', ''],            spellbadword('centre'))
  call assert_equal(['', ''],            spellbadword('center'))
  set spelllang=en_us
  call assert_equal(['centre', 'local'], spellbadword('centre'))
  call assert_equal(['', ''],            spellbadword('center'))
  set spelllang=en_gb
  call assert_equal(['', ''],            spellbadword('centre'))
  call assert_equal(['center', 'local'], spellbadword('center'))

  " Create a small word list to test that spellbadword('...')
  " can return ['...', 'rare'].
  e Xwords
  insert
foo
foobar/?
.
   w!
   mkspell! Xwords.spl Xwords
   set spelllang=Xwords.spl
   call assert_equal(['foobar', 'rare'], spellbadword('foo foobar'))

  " Typo should be detected even without the 'spell' option.
  set spelllang=en_gb nospell
  call assert_equal(['', ''], spellbadword('centre'))
  call assert_equal(['bycycle', 'bad'], spellbadword('My bycycle.'))
  call assert_equal(['another', 'caps'], spellbadword('A sentence. another sentence'))

  set spelllang=
  call assert_fails("call spellbadword('maxch')", 'E756:')

  call delete('Xwords.spl')
  call delete('Xwords')
  set spelllang&
  set spell&
endfunc

func Test_spell_file_missing()
  let s:spell_file_missing = 0
  augroup TestSpellFileMissing
    autocmd! SpellFileMissing * let s:spell_file_missing += 1
  augroup END

  set spell spelllang=ab_cd
  let messages = GetMessages()
  " This message is not shown in Nvim because of #3027
  " call assert_equal('Warning: Cannot find word list "ab.utf-8.spl" or "ab.ascii.spl"', messages[-1])
  call assert_equal(1, s:spell_file_missing)

  new XTestSpellFileMissing
  augroup TestSpellFileMissing
    autocmd! SpellFileMissing * bwipe
  augroup END
  call assert_fails('set spell spelllang=ab_cd', 'E937:')

  " clean up
  augroup TestSpellFileMissing
    autocmd! SpellFileMissing
  augroup END
  augroup! TestSpellFileMissing
  unlet s:spell_file_missing
  set spell& spelllang&
  %bwipe!
endfunc

func Test_spell_file_missing_bwipe()
  " this was using a window that was wiped out in a SpellFileMissing autocmd
  set spelllang=xy
  au SpellFileMissing * n0
  set spell
  au SpellFileMissing * bw
  snext somefile

  au! SpellFileMissing
  bwipe!
  set nospell spelllang=en
endfunc

func Test_spelldump()
  " In case the spell file is not found avoid getting the download dialog, we
  " would get stuck at the prompt.
  let g:en_not_found = 0
  augroup TestSpellFileMissing
    au! SpellFileMissing * let g:en_not_found = 1
  augroup END
  set spell spelllang=en
  spellrare! emacs
  if g:en_not_found
    call assert_report("Could not find English spell file")
  else
    spelldump

    " Check assumption about region: 1: us, 2: au, 3: ca, 4: gb, 5: nz.
    call assert_equal('/regions=usaucagbnz', getline(1))
    call assert_notequal(0, search('^theater/1$'))    " US English only.
    call assert_notequal(0, search('^theatre/2345$')) " AU, CA, GB or NZ English.

    call assert_notequal(0, search('^emacs/?$'))      " ? for a rare word.
    call assert_notequal(0, search('^the the/!$'))    " ! for a wrong word.
  endif

  " clean up
  unlet g:en_not_found
  augroup TestSpellFileMissing
    autocmd! SpellFileMissing
  augroup END
  augroup! TestSpellFileMissing
  bwipe
  set spell&
endfunc

func Test_spelldump_bang()
  new
  call setline(1, 'This is a sample sentence.')
  redraw

  " In case the spell file is not found avoid getting the download dialog, we
  " would get stuck at the prompt.
  let g:en_not_found = 0
  augroup TestSpellFileMissing
    au! SpellFileMissing * let g:en_not_found = 1
  augroup END

  set spell

  if g:en_not_found
    call assert_report("Could not find English spell file")
  else
    redraw
    spelldump!

    " :spelldump! includes the number of times a word was found while updating
    " the screen.
    " Common word count starts at 10, regular word count starts at 0.
    call assert_notequal(0, search("^is\t11$"))    " common word found once.
    call assert_notequal(0, search("^the\t10$"))   " common word never found.
    call assert_notequal(0, search("^sample\t1$")) " regular word found once.
    call assert_equal(0, search("^screen\t"))      " regular word never found.
  endif

  " clean up
  unlet g:en_not_found
  augroup TestSpellFileMissing
    autocmd! SpellFileMissing
  augroup END
  augroup! TestSpellFileMissing
  %bwipe!
  set spell&
endfunc

func Test_spelllang_inv_region()
  set spell spelllang=en_xx
  let messages = GetMessages()
  call assert_equal('Warning: region xx not supported', messages[-1])
  set spell& spelllang&
endfunc

func Test_compl_with_CTRL_X_CTRL_K_using_spell()
  " When spell checking is enabled and 'dictionary' is empty,
  " CTRL-X CTRL-K in insert mode completes using the spelling dictionary.
  new
  set spell spelllang=en dictionary=

  set ignorecase
  call feedkeys("Senglis\<c-x>\<c-k>\<esc>", 'tnx')
  call assert_equal(['English'], getline(1, '$'))
  call feedkeys("SEnglis\<c-x>\<c-k>\<esc>", 'tnx')
  call assert_equal(['English'], getline(1, '$'))

  set noignorecase
  call feedkeys("Senglis\<c-x>\<c-k>\<esc>", 'tnx')
  call assert_equal(['englis'], getline(1, '$'))
  call feedkeys("SEnglis\<c-x>\<c-k>\<esc>", 'tnx')
  call assert_equal(['English'], getline(1, '$'))

  set spelllang=en_us
  call feedkeys("Stheat\<c-x>\<c-k>\<esc>", 'tnx')
  call assert_equal(['theater'], getline(1, '$'))
  set spelllang=en_gb
  call feedkeys("Stheat\<c-x>\<c-k>\<esc>", 'tnx')
  " FIXME: commented out, expected theatre bug got theater. See issue #7025.
  " call assert_equal(['theatre'], getline(1, '$'))

  bwipe!
  set spell& spelllang& dictionary& ignorecase&
endfunc

func Test_spellrepall()
  new
  set spell
  call assert_fails('spellrepall', 'E752:')
  call setline(1, ['A speling mistake. The same speling mistake.',
        \                'Another speling mistake.'])
  call feedkeys(']s1z=', 'tx')
  call assert_equal('A spelling mistake. The same speling mistake.', getline(1))
  call assert_equal('Another speling mistake.', getline(2))
  spellrepall
  call assert_equal('A spelling mistake. The same spelling mistake.', getline(1))
  call assert_equal('Another spelling mistake.', getline(2))
  call assert_fails('spellrepall', 'E753:')
  set spell&
  bwipe!
endfunc

func Test_spell_dump_word_length()
  " this was running over MAXWLEN
  new
  noremap 0 0a0zW0000000
  sil! norm 0z=0
  sil norm 0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
  sil! norm 0z=0

  bwipe!
  nunmap 0
endfunc

" Test spellsuggest({word} [, {max} [, {capital}]])
func Test_spellsuggest()
  " Verify suggestions are given even when spell checking is not enabled.
  set nospell
  call assert_equal(['march', 'March'], spellsuggest('marrch', 2))

  set spell

  " With 1 argument.
  call assert_equal(['march', 'March'], spellsuggest('marrch')[0:1])

  " With 2 arguments.
  call assert_equal(['march', 'March'], spellsuggest('marrch', 2))

  " With 3 arguments.
  call assert_equal(['march'], spellsuggest('marrch', 1, 0))
  call assert_equal(['March'], spellsuggest('marrch', 1, 1))

  " Test with digits and hyphen.
  call assert_equal('Carbon-14', spellsuggest('Carbon-15')[0])

  " Comment taken from spellsuggest.c explains the following test cases:
  "
  " If there are more UPPER than lower case letters suggest an
  " ALLCAP word.  Otherwise, if the first letter is UPPER then
  " suggest ONECAP.  Exception: "ALl" most likely should be "All",
  " require three upper case letters.
  call assert_equal(['THIRD', 'third'], spellsuggest('thIRD', 2))
  call assert_equal(['third', 'THIRD'], spellsuggest('tHIrd', 2))
  call assert_equal(['Third'], spellsuggest('THird', 1))
  call assert_equal(['All'],      spellsuggest('ALl', 1))

  " Special suggestion for repeated 'the the'.
  call assert_inrange(0, 2, index(spellsuggest('the the',   3), 'the'))
  call assert_inrange(0, 2, index(spellsuggest('the   the', 3), 'the'))
  call assert_inrange(0, 2, index(spellsuggest('The the',   3), 'The'))

  call assert_fails("call spellsuggest('maxch', [])", 'E745:')
  call assert_fails("call spellsuggest('maxch', 2, [])", 'E745:')

  set spelllang=
  call assert_fails("call spellsuggest('maxch')", 'E756:')
  set spelllang&

  set spell&
endfunc

" Test 'spellsuggest' option with methods fast, best and double.
func Test_spellsuggest_option_methods()
  set spell

  for e in ['utf-8']
    exe 'set encoding=' .. e

    set spellsuggest=fast
    call assert_equal(['Stick', 'Stitch'], spellsuggest('Stich', 2), e)

    " With best or double option, "Stitch" should become the top suggestion
    " because of better phonetic matching.
    set spellsuggest=best
    call assert_equal(['Stitch', 'Stick'], spellsuggest('Stich', 2), e)

    set spellsuggest=double
    call assert_equal(['Stitch', 'Stick'], spellsuggest('Stich', 2), e)
  endfor

  set spell& spellsuggest& encoding&
endfunc

" Test 'spellsuggest' option with value file:{filename}
func Test_spellsuggest_option_file()
  set spell spellsuggest=file:Xspellsuggest
  call writefile(['emacs/vim',
        \         'theribal/terrible',
        \         'teribal/terrrible',
        \         'terribal'],
        \         'Xspellsuggest')

  call assert_equal(['vim'],      spellsuggest('emacs', 2))
  call assert_equal(['terrible'], spellsuggest('theribal',2))

  " If the suggestion is misspelled (*terrrible* with 3 r),
  " it should not be proposed.
  " The entry for "terribal" should be ignored because of missing slash.
  call assert_equal([], spellsuggest('teribal', 2))
  call assert_equal([], spellsuggest('terribal', 2))

  set spell spellsuggest=best,file:Xspellsuggest
  call assert_equal(['vim', 'Emacs'],       spellsuggest('emacs', 2))
  call assert_equal(['terrible', 'tribal'], spellsuggest('theribal', 2))
  call assert_equal(['tribal'],             spellsuggest('teribal', 1))
  call assert_equal(['tribal'],             spellsuggest('terribal', 1))

  call delete('Xspellsuggest')
  call assert_fails("call spellsuggest('vim')", "E484: Can't open file Xspellsuggest")

  set spellsuggest& spell&
endfunc

" Test 'spellsuggest' option with value {number}
" to limit the number of suggestions
func Test_spellsuggest_option_number()
  set spell spellsuggest=2,best
  new

  " We limited the number of suggestions to 2, so selecting
  " the 1st and 2nd suggestion should correct the word, but
  " selecting a 3rd suggestion should do nothing.
  call setline(1, 'A baord')
  norm $1z=
  call assert_equal('A board', getline(1))

  call setline(1, 'A baord')
  norm $2z=
  call assert_equal('A bard', getline(1))

  call setline(1, 'A baord')
  norm $3z=
  call assert_equal('A baord', getline(1))

  let a = execute('norm $z=')
  call assert_equal(
  \    "\n"
  \ .. "Change \"baord\" to:\n"
  \ .. " 1 \"board\"\n"
  \ .. " 2 \"bard\"\n"
  \ .. "Type number and <Enter> or click with the mouse (q or empty cancels): ", a)

  set spell spellsuggest=0
  call assert_equal("\nSorry, no suggestions", execute('norm $z='))

  " Unlike z=, function spellsuggest(...) should not be affected by the
  " max number of suggestions (2) set by the 'spellsuggest' option.
  call assert_equal(['board', 'bard', 'broad'], spellsuggest('baord', 3))

  set spellsuggest& spell&
  bwipe!
endfunc

" Test 'spellsuggest' option with value expr:{expr}
func Test_spellsuggest_option_expr()
  " A silly 'spellsuggest' function which makes suggestions all uppercase
  " and makes the score of each suggestion the length of the suggested word.
  " So shorter suggestions are preferred.
  func MySuggest()
    let spellsuggest_save = &spellsuggest
    set spellsuggest=3,best
    let result = map(spellsuggest(v:val, 3), "[toupper(v:val), len(v:val)]")
    let &spellsuggest = spellsuggest_save
    return result
  endfunc

  set spell spellsuggest=expr:MySuggest()
  call assert_equal(['BARD', 'BOARD', 'BROAD'], spellsuggest('baord', 3))

  new
  call setline(1, 'baord')
  let a = execute('norm z=')
  call assert_equal(
  \    "\n"
  \ .. "Change \"baord\" to:\n"
  \ .. " 1 \"BARD\"\n"
  \ .. " 2 \"BOARD\"\n"
  \ .. " 3 \"BROAD\"\n"
  \ .. "Type number and <Enter> or click with the mouse (q or empty cancels): ", a)

  " With verbose, z= should show the score i.e. word length with
  " our SpellSuggest() function.
  set verbose=1
  let a = execute('norm z=')
  call assert_equal(
  \    "\n"
  \ .. "Change \"baord\" to:\n"
  \ .. " 1 \"BARD\"                      (4 - 0)\n"
  \ .. " 2 \"BOARD\"                     (5 - 0)\n"
  \ .. " 3 \"BROAD\"                     (5 - 0)\n"
  \ .. "Type number and <Enter> or click with the mouse (q or empty cancels): ", a)

  set spell& spellsuggest& verbose&
  bwipe!
endfunc

" Test for 'spellsuggest' expr errrors
func Test_spellsuggest_expr_errors()
  " 'spellsuggest'
  func MySuggest()
    return range(3)
  endfunc
  set spell spellsuggest=expr:MySuggest()
  call assert_equal([], spellsuggest('baord', 3))

  " Test for 'spellsuggest' expression returning a non-list value
  func! MySuggest2()
    return 'good'
  endfunc
  set spellsuggest=expr:MySuggest2()
  call assert_equal([], spellsuggest('baord'))

  " Test for 'spellsuggest' expression returning a list with dict values
  func! MySuggest3()
    return [[{}, {}]]
  endfunc
  set spellsuggest=expr:MySuggest3()
  call assert_fails("call spellsuggest('baord')", 'E731:')

  set nospell spellsuggest&
  delfunc MySuggest
  delfunc MySuggest2
  delfunc MySuggest3
endfunc

func Test_spellsuggest_timeout()
  set spellsuggest=timeout:30
  set spellsuggest=timeout:-123
  set spellsuggest=timeout:999999
  call assert_fails('set spellsuggest=timeout', 'E474:')
  call assert_fails('set spellsuggest=timeout:x', 'E474:')
  call assert_fails('set spellsuggest=timeout:-x', 'E474:')
  call assert_fails('set spellsuggest=timeout:--9', 'E474:')
endfunc

func Test_spellsuggest_visual_end_of_line()
  let enc_save = &encoding
  " set encoding=iso8859

  " This was reading beyond the end of the line.
  norm R00000000000
  sil norm 0
  sil! norm i00000)
  sil! norm i00000)
  call feedkeys("\<CR>")
  norm z=

  let &encoding = enc_save
endfunc

func Test_spellinfo()
  throw 'Skipped: Nvim does not support enc=latin1'
  new
  let runtime = substitute($VIMRUNTIME, '\\', '/', 'g')

  set enc=latin1 spell spelllang=en
  call assert_match("^\nfile: " .. runtime .. "/spell/en.latin1.spl\n$", execute('spellinfo'))

  set enc=cp1250 spell spelllang=en
  call assert_match("^\nfile: " .. runtime .. "/spell/en.ascii.spl\n$", execute('spellinfo'))

  set enc=utf-8 spell spelllang=en
  call assert_match("^\nfile: " .. runtime .. "/spell/en.utf-8.spl\n$", execute('spellinfo'))

  set enc=latin1 spell spelllang=en_us,en_nz
  call assert_match("^\n" .
                 \  "file: " .. runtime .. "/spell/en.latin1.spl\n" .
                 \  "file: " .. runtime .. "/spell/en.latin1.spl\n$", execute('spellinfo'))

  set spell spelllang=
  call assert_fails('spellinfo', 'E756:')

  set nospell spelllang=en
  call assert_fails('spellinfo', 'E756:')

  call assert_fails('set spelllang=foo/bar', 'E474:')
  call assert_fails('set spelllang=foo\ bar', 'E474:')
  call assert_fails("set spelllang=foo\\\nbar", 'E474:')
  call assert_fails("set spelllang=foo\\\rbar", 'E474:')
  call assert_fails("set spelllang=foo+bar", 'E474:')

  set enc& spell& spelllang&
  bwipe
endfunc

func Test_zz_basic()
  call LoadAffAndDic(g:test_data_aff1, g:test_data_dic1)
  call RunGoodBad("wrong OK puts. Test the end",
        \ "bad: inputs comment ok Ok. test d\xE9\xF4l end the",
        \["Comment", "deol", "d\xE9\xF4r", "input", "OK", "output", "outputs", "outtest", "put", "puts",
        \  "test", "testen", "testn", "the end", "uk", "wrong"],
        \[
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment", "outtest", "the end"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\xE9\xF4l", ["deol", "d\xE9\xF4r", "test"]],
        \   ["end", ["put", "uk", "test"]],
        \   ["the", ["put", "uk", "test"]],
        \ ]
        \ )

  call assert_equal("gebletegek", soundfold('goobledygoook'))
  call assert_equal("kepereneven", 'kóopërÿnôven'->soundfold())
  call assert_equal("everles gesvets etele", soundfold('oeverloos gezwets edale'))
endfunc

" Postponed prefixes
func Test_zz_prefixes()
  call LoadAffAndDic(g:test_data_aff2, g:test_data_dic1)
  call RunGoodBad("puts",
        \ "bad: inputs comment ok Ok end the. test d\xE9\xF4l",
        \ ["Comment", "deol", "d\xE9\xF4r", "OK", "put", "input", "output", "puts", "outputs", "test", "outtest", "testen", "testn", "the end", "uk", "wrong"],
        \ [
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["end", ["put", "uk", "deol"]],
        \   ["the", ["put", "uk", "test"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\xE9\xF4l", ["deol", "d\xE9\xF4r", "test"]],
        \ ])
endfunc

"Compound words
func Test_zz_compound()
  call LoadAffAndDic(g:test_data_aff3, g:test_data_dic3)
  call RunGoodBad("foo m\xEF foobar foofoobar barfoo barbarfoo",
        \ "bad: bar la foom\xEF barm\xEF m\xEFfoo m\xEFbar m\xEFm\xEF lala m\xEFla lam\xEF foola labar",
        \ ["foo", "m\xEF"],
        \ [
        \   ["bad", ["foo", "m\xEF"]],
        \   ["bar", ["barfoo", "foobar", "foo"]],
        \   ["la", ["m\xEF", "foo"]],
        \   ["foom\xEF", ["foo m\xEF", "foo", "foofoo"]],
        \   ["barm\xEF", ["barfoo", "m\xEF", "barbar"]],
        \   ["m\xEFfoo", ["m\xEF foo", "foo", "foofoo"]],
        \   ["m\xEFbar", ["foobar", "barbar", "m\xEF"]],
        \   ["m\xEFm\xEF", ["m\xEF m\xEF", "m\xEF"]],
        \   ["lala", []],
        \   ["m\xEFla", ["m\xEF", "m\xEF m\xEF"]],
        \   ["lam\xEF", ["m\xEF", "m\xEF m\xEF"]],
        \   ["foola", ["foo", "foobar", "foofoo"]],
        \   ["labar", ["barbar", "foobar"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff4, g:test_data_dic4)
  call RunGoodBad("word util bork prebork start end wordutil wordutils pro-ok bork borkbork borkborkbork borkborkborkbork borkborkborkborkbork tomato tomatotomato startend startword startwordword startwordend startwordwordend startwordwordwordend prebork preborkbork preborkborkbork nouword",
        \ "bad: wordutilize pro borkborkborkborkborkbork tomatotomatotomato endstart endend startstart wordend wordstart preborkprebork  preborkpreborkbork startwordwordwordwordend borkpreborkpreborkbork utilsbork  startnouword",
        \ ["bork", "prebork", "end", "pro-ok", "start", "tomato", "util", "utilize", "utils", "word", "nouword"],
        \ [
        \   ["bad", ["end", "bork", "word"]],
        \   ["wordutilize", ["word utilize", "wordutils", "wordutil"]],
        \   ["pro", ["bork", "word", "end"]],
        \   ["borkborkborkborkborkbork", ["bork borkborkborkborkbork", "borkbork borkborkborkbork", "borkborkbork borkborkbork"]],
        \   ["tomatotomatotomato", ["tomato tomatotomato", "tomatotomato tomato", "tomato tomato tomato"]],
        \   ["endstart", ["end start", "start"]],
        \   ["endend", ["end end", "end"]],
        \   ["startstart", ["start start"]],
        \   ["wordend", ["word end", "word", "wordword"]],
        \   ["wordstart", ["word start", "bork start"]],
        \   ["preborkprebork", ["prebork prebork", "preborkbork", "preborkborkbork"]],
        \   ["preborkpreborkbork", ["prebork preborkbork", "preborkborkbork", "preborkborkborkbork"]],
        \   ["startwordwordwordwordend", ["startwordwordwordword end", "startwordwordwordword", "start wordwordwordword end"]],
        \   ["borkpreborkpreborkbork", ["bork preborkpreborkbork", "bork prebork preborkbork", "bork preborkprebork bork"]],
        \   ["utilsbork", ["utilbork", "utils bork", "util bork"]],
        \   ["startnouword", ["start nouword", "startword", "startborkword"]],
        \ ])

endfunc

"Test affix flags with two characters
func Test_zz_affix()
  call LoadAffAndDic(g:test_data_aff5, g:test_data_dic5)
  call RunGoodBad("fooa1 fooa\xE9 bar prebar barbork prebarbork  startprebar start end startend  startmiddleend nouend",
        \ "bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart startprobar startnouend",
        \ ["bar", "barbork", "end", "fooa1", "fooa\xE9", "nouend", "prebar", "prebarbork", "start"],
        \ [
        \   ["bad", ["bar", "end", "fooa1"]],
        \   ["foo", ["fooa1", "fooa\xE9", "bar"]],
        \   ["fooa2", ["fooa1", "fooa\xE9", "bar"]],
        \   ["prabar", ["prebar", "bar", "bar bar"]],
        \   ["probarbirk", ["prebarbork"]],
        \   ["middle", []],
        \   ["startmiddle", ["startmiddleend", "startmiddlebar"]],
        \   ["middleend", []],
        \   ["endstart", ["end start", "start"]],
        \   ["startprobar", ["startprebar", "start prebar", "startbar"]],
        \   ["startnouend", ["start nouend", "startend"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff6, g:test_data_dic6)
  call RunGoodBad("meea1 meea\xE9 bar prebar barbork prebarbork  leadprebar lead end leadend  leadmiddleend",
        \  "bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead leadprobar",
        \ ["bar", "barbork", "end", "lead", "meea1", "meea\xE9", "prebar", "prebarbork"],
        \ [
        \   ["bad", ["bar", "end", "lead"]],
        \   ["mee", ["meea1", "meea\xE9", "bar"]],
        \   ["meea2", ["meea1", "meea\xE9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarbirk", ["prebarbork"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddleend", "leadmiddlebar"]],
        \   ["middleend", []],
        \   ["endlead", ["end lead", "lead", "end end"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff7, g:test_data_dic7)
  call RunGoodBad("meea1 meezero meea\xE9 bar prebar barmeat prebarmeat  leadprebar lead tail leadtail  leadmiddletail",
        \ "bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead leadprobar",
        \ ["bar", "barmeat", "lead", "meea1", "meea\xE9", "meezero", "prebar", "prebarmeat", "tail"],
        \ [
        \   ["bad", ["bar", "lead", "tail"]],
        \   ["mee", ["meea1", "meea\xE9", "bar"]],
        \   ["meea2", ["meea1", "meea\xE9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarmaat", ["prebarmeat"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddlebar"]],
        \   ["middletail", []],
        \   ["taillead", ["tail lead", "tail"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])
endfunc

func Test_zz_NOSLITSUGS()
  call LoadAffAndDic(g:test_data_aff8, g:test_data_dic8)
  call RunGoodBad("foo bar faabar", "bad: foobar barfoo",
        \ ["bar", "faabar", "foo"],
        \ [
        \   ["bad", ["bar", "foo"]],
        \   ["foobar", ["faabar", "foo bar", "bar"]],
        \   ["barfoo", ["bar foo", "bar", "foo"]],
        \ ])
endfunc

" Numbers
func Test_zz_Numbers()
  call LoadAffAndDic(g:test_data_aff9, g:test_data_dic9)
  call RunGoodBad("0b1011 0777 1234 0x01ff", "",
        \ ["bar", "foo"],
        \ [
        \ ])
endfunc

" Affix flags
func Test_zz_affix_flags()
  call LoadAffAndDic(g:test_data_aff10, g:test_data_dic10)
  call RunGoodBad("drink drinkable drinkables drinktable drinkabletable",
	\ "bad: drinks drinkstable drinkablestable",
        \ ["drink", "drinkable", "drinkables", "table"],
        \ [['bad', []],
	\ ['drinks', ['drink']],
	\ ['drinkstable', ['drinktable', 'drinkable', 'drink table']],
        \ ['drinkablestable', ['drinkabletable', 'drinkables table', 'drinkable table']],
	\ ])
endfunc

function FirstSpellWord()
  call feedkeys("/^start:\n", 'tx')
  normal ]smm
  let [str, a] = spellbadword()
  return str
endfunc

function SecondSpellWord()
  normal `m]s
  let [str, a] = spellbadword()
  return str
endfunc

"Test with SAL instead of SOFO items; test automatic reloading
func Test_zz_sal_and_addition()
  throw 'skipped: Nvim does not support enc=latin1'
  set enc=latin1
  set spellfile=
  call writefile(g:test_data_dic1, "Xtest.dic")
  call writefile(g:test_data_aff_sal, "Xtest.aff")
  mkspell! Xtest Xtest
  set spl=Xtest.latin1.spl spell
  call assert_equal('kbltykk', soundfold('goobledygoook'))
  call assert_equal('kprnfn', soundfold('kóopërÿnôven'))
  call assert_equal('*fls kswts tl', soundfold('oeverloos gezwets edale'))

  "also use an addition file
  call writefile(["/regions=usgbnz", "elequint/2", "elekwint/3"], "Xtest.latin1.add")
  mkspell! Xtest.latin1.add.spl Xtest.latin1.add

  bwipe!
  call setline(1, ["start: elequint test elekwint test elekwent asdf"])

  set spellfile=Xtest.latin1.add
  call assert_equal("elekwent", FirstSpellWord())

  set spl=Xtest_us.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())

  set spl=Xtest_gb.latin1.spl
  call assert_equal("elekwint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_nz.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_ca.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())

  bwipe!
  set spellfile=
  set spl&
endfunc

func Test_spellfile_value()
  set spellfile=Xdir/Xtest.latin1.add
  set spellfile=Xdir/Xtest.utf-8.add,Xtest_other.add
endfunc

func Test_region_error()
  messages clear
  call writefile(["/regions=usgbnz", "elequint/0"], "Xtest.latin1.add")
  mkspell! Xtest.latin1.add.spl Xtest.latin1.add
  call assert_match('Invalid region nr in Xtest.latin1.add line 2: 0', execute('messages'))
  call delete('Xtest.latin1.add')
  call delete('Xtest.latin1.add.spl')
endfunc

" Check using z= in new buffer (crash fixed by patch 7.4a.028).
func Test_zeq_crash()
  new
  set spell
  call feedkeys('iasdz=:\"', 'tx')

  bwipe!
endfunc

" Check that z= works even when 'nospell' is set.  This test uses one of the
" tests in Test_spellsuggest_option_number() just to verify that z= basically
" works and that "E756: Spell checking is not enabled" is not generated.
func Test_zeq_nospell()
  new
  set nospell spellsuggest=1,best
  call setline(1, 'A baord')
  try
    norm $1z=
    call assert_equal('A board', getline(1))
  catch
    call assert_report("Caught exception: " . v:exception)
  endtry
  set spell& spellsuggest&
  bwipe!
endfunc

" Check that "E756: Spell checking is not possible" is reported when z= is
" executed and 'spelllang' is empty.
func Test_zeq_no_spelllang()
  new
  set spelllang= spellsuggest=1,best
  call setline(1, 'A baord')
  call assert_fails('normal $1z=', 'E756:')
  set spelllang& spellsuggest&
  bwipe!
endfunc

" Check handling a word longer than MAXWLEN.
func Test_spell_long_word()
  set enc=utf-8
  new
  call setline(1, "d\xCC\xB4\xCC\xBD\xCD\x88\xCD\x94a\xCC\xB5\xCD\x84\xCD\x84\xCC\xA8\xCD\x9Cr\xCC\xB5\xCC\x8E\xCD\x85\xCD\x85k\xCC\xB6\xCC\x89\xCC\x9D \xCC\xB6\xCC\x83\xCC\x8F\xCC\xA4\xCD\x8Ef\xCC\xB7\xCC\x81\xCC\x80\xCC\xA9\xCC\xB0\xCC\xAC\xCC\xA2\xCD\x95\xCD\x87\xCD\x8D\xCC\x9E\xCD\x99\xCC\xAD\xCC\xAB\xCC\x97\xCC\xBBo\xCC\xB6\xCC\x84\xCC\x95\xCC\x8C\xCC\x8B\xCD\x9B\xCD\x9C\xCC\xAFr\xCC\xB7\xCC\x94\xCD\x83\xCD\x97\xCC\x8C\xCC\x82\xCD\x82\xCD\x80\xCD\x91\xCC\x80\xCC\xBE\xCC\x82\xCC\x8F\xCC\xA3\xCD\x85\xCC\xAE\xCD\x8D\xCD\x99\xCC\xBC\xCC\xAB\xCC\xA7\xCD\x88c\xCC\xB7\xCD\x83\xCC\x84\xCD\x92\xCC\x86\xCC\x83\xCC\x88\xCC\x92\xCC\x94\xCC\xBE\xCC\x9D\xCC\xAF\xCC\x98\xCC\x9D\xCC\xBB\xCD\x8E\xCC\xBB\xCC\xB3\xCC\xA3\xCD\x8E\xCD\x99\xCC\xA5\xCC\xAD\xCC\x99\xCC\xB9\xCC\xAE\xCC\xA5\xCC\x9E\xCD\x88\xCC\xAE\xCC\x9E\xCC\xA9\xCC\x97\xCC\xBC\xCC\x99\xCC\xA5\xCD\x87\xCC\x97\xCD\x8E\xCD\x94\xCC\x99\xCC\x9D\xCC\x96\xCD\x94\xCC\xAB\xCC\xA7\xCC\xA5\xCC\x98\xCC\xBB\xCC\xAF\xCC\xABe\xCC\xB7\xCC\x8E\xCC\x82\xCD\x86\xCD\x9B\xCC\x94\xCD\x83\xCC\x85\xCD\x8A\xCD\x8C\xCC\x8B\xCD\x92\xCD\x91\xCC\x8F\xCC\x81\xCD\x95\xCC\xA2\xCC\xB9\xCC\xB2\xCD\x9C\xCC\xB1\xCC\xA6\xCC\xB3\xCC\xAF\xCC\xAE\xCC\x9C\xCD\x99s\xCC\xB8\xCC\x8C\xCC\x8E\xCC\x87\xCD\x81\xCD\x82\xCC\x86\xCD\x8C\xCD\x8C\xCC\x8B\xCC\x84\xCC\x8C\xCD\x84\xCD\x9B\xCD\x86\xCC\x93\xCD\x90\xCC\x85\xCC\x94\xCD\x98\xCD\x84\xCD\x92\xCD\x8B\xCC\x90\xCC\x83\xCC\x8F\xCD\x84\xCD\x81\xCD\x9B\xCC\x90\xCD\x81\xCC\x8F\xCC\xBD\xCC\x88\xCC\xBF\xCC\x88\xCC\x84\xCC\x8E\xCD\x99\xCD\x94\xCC\x99\xCD\x99\xCC\xB0\xCC\xA8\xCC\xA3\xCC\xA8\xCC\x96\xCC\x99\xCC\xAE\xCC\xBC\xCC\x99\xCD\x9A\xCC\xB2\xCC\xB1\xCC\x9F\xCC\xBB\xCC\xA6\xCD\x85\xCC\xAA\xCD\x89\xCC\x9D\xCC\x99\xCD\x96\xCC\xB1\xCC\xB1\xCC\x99\xCC\xA6\xCC\xA5\xCD\x95\xCC\xB2\xCC\xA0\xCD\x99 within")
  set spell spelllang=en
  redraw
  redraw!
  bwipe!
  set nospell
endfunc

func Test_spellsuggest_too_deep()
  " This was incrementing "depth" over MAXWLEN.
  new
  norm s000G00ý000000000000
  sil norm ..vzG................vvzG0     v z=
  bwipe!
endfunc

func Test_spell_good_word_invalid()
  " This was adding a word with a 0x02 byte, which causes havoc.
  enew
  norm o0
  sil! norm rzzWs00/
  2
  sil! norm VzGprzzW
  sil! norm z=

  bwipe!
endfunc

func Test_spell_good_word_slash()
  " This caused E1280.
  new
  norm afoo /
  1
  norm zG

  bwipe!
endfunc

func LoadAffAndDic(aff_contents, dic_contents)
  throw 'skipped: Nvim does not support enc=latin1'
  set enc=latin1
  set spellfile=
  call writefile(a:aff_contents, "Xtest.aff")
  call writefile(a:dic_contents, "Xtest.dic")
  " Generate a .spl file from a .dic and .aff file.
  mkspell! Xtest Xtest
  " use that spell file
  set spl=Xtest.latin1.spl spell
endfunc

func ListWords()
  spelldump
  %yank
  quit
  return split(@", "\n")
endfunc

func TestGoodBadBase()
  exe '1;/^good:'
  normal 0f:]s
  let prevbad = ''
  let result = []
  while 1
    let [bad, a] = spellbadword()
    if bad == '' || bad == prevbad || bad == 'badend'
      break
    endif
    let prevbad = bad
    let lst = bad->spellsuggest(3)
    normal mm

    call add(result, [bad, lst])
    normal `m]s
  endwhile
  return result
endfunc

func RunGoodBad(good, bad, expected_words, expected_bad_words)
  bwipe!
  call setline(1, ["good: ", a:good,  a:bad, " badend "])
  let words = ListWords()
  call assert_equal(a:expected_words, words[1:-1])
  let bad_words = TestGoodBadBase()
  call assert_equal(a:expected_bad_words, bad_words)
  bwipe!
endfunc

func Test_spell_screendump()
  CheckScreendump

  let lines =<< trim END
       call test_override('alloc_lines', 1)
       call setline(1, [
             \ "This is some text without any spell errors.  Everything",
             \ "should just be black, nothing wrong here.",
             \ "",
             \ "This line has a sepll error. and missing caps.",
             \ "And and this is the the duplication.",
             \ "with missing caps here.",
             \ ])
       set spell spelllang=en_nz
  END
  call writefile(lines, 'XtestSpell', 'D')
  let buf = RunVimInTerminal('-S XtestSpell', {'rows': 8})
  call VerifyScreenDump(buf, 'Test_spell_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_spell_screendump_spellcap()
  CheckScreendump

  let lines =<< trim END
       call test_override('alloc_lines', 1)
       call setline(1, [
             \ "   This line has a sepll error. and missing caps and trailing spaces.   ",
             \ "another missing cap here.",
             \ "",
             \ "and here.",
             \ "    ",
             \ "and here."
             \ ])
       set spell spelllang=en
  END
  call writefile(lines, 'XtestSpellCap', 'D')
  let buf = RunVimInTerminal('-S XtestSpellCap', {'rows': 8})
  call VerifyScreenDump(buf, 'Test_spell_2', {})

  " After adding word missing Cap in next line is updated
  call term_sendkeys(buf, "3GANot\<Esc>")
  call VerifyScreenDump(buf, 'Test_spell_3', {})

  " Deleting a full stop removes missing Cap in next line
  call term_sendkeys(buf, "5Gdd\<C-L>k$x")
  call VerifyScreenDump(buf, 'Test_spell_4', {})

  " Undo also updates the next line (go to command line to remove message)
  call term_sendkeys(buf, "u:\<Esc>")
  call VerifyScreenDump(buf, 'Test_spell_5', {})

  " Folding an empty line does not remove Cap in next line
  call term_sendkeys(buf, "uzfk:\<Esc>")
  call VerifyScreenDump(buf, 'Test_spell_6', {})

  " Folding the end of a sentence does not remove Cap in next line
  " and editing a line does not remove Cap in current line
  call term_sendkeys(buf, "Jzfkk$x")
  call VerifyScreenDump(buf, 'Test_spell_7', {})

  " Cap is correctly applied in the first row of a window
  call term_sendkeys(buf, "\<C-E>\<C-L>")
  call VerifyScreenDump(buf, 'Test_spell_8', {})

  " Adding an empty line does not remove Cap in "mod_bot" area
  call term_sendkeys(buf, "zbO\<Esc>")
  call VerifyScreenDump(buf, 'Test_spell_9', {})

  " Multiple empty lines does not remove Cap in the line after
  call term_sendkeys(buf, "O\<Esc>\<C-L>")
  call VerifyScreenDump(buf, 'Test_spell_10', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_spell_compatible()
  CheckScreendump

  let lines =<< trim END
       call test_override('alloc_lines', 1)
       call setline(1, [
             \ "test "->repeat(20),
             \ "",
             \ "end",
             \ ])
       set spell cpo+=$
  END
  call writefile(lines, 'XtestSpellComp', 'D')
  let buf = RunVimInTerminal('-S XtestSpellComp', {'rows': 8})

  call term_sendkeys(buf, "51|C")
  call VerifyScreenDump(buf, 'Test_spell_compatible_1', {})

  call term_sendkeys(buf, "x")
  call VerifyScreenDump(buf, 'Test_spell_compatible_2', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

let g:test_data_aff1 = [
      \"SET ISO8859-1",
      \"TRY esianrtolcdugmphbyfvkwjkqxz-\xEB\xE9\xE8\xEA\xEF\xEE\xE4\xE0\xE2\xF6\xFC\xFB'ESIANRTOLCDUGMPHBYFVKWJKQXZ",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"SOFOFROM abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xBF",
      \"SOFOTO   ebctefghejklnnepkrstevvkesebctefghejklnnepkrstevvkeseeeeeeeceeeeeeeedneeeeeeeeeeepseeeeeeeeceeeeeeeedneeeeeeeeeeep?",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out .",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \ ]
let g:test_data_dic1 = [
      \"123456",
      \"test/NO",
      \"# comment",
      \"wrong",
      \"Comment",
      \"OK",
      \"uk",
      \"put/ISO",
      \"the end",
      \"deol",
      \"d\xE9\xF4r",
      \ ]
let g:test_data_aff2 = [
      \"SET ISO8859-1",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"PFXPOSTPONE",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out [a-z]",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \ ]
let g:test_data_aff3 = [
      \"SET ISO8859-1",
      \"",
      \"COMPOUNDMIN 3",
      \"COMPOUNDRULE m*",
      \"NEEDCOMPOUND x",
      \ ]
let g:test_data_dic3 = [
      \"1234",
      \"foo/m",
      \"bar/mx",
      \"m\xEF/m",
      \"la/mx",
      \ ]
let g:test_data_aff4 = [
      \"SET ISO8859-1",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"COMPOUNDRULE m+",
      \"COMPOUNDRULE sm*e",
      \"COMPOUNDRULE sm+",
      \"COMPOUNDMIN 3",
      \"COMPOUNDWORDMAX 3",
      \"COMPOUNDFORBIDFLAG t",
      \"",
      \"COMPOUNDSYLMAX 5",
      \"SYLLABLE a\xE1e\xE9i\xEDo\xF3\xF6\xF5u\xFA\xFC\xFBy/aa/au/ea/ee/ei/ie/oa/oe/oo/ou/uu/ui",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \"",
      \"NEEDAFFIX x",
      \"",
      \"PFXPOSTPONE",
      \"",
      \"MIDWORD '-",
      \"",
      \"SFX q N 1",
      \"SFX q   0    -ok .",
      \"",
      \"SFX a Y 2",
      \"SFX a 0 s .",
      \"SFX a 0 ize/t .",
      \"",
      \"PFX p N 1",
      \"PFX p 0 pre .",
      \"",
      \"PFX P N 1",
      \"PFX P 0 nou .",
      \ ]
let g:test_data_dic4 = [
      \"1234",
      \"word/mP",
      \"util/am",
      \"pro/xq",
      \"tomato/m",
      \"bork/mp",
      \"start/s",
      \"end/e",
      \ ]
let g:test_data_aff5 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG long",
      \"",
      \"NEEDAFFIX !!",
      \"",
      \"COMPOUNDRULE ssmm*ee",
      \"",
      \"NEEDCOMPOUND xx",
      \"COMPOUNDPERMITFLAG pp",
      \"",
      \"SFX 13 Y 1",
      \"SFX 13 0 bork .",
      \"",
      \"SFX a1 Y 1",
      \"SFX a1 0 a1 .",
      \"",
      \"SFX a\xE9 Y 1",
      \"SFX a\xE9 0 a\xE9 .",
      \"",
      \"PFX zz Y 1",
      \"PFX zz 0 pre/pp .",
      \"",
      \"PFX yy Y 1",
      \"PFX yy 0 nou .",
      \ ]
let g:test_data_dic5 = [
      \"1234",
      \"foo/a1a\xE9!!",
      \"bar/zz13ee",
      \"start/ss",
      \"end/eeyy",
      \"middle/mmxx",
      \ ]
let g:test_data_aff6 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG caplong",
      \"",
      \"NEEDAFFIX A!",
      \"",
      \"COMPOUNDRULE sMm*Ee",
      \"",
      \"NEEDCOMPOUND Xx",
      \"",
      \"COMPOUNDPERMITFLAG p",
      \"",
      \"SFX N3 Y 1",
      \"SFX N3 0 bork .",
      \"",
      \"SFX A1 Y 1",
      \"SFX A1 0 a1 .",
      \"",
      \"SFX A\xE9 Y 1",
      \"SFX A\xE9 0 a\xE9 .",
      \"",
      \"PFX Zz Y 1",
      \"PFX Zz 0 pre/p .",
      \ ]
let g:test_data_dic6 = [
      \"1234",
      \"mee/A1A\xE9A!",
      \"bar/ZzN3Ee",
      \"lead/s",
      \"end/Ee",
      \"middle/MmXx",
      \ ]
let g:test_data_aff7 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG num",
      \"",
      \"NEEDAFFIX 9999",
      \"",
      \"COMPOUNDRULE 2,77*123",
      \"",
      \"NEEDCOMPOUND 1",
      \"COMPOUNDPERMITFLAG 432",
      \"",
      \"SFX 61003 Y 1",
      \"SFX 61003 0 meat .",
      \"",
      \"SFX 0 Y 1",
      \"SFX 0 0 zero .",
      \"",
      \"SFX 391 Y 1",
      \"SFX 391 0 a1 .",
      \"",
      \"SFX 111 Y 1",
      \"SFX 111 0 a\xE9 .",
      \"",
      \"PFX 17 Y 1",
      \"PFX 17 0 pre/432 .",
      \ ]
let g:test_data_dic7 = [
      \"1234",
      \"mee/0,391,111,9999",
      \"bar/17,61003,123",
      \"lead/2",
      \"tail/123",
      \"middle/77,1",
      \ ]
let g:test_data_aff8 = [
      \"SET ISO8859-1",
      \"",
      \"NOSPLITSUGS",
      \ ]
let g:test_data_dic8 = [
      \"1234",
      \"foo",
      \"bar",
      \"faabar",
      \ ]
let g:test_data_aff9 = [
      \ ]
let g:test_data_dic9 = [
      \"1234",
      \"foo",
      \"bar",
      \ ]
let g:test_data_aff10 = [
      \"COMPOUNDRULE se",
      \"COMPOUNDPERMITFLAG p",
      \"",
      \"SFX A Y 1",
      \"SFX A 0 able/Mp .",
      \"",
      \"SFX M Y 1",
      \"SFX M 0 s .",
      \ ]
let g:test_data_dic10 = [
      \"1234",
      \"drink/As",
      \"table/e",
      \ ]
let g:test_data_aff_sal = [
      \"SET ISO8859-1",
      \"TRY esianrtolcdugmphbyfvkwjkqxz-\xEB\xE9\xE8\xEA\xEF\xEE\xE4\xE0\xE2\xF6\xFC\xFB'ESIANRTOLCDUGMPHBYFVKWJKQXZ",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out .",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \"",
      \"SAL AH(AEIOUY)-^         *H",
      \"SAL AR(AEIOUY)-^         *R",
      \"SAL A(HR)^               *",
      \"SAL A^                   *",
      \"SAL AH(AEIOUY)-          H",
      \"SAL AR(AEIOUY)-          R",
      \"SAL A(HR)                _",
      \"SAL \xC0^                   *",
      \"SAL \xC5^                   *",
      \"SAL BB-                  _",
      \"SAL B                    B",
      \"SAL CQ-                  _",
      \"SAL CIA                  X",
      \"SAL CH                   X",
      \"SAL C(EIY)-              S",
      \"SAL CK                   K",
      \"SAL COUGH^               KF",
      \"SAL CC<                  C",
      \"SAL C                    K",
      \"SAL DG(EIY)              K",
      \"SAL DD-                  _",
      \"SAL D                    T",
      \"SAL \xC9<                   E",
      \"SAL EH(AEIOUY)-^         *H",
      \"SAL ER(AEIOUY)-^         *R",
      \"SAL E(HR)^               *",
      \"SAL ENOUGH^$             *NF",
      \"SAL E^                   *",
      \"SAL EH(AEIOUY)-          H",
      \"SAL ER(AEIOUY)-          R",
      \"SAL E(HR)                _",
      \"SAL FF-                  _",
      \"SAL F                    F",
      \"SAL GN^                  N",
      \"SAL GN$                  N",
      \"SAL GNS$                 NS",
      \"SAL GNED$                N",
      \"SAL GH(AEIOUY)-          K",
      \"SAL GH                   _",
      \"SAL GG9                  K",
      \"SAL G                    K",
      \"SAL H                    H",
      \"SAL IH(AEIOUY)-^         *H",
      \"SAL IR(AEIOUY)-^         *R",
      \"SAL I(HR)^               *",
      \"SAL I^                   *",
      \"SAL ING6                 N",
      \"SAL IH(AEIOUY)-          H",
      \"SAL IR(AEIOUY)-          R",
      \"SAL I(HR)                _",
      \"SAL J                    K",
      \"SAL KN^                  N",
      \"SAL KK-                  _",
      \"SAL K                    K",
      \"SAL LAUGH^               LF",
      \"SAL LL-                  _",
      \"SAL L                    L",
      \"SAL MB$                  M",
      \"SAL MM                   M",
      \"SAL M                    M",
      \"SAL NN-                  _",
      \"SAL N                    N",
      \"SAL OH(AEIOUY)-^         *H",
      \"SAL OR(AEIOUY)-^         *R",
      \"SAL O(HR)^               *",
      \"SAL O^                   *",
      \"SAL OH(AEIOUY)-          H",
      \"SAL OR(AEIOUY)-          R",
      \"SAL O(HR)                _",
      \"SAL PH                   F",
      \"SAL PN^                  N",
      \"SAL PP-                  _",
      \"SAL P                    P",
      \"SAL Q                    K",
      \"SAL RH^                  R",
      \"SAL ROUGH^               RF",
      \"SAL RR-                  _",
      \"SAL R                    R",
      \"SAL SCH(EOU)-            SK",
      \"SAL SC(IEY)-             S",
      \"SAL SH                   X",
      \"SAL SI(AO)-              X",
      \"SAL SS-                  _",
      \"SAL S                    S",
      \"SAL TI(AO)-              X",
      \"SAL TH                   @",
      \"SAL TCH--                _",
      \"SAL TOUGH^               TF",
      \"SAL TT-                  _",
      \"SAL T                    T",
      \"SAL UH(AEIOUY)-^         *H",
      \"SAL UR(AEIOUY)-^         *R",
      \"SAL U(HR)^               *",
      \"SAL U^                   *",
      \"SAL UH(AEIOUY)-          H",
      \"SAL UR(AEIOUY)-          R",
      \"SAL U(HR)                _",
      \"SAL V^                   W",
      \"SAL V                    F",
      \"SAL WR^                  R",
      \"SAL WH^                  W",
      \"SAL W(AEIOU)-            W",
      \"SAL X^                   S",
      \"SAL X                    KS",
      \"SAL Y(AEIOU)-            Y",
      \"SAL ZZ-                  _",
      \"SAL Z                    S",
      \ ]

" vim: shiftwidth=2 sts=2 expandtab
