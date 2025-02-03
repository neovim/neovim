" Test the :compiler command

source check.vim
source shared.vim

func Test_compiler()
  CheckExecutable perl
  CheckFeature quickfix

  let save_LC_ALL = $LC_ALL
  let $LC_ALL= "C"

  let save_shellslash = &shellslash
  " Nvim doesn't allow setting value of a hidden option to non-default value
  if exists('+shellslash')
    " %:S does not work properly with 'shellslash' set
    set noshellslash
  endif

  e Xfoo.pl
  " Play nice with other tests.
  defer setqflist([])
  compiler perl
  call assert_equal('perl', b:current_compiler)
  call assert_fails('let g:current_compiler', 'E121:')

  let verbose_efm = execute('verbose set efm')
  call assert_match('Last set from .*[/\\]compiler[/\\]perl.vim ', verbose_efm)

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', 'my $foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  call assert_fails('clist', 'E42:')

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', '$foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  let a=execute('clist')
  call assert_match('\n \d\+ Xfoo.pl:3: Global symbol "$foo" '
  \ .               'requires explicit package name', a)


  let &shellslash = save_shellslash
  call delete('Xfoo.pl')
  bw!
  let $LC_ALL = save_LC_ALL
endfunc

func GetCompilerNames()
  return glob('$VIMRUNTIME/compiler/*.vim', 0, 1)
        \ ->map({i, v -> substitute(v, '.*[\\/]\([a-zA-Z0-9_\-]*\).vim', '\1', '')})
        \ ->sort()
endfunc

func Test_compiler_without_arg()
  let runtime = substitute($VIMRUNTIME, '\\', '/', 'g')
  let a = split(execute('compiler'))
  let exp = GetCompilerNames()
  call assert_match(runtime .. '/compiler/' .. exp[0] .. '.vim$',  a[0])
  call assert_match(runtime .. '/compiler/' .. exp[1] .. '.vim$',  a[1])
  call assert_match(runtime .. '/compiler/' .. exp[-1] .. '.vim$', a[-1])
endfunc

