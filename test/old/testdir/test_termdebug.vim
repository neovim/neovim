" Test for the termdebug plugin

source shared.vim
source check.vim

CheckUnix
" CheckFeature terminal
CheckExecutable gdb
CheckExecutable gcc

let g:GDB = exepath('gdb')
if g:GDB->empty()
  throw 'Skipped: gdb is not found in $PATH'
endif

let g:GCC = exepath('gcc')
if g:GCC->empty()
  throw 'Skipped: gcc is not found in $PATH'
endif

function s:generate_files(bin_name)
  let src_name = a:bin_name .. '.c'
  let lines =<< trim END
    #include <stdio.h>
    #include <stdlib.h>

    int isprime(int n)
    {
      if (n <= 1)
        return 0;

      for (int i = 2; i <= n / 2; i++)
        if (n % i == 0)
          return 0;

      return 1;
    }

    int main(int argc, char *argv[])
    {
      int n = 7;

      printf("%d is %s prime\n", n, isprime(n) ? "a" : "not a");

      return 0;
    }
  END
  call writefile(lines, src_name)
  call system($'{g:GCC} -g -o {a:bin_name} {src_name}')
endfunction

function s:cleanup_files(bin_name)
  call delete(a:bin_name)
  call delete(a:bin_name .. '.c')
endfunction

packadd termdebug

