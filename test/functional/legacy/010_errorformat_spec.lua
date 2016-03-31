-- Test for 'errorformat'.  This will fail if the quickfix feature was disabled.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

local input_file = [==[
STARTTEST
:" Also test a BOM is ignored.
:so mbyte.vim
:7/start of errorfile/,/end of errorfile/w! Xerrorfile1
:7/start of errorfile/,/end of errorfile/-1w! Xerrorfile2
:/start of testfile/,/end of testfile/w! Xtestfile
:set efm+==%f=\\,\ line\ %l%*\\D%v%*[^\ ]\ %m
:set efm^=%AError\ in\ \"%f\"\ at\ line\ %l:,%Z%p^,%C%m
:cf Xerrorfile2
:clast
:copen
:let a=w:quickfix_title
:wincmd p
lgR<C-R>=a<C-M><Esc>
:cf Xerrorfile1
grA
:cn
gRLINE 6, COL 19<Esc>
:cn
gRNO COLUMN SPECIFIED<Esc>
:cn
gRAGAIN NO COLUMN<Esc>
:cn
gRCOL 1<Esc>
:cn
gRCOL 2<Esc>
:cn
gRCOL 10<Esc>
:cn
gRVCOL 10<Esc>
:cn
grI
:cn
gR. SPACE POINTER<Esc>
:cn
gR. DOT POINTER<Esc>
:cn
gR. DASH POINTER<Esc>
:cn
gR. TAB-SPACE POINTER<Esc>
:clast
:cprev
:cprev
:wincmd w
:let a=w:quickfix_title
:wincmd p
lgR<C-R>=a<C-M><Esc>
:w! test.out             " Write contents of this file
:qa!
ENDTEST

start of errorfile
"Xtestfile", line 4.12: 1506-045 (S) Undeclared identifier fd_set.
﻿"Xtestfile", line 6 col 19; this is an error
gcc -c -DHAVE_CONFIsing-prototypes -I/usr/X11R6/include  version.c
Xtestfile:9: parse error before `asd'
make: *** [vim] Error 1
in file "Xtestfile" linenr 10: there is an error

2 returned
"Xtestfile", line 11 col 1; this is an error
"Xtestfile", line 12 col 2; this is another error
"Xtestfile", line 14:10; this is an error in column 10
=Xtestfile=, line 15:10; this is another error, but in vcol 10 this time
"Xtestfile", linenr 16: yet another problem
Error in "Xtestfile" at line 17:
x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17
            ^
Error in "Xtestfile" at line 18:
x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18
.............^
Error in "Xtestfile" at line 19:
x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19
--------------^
Error in "Xtestfile" at line 20:
x should be a dot
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20
	       ^

Does anyone know what is the problem and how to correction it?
"Xtestfile", line 21 col 9: What is the title of the quickfix window?
"Xtestfile", line 22 col 9: What is the title of the quickfix window?
end of errorfile

start of testfile
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  2
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  3
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  4
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  5
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  6
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  7
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  8
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  9
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 10
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 11
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 12
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 13
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 14
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 15
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 16
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 17
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 18
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 19
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 20
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 21
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 22
end of testfile
]==]

describe('10', function()
  teardown(function()
    os.remove('Xerrorfile1')
    os.remove('Xerrorfile2')
    os.remove('Xtestfile')
  end)

  setup(clear)

  it('is working', function()
    -- First insert the input
    insert(input_file)
    -- Got to endtest tag to start the test
    execute('/ENDTEST')
    -- Also test a BOM is ignored.
    execute('7/start of errorfile/,/end of errorfile/w! Xerrorfile1')
    execute('7/start of errorfile/,/end of errorfile/-1w! Xerrorfile2')
    execute('7/start of testfile/,/end of testfile/w! Xtestfile')
    execute([[set efm+==%f=\\,\ line\ %l%*\\D%v%*[^\ ]\ %m]])
    execute([[set efm^=%AError\ in\ \"%f\"\ at\ line\ %l:,%Z%p^,%C%m]])
    execute('cf! Xerrorfile2')
    execute('clast')
    execute('copen')
    execute('let a=w:quickfix_title')
    execute('wincmd p')
    feed('lgR<C-R>=a<C-M><esc>')
    execute('cf Xerrorfile1')
    feed('grA<cr>')
    execute('cn')
    feed('gRLINE 6, COL 19<esc>')
    execute('cn')
    feed('gRNO COLUMN SPECIFIED<esc>')
    execute('cn')
    feed('gRAGAIN NO COLUMN<esc>')
    execute('cn')
    feed('gRCOL 1<esc>')
    execute('cn')
    feed('gRCOL 2<esc>')
    execute('cn')
    feed('gRCOL 10<esc>')
    execute('cn')
    feed('gRVCOL 10<esc>')
    execute('cn')
    feed('grI<cr>')
    execute('cn')
    feed('gR. SPACE POINTER<esc>')
    execute('cn')
    feed('gR. DOT POINTER<esc>')
    execute('cn')
    feed('gR. DASH POINTER<esc>')
    execute('cn')
    feed('gR. TAB-SPACE POINTER<esc>')
    execute('clast')
    execute('cprev')
    execute('cprev')
    execute('wincmd w')
    execute('let a=w:quickfix_title')
    execute('wincmd p')
    feed('lgR<C-R>=a<C-M><esc>')
    
    -- assert buffer contents
    expect([=[
start of testfile
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  2
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  3
	xxxxxxxxxxAxxxxxxxxxxxxxxxxxxx    line  4
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  5
	xxxxxxxxxxxxxxxxxLINE 6, COL 19   line  6
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  7
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line  8
	NO COLUMN SPECIFIEDxxxxxxxxxxx    line  9
	AGAIN NO COLUMNxxxxxxxxxxxxxxx    line 10
COL 1	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 11
	COL 2xxxxxxxxxxxxxxxxxxxxxxxxx    line 12
	xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 13
	xxxxxxxxCOL 10xxxxxxxxxxxxxxxx    line 14
	xVCOL 10xxxxxxxxxxxxxxxxxxxxxx    line 15
	Ixxxxxxxxxxxxxxxxxxxxxxxxxxxxx    line 16
	xxxx. SPACE POINTERxxxxxxxxxxx    line 17
	xxxxx. DOT POINTERxxxxxxxxxxxx    line 18
	xxxxxx. DASH POINTERxxxxxxxxxx    line 19
	xxxxxxx. TAB-SPACE POINTERxxxx    line 20
	xxxxxxxx:cf Xerrorfile1xxxxxxx    line 21
	xxxxxxxx:cf! Xerrorfile2xxxxxx    line 22
end of testfile]=])
  end)
end)