func Test_compiler_completion()
  let clist = GetCompilerNames()->join(' ')
  call feedkeys(":compiler \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"compiler ' .. clist .. '$', @:)

  call feedkeys(":compiler p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"compiler pandoc pbx perl\( p[a-z_]\+\)\+ pyunit', @:)

  call feedkeys(":compiler! p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"compiler! pandoc pbx perl\( p[a-z_]\+\)\+ pyunit', @:)
endfunc

func Test_compiler_error()
  let g:current_compiler = 'abc'
  call assert_fails('compiler doesnotexist', 'E666:')
  call assert_equal('abc', g:current_compiler)
  call assert_fails('compiler! doesnotexist', 'E666:')
  unlet! g:current_compiler
endfunc

func s:SpotBugsParseFilterMakePrg(dirname, makeprg)
  let result = {}
  let result.sourcepath = ''
  let result.classfiles = []

  " Get the argument after the rightmost occurrence of "-sourcepath".
  let offset = strridx(a:makeprg, '-sourcepath')
  if offset < 0
    return result
  endif
  let offset += 1 + strlen('-sourcepath')
  let result.sourcepath = matchstr(strpart(a:makeprg, offset), '.\{-}\ze[ \t]')
  let offset += 1 + strlen(result.sourcepath)

  " Get the class file arguments, dropping the pathname prefix.
  let offset = stridx(a:makeprg, a:dirname, offset)
  if offset < 0
    return result
  endif

  while offset > -1
    let candidate = matchstr(a:makeprg, '[^ \t]\{-}\.class\>', offset)
    if empty(candidate)
      break
    endif
    call add(result.classfiles, candidate)
    let offset = stridx(a:makeprg, a:dirname, (1 + strlen(candidate) + offset))
  endwhile

  call sort(result.classfiles)
  return result
endfunc

func Test_compiler_spotbugs_makeprg()
  let save_shellslash = &shellslash
  set shellslash

  call assert_true(mkdir('Xspotbugs/src/tests/α/β/γ/δ', 'pR'))
  call assert_true(mkdir('Xspotbugs/tests/α/β/γ/δ', 'pR'))

  let lines =<< trim END
      // EOL comment. /*
      abstract class
      𐌂1 /* Multiline comment. */ {
          /* Multiline comment. */ // EOL comment. /*
          static final String COMMENT_A_LIKE = "/*";
          { new Object() {/* Try globbing. */}; }
          static { interface 𐌉𐌉1 {} }
          static class 𐌂11 { interface 𐌉𐌉2 {} }
      }
      /* Multiline comment. */ // EOL comment. /*
      final class 𐌂2 {
          public static void main(String... aa) {
              record 𐌓() {}
              enum 𐌄 {}
          }
      } // class
  END

  " THE EXPECTED RESULTS.
  let results = {}
  let results['Xspotbugs/src/tests/𐌂1.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/𐌂1.java',
          \ ':p:h:S')},
      \ 'classfiles': sort([
          \ 'Xspotbugs/tests/𐌂1$1.class',
          \ 'Xspotbugs/tests/𐌂1$1𐌉𐌉1.class',
          \ 'Xspotbugs/tests/𐌂1$𐌂11$𐌉𐌉2.class',
          \ 'Xspotbugs/tests/𐌂1$𐌂11.class',
          \ 'Xspotbugs/tests/𐌂1.class',
          \ 'Xspotbugs/tests/𐌂2$1𐌄.class',
          \ 'Xspotbugs/tests/𐌂2$1𐌓.class',
          \ 'Xspotbugs/tests/𐌂2.class']),
      \ }
  " No class file for an empty source file even with "-Xpkginfo:always".
  let results['Xspotbugs/src/tests/package-info.java'] = {
      \ 'Sourcepath': {-> ''},
      \ 'classfiles': [],
      \ }
  let results['Xspotbugs/src/tests/α/𐌂1.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/𐌂1.java',
          \ ':p:h:h:S')},
      \ 'classfiles': sort([
          \ 'Xspotbugs/tests/α/𐌂1$1.class',
          \ 'Xspotbugs/tests/α/𐌂1$1𐌉𐌉1.class',
          \ 'Xspotbugs/tests/α/𐌂1$𐌂11$𐌉𐌉2.class',
          \ 'Xspotbugs/tests/α/𐌂1$𐌂11.class',
          \ 'Xspotbugs/tests/α/𐌂1.class',
          \ 'Xspotbugs/tests/α/𐌂2$1𐌄.class',
          \ 'Xspotbugs/tests/α/𐌂2$1𐌓.class',
          \ 'Xspotbugs/tests/α/𐌂2.class']),
      \ }
  let results['Xspotbugs/src/tests/α/package-info.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/package-info.java',
          \ ':p:h:S')},
      \ 'classfiles': ['Xspotbugs/tests/α/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/𐌂1.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/𐌂1.java',
          \ ':p:h:h:h:S')},
      \ 'classfiles': sort([
          \ 'Xspotbugs/tests/α/β/𐌂1$1.class',
          \ 'Xspotbugs/tests/α/β/𐌂1$1𐌉𐌉1.class',
          \ 'Xspotbugs/tests/α/β/𐌂1$𐌂11$𐌉𐌉2.class',
          \ 'Xspotbugs/tests/α/β/𐌂1$𐌂11.class',
          \ 'Xspotbugs/tests/α/β/𐌂1.class',
          \ 'Xspotbugs/tests/α/β/𐌂2$1𐌄.class',
          \ 'Xspotbugs/tests/α/β/𐌂2$1𐌓.class',
          \ 'Xspotbugs/tests/α/β/𐌂2.class']),
      \ }
  let results['Xspotbugs/src/tests/α/β/package-info.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/package-info.java',
          \ ':p:h:S')},
      \ 'classfiles': ['Xspotbugs/tests/α/β/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/𐌂1.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/γ/𐌂1.java',
          \ ':p:h:h:h:h:S')},
      \ 'classfiles': sort([
          \ 'Xspotbugs/tests/α/β/γ/𐌂1$1.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂1$1𐌉𐌉1.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂1$𐌂11$𐌉𐌉2.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂1$𐌂11.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂1.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂2$1𐌄.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂2$1𐌓.class',
          \ 'Xspotbugs/tests/α/β/γ/𐌂2.class']),
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/package-info.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/γ/package-info.java',
          \ ':p:h:S')},
      \ 'classfiles': ['Xspotbugs/tests/α/β/γ/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/δ/𐌂1.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/γ/δ/𐌂1.java',
          \ ':p:h:h:h:h:h:S')},
      \ 'classfiles': sort([
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂1$1.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂1$1𐌉𐌉1.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂1$𐌂11$𐌉𐌉2.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂1$𐌂11.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂1.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂2$1𐌄.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂2$1𐌓.class',
          \ 'Xspotbugs/tests/α/β/γ/δ/𐌂2.class']),
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/δ/package-info.java'] = {
      \ 'Sourcepath': {-> fnamemodify('Xspotbugs/src/tests/α/β/γ/δ/package-info.java',
          \ ':p:h:S')},
      \ 'classfiles': ['Xspotbugs/tests/α/β/γ/δ/package-info.class'],
      \ }

  " MAKE CLASS FILES DISCOVERABLE!
  let g:spotbugs_properties = {
      \ 'sourceDirPath': ['src/tests'],
      \ 'classDirPath': ['tests'],
  \ }

  call assert_true(has_key(s:SpotBugsParseFilterMakePrg('Xspotbugs', ''), 'sourcepath'))
  call assert_true(has_key(s:SpotBugsParseFilterMakePrg('Xspotbugs', ''), 'classfiles'))

  " Write 45 mock-up class files for 10 source files.
  for [class_dir, src_dir, package] in [
        \ ['Xspotbugs/tests/', 'Xspotbugs/src/tests/', ''],
        \ ['Xspotbugs/tests/α/', 'Xspotbugs/src/tests/α/', 'package α;'],
        \ ['Xspotbugs/tests/α/β/', 'Xspotbugs/src/tests/α/β/', 'package α.β;'],
        \ ['Xspotbugs/tests/α/β/γ/', 'Xspotbugs/src/tests/α/β/γ/', 'package α.β.γ;'],
        \ ['Xspotbugs/tests/α/β/γ/δ/', 'Xspotbugs/src/tests/α/β/γ/δ/', 'package α.β.γ.δ;']]
    for class_file in ['𐌂1$1.class', '𐌂1$1𐌉𐌉1.class', '𐌂1$𐌂11$𐌉𐌉2.class',
          \ '𐌂1$𐌂11.class', '𐌂1.class', '𐌂2$1𐌄.class', '𐌂2$1𐌓.class', '𐌂2.class']
      call writefile(0zcafe.babe.0000.0041, class_dir .. class_file)
    endfor
    call writefile(0zcafe.babe.0000.0041, class_dir .. 'package-info.class')

    " Write Java source files.
    let type_file = src_dir .. '𐌂1.java'
    call writefile(insert(copy(lines), package), type_file)
    let package_file = src_dir .. 'package-info.java'
    call writefile([package], src_dir .. 'package-info.java')

    " Note that using "off" for the first _outer_ iteration is preferable
    " because only then "hlexists()" may be 0 (see "compiler/spotbugs.vim").
    for s in ['off', 'on']
      execute 'syntax ' .. s

      execute 'edit ' .. type_file
      compiler spotbugs
      let result = s:SpotBugsParseFilterMakePrg('Xspotbugs', &l:makeprg)
      call assert_equal(results[type_file].Sourcepath(), result.sourcepath)
      call assert_equal(results[type_file].classfiles, result.classfiles)
      bwipeout

      execute 'edit ' .. package_file
      compiler spotbugs
      let result = s:SpotBugsParseFilterMakePrg('Xspotbugs', &l:makeprg)
      call assert_equal(results[package_file].Sourcepath(), result.sourcepath)
      call assert_equal(results[package_file].classfiles, result.classfiles)
      bwipeout
    endfor
  endfor

  let &shellslash = save_shellslash