func Test_termdebug_basic()
  let bin_name = 'XTD_basic'
  let src_name = bin_name .. '.c'
  call s:generate_files(bin_name)

  edit XTD_basic.c
  Termdebug ./XTD_basic
  call WaitForAssert({-> assert_equal(3, winnr('$'))})
  let gdb_buf = winbufnr(1)
  wincmd b
  Break 9
  call Nterm_wait(gdb_buf)
  redraw!
  call assert_equal([
        \ {'lnum': 9, 'id': 1014, 'name': 'debugBreakpoint1.0',
        \  'priority': 110, 'group': 'TermDebug'}],
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs)
  Run
  call Nterm_wait(gdb_buf, 400)
  redraw!
  call WaitForAssert({-> assert_equal([
        \ {'lnum': 9, 'id': 12, 'name': 'debugPC', 'priority': 110,
        \  'group': 'TermDebug'},
        \ {'lnum': 9, 'id': 1014, 'name': 'debugBreakpoint1.0',
        \  'priority': 110, 'group': 'TermDebug'}],
        "\ sign_getplaced('', #{group: 'TermDebug'})[0].signs)})
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs->reverse())})
  Finish
  call Nterm_wait(gdb_buf)
  redraw!
  call WaitForAssert({-> assert_equal([
        \ {'lnum': 9, 'id': 1014, 'name': 'debugBreakpoint1.0',
        \  'priority': 110, 'group': 'TermDebug'},
        \ {'lnum': 20, 'id': 12, 'name': 'debugPC',
        \  'priority': 110, 'group': 'TermDebug'}],
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs)})
  Continue
  call Nterm_wait(gdb_buf)

  let i = 2
  while i <= 258
    Break
    call Nterm_wait(gdb_buf)
    if i == 2
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint2.0')[0].text, '02')})
    endif
    if i == 10
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint10.0')[0].text, '0A')})
    endif
    if i == 168
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint168.0')[0].text, 'A8')})
    endif
    if i == 255
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint255.0')[0].text, 'FF')})
    endif
    if i == 256
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint256.0')[0].text, 'F+')})
    endif
    if i == 258
      call WaitForAssert({-> assert_equal(sign_getdefined('debugBreakpoint258.0')[0].text, 'F+')})
    endif
    let i += 1
  endwhile

  let cn = 0
  " 60 is approx spaceBuffer * 3
  if winwidth(0) <= 78 + 60
    Var
    call assert_equal(winnr(), winnr('$'))
    call assert_equal(winlayout(), ['col', [['leaf', 1002], ['leaf', 1001], ['leaf', 1000], ['leaf', 1003 + cn]]])
    let cn += 1
    bw!
    Asm
    call assert_equal(winnr(), winnr('$'))
    call assert_equal(winlayout(), ['col', [['leaf', 1002], ['leaf', 1001], ['leaf', 1000], ['leaf', 1003 + cn]]])
    let cn += 1
    bw!
  endif
  set columns=160
  call Nterm_wait(gdb_buf)
  let winw = winwidth(0)
  Var
  if winwidth(0) < winw
    call assert_equal(winnr(), winnr('$') - 1)
    call assert_equal(winlayout(), ['col', [['leaf', 1002], ['leaf', 1001], ['row', [['leaf', 1003 + cn], ['leaf', 1000]]]]])
    let cn += 1
    bw!
  endif
  let winw = winwidth(0)
  Asm
  if winwidth(0) < winw
    call assert_equal(winnr(), winnr('$') - 1)
    call assert_equal(winlayout(), ['col', [['leaf', 1002], ['leaf', 1001], ['row', [['leaf', 1003 + cn], ['leaf', 1000]]]]])
    let cn += 1
    bw!
  endif
  set columns&
  call Nterm_wait(gdb_buf)

  wincmd t
  quit!
  redraw!
  call WaitForAssert({-> assert_equal(1, winnr('$'))})
  call assert_equal([], sign_getplaced('', #{group: 'TermDebug'})[0].signs)

  call s:cleanup_files(bin_name)
  %bw!
endfunc

func Test_termdebug_tbreak()
  let g:test_is_flaky = 1
  let bin_name = 'XTD_tbreak'
  let src_name = bin_name .. '.c'

  eval s:generate_files(bin_name)

  execute 'edit ' .. src_name
  execute 'Termdebug ./' .. bin_name

  call WaitForAssert({-> assert_equal(3, winnr('$'))})
  let gdb_buf = winbufnr(1)
  wincmd b

  let bp_line = 22        " 'return' statement in main
  let temp_bp_line = 10   " 'if' statement in 'for' loop body
  execute "Tbreak " .. temp_bp_line
  execute "Break " .. bp_line

  call Nterm_wait(gdb_buf)
  redraw!
  " both temporary and normal breakpoint signs were displayed...
  call assert_equal([
        \ {'lnum': temp_bp_line, 'id': 1014, 'name': 'debugBreakpoint1.0',
        \  'priority': 110, 'group': 'TermDebug'},
        \ {'lnum': bp_line, 'id': 2014, 'name': 'debugBreakpoint2.0',
        \  'priority': 110, 'group': 'TermDebug'}],
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs)

  Run
  call Nterm_wait(gdb_buf, 400)
  redraw!
  " debugPC sign is on the line where the temp. bp was set;
  " temp. bp sign was removed after hit;
  " normal bp sign is still present
  call WaitForAssert({-> assert_equal([
        \ {'lnum': temp_bp_line, 'id': 12, 'name': 'debugPC', 'priority': 110,
        \  'group': 'TermDebug'},
        \ {'lnum': bp_line, 'id': 2014, 'name': 'debugBreakpoint2.0',
        \  'priority': 110, 'group': 'TermDebug'}],
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs)})

  Continue
  call Nterm_wait(gdb_buf)
  redraw!
  " debugPC is on the normal breakpoint,
  " temp. bp on line 10 was only hit once
  call WaitForAssert({-> assert_equal([
        \ {'lnum': bp_line, 'id': 12, 'name': 'debugPC', 'priority': 110,
        \  'group': 'TermDebug'},
        \ {'lnum': bp_line, 'id': 2014, 'name': 'debugBreakpoint2.0',
        \  'priority': 110, 'group': 'TermDebug'}],
        "\ sign_getplaced('', #{group: 'TermDebug'})[0].signs)})
        \ sign_getplaced('', #{group: 'TermDebug'})[0].signs->reverse())})

  wincmd t
  quit!
  redraw!
  call WaitForAssert({-> assert_equal(1, winnr('$'))})
  call assert_equal([], sign_getplaced('', #{group: 'TermDebug'})[0].signs)

  eval s:cleanup_files(bin_name)
  %bw!
endfunc

func Test_termdebug_mapping()
  %bw!
  call assert_equal(maparg('K', 'n', 0, 1)->empty(), 1)
  call assert_equal(maparg('-', 'n', 0, 1)->empty(), 1)
  call assert_equal(maparg('+', 'n', 0, 1)->empty(), 1)
  Termdebug
  call WaitForAssert({-> assert_equal(3, winnr('$'))})
  wincmd b
  call assert_equal(maparg('K', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('-', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('+', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('K', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('-', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('+', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('K', 'n', 0, 1).rhs, ':Evaluate<CR>')
  wincmd t
  quit!
  redraw!
  call WaitForAssert({-> assert_equal(1, winnr('$'))})
  call assert_equal(maparg('K', 'n', 0, 1)->empty(), 1)
  call assert_equal(maparg('-', 'n', 0, 1)->empty(), 1)
  call assert_equal(maparg('+', 'n', 0, 1)->empty(), 1)

  %bw!
  nnoremap K :echom "K"<cr>
  nnoremap - :echom "-"<cr>
  nnoremap + :echom "+"<cr>
  Termdebug
  call WaitForAssert({-> assert_equal(3, winnr('$'))})
  wincmd b
  call assert_equal(maparg('K', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('-', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('+', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('K', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('-', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('+', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('K', 'n', 0, 1).rhs, ':Evaluate<CR>')
  wincmd t
  quit!
  redraw!
  call WaitForAssert({-> assert_equal(1, winnr('$'))})
  call assert_equal(maparg('K', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('-', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('+', 'n', 0, 1)->empty(), 0)
  call assert_equal(maparg('K', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('-', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('+', 'n', 0, 1).buffer, 0)
  call assert_equal(maparg('K', 'n', 0, 1).rhs, ':echom "K"<cr>')

  %bw!
  nnoremap <buffer> K :echom "bK"<cr>
  nnoremap <buffer> - :echom "b-"<cr>
  nnoremap <buffer> + :echom "b+"<cr>
  Termdebug
  call WaitForAssert({-> assert_equal(3, winnr('$'))})
  wincmd b
  call assert_equal(maparg('K', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('-', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('+', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('K', 'n', 0, 1).rhs, ':echom "bK"<cr>')
  wincmd t
  quit!
  redraw!
  call WaitForAssert({-> assert_equal(1, winnr('$'))})
  call assert_equal(maparg('K', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('-', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('+', 'n', 0, 1).buffer, 1)
  call assert_equal(maparg('K', 'n', 0, 1).rhs, ':echom "bK"<cr>')

  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
