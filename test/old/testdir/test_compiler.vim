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
      \ 'sourcepath': '%:p:h:S',
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
      \ 'sourcepath': '',
      \ 'classfiles': [],
      \ }
  let results['Xspotbugs/src/tests/α/𐌂1.java'] = {
      \ 'sourcepath': '%:p:h:h:S',
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
      \ 'sourcepath': '%:p:h:S',
      \ 'classfiles': ['Xspotbugs/tests/α/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/𐌂1.java'] = {
      \ 'sourcepath': '%:p:h:h:h:S',
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
      \ 'sourcepath': '%:p:h:S',
      \ 'classfiles': ['Xspotbugs/tests/α/β/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/𐌂1.java'] = {
      \ 'sourcepath': '%:p:h:h:h:h:S',
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
      \ 'sourcepath': '%:p:h:S',
      \ 'classfiles': ['Xspotbugs/tests/α/β/γ/package-info.class'],
      \ }
  let results['Xspotbugs/src/tests/α/β/γ/δ/𐌂1.java'] = {
      \ 'sourcepath': '%:p:h:h:h:h:h:S',
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
      \ 'sourcepath': '%:p:h:S',
      \ 'classfiles': ['Xspotbugs/tests/α/β/γ/δ/package-info.class'],
      \ }

  " MAKE CLASS FILES DISCOVERABLE!
  let g:spotbugs_properties = {
    \ 'sourceDirPath': 'src/tests',
    \ 'classDirPath': 'tests',
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

    for s in ['on', 'off']
      execute 'syntax ' .. s

      execute 'edit ' .. type_file
      compiler spotbugs
      let result = s:SpotBugsParseFilterMakePrg('Xspotbugs', &l:makeprg)
      call assert_equal(results[type_file].sourcepath, result.sourcepath)
      call assert_equal(results[type_file].classfiles, result.classfiles)
      bwipeout

      execute 'edit ' .. package_file
      compiler spotbugs
      let result = s:SpotBugsParseFilterMakePrg('Xspotbugs', &l:makeprg)
      call assert_equal(results[package_file].sourcepath, result.sourcepath)
      call assert_equal(results[package_file].classfiles, result.classfiles)
      bwipeout
    endfor
  endfor

  let &shellslash = save_shellslash
endfunc

" vim: shiftwidth=2 sts=2 expandtab
