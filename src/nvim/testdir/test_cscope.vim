" Test for cscope commands.

if !has('cscope') || !executable('cscope') || !has('quickfix')
  finish
endif

func Test_cscopequickfix()
  set cscopequickfix=s-,g-,d+,c-,t+,e-,f0,i-,a-
  call assert_equal('s-,g-,d+,c-,t+,e-,f0,i-,a-', &cscopequickfix)

  call assert_fails('set cscopequickfix=x-', 'E474:')
  call assert_fails('set cscopequickfix=s', 'E474:')
  call assert_fails('set cscopequickfix=s7', 'E474:')
  call assert_fails('set cscopequickfix=s-a', 'E474:')
endfunc

func CscopeSetupOrClean(setup)
    if a:setup
      noa sp ../memfile_test.c
      saveas! Xmemfile_test.c
      call system('cscope -bk -fXcscope.out Xmemfile_test.c')
      cscope add Xcscope.out
      set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-,a-
    else
      cscope kill -1
      for file in ['Xcscope.out', 'Xmemfile_test.c']
          call delete(file)
      endfor
    endif
endfunc

func Test_cscope1()
    call CscopeSetupOrClean(1)
    " Test 0: E568: duplicate cscope database not added
    try
      set nocscopeverbose
      cscope add Xcscope.out
      set cscopeverbose
    catch
      call assert_true(0)
    endtry
    call assert_fails('cscope add Xcscope.out', 'E568')
    " Test 1: Find this C-Symbol
    let a=execute('cscope find s main')
    " Test 1.1 test where it moves the cursor
    call assert_equal('main(void)', getline('.'))
    " Test 1.2 test the output of the :cs command
    call assert_match('\n(1 of 1): <<main>> main(void )', a)

    " Test 2: Find this definition
    cscope find g test_mf_hash
    call assert_equal(['', '/*', ' * Test mf_hash_*() functions.', ' */', '    static void', 'test_mf_hash(void)', '{'], getline(line('.')-5, line('.')+1))

    " Test 3: Find functions called by this function
    let a=execute('cscope find d test_mf_hash')
    call assert_match('\n(1 of 42): <<mf_hash_init>> mf_hash_init(&ht);', a)
    call assert_equal('    mf_hash_init(&ht);', getline('.'))

    " Test 4: Find functions calling this function
    let a=execute('cscope find c test_mf_hash')
    call assert_match('\n(1 of 1): <<main>> test_mf_hash();', a)
    call assert_equal('    test_mf_hash();', getline('.'))

    " Test 5: Find this text string
    let a=execute('cscope find t Bram')
    call assert_match('(1 of 1): <<<unknown>>>  \* VIM - Vi IMproved^Iby Bram Moolenaar', a)
    call assert_equal(' * VIM - Vi IMproved	by Bram Moolenaar', getline('.'))

    " Test 6: Find this egrep pattern
    " test all matches returned by cscope
    let a=execute('cscope find e ^\#includ.')
    call assert_match('\n(1 of 3): <<<unknown>>> #include <assert.h>', a)
    call assert_equal('#include <assert.h>', getline('.'))
    cnext
    call assert_equal('#include "main.c"', getline('.'))
    cnext
    call assert_equal('#include "memfile.c"', getline('.'))
    call assert_fails('cnext', 'E553')

    " Test 7: Find this file
    enew
    let a=execute('cscope find f Xmemfile_test.c')
    call assert_match('\n"Xmemfile_test.c" 143L, 3137C', a)
    call assert_equal('Xmemfile_test.c', @%)

    " Test 8: Find files #including this file
    enew
    let a=execute('cscope find i assert.h')
    call assert_equal(['','"Xmemfile_test.c" 143L, 3137C','(1 of 1): <<global>> #include <assert.h>'], split(a, '\n', 1))
    call assert_equal('#include <assert.h>', getline('.'))

    " Test 9: Find places where this symbol is assigned a value
    " this needs a cscope >= 15.8
    " unfortunatly, Travis has cscope version 15.7
    let cscope_version=systemlist('cscope --version')[0]
    let cs_version=str2float(matchstr(cscope_version, '\d\+\(\.\d\+\)\?'))
    if cs_version >= 15.8
      let a=execute('cscope find a item')
      call assert_equal(['', '(1 of 4): <<test_mf_hash>> item = (mf_hashitem_T *)lalloc_clear(sizeof(mf_hashtab_T), FALSE);'], split(a, '\n', 1))
      call assert_equal('	item = (mf_hashitem_T *)lalloc_clear(sizeof(mf_hashtab_T), FALSE);', getline('.'))
      cnext
      call assert_equal('	item = mf_hash_find(&ht, key);', getline('.'))
      cnext
      call assert_equal('	    item = mf_hash_find(&ht, key);', getline('.'))
      cnext
      call assert_equal('	item = mf_hash_find(&ht, key);', getline('.'))
    endif

    " Test 10: leading whitespace is not removed for cscope find text
    let a=execute('cscope find t     test_mf_hash')
    call assert_equal(['', '(1 of 1): <<<unknown>>>     test_mf_hash();'], split(a, '\n', 1))
    call assert_equal('    test_mf_hash();', getline('.'))

    " Test 11: cscope help
    let a=execute('cscope help')
    call assert_match('^cscope commands:\n', a)
    call assert_match('\nadd  :', a)
    call assert_match('\nfind :', a)
    call assert_match('\nhelp : Show this message', a)
    call assert_match('\nkill : Kill a connection', a)
    call assert_match('\nreset: Reinit all connections', a)
    call assert_match('\nshow : Show connections', a)

    " Test 12: reset connections
    let a=execute('cscope reset')
    call assert_match('\nAdded cscope database.*Xcscope.out (#0)', a)
    call assert_match('\nAll cscope databases reset', a)

    " Test 13: cscope show
    let a=execute('cscope show')
    call assert_match('\n 0 \d\+.*Xcscope.out\s*<none>', a)

    " Test 14: 'csprg' option
    call assert_equal('cscope', &csprg)

    " CleanUp
    call CscopeSetupOrClean(0)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
