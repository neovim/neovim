" Test for commands that operate on the spellfile.

source shared.vim
source check.vim

CheckFeature spell
CheckFeature syntax

func Test_spell_normal()
  new
  call append(0, ['1 good', '2 goood', '3 goood'])
  set spell spellfile=./Xspellfile.add spelllang=en
  let oldlang=v:lang
  lang C

  " Test for zg
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  norm! zg
  1
  let a=execute('unsilent :norm! ]s')
  call assert_equal('1 good', getline('.'))
  call assert_equal('search hit BOTTOM, continuing at TOP', a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])

  " zg should fail in operator-pending mode
  call assert_beeps('norm! czg')

  " zg fails in visual mode when not able to get the visual text
  call assert_beeps('norm! ggVjzg')
  norm! V

  " zg fails for a non-identifier word
  call append(line('$'), '###')
  call assert_fails('norm! Gzg', 'E349:')
  $d

  " Test for zw
  2
  norm! $zw
  1
  norm! ]s
  call assert_equal('2 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  call assert_equal('goood/!', cnt[1])

  " Test for :spellrare
  spellrare rare
  let cnt=readfile('./Xspellfile.add')
  call assert_equal(['#oood', 'goood/!', 'rare/?'], cnt)

  " Make sure :spellundo works for rare words.
  spellundo rare
  let cnt=readfile('./Xspellfile.add')
  call assert_equal(['#oood', 'goood/!', '#are/?'], cnt)

  " Test for zg in visual mode
  let a=execute('unsilent :norm! V$zg')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  1
  norm! ]s
  call assert_equal('3 goood', getline('.'))
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood', cnt[3])
  " Remove "2 good" from spellfile
  2
  let a=execute('unsilent norm! V$zw')
  call assert_equal("Word '2 goood' added to ./Xspellfile.add", a[1:])
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[4])

  " Test for zG
  let a=execute('unsilent norm! V$zG')
  call assert_match("Word '2 goood' added to .*", a)
  let fname=matchstr(a, 'to\s\+\zs\f\+$')
  let cnt=readfile(fname)
  call assert_equal('2 goood', cnt[0])

  " Test for zW
  let a=execute('unsilent norm! V$zW')
  call assert_match("Word '2 goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('2 goood/!', cnt[1])

  " Test for zuW
  let a=execute('unsilent norm! V$zuW')
  call assert_match("Word '2 goood' removed from .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])

  " Test for zuG
  let a=execute('unsilent norm! $zG')
  call assert_match("Word 'goood' added to .*", a)
  let cnt=readfile(fname)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('goood', cnt[2])
  let a=execute('unsilent norm! $zuG')
  let cnt=readfile(fname)
  call assert_match("Word 'goood' removed from .*", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])
  " word not found in wordlist
  let a=execute('unsilent norm! V$zuG')
  let cnt=readfile(fname)
  call assert_match("", a)
  call assert_equal('# goood', cnt[0])
  call assert_equal('# goood/!', cnt[1])
  call assert_equal('#oood', cnt[2])

  " Test for zug
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $zg')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('goood', cnt[0])
  let a=execute('unsilent norm! $zug')
  call assert_match("Word 'goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! V$zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('#oood', cnt[0])

  " Test for zuw
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! Vzw')
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('2 goood/!', cnt[0])
  let a=execute('unsilent norm! Vzuw')
  call assert_match("Word '2 goood' removed from \./Xspellfile.add", a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])
  " word not in wordlist
  let a=execute('unsilent norm! $zug')
  call assert_match('', a)
  let cnt=readfile('./Xspellfile.add')
  call assert_equal('# goood/!', cnt[0])

  " add second entry to spellfile setting
  set spellfile=./Xspellfile.add,./Xspellfile2.add
  call delete('./Xspellfile.add')
  2
  let a=execute('unsilent norm! $2zg')
  let cnt=readfile('./Xspellfile2.add')
  call assert_match("Word 'goood' added to ./Xspellfile2.add", a)
  call assert_equal('goood', cnt[0])

  " Test for :spellgood!
  let temp = execute(':spe!0/0')
  call assert_match('Invalid region', temp)
  let spellfile = matchstr(temp, 'Invalid region nr in \zs.*\ze line \d: 0')
  call assert_equal(['# goood', '# goood/!', '#oood', '0/0'], readfile(spellfile))

  " Test for :spellrare!
  :spellrare! raare
  call assert_equal(['# goood', '# goood/!', '#oood', '0/0', 'raare/?'], readfile(spellfile))
  call delete(spellfile)

  " clean up
  exe "lang" oldlang
  call delete("./Xspellfile.add")
  call delete("./Xspellfile2.add")
  call delete("./Xspellfile.add.spl")
  call delete("./Xspellfile2.add.spl")

  " zux -> no-op
  2
  norm! $zux
  call assert_equal([], glob('Xspellfile.add',0,1))
  call assert_equal([], glob('Xspellfile2.add',0,1))

  set spellfile= spell& spelllang&
  bw!
endfunc

" Spell file content test. Write 'content' to the spell file prefixed by the
" spell file header and then enable spell checking. If 'emsg' is not empty,
" then check for error.
func Spellfile_Test(content, emsg)
  let splfile = './Xtest/spell/Xtest.utf-8.spl'
  " Add the spell file header and version (VIMspell2)
  let v = 0z56494D7370656C6C32 + a:content
  call writefile(v, splfile, 'b')

  " 'encoding' is set before each test to clear the previously loaded suggest
  " file from memory.
  set encoding=utf-8

  set runtimepath=./Xtest
  set spelllang=Xtest
  if a:emsg != ''
    call assert_fails('set spell', a:emsg)
  else
    " FIXME: With some invalid spellfile contents, there are no error
    " messages. So don't know how to check for the test result.
    set spell
  endif
  set nospell spelllang& rtp&
endfunc

" Test for spell file format errors.
" The spell file format is described in spellfile.c
func Test_spellfile_format_error()
  let save_rtp = &rtp
  call mkdir('Xtest/spell', 'pR')
  let splfile = './Xtest/spell/Xtest.utf-8.spl'

  " empty spell file
  call writefile([], splfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  call assert_fails('set spell', 'E757:')
  set nospell spelllang&

  " invalid file ID
  call writefile(0z56494D, splfile, 'b')
  set runtimepath=./Xtest
  set spelllang=Xtest
  call assert_fails('set spell', 'E757:')
  set nospell spelllang&

  " missing version number
  call writefile(0z56494D7370656C6C, splfile, 'b')
  set runtimepath=./Xtest
  set spelllang=Xtest
  call assert_fails('set spell', 'E771:')
  set nospell spelllang&

  " invalid version number
  call writefile(0z56494D7370656C6C7A, splfile, 'b')
  set runtimepath=./Xtest
  set spelllang=Xtest
  call assert_fails('set spell', 'E772:')
  set nospell spelllang&

  " no sections
  call Spellfile_Test(0z, 'E758:')

  " missing section length
  call Spellfile_Test(0z00, 'E758:')

  " unsupported required section
  call Spellfile_Test(0z7A0100000004, 'E770:')

  " unsupported not-required section
  call Spellfile_Test(0z7A0000000004, 'E758:')

  " SN_REGION: invalid number of region names
  call Spellfile_Test(0z0000000000FF, 'E759:')

  " SN_CHARFLAGS: missing <charflagslen> length
  call Spellfile_Test(0z010000000004, 'E758:')

  " SN_CHARFLAGS: invalid <charflagslen> length
  call Spellfile_Test(0z0100000000010201, '')

  " SN_CHARFLAGS: charflagslen == 0 and folcharslen != 0
  call Spellfile_Test(0z01000000000400000101, 'E759:')

  " SN_CHARFLAGS: missing <folcharslen> length
  call Spellfile_Test(0z01000000000100, 'E758:')

  " SN_PREFCOND: invalid prefcondcnt
  call Spellfile_Test(0z03000000000100, 'E759:')

  " SN_PREFCOND: invalid condlen
  call Spellfile_Test(0z0300000000020001, 'E759:')

  " SN_REP: invalid repcount
  call Spellfile_Test(0z04000000000100, 'E758:')

  " SN_REP: missing rep
  call Spellfile_Test(0z0400000000020004, 'E758:')

  " SN_REP: zero repfromlen
  call Spellfile_Test(0z040000000003000100, 'E759:')

  " SN_REP: invalid reptolen
  call Spellfile_Test(0z0400000000050001014101, '')

  " SN_REP: zero reptolen
  call Spellfile_Test(0z0400000000050001014100, 'E759:')

  " SN_SAL: missing salcount
  call Spellfile_Test(0z05000000000102, 'E758:')

  " SN_SAL: missing salfromlen
  call Spellfile_Test(0z050000000003080001, 'E758:')

  " SN_SAL: missing saltolen
  call Spellfile_Test(0z0500000000050400010161, 'E758:')

  " SN_WORDS: non-NUL terminated word
  call Spellfile_Test(0z0D000000000376696D, 'E758:')

  " SN_WORDS: very long word
  let v = eval('0z0D000000012C' .. repeat('41', 300))
  call Spellfile_Test(v, 'E759:')

  " SN_SOFO: missing sofofromlen
  call Spellfile_Test(0z06000000000100, 'E758:')

  " SN_SOFO: missing sofotolen
  call Spellfile_Test(0z06000000000400016100, 'E758:')

  " SN_SOFO: missing sofoto
  call Spellfile_Test(0z0600000000050001610000, 'E759:')

  " SN_SOFO: empty sofofrom and sofoto
  call Spellfile_Test(0z06000000000400000000FF000000000000000000000000, '')

  " SN_SOFO: multi-byte characters in sofofrom and sofoto
  call Spellfile_Test(0z0600000000080002CF810002CF82FF000000000000000000000000, '')

  " SN_COMPOUND: compmax is less than 2
  call Spellfile_Test(0z08000000000101, 'E759:')

  " SN_COMPOUND: missing compsylmax and other options
  call Spellfile_Test(0z0800000000020401, 'E759:')

  " SN_COMPOUND: missing compoptions
  call Spellfile_Test(0z080000000005040101, 'E758:')

  " SN_COMPOUND: missing comppattern
  call Spellfile_Test(0z08000000000704010100000001, 'E758:')

  " SN_COMPOUND: incorrect comppatlen
  call Spellfile_Test(0z080000000007040101000000020165, 'E758:')

  " SN_INFO: missing info
  call Spellfile_Test(0z0F0000000005040101, '')

  " SN_MIDWORD: missing midword
  call Spellfile_Test(0z0200000000040102, '')

  " SN_MAP: missing midword
  call Spellfile_Test(0z0700000000040102, '')

  " SN_MAP: empty map string
  call Spellfile_Test(0z070000000000FF000000000000000000000000, '')

  " SN_MAP: duplicate multibyte character
  call Spellfile_Test(0z070000000004DC81DC81, 'E783:')

  " SN_SYLLABLE: missing SYLLABLE item
  call Spellfile_Test(0z0900000000040102, '')

  " SN_SYLLABLE: More than SY_MAXLEN size
  let v = eval('0z090000000022612F' .. repeat('62', 32))
  call Spellfile_Test(v, '')

  " LWORDTREE: missing
  call Spellfile_Test(0zFF, 'E758:')

  " LWORDTREE: missing tree node
  call Spellfile_Test(0zFF00000004, 'E758:')

  " LWORDTREE: missing tree node value
  call Spellfile_Test(0zFF0000000402, 'E758:')

  " LWORDTREE: incorrect sibling node count
  call Spellfile_Test(0zFF00000001040000000000000000, 'E759:')

  " KWORDTREE: missing tree node
  call Spellfile_Test(0zFF0000000000000004, 'E758:')

  " PREFIXTREE: missing tree node
  call Spellfile_Test(0zFF000000000000000000000004, 'E758:')

  " PREFIXTREE: incorrect prefcondnr
  call Spellfile_Test(0zFF000000000000000000000002010200000020, 'E759:')

  " PREFIXTREE: invalid nodeidx
  call Spellfile_Test(0zFF00000000000000000000000201010000, 'E759:')

  let &rtp = save_rtp
endfunc

" Test for format errors in suggest file
func Test_sugfile_format_error()
  let save_rtp = &rtp
  call mkdir('Xtest/spell', 'pR')
  let splfile = './Xtest/spell/Xtest.utf-8.spl'
  let sugfile = './Xtest/spell/Xtest.utf-8.sug'

  " create an empty spell file with a suggest timestamp
  call writefile(0z56494D7370656C6C320B00000000080000000000000044FF000000000000000000000000, splfile, 'b')

  " 'encoding' is set before each test to clear the previously loaded suggest
  " file from memory.

  " empty suggest file
  set encoding=utf-8
  call writefile([], sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E778:')
  set nospell spelllang&

  " zero suggest version
  set encoding=utf-8
  call writefile(0z56494D73756700, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E779:')
  set nospell spelllang&

  " unsupported suggest version
  set encoding=utf-8
  call writefile(0z56494D7375671F, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E780:')
  set nospell spelllang&

  " missing suggest timestamp
  set encoding=utf-8
  call writefile(0z56494D73756701, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E781:')
  set nospell spelllang&

  " incorrect suggest timestamp
  set encoding=utf-8
  call writefile(0z56494D7375670100000000000000FF, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E781:')
  set nospell spelllang&

  " missing suggest wordtree
  set encoding=utf-8
  call writefile(0z56494D737567010000000000000044, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E782:')
  set nospell spelllang&

  " invalid suggest word count in SUGTABLE
  set encoding=utf-8
  call writefile(0z56494D7375670100000000000000440000000022, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E782:')
  set nospell spelllang&

  " missing sugline in SUGTABLE
  set encoding=utf-8
  call writefile(0z56494D7375670100000000000000440000000000000005, sugfile)
  set runtimepath=./Xtest
  set spelllang=Xtest
  set spell
  call assert_fails("let s = spellsuggest('abc')", 'E782:')
  set nospell spelllang&

  let &rtp = save_rtp
endfunc

" Test for using :mkspell to create a spell file from a list of words
func Test_wordlist_dic()
  " duplicate encoding
  let lines =<< trim [END]
    # This is an example word list

    /encoding=latin1
    /encoding=latin1
    example
  [END]
  call writefile(lines, 'Xwordlist.dic', 'D')
  let output = execute('mkspell Xwordlist.spl Xwordlist.dic')
  call assert_match('Duplicate /encoding= line ignored in Xwordlist.dic line 4: /encoding=latin1', output)

  " multiple encoding for a word
  let lines =<< trim [END]
    example
    /encoding=latin1
    example
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('/encoding= line after word ignored in Xwordlist.dic line 2: /encoding=latin1', output)

  " unsupported encoding for a word
  let lines =<< trim [END]
    /encoding=Xtest
    example
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('Conversion in Xwordlist.dic not supported: from Xtest to utf-8', output)

  " duplicate region
  let lines =<< trim [END]
    /regions=usca
    /regions=usca
    example
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('Duplicate /regions= line ignored in Xwordlist.dic line 2: regions=usca', output)

  " maximum regions
  let lines =<< trim [END]
    /regions=uscauscauscauscausca
    example
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('Too many regions in Xwordlist.dic line 1: uscauscauscauscausca', output)

  " unsupported '/' value
  let lines =<< trim [END]
    /test=abc
    example
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('/ line ignored in Xwordlist.dic line 1: /test=abc', output)

  " unsupported flag
  let lines =<< trim [END]
    example/+
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('Unrecognized flags in Xwordlist.dic line 1: +', output)

  " non-ascii word
  call writefile(["ʀʀ"], 'Xwordlist.dic')
  let output = execute('mkspell! -ascii Xwordlist.spl Xwordlist.dic')
  call assert_match('Ignored 1 words with non-ASCII characters', output)

  " keep case of a word
  let lines =<< trim [END]
    example/=
  [END]
  call writefile(lines, 'Xwordlist.dic')
  let output = execute('mkspell! Xwordlist.spl Xwordlist.dic')
  call assert_match('Compressed keep-case:', output)

  call delete('Xwordlist.spl')
endfunc

" Test for the :mkspell command
func Test_mkspell()
  call assert_fails('mkspell Xtest_us.spl', 'E751:')
  call assert_fails('mkspell Xtest.spl abc', 'E484:')
  call assert_fails('mkspell a b c d e f g h i j k', 'E754:')

  " create a .aff file but not the .dic file
  call writefile([], 'Xtest.aff')
  call assert_fails('mkspell Xtest.spl Xtest', 'E484:')
  call delete('Xtest.aff')

  call writefile([], 'Xtest.spl')
  call writefile([], 'Xtest.dic')
  call assert_fails('mkspell Xtest.spl Xtest.dic', 'E13:')
  call delete('Xtest.spl')
  call delete('Xtest.dic')

  call mkdir('Xtest.spl')
  call assert_fails('mkspell! Xtest.spl Xtest.dic', 'E17:')
  call delete('Xtest.spl', 'rf')

  " can't write the .spl file as its directory does not exist
  call writefile([], 'Xtest.aff')
  call writefile([], 'Xtest.dic')
  call assert_fails('mkspell DOES_NOT_EXIT/Xtest.spl Xtest.dic', 'E484:')
  call delete('Xtest.aff')
  call delete('Xtest.dic')

  call assert_fails('mkspell en en_US abc_xyz', 'E755:')
endfunc

" Tests for :mkspell with a .dic and .aff file
func Test_aff_file_format_error()
  " FIXME: For some reason, the :mkspell command below doesn't fail on the
  " MS-Windows CI build. Disable this test on MS-Windows for now.
  CheckNotMSWindows

  " No word count in .dic file
  call writefile([], 'Xtest.dic', 'D')
  call writefile([], 'Xtest.aff', 'D')
  call assert_fails('mkspell! Xtest.spl Xtest', 'E760:')

  " create a .dic file for the tests below
  call writefile(['1', 'work'], 'Xtest.dic')

  " Invalid encoding in .aff file
  call writefile(['# comment', 'SET Xinvalidencoding'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Conversion in Xtest.aff not supported: from xinvalidencoding', output)

  " Invalid flag in .aff file
  call writefile(['FLAG xxx'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Invalid value for FLAG in Xtest.aff line 1: xxx', output)

  " set FLAGS after using flag for an affix
  call writefile(['SFX L Y 1', 'SFX L 0 re [^x]', 'FLAG long'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('FLAG after using flags in Xtest.aff line 3: long', output)

  " INFO in affix file
  let save_encoding = &encoding
  call mkdir('Xrtp/spell', 'p')
  call writefile(['1', 'work'], 'Xrtp/spell/Xtest.dic')
  call writefile(['NAME klingon', 'VERSION 1.4', 'AUTHOR Spock'],
        \ 'Xrtp/spell/Xtest.aff')
  silent mkspell! Xrtp/spell/Xtest.utf-8.spl Xrtp/spell/Xtest
  let save_rtp = &rtp
  set runtimepath=./Xrtp
  set spelllang=Xtest
  set spell
  let output = split(execute('spellinfo'), "\n")
  call assert_equal("NAME klingon", output[1])
  call assert_equal("VERSION 1.4", output[2])
  call assert_equal("AUTHOR Spock", output[3])
  let &rtp = save_rtp
  call delete('Xrtp', 'rf')
  set spell& spelllang& spellfile&
  %bw!
  " 'encoding' must be set again to clear the spell file in memory
  let &encoding = save_encoding

  " COMPOUNDFORBIDFLAG flag after PFX in an affix file
  call writefile(['PFX L Y 1', 'PFX L 0 re x', 'COMPOUNDFLAG c', 'COMPOUNDFORBIDFLAG x'],
        \ 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Defining COMPOUNDFORBIDFLAG after PFX item may give wrong results in Xtest.aff line 4', output)

  " COMPOUNDPERMITFLAG flag after PFX in an affix file
  call writefile(['PFX L Y 1', 'PFX L 0 re x', 'COMPOUNDPERMITFLAG c'],
        \ 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Defining COMPOUNDPERMITFLAG after PFX item may give wrong results in Xtest.aff line 3', output)

  " Wrong COMPOUNDRULES flag value in an affix file
  call writefile(['COMPOUNDRULES a'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Wrong COMPOUNDRULES value in Xtest.aff line 1: a', output)

  " Wrong COMPOUNDWORDMAX flag value in an affix file
  call writefile(['COMPOUNDWORDMAX 0'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Wrong COMPOUNDWORDMAX value in Xtest.aff line 1: 0', output)

  " Wrong COMPOUNDMIN flag value in an affix file
  call writefile(['COMPOUNDMIN 0'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Wrong COMPOUNDMIN value in Xtest.aff line 1: 0', output)

  " Wrong COMPOUNDSYLMAX flag value in an affix file
  call writefile(['COMPOUNDSYLMAX 0'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Wrong COMPOUNDSYLMAX value in Xtest.aff line 1: 0', output)

  " Wrong CHECKCOMPOUNDPATTERN flag value in an affix file
  call writefile(['CHECKCOMPOUNDPATTERN 0'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Wrong CHECKCOMPOUNDPATTERN value in Xtest.aff line 1: 0', output)

  " Both compounding and NOBREAK specified
  call writefile(['COMPOUNDFLAG c', 'NOBREAK'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Warning: both compounding and NOBREAK specified', output)

  " Duplicate affix entry in an affix file
  call writefile(['PFX L Y 1', 'PFX L 0 re x', 'PFX L Y 1', 'PFX L 0 re x'],
        \ 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Duplicate affix in Xtest.aff line 3: L', output)

  " Duplicate affix entry in an affix file
  call writefile(['PFX L Y 1', 'PFX L Y 1'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Unrecognized or duplicate item in Xtest.aff line 2: PFX', output)

  " Different combining flags in an affix file
  call writefile(['PFX L Y 1', 'PFX L 0 re x', 'PFX L N 1'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Different combining flag in continued affix block in Xtest.aff line 3', output)

  " Try to reuse an affix used for BAD flag
  call writefile(['BAD x', 'PFX x Y 1', 'PFX x 0 re x'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Affix also used for BAD/RARE/KEEPCASE/NEEDAFFIX/NEEDCOMPOUND/NOSUGGEST in Xtest.aff line 2: x', output)

  " Trailing characters in an affix entry
  call writefile(['PFX L Y 1 Test', 'PFX L 0 re x'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Trailing text in Xtest.aff line 1: Test', output)

  " Trailing characters in an affix entry
  call writefile(['PFX L Y 1', 'PFX L 0 re x Test'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Trailing text in Xtest.aff line 2: Test', output)

  " Incorrect combine flag in an affix entry
  call writefile(['PFX L X 1', 'PFX L 0 re x'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Expected Y or N in Xtest.aff line 1: X', output)

  " Invalid count for REP item
  call writefile(['REP a'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Expected REP(SAL) count in Xtest.aff line 1', output)

  " Trailing characters in REP item
  call writefile(['REP 1', 'REP f ph test'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Trailing text in Xtest.aff line 2: test', output)

  " Invalid count for MAP item
  call writefile(['MAP a'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Expected MAP count in Xtest.aff line 1', output)

  " Duplicate character in a MAP item
  call writefile(['MAP 2', 'MAP xx', 'MAP yy'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Duplicate character in MAP in Xtest.aff line 2', output)

  " Use COMPOUNDSYLMAX without SYLLABLE
  call writefile(['COMPOUNDSYLMAX 2'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('COMPOUNDSYLMAX used without SYLLABLE', output)

  " Missing SOFOTO
  call writefile(['SOFOFROM abcdef'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Missing SOFOTO line in Xtest.aff', output)

  " Length of SOFOFROM and SOFOTO differ
  call writefile(['SOFOFROM abcde', 'SOFOTO ABCD'], 'Xtest.aff')
  call assert_fails('mkspell! Xtest.spl Xtest', 'E759:')

  " Both SAL and SOFOFROM/SOFOTO items
  call writefile(['SOFOFROM abcd', 'SOFOTO ABCD', 'SAL CIA X'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Both SAL and SOFO lines in Xtest.aff', output)

  " use an alphabet flag when FLAG is num
  call writefile(['FLAG num', 'SFX L Y 1', 'SFX L 0 re [^x]'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Flag is not a number in Xtest.aff line 2: L', output)

  " use number and alphabet flag when FLAG is num
  call writefile(['FLAG num', 'SFX 4f Y 1', 'SFX 4f 0 re [^x]'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Affix name too long in Xtest.aff line 2: 4f', output)

  " use a single character flag when FLAG is long
  call writefile(['FLAG long', 'SFX L Y 1', 'SFX L 0 re [^x]'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('Illegal flag in Xtest.aff line 2: L', output)

  " Nvim: non-utf8 encoding not supported
  " " missing character in UPP entry. The character table is used only in a
  " " non-utf8 encoding
  " call writefile(['FOL abc', 'LOW abc', 'UPP A'], 'Xtest.aff')
  " let save_encoding = &encoding
  " set encoding=cp949
  " call assert_fails('mkspell! Xtest.spl Xtest', 'E761:')
  " let &encoding = save_encoding
  "
  " " character range doesn't match between FOL and LOW entries
  " call writefile(["FOL \u0102bc", 'LOW abc', 'UPP ABC'], 'Xtest.aff')
  " let save_encoding = &encoding
  " set encoding=cp949
  " call assert_fails('mkspell! Xtest.spl Xtest', 'E762:')
  " let &encoding = save_encoding
  "
  " " character range doesn't match between FOL and UPP entries
  " call writefile(["FOL \u0102bc", "LOW \u0102bc", 'UPP ABC'], 'Xtest.aff')
  " let save_encoding = &encoding
  " set encoding=cp949
  " call assert_fails('mkspell! Xtest.spl Xtest', 'E762:')
  " let &encoding = save_encoding
  "
  " " additional characters in LOW and UPP entries
  " call writefile(["FOL ab", "LOW abc", 'UPP ABC'], 'Xtest.aff')
  " let save_encoding = &encoding
  " set encoding=cp949
  " call assert_fails('mkspell! Xtest.spl Xtest', 'E761:')
  " let &encoding = save_encoding
  "
  " " missing UPP entry
  " call writefile(["FOL abc", "LOW abc"], 'Xtest.aff')
  " let save_encoding = &encoding
  " set encoding=cp949
  " let output = execute('mkspell! Xtest.spl Xtest')
  " call assert_match('Missing FOL/LOW/UPP line in Xtest.aff', output)
  " let &encoding = save_encoding

  " duplicate word in the .dic file
  call writefile(['2', 'good', 'good', 'good'], 'Xtest.dic')
  call writefile(['NAME vim'], 'Xtest.aff')
  let output = execute('mkspell! Xtest.spl Xtest')
  call assert_match('First duplicate word in Xtest.dic line 3: good', output)
  call assert_match('2 duplicate word(s) in Xtest.dic', output)

  " use multiple .aff files with different values for COMPOUNDWORDMAX and
  " MIDWORD (number and string)
  call writefile(['1', 'world'], 'Xtest_US.dic', 'D')
  call writefile(['1', 'world'], 'Xtest_CA.dic', 'D')
  call writefile(["COMPOUNDWORDMAX 3", "MIDWORD '-"], 'Xtest_US.aff', 'D')
  call writefile(["COMPOUNDWORDMAX 4", "MIDWORD '="], 'Xtest_CA.aff', 'D')
  let output = execute('mkspell! Xtest.spl Xtest_US Xtest_CA')
  call assert_match('COMPOUNDWORDMAX value differs from what is used in another .aff file', output)
  call assert_match('MIDWORD value differs from what is used in another .aff file', output)

  call delete('Xtest.spl')
  call delete('Xtest.sug')
endfunc

func Test_spell_add_word()
  set spellfile=
  call assert_fails('spellgood abc', 'E764:')

  set spellfile=Xtest.utf-8.add
  call assert_fails('2spellgood abc', 'E765:')

  edit Xtest.utf-8.add
  call setline(1, 'sample')
  call assert_fails('spellgood abc', 'E139:')
  set spellfile&
  %bw!
endfunc

func Test_spell_add_long_word()
  set spell spellfile=./Xspellfile.add spelllang=en

  let word = repeat('a', 9000)
  let v:errmsg = ''
  " Spell checking doesn't really work for such a long word,
  " but this should not cause an E1510 error.
  exe 'spellgood ' .. word
  call assert_equal('', v:errmsg)
  call assert_equal([word], readfile('./Xspellfile.add'))

  set spell& spellfile= spelllang& encoding=utf-8
  call delete('./Xspellfile.add')
  call delete('./Xspellfile.add.spl')
endfunc

func Test_spellfile_verbose()
  call writefile(['1', 'one'], 'XtestVerbose.dic', 'D')
  call writefile([], 'XtestVerbose.aff', 'D')
  mkspell! XtestVerbose-utf8.spl XtestVerbose
  set spell

  " First time: the spl file should be read.
  let a = execute('3verbose set spelllang=XtestVerbose-utf8.spl')
  call assert_match('Reading spell file "XtestVerbose-utf8.spl"', a)

  " Second time time: the spl file should not be read (already read).
  let a = execute('3verbose set spelllang=XtestVerbose-utf8.spl')
  call assert_notmatch('Reading spell file "XtestVerbose-utf8.spl"', a)

  set spell& spelllang&
  call delete('XtestVerbose-utf8.spl')
endfunc

" Test NOBREAK (see :help spell-NOBREAK)
func Test_NOBREAK()
  call writefile(['3', 'one', 'two', 'three' ], 'XtestNOBREAK.dic', 'D')
  call writefile(['NOBREAK' ], 'XtestNOBREAK.aff', 'D')

  mkspell! XtestNOBREAK-utf8.spl XtestNOBREAK
  set spell spelllang=XtestNOBREAK-utf8.spl

  call assert_equal(['', ''], spellbadword('One two three onetwo onetwothree threetwoone'))

  call assert_equal(['x', 'bad'], spellbadword('x'))
  call assert_equal(['y', 'bad'], spellbadword('yone'))
  call assert_equal(['z', 'bad'], spellbadword('onez'))
  call assert_equal(['zero', 'bad'], spellbadword('Onetwozerothree'))

  new
  call setline(1, 'Onetwwothree')
  norm! fw1z=
  call assert_equal('Onetwothree', getline(1))
  call setline(1, 'Onetwothre')
  norm! fh1z=
  call assert_equal('Onetwothree', getline(1))

  bw!
  set spell& spelllang&
  call delete('XtestNOBREAK-utf8.spl')
endfunc

" Test CHECKCOMPOUNDPATTERN (see :help spell-CHECKCOMPOUNDPATTERN)
func Test_spellfile_CHECKCOMPOUNDPATTERN()
  call writefile(['4',
        \         'one/c',
        \         'two/c',
        \         'three/c',
        \         'four'], 'XtestCHECKCOMPOUNDPATTERN.dic', 'D')
  " Forbid compound words where first word ends with 'wo' and second starts with 'on'.
  call writefile(['CHECKCOMPOUNDPATTERN 1',
        \         'CHECKCOMPOUNDPATTERN wo on',
        \         'COMPOUNDFLAG c'], 'XtestCHECKCOMPOUNDPATTERN.aff', 'D')

  mkspell! XtestCHECKCOMPOUNDPATTERN-utf8.spl XtestCHECKCOMPOUNDPATTERN
  set spell spelllang=XtestCHECKCOMPOUNDPATTERN-utf8.spl

  " Check valid words with and without valid compounds.
  for goodword in ['one', 'two', 'three', 'four',
        \          'oneone', 'onetwo',  'onethree',
        \          'twotwo', 'twothree',
        \          'threeone', 'threetwo', 'threethree',
        \          'onetwothree', 'onethreetwo', 'twothreeone', 'oneoneone']
    call assert_equal(['', ''], spellbadword(goodword), goodword)
  endfor

  " Compounds 'twoone' or 'threetwoone' should be forbidden by CHECKCOMPOUNPATTERN.
  " 'four' does not have the 'c' flag in *.aff file so no compound.
  " 'five' is not in the *.dic file.
  for badword in ['five', 'onetwox',
        \         'twoone', 'threetwoone',
        \         'fourone', 'onefour']
    call assert_equal([badword, 'bad'], spellbadword(badword))
  endfor

  set spell& spelllang&
  call delete('XtestCHECKCOMPOUNDPATTERN-utf8.spl')
endfunc

" Test NOCOMPOUNDSUGS (see :help spell-NOCOMPOUNDSUGS)
func Test_spellfile_NOCOMPOUNDSUGS()
  call writefile(['3',
        \         'one/c',
        \         'two/c',
        \         'three/c'], 'XtestNOCOMPOUNDSUGS.dic', 'D')

  " pass 0 tests without NOCOMPOUNDSUGS, pass 1 tests with NOCOMPOUNDSUGS
  for pass in [0, 1]
    if pass == 0
      call writefile(['COMPOUNDFLAG c'], 'XtestNOCOMPOUNDSUGS.aff', 'D')
    else
      call writefile(['NOCOMPOUNDSUGS',
          \           'COMPOUNDFLAG c'], 'XtestNOCOMPOUNDSUGS.aff', 'D')
    endif

    mkspell! XtestNOCOMPOUNDSUGS-utf8.spl XtestNOCOMPOUNDSUGS
    set spell spelllang=XtestNOCOMPOUNDSUGS-utf8.spl

    for goodword in ['one', 'two', 'three',
          \          'oneone', 'onetwo',  'onethree',
          \          'twoone', 'twotwo', 'twothree',
          \          'threeone', 'threetwo', 'threethree',
          \          'onetwothree', 'onethreetwo', 'twothreeone', 'oneoneone']
      call assert_equal(['', ''], spellbadword(goodword), goodword)
    endfor

    for badword in ['four', 'onetwox', 'onexone']
      call assert_equal([badword, 'bad'], spellbadword(badword))
    endfor

    if pass == 0
      call assert_equal(['one', 'oneone'], spellsuggest('onne', 2))
      call assert_equal(['onethree', 'one three'], spellsuggest('onethre', 2))
    else
      call assert_equal(['one', 'one one'], spellsuggest('onne', 2))
      call assert_equal(['one three'], spellsuggest('onethre', 2))
    endif
  endfor

  set spell& spelllang&
  call delete('XtestNOCOMPOUNDSUGS-utf8.spl')
endfunc

" Test COMMON (better suggestions with common words, see :help spell-COMMON)
func Test_spellfile_COMMON()
  call writefile(['7',
        \         'and',
        \         'ant',
        \         'end',
        \         'any',
        \         'tee',
        \         'the',
        \         'ted'], 'XtestCOMMON.dic', 'D')
  call writefile(['COMMON the and'], 'XtestCOMMON.aff', 'D')

  mkspell! XtestCOMMON-utf8.spl XtestCOMMON
  set spell spelllang=XtestCOMMON-utf8.spl

  " COMMON words 'and' and 'the' should be the top suggestions.
  call assert_equal(['and', 'ant'], spellsuggest('anr', 2))
  call assert_equal(['and', 'end'], spellsuggest('ond', 2))
  call assert_equal(['the', 'ted'], spellsuggest('tha', 2))
  call assert_equal(['the', 'tee'], spellsuggest('dhe', 2))

  set spell& spelllang&
  call delete('XtestCOMMON-utf8.spl')
endfunc

" Test NOSUGGEST (see :help spell-COMMON)
func Test_spellfile_NOSUGGEST()
  call writefile(['2', 'foo/X', 'fog'], 'XtestNOSUGGEST.dic', 'D')
  call writefile(['NOSUGGEST X'], 'XtestNOSUGGEST.aff', 'D')

  mkspell! XtestNOSUGGEST-utf8.spl XtestNOSUGGEST
  set spell spelllang=XtestNOSUGGEST-utf8.spl

  for goodword in ['foo', 'Foo', 'FOO', 'fog', 'Fog', 'FOG']
    call assert_equal(['', ''], spellbadword(goodword), goodword)
  endfor
  for badword in ['foO', 'fOO', 'fooo', 'foog', 'foofog', 'fogfoo']
    call assert_equal([badword, 'bad'], spellbadword(badword))
  endfor

  call assert_equal(['fog'], spellsuggest('fooo', 1))
  call assert_equal(['fog'], spellsuggest('fOo', 1))
  call assert_equal(['fog'], spellsuggest('foG', 1))
  call assert_equal(['fog'], spellsuggest('fogg', 1))

  set spell& spelllang&
  call delete('XtestNOSUGGEST-utf8.spl')
endfunc


" Test CIRCUMFIX (see: :help spell-CIRCUMFIX)
func Test_spellfile_CIRCUMFIX()
  " Example taken verbatim from https://github.com/hunspell/hunspell/tree/master/tests
  call writefile(['1',
        \         'nagy/C	po:adj'], 'XtestCIRCUMFIX.dic', 'D')
  call writefile(['# circumfixes: ~ obligate prefix/suffix combinations',
        \         '# superlative in Hungarian: leg- (prefix) AND -bb (suffix)',
        \         '',
        \         'CIRCUMFIX X',
        \         '',
        \         'PFX A Y 1',
        \         'PFX A 0 leg/X .',
        \         '',
        \         'PFX B Y 1',
        \         'PFX B 0 legesleg/X .',
        \         '',
        \         'SFX C Y 3',
        \         'SFX C 0 obb . is:COMPARATIVE',
        \         'SFX C 0 obb/AX . is:SUPERLATIVE',
        \         'SFX C 0 obb/BX . is:SUPERSUPERLATIVE'], 'XtestCIRCUMFIX.aff', 'D')

  mkspell! XtestCIRCUMFIX-utf8.spl XtestCIRCUMFIX
  set spell spelllang=XtestCIRCUMFIX-utf8.spl

  " From https://catalog.ldc.upenn.edu/docs/LDC2008T01/acta04.pdf:
  " Hungarian       English
  " ---------       -------
  " nagy            great
  " nagyobb         greater
  " legnagyobb      greatest
  " legeslegnagyob  most greatest
  call assert_equal(['', ''], spellbadword('nagy nagyobb legnagyobb legeslegnagyobb'))

  for badword in ['legnagy', 'legeslegnagy', 'legobb', 'legeslegobb']
    call assert_equal([badword, 'bad'], spellbadword(badword))
  endfor

  set spell& spelllang&
  call delete('XtestCIRCUMFIX-utf8.spl')
endfunc

" Test SFX that strips/chops characters
func Test_spellfile_SFX_strip()
  " Simplified conjugation of Italian verbs ending in -are (first conjugation).
  call writefile(['SFX A Y 4',
        \         'SFX A are iamo [^icg]are',
        \         'SFX A are hiamo [cg]are',
        \         'SFX A re mo iare',
        \         'SFX A re vamo are'],
        \         'XtestSFX.aff', 'D')
  " Examples of Italian verbs:
  " - cantare = to sing
  " - cercare = to search
  " - odiare = to hate
  call writefile(['3', 'cantare/A', 'cercare/A', 'odiare/A'], 'XtestSFX.dic', 'D')

  mkspell! XtestSFX-utf8.spl XtestSFX
  set spell spelllang=XtestSFX-utf8.spl

  " To sing, we're singing, we were singing.
  call assert_equal(['', ''], spellbadword('cantare cantiamo cantavamo'))

  " To search, we're searching, we were searching.
  call assert_equal(['', ''], spellbadword('cercare cerchiamo cercavamo'))

  " To hate, we hate, we were hating.
  call assert_equal(['', ''], spellbadword('odiare odiamo odiavamo'))

  for badword in ['canthiamo', 'cerciamo', 'cantarevamo', 'odiiamo']
    call assert_equal([badword, 'bad'], spellbadword(badword))
  endfor

  call assert_equal(['cantiamo'],  spellsuggest('canthiamo', 1))
  call assert_equal(['cerchiamo'], spellsuggest('cerciamo', 1))
  call assert_equal(['cantavamo'], spellsuggest('cantarevamo', 1))
  call assert_equal(['odiamo'],    spellsuggest('odiiamo', 1))

  set spell& spelllang&
  call delete('XtestSFX-utf8.spl')
endfunc

" When 'spellfile' is not set, adding a new good word will automatically set
" the 'spellfile'
func Test_init_spellfile()
  let save_rtp = &rtp
  let save_encoding = &encoding
  call mkdir('Xrtp/spell', 'pR')
  call writefile(['vim'], 'Xrtp/spell/Xtest.dic')
  silent mkspell Xrtp/spell/Xtest.utf-8.spl Xrtp/spell/Xtest.dic
  set runtimepath=./Xrtp
  set spelllang=Xtest
  set spell
  silent spellgood abc
  call assert_equal('./Xrtp/spell/Xtest.utf-8.add', &spellfile)
  call assert_equal(['abc'], readfile('Xrtp/spell/Xtest.utf-8.add'))
  call assert_true(filereadable('Xrtp/spell/Xtest.utf-8.spl'))

  set spell& spelllang& spellfile&
  let &encoding = save_encoding
  let &rtp = save_rtp
  %bw!
endfunc

" Test for the 'mkspellmem' option
func Test_mkspellmem_opt()
  call assert_fails('set mkspellmem=1000', 'E474:')
  call assert_fails('set mkspellmem=1000,', 'E474:')
  call assert_fails('set mkspellmem=1000,50', 'E474:')
  call assert_fails('set mkspellmem=1000,50,', 'E474:')
  call assert_fails('set mkspellmem=1000,50,10,', 'E474:')
  call assert_fails('set mkspellmem=1000,50,0', 'E474:')
endfunc

" 'spellfile' accepts '@' on top of 'isfname'.
func Test_spellfile_allow_at_character()
  call mkdir('Xtest/the foo@bar,dir', 'p')
  let &spellfile = './Xtest/the foo@bar,dir/Xspellfile.add'
  let &spellfile = ''
  call delete('Xtest', 'rf')
endfunc

" this was using a NULL pointer
func Test_mkspell_empty_dic()
  call writefile(['1'], 'XtestEmpty.dic', 'D')
  call writefile(['SOFOFROM abcd', 'SOFOTO ABCD', 'SAL CIA X'], 'XtestEmpty.aff', 'D')
  mkspell! XtestEmpty.spl XtestEmpty

  call delete('XtestEmpty.spl')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