endfunc

func s:SpotBugsBeforeFileTypeTryPluginAndClearCache(state)
  " Ponder over "extend(spotbugs#DefaultProperties(), g:spotbugs_properties)"
  " in "ftplugin/java.vim".
  let g:spotbugs#state = a:state
  runtime autoload/spotbugs.vim
endfunc

func Test_compiler_spotbugs_properties()
  let save_shellslash = &shellslash
  set shellslash
  setlocal makeprg=
  filetype plugin on

  call assert_true(mkdir('Xspotbugs/src', 'pR'))
  call assert_true(mkdir('Xspotbugs/tests', 'pR'))
  let type_file = 'Xspotbugs/src/𐌄.java'
  let test_file = 'Xspotbugs/tests/𐌄$.java'
  call writefile(['enum 𐌄{}'], type_file)
  call writefile(['class 𐌄${}'], test_file)

  " TEST INTEGRATION WITH A BOGUS COMPILER PLUGIN.
  if !filereadable($VIMRUNTIME .. '/compiler/foo.vim') && !executable('foo')
    let g:spotbugs_properties = {'compiler': 'foo'}
    " XXX: In case this "if" block is no longer first.
    call s:SpotBugsBeforeFileTypeTryPluginAndClearCache({
        \ 'compiler': g:spotbugs_properties.compiler,
    \ })
    execute 'edit ' .. type_file
    call assert_equal('java', &l:filetype)
    " This variable will indefinitely keep the compiler name.
    call assert_equal('foo', g:spotbugs#state.compiler)
    " The "compiler" entry should be gone after FileType and default entries
    " should only appear for a supported compiler.
    call assert_false(has_key(g:spotbugs_properties, 'compiler'))
    call assert_true(empty(g:spotbugs_properties))
    " Query default implementations.
    call assert_true(exists('*spotbugs#DefaultProperties'))
    call assert_true(exists('*spotbugs#DefaultPreCompilerAction'))
    call assert_true(exists('*spotbugs#DefaultPreCompilerTestAction'))
    call assert_true(empty(spotbugs#DefaultProperties()))
    " Get a ":message".
    redir => out
    call spotbugs#DefaultPreCompilerAction()
    redir END
    call assert_equal('Not supported: "foo"', out[stridx(out, 'Not') :])
    " Get a ":message".
    redir => out
    call spotbugs#DefaultPreCompilerTestAction()
    redir END
    call assert_equal('Not supported: "foo"', out[stridx(out, 'Not') :])
    " No ":autocmd"s without one of "PreCompiler*Action", "PostCompilerAction".
    call assert_false(exists('#java_spotbugs'))
    bwipeout
  endif

  let s:spotbugs_results = {
      \ 'preActionDone': 0,
      \ 'preTestActionDone': 0,
      \ 'preTestLocalActionDone': 0,
      \ 'postActionDone': 0,
      \ 'preCommandArguments': '',
      \ 'preTestCommandArguments': '',
      \ 'postCommandArguments': '',
  \ }
  defer execute('unlet s:spotbugs_results')

  func! g:SpotBugsPreAction() abort
    let s:spotbugs_results.preActionDone = 1
    " XXX: Notify the spotbugs compiler about success or failure.
    cc
  endfunc
  defer execute('delfunction g:SpotBugsPreAction')

  func! g:SpotBugsPreTestAction() abort
    let s:spotbugs_results.preTestActionDone = 1
    " XXX: Let see compilation fail.
    throw 'Oops'
  endfunc
  defer execute('delfunction g:SpotBugsPreTestAction')

  func! g:SpotBugsPreTestLocalAction() abort
    let s:spotbugs_results.preTestLocalActionDone = 1
    " XXX: Notify the spotbugs compiler about success or failure.
    cc
  endfunc
  defer execute('delfunction g:SpotBugsPreTestLocalAction')

  func! g:SpotBugsPostAction() abort
    let s:spotbugs_results.postActionDone = 1
  endfunc
  defer execute('delfunction g:SpotBugsPostAction')

  func! g:SpotBugsPreCommand(arguments) abort
    let s:spotbugs_results.preActionDone = 1
    let s:spotbugs_results.preCommandArguments = a:arguments
    " XXX: Notify the spotbugs compiler about success or failure.
    cc
  endfunc
  defer execute('delfunction g:SpotBugsPreCommand')

  func! g:SpotBugsPreTestCommand(arguments) abort
    let s:spotbugs_results.preTestActionDone = 1
    let s:spotbugs_results.preTestCommandArguments = a:arguments
    " XXX: Notify the spotbugs compiler about success or failure.
    cc
  endfunc
  defer execute('delfunction g:SpotBugsPreTestCommand')

  func! g:SpotBugsPostCommand(arguments) abort
    let s:spotbugs_results.postActionDone = 1
    let s:spotbugs_results.postCommandArguments = a:arguments
  endfunc
  defer execute('delfunction g:SpotBugsPostCommand')

  func! g:SpotBugsPostCompilerActionExecutor(action) abort
    try
      " XXX: Notify the spotbugs compiler about success or failure.
      cc
    catch /\<E42:/
      execute a:action
    endtry
  endfunc
  defer execute('delfunction g:SpotBugsPostCompilerActionExecutor')

  " TEST INTEGRATION WITH A SUPPORTED COMPILER PLUGIN.
  if filereadable($VIMRUNTIME .. '/compiler/maven.vim')
    let save_PATH = $PATH
    if !executable('mvn')
      if has('win32')
        let $PATH = 'Xspotbugs;' .. $PATH
        " This is what ":help executable()" suggests.
        call writefile([], 'Xspotbugs/mvn.cmd')
      else
        let $PATH = 'Xspotbugs:' .. $PATH
        call writefile([], 'Xspotbugs/mvn')
        call setfperm('Xspotbugs/mvn', 'rwx------')
      endif
    endif

    let g:spotbugs_properties = {
        \ 'compiler': 'maven',
        \ 'PreCompilerAction': function('g:SpotBugsPreAction'),
        \ 'PreCompilerTestAction': function('g:SpotBugsPreTestAction'),
        \ 'PostCompilerAction': function('g:SpotBugsPostAction'),
    \ }
    " XXX: In case this is a runner-up ":edit".
    call s:SpotBugsBeforeFileTypeTryPluginAndClearCache({
        \ 'compiler': g:spotbugs_properties.compiler,
    \ })
    execute 'edit ' .. type_file
    call assert_equal('java', &l:filetype)
    call assert_equal('maven', g:spotbugs#state.compiler)
    call assert_false(has_key(g:spotbugs_properties, 'compiler'))
    call assert_false(empty(g:spotbugs_properties))
    " Query default implementations.
    call assert_true(exists('*spotbugs#DefaultProperties'))
    call assert_equal(sort([
            \ 'PreCompilerAction',
            \ 'PreCompilerTestAction',
            \ 'PostCompilerAction',
            \ 'sourceDirPath',
            \ 'classDirPath',
            \ 'testSourceDirPath',
            \ 'testClassDirPath',
        \ ]),
        \ sort(keys(spotbugs#DefaultProperties())))
    " Some ":autocmd"s with one of "PreCompiler*Action", "PostCompilerAction".
    call assert_true(exists('#java_spotbugs'))
    call assert_true(exists('#java_spotbugs#Syntax'))
    call assert_true(exists('#java_spotbugs#User'))
    call assert_equal(2, exists(':SpotBugsDefineBufferAutocmd'))
    " SpotBugsDefineBufferAutocmd SigUSR1 User SigUSR1 User SigUSR1 User
    " call assert_true(exists('#java_spotbugs#SigUSR1'))
    SpotBugsDefineBufferAutocmd Signal User Signal User Signal User
    call assert_true(exists('#java_spotbugs#Signal'))
    call assert_true(exists('#java_spotbugs#Syntax'))
    call assert_true(exists('#java_spotbugs#User'))
    call assert_equal(2, exists(':SpotBugsRemoveBufferAutocmd'))
    " SpotBugsRemoveBufferAutocmd SigUSR1 User SigUSR1 User UserGettingBored
    " call assert_false(exists('#java_spotbugs#SigUSR1'))
    SpotBugsRemoveBufferAutocmd Signal User Signal User UserGettingBored
    call assert_false(exists('#java_spotbugs#Signal'))
    call assert_true(exists('#java_spotbugs#Syntax'))
    call assert_true(exists('#java_spotbugs#User'))

    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.postActionDone = 0

    doautocmd java_spotbugs Syntax
    call assert_false(exists('#java_spotbugs#Syntax'))

    " No match: "type_file !~# 'src/main/java'".
    call assert_false(s:spotbugs_results.preActionDone)
    " No match: "type_file !~# 'src/test/java'".
    call assert_false(s:spotbugs_results.preTestActionDone)
    " No pre-match, no post-action.
    call assert_false(s:spotbugs_results.postActionDone)
    " Without a match, confirm that ":compiler spotbugs" has NOT run.
    call assert_true(empty(&l:makeprg))

    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.postActionDone = 0
    " Update path entries.  (Note that we cannot use just "src" because there
    " is another "src" directory nearer the filesystem root directory, i.e.
    " "vim/vim/src/testdir/Xspotbugs/src", and "s:DispatchAction()" (see
    " "ftplugin/java.vim") will match "vim/vim/src/testdir/Xspotbugs/tests"
    " against "src".)
    let g:spotbugs_properties.sourceDirPath = ['Xspotbugs/src']
    let g:spotbugs_properties.classDirPath = ['Xspotbugs/src']
    let g:spotbugs_properties.testSourceDirPath = ['tests']
    let g:spotbugs_properties.testClassDirPath = ['tests']

    doautocmd java_spotbugs User
    " No match: "type_file !~# 'src/main/java'" (with old "*DirPath" values
    " cached).
    call assert_false(s:spotbugs_results.preActionDone)
    " No match: "type_file !~# 'src/test/java'" (with old "*DirPath" values
    " cached).
    call assert_false(s:spotbugs_results.preTestActionDone)
    " No pre-match, no post-action.
    call assert_false(s:spotbugs_results.postActionDone)
    " Without a match, confirm that ":compiler spotbugs" has NOT run.
    call assert_true(empty(&l:makeprg))

    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.postActionDone = 0
    " XXX: Re-build ":autocmd"s from scratch with new values applied.
    doautocmd FileType

    call assert_true(exists('b:spotbugs_syntax_once'))
    doautocmd java_spotbugs User
    " A match: "type_file =~# 'Xspotbugs/src'" (with new "*DirPath" values
    " cached).
    call assert_true(s:spotbugs_results.preActionDone)
    " No match: "type_file !~# 'tests'" (with new "*DirPath" values cached).
    call assert_false(s:spotbugs_results.preTestActionDone)
    " For a pre-match, a post-action.
    call assert_true(s:spotbugs_results.postActionDone)

    " With a match, confirm that ":compiler spotbugs" has run.
    if has('win32')
      call assert_match('^spotbugs\.bat\s', &l:makeprg)
    else
      call assert_match('^spotbugs\s', &l:makeprg)
    endif

    bwipeout
    setlocal makeprg=
    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.preTestLocalActionDone = 0
    let s:spotbugs_results.postActionDone = 0

    execute 'edit ' .. test_file
    " Prepare a buffer-local, incomplete variant of properties, relying on
    " "ftplugin/java.vim" to take care of merging in unique entries, if any,
    " from "g:spotbugs_properties".
    let b:spotbugs_properties = {
        \ 'PreCompilerTestAction': function('g:SpotBugsPreTestLocalAction'),
    \ }
    call assert_equal('java', &l:filetype)
    call assert_true(exists('#java_spotbugs'))
    call assert_true(exists('#java_spotbugs#Syntax'))
    call assert_true(exists('#java_spotbugs#User'))
    call assert_fails('doautocmd java_spotbugs Syntax', 'Oops')
    call assert_false(exists('#java_spotbugs#Syntax'))
    " No match: "test_file !~# 'Xspotbugs/src'".
    call assert_false(s:spotbugs_results.preActionDone)
    " A match: "test_file =~# 'tests'".
    call assert_true(s:spotbugs_results.preTestActionDone)
    call assert_false(s:spotbugs_results.preTestLocalActionDone)
    " No action after pre-failure (the thrown "Oops" doesn't qualify for ":cc").
    call assert_false(s:spotbugs_results.postActionDone)
    " No ":compiler spotbugs" will be run after pre-failure.
    call assert_true(empty(&l:makeprg))

    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.preTestLocalActionDone = 0
    let s:spotbugs_results.postActionDone = 0
    " XXX: Re-build ":autocmd"s from scratch with buffer-local values applied.
    doautocmd FileType

    call assert_true(exists('b:spotbugs_syntax_once'))
    doautocmd java_spotbugs User
    " No match: "test_file !~# 'Xspotbugs/src'".
    call assert_false(s:spotbugs_results.preActionDone)
    " A match: "test_file =~# 'tests'".
    call assert_true(s:spotbugs_results.preTestLocalActionDone)
    call assert_false(s:spotbugs_results.preTestActionDone)
    " For a pre-match, a post-action.
    call assert_true(s:spotbugs_results.postActionDone)

    " With a match, confirm that ":compiler spotbugs" has run.
    if has('win32')
      call assert_match('^spotbugs\.bat\s', &l:makeprg)
    else
      call assert_match('^spotbugs\s', &l:makeprg)
    endif

    setlocal makeprg=
    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionDone = 0
    let s:spotbugs_results.preTestLocalActionDone = 0
    let s:spotbugs_results.postActionDone = 0
    let s:spotbugs_results.preCommandArguments = ''
    let s:spotbugs_results.preTestCommandArguments = ''
    let s:spotbugs_results.postCommandArguments = ''
    " XXX: Compose the assigned "*Command"s with the default Maven "*Action"s.
    let b:spotbugs_properties = {
        \ 'compiler': 'maven',
        \ 'DefaultPreCompilerTestCommand': function('g:SpotBugsPreTestCommand'),
        \ 'DefaultPreCompilerCommand': function('g:SpotBugsPreCommand'),
        \ 'DefaultPostCompilerCommand': function('g:SpotBugsPostCommand'),
        \ 'PostCompilerActionExecutor': function('g:SpotBugsPostCompilerActionExecutor'),
        \ 'augroupForPostCompilerAction': 'java_spotbugs_test',
        \ 'sourceDirPath': ['Xspotbugs/src'],
        \ 'classDirPath': ['Xspotbugs/src'],
        \ 'testSourceDirPath': ['tests'],
        \ 'testClassDirPath': ['tests'],
    \ }
    unlet g:spotbugs_properties
    " XXX: Re-build ":autocmd"s from scratch with buffer-local values applied.
    call s:SpotBugsBeforeFileTypeTryPluginAndClearCache({
        \ 'compiler': b:spotbugs_properties.compiler,
        \ 'commands': {
            \ 'DefaultPreCompilerTestCommand':
                \ b:spotbugs_properties.DefaultPreCompilerTestCommand,
            \ 'DefaultPreCompilerCommand':
                \ b:spotbugs_properties.DefaultPreCompilerCommand,
            \ 'DefaultPostCompilerCommand':
                \ b:spotbugs_properties.DefaultPostCompilerCommand,
        \ },
    \ })
    doautocmd FileType

    call assert_equal('maven', g:spotbugs#state.compiler)
    call assert_equal(sort([
            \ 'DefaultPreCompilerTestCommand',
            \ 'DefaultPreCompilerCommand',
            \ 'DefaultPostCompilerCommand',
        \ ]),
        \ sort(keys(g:spotbugs#state.commands)))
    call assert_true(exists('b:spotbugs_syntax_once'))
    doautocmd java_spotbugs User
    " No match: "test_file !~# 'Xspotbugs/src'".
    call assert_false(s:spotbugs_results.preActionDone)
    call assert_true(empty(s:spotbugs_results.preCommandArguments))
    " A match: "test_file =~# 'tests'".
    call assert_true(s:spotbugs_results.preTestActionDone)
    call assert_equal('test-compile', s:spotbugs_results.preTestCommandArguments)
    " For a pre-match, a post-action.
    call assert_true(s:spotbugs_results.postActionDone)
    call assert_equal('%:S', s:spotbugs_results.postCommandArguments)

    " With a match, confirm that ":compiler spotbugs" has run.
    if has('win32')
      call assert_match('^spotbugs\.bat\s', &l:makeprg)
    else
      call assert_match('^spotbugs\s', &l:makeprg)
    endif

    setlocal makeprg=
    let s:spotbugs_results.preActionDone = 0
    let s:spotbugs_results.preTestActionOtherDone = 0
    let s:spotbugs_results.preTestLocalActionDone = 0
    let s:spotbugs_results.postActionDone = 0
    let s:spotbugs_results.preCommandArguments = ''
    let s:spotbugs_results.preTestCommandArguments = ''
    let s:spotbugs_results.postCommandArguments = ''

    " When "PostCompilerActionExecutor", "Pre*Action" and/or "Pre*TestAction",
    " and "Post*Action" are available, "#java_spotbugs_post" must be defined.
    call assert_true(exists('#java_spotbugs_post'))
    call assert_true(exists('#java_spotbugs_post#User'))
    call assert_false(exists('#java_spotbugs_post#ShellCmdPost'))
    call assert_false(exists('#java_spotbugs_test#ShellCmdPost'))

    " Re-link a Funcref on the fly.
    func! g:SpotBugsPreTestCommand(arguments) abort
      let s:spotbugs_results.preTestActionOtherDone = 1
      let s:spotbugs_results.preTestCommandArguments = a:arguments
      " Define a once-only ":autocmd" for "#java_spotbugs_test#ShellCmdPost".
      doautocmd java_spotbugs_post User
      " XXX: Do NOT use ":cc" to notify the spotbugs compiler about success or
      " failure, and assume the transfer of control to a ShellCmdPost command.
    endfunc

    doautocmd java_spotbugs User
    " No match: "test_file !~# 'Xspotbugs/src'".
    call assert_false(s:spotbugs_results.preActionDone)
    call assert_true(empty(s:spotbugs_results.preCommandArguments))
    " A match: "test_file =~# 'tests'".
    call assert_true(s:spotbugs_results.preTestActionOtherDone)
    call assert_equal('test-compile', s:spotbugs_results.preTestCommandArguments)
    " For a pre-match, no post-action (without ":cc") UNLESS a ShellCmdPost
    " event is consumed whose command will invoke "PostCompilerActionExecutor"
    " and the latter will accept a post-compiler action argument.
    call assert_false(s:spotbugs_results.postActionDone)
    call assert_true(exists('#java_spotbugs_test#ShellCmdPost'))
    doautocmd ShellCmdPost
    call assert_false(exists('#java_spotbugs_test#ShellCmdPost'))
    call assert_true(s:spotbugs_results.postActionDone)
    call assert_equal('%:S', s:spotbugs_results.postCommandArguments)

    " With a match, confirm that ":compiler spotbugs" has run.
    if has('win32')
      call assert_match('^spotbugs\.bat\s', &l:makeprg)
    else
      call assert_match('^spotbugs\s', &l:makeprg)
    endif

    bwipeout
    setlocal makeprg=
    let $PATH = save_PATH
  endif

  filetype plugin off
  setlocal makeprg=
  let &shellslash = save_shellslash
endfunc

" vim: shiftwidth=2 sts=2 expandtab
