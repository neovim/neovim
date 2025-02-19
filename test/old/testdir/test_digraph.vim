" Tests for digraphs

source check.vim
CheckFeature digraphs
source term_util.vim

func Put_Dig(chars)
  exe "norm! o\<c-k>".a:chars
endfu

func Put_Dig_BS(char1, char2)
  exe "norm! o".a:char1."\<bs>".a:char2
endfu

func Test_digraphs()
  new
  call Put_Dig("00")
  call assert_equal("∞", getline('.'))
  " not a digraph
  call Put_Dig("el")
  call assert_equal("l", getline('.'))
  call Put_Dig("ht")
  call assert_equal("þ", getline('.'))
  " digraph "ab" is the same as "ba"
  call Put_Dig("ab")
  call Put_Dig("ba")
  call assert_equal(["ば","ば"], getline(line('.')-1,line('.')))
  " Euro sign
  call Put_Dig("e=")
  call Put_Dig("=e")
  call Put_Dig("Eu")
  call Put_Dig("uE")
  call assert_equal(['е']+repeat(["€"],3), getline(line('.')-3,line('.')))
  " Rouble sign
  call Put_Dig("R=")
  call Put_Dig("=R")
  call Put_Dig("=P")
  call Put_Dig("P=")
  call assert_equal(['Р']+repeat(["₽"],2)+['П'], getline(line('.')-3,line('.')))
  " Quadruple prime
  call Put_Dig("'4")
  call assert_equal("⁗", getline('.'))
  " APPROACHES THE LIMIT
  call Put_Dig(".=")
  call assert_equal("≐", getline('.'))
  " Not a digraph
  call Put_Dig("a\<bs>")
  call Put_Dig("\<bs>a")
  call assert_equal(["<BS>", "<BS>a"], getline(line('.')-1,line('.')))
  " Grave
  call Put_Dig("a!")
  call Put_Dig("!e")
  call Put_Dig("b!") " not defined
  call assert_equal(["à", "è", "!"], getline(line('.')-2,line('.')))
  " Acute accent
  call Put_Dig("a'")
  call Put_Dig("'e")
  call Put_Dig("b'") " not defined
  call assert_equal(["á", "é", "'"], getline(line('.')-2,line('.')))
  " Circumflex
  call Put_Dig("a>")
  call Put_Dig(">e")
  call Put_Dig("b>") " not defined
  call assert_equal(['â', 'ê', '>'], getline(line('.')-2,line('.')))
  " Tilde
  call Put_Dig("o~")
  call Put_Dig("~u") " not defined
  call Put_Dig("z~") " not defined
  call assert_equal(['õ', 'u', '~'], getline(line('.')-2,line('.')))
  " Tilde
  call Put_Dig("o?")
  call Put_Dig("?u")
  call Put_Dig("z?") " not defined
  call assert_equal(['õ', 'ũ', '?'], getline(line('.')-2,line('.')))
  " Macron
  call Put_Dig("o-")
  call Put_Dig("-u")
  call Put_Dig("z-") " not defined
  call assert_equal(['ō', 'ū', '-'], getline(line('.')-2,line('.')))
  " Breve
  call Put_Dig("o(")
  call Put_Dig("(u")
  call Put_Dig("z(") " not defined
  call assert_equal(['ŏ', 'ŭ', '('], getline(line('.')-2,line('.')))
  " Dot above
  call Put_Dig("b.")
  call Put_Dig(".e")
  call Put_Dig("a.") " not defined
  call assert_equal(['ḃ', 'ė', '.'], getline(line('.')-2,line('.')))
  " Diaeresis
  call Put_Dig("a:")
  call Put_Dig(":u")
  call Put_Dig("b:") " not defined
  call assert_equal(['ä', 'ü', ':'], getline(line('.')-2,line('.')))
  " Cedilla
  call Put_Dig("',")
  call Put_Dig(",C")
  call Put_Dig("b,") " not defined
  call assert_equal(['¸', 'Ç', ','], getline(line('.')-2,line('.')))
  " Underline
  call Put_Dig("B_")
  call Put_Dig("_t")
  call Put_Dig("a_") " not defined
  call assert_equal(['Ḇ', 'ṯ', '_'], getline(line('.')-2,line('.')))
  " Stroke
  call Put_Dig("j/")
  call Put_Dig("/l")
  call Put_Dig("b/") " not defined
  call assert_equal(['/', 'ł', '/'], getline(line('.')-2,line('.')))
  " Double acute
  call Put_Dig('O"')
  call Put_Dig('"y')
  call Put_Dig('b"') " not defined
  call assert_equal(['Ő', 'ÿ', '"'], getline(line('.')-2,line('.')))
  " Ogonek
  call Put_Dig('u;')
  call Put_Dig(';E')
  call Put_Dig('b;') " not defined
  call assert_equal(['ų', 'Ę', ';'], getline(line('.')-2,line('.')))
  " Caron
  call Put_Dig('u<')
  call Put_Dig('<E')
  call Put_Dig('b<') " not defined
  call assert_equal(['ǔ', 'Ě', '<'], getline(line('.')-2,line('.')))
  " Ring above
  call Put_Dig('u0')
  call Put_Dig('0E') " not defined
  call Put_Dig('b0') " not defined
  call assert_equal(['ů', 'E', '0'], getline(line('.')-2,line('.')))
  " Hook
  call Put_Dig('u2')
  call Put_Dig('2E')
  call Put_Dig('b2') " not defined
  call assert_equal(['ủ', 'Ẻ', '2'], getline(line('.')-2,line('.')))
  " Horn
  call Put_Dig('u9')
  call Put_Dig('9E') " not defined
  call Put_Dig('b9') " not defined
  call assert_equal(['ư', 'E', '9'], getline(line('.')-2,line('.')))
  " Cyrillic
  call Put_Dig('u=')
  call Put_Dig('=b')
  call Put_Dig('=_')
  call assert_equal(['у', 'б', '〓'], getline(line('.')-2,line('.')))
  " Greek
  call Put_Dig('u*')
  call Put_Dig('*b')
  call Put_Dig('*_')
  call assert_equal(['υ', 'β', '々'], getline(line('.')-2,line('.')))
  " Greek/Cyrillic special
  call Put_Dig('u%')
  call Put_Dig('%b') " not defined
  call Put_Dig('%_') " not defined
  call assert_equal(['ύ', 'b', '_'], getline(line('.')-2,line('.')))
  " Arabic
  call Put_Dig('u+')
  call Put_Dig('+b')
  call Put_Dig('+_') " japanese industrial symbol
  call assert_equal(['+', 'ب', '〄'], getline(line('.')-2,line('.')))
  " Hebrew
  call Put_Dig('Q+')
  call Put_Dig('+B')
  call Put_Dig('+X')
  call assert_equal(['ק', 'ב', 'ח'], getline(line('.')-2,line('.')))
  " Latin
  call Put_Dig('a3')
  call Put_Dig('A3')
  call Put_Dig('3X')
  call assert_equal(['ǣ', 'Ǣ', 'X'], getline(line('.')-2,line('.')))
  " Bopomofo
  call Put_Dig('a4')
  call Put_Dig('A4')
  call Put_Dig('4X')
  call assert_equal(['ㄚ', '4', 'X'], getline(line('.')-2,line('.')))
  " Hiragana
  call Put_Dig('a5')
  call Put_Dig('A5')
  call Put_Dig('5X')
  call assert_equal(['あ', 'ぁ', 'X'], getline(line('.')-2,line('.')))
  " Katakana
  call Put_Dig('a6')
  call Put_Dig('A6')
  call Put_Dig('6X')
  call assert_equal(['ァ', 'ア', 'X'], getline(line('.')-2,line('.')))
  " Superscripts
  call Put_Dig('1S')
  call Put_Dig('2S')
  call Put_Dig('3S')
  call assert_equal(['¹', '²', '³'], getline(line('.')-2,line('.')))
  " Subscripts
  call Put_Dig('1s')
  call Put_Dig('2s')
  call Put_Dig('3s')
  call assert_equal(['₁', '₂', '₃'], getline(line('.')-2,line('.')))
  " Eszet (only lowercase)
  call Put_Dig("ss")
  call Put_Dig("SS") " start of string
  call assert_equal(["ß", ""], getline(line('.')-1,line('.')))
  " High bit set
  call Put_Dig("a ")
  call Put_Dig(" A")
  call assert_equal(['á', 'Á'], getline(line('.')-1,line('.')))
  " Escape is not part of a digraph
  call Put_Dig("a\<esc>")
  call Put_Dig("\<esc>A")
  call assert_equal(['', 'A'], getline(line('.')-1,line('.')))
  " define some custom digraphs
  " old: 00 ∞
  " old: el l
  digraph 00 9216
  digraph el 0252
  call Put_Dig("00")
  call Put_Dig("el")
  " Reset digraphs
  digraph 00 8734
  digraph el 108
  call Put_Dig("00")
  call Put_Dig("el")
  call assert_equal(['␀', 'ü', '∞', 'l'], getline(line('.')-3,line('.')))
  call assert_fails('exe "digraph a\<Esc> 100"', 'E104:')
  call assert_fails('exe "digraph \<Esc>a 100"', 'E104:')
  call assert_fails('digraph xy z', 'E39:')
  call assert_fails('digraph x', 'E1214:')
  bw!
endfunc

func Test_digraphs_option()
  " reset whichwrap option, so that testing <esc><bs>A works,
  " without moving up a line
  set digraph ww=
  new
  call Put_Dig_BS("0","0")
  call assert_equal("∞", getline('.'))
  " not a digraph
  call Put_Dig_BS("e","l")
  call assert_equal("l", getline('.'))
  call Put_Dig_BS("h","t")
  call assert_equal("þ", getline('.'))
  " digraph "ab" is the same as "ba"
  call Put_Dig_BS("a","b")
  call Put_Dig_BS("b","a")
  call assert_equal(["ば","ば"], getline(line('.')-1,line('.')))
  " Euro sign
  call Put_Dig_BS("e","=")
  call Put_Dig_BS("=","e")
  call Put_Dig_BS("E","u")
  call Put_Dig_BS("u","E")
  call assert_equal(['е']+repeat(["€"],3), getline(line('.')-3,line('.')))
  " Rouble sign
  call Put_Dig_BS("R","=")
  call Put_Dig_BS("=","R")
  call Put_Dig_BS("=","P")
  call Put_Dig_BS("P","=")
  call assert_equal(['Р']+repeat(["₽"],2)+['П'], getline(line('.')-3,line('.')))
  " Not a digraph: this is different from <c-k>!
  let _bs = &bs
  set bs=
  call Put_Dig_BS("a","\<bs>")
  call Put_Dig_BS("\<bs>","a")
  call assert_equal(['','a'], getline(line('.')-1,line('.')))
  let &bs = _bs
  " Grave
  call Put_Dig_BS("a","!")
  call Put_Dig_BS("!","e")
  call Put_Dig_BS("b","!") " not defined
  call assert_equal(["à", "è", "!"], getline(line('.')-2,line('.')))
  " Acute accent
  call Put_Dig_BS("a","'")
  call Put_Dig_BS("'","e")
  call Put_Dig_BS("b","'") " not defined
  call assert_equal(["á", "é", "'"], getline(line('.')-2,line('.')))
  " Cicumflex
  call Put_Dig_BS("a",">")
  call Put_Dig_BS(">","e")
  call Put_Dig_BS("b",">") " not defined
  call assert_equal(['â', 'ê', '>'], getline(line('.')-2,line('.')))
  " Tilde
  call Put_Dig_BS("o","~")
  call Put_Dig_BS("~","u") " not defined
  call Put_Dig_BS("z","~") " not defined
  call assert_equal(['õ', 'u', '~'], getline(line('.')-2,line('.')))
  " Tilde
  call Put_Dig_BS("o","?")
  call Put_Dig_BS("?","u")
  call Put_Dig_BS("z","?") " not defined
  call assert_equal(['õ', 'ũ', '?'], getline(line('.')-2,line('.')))
  " Macron
  call Put_Dig_BS("o","-")
  call Put_Dig_BS("-","u")
  call Put_Dig_BS("z","-") " not defined
  call assert_equal(['ō', 'ū', '-'], getline(line('.')-2,line('.')))
  " Breve
  call Put_Dig_BS("o","(")
  call Put_Dig_BS("(","u")
  call Put_Dig_BS("z","(") " not defined
  call assert_equal(['ŏ', 'ŭ', '('], getline(line('.')-2,line('.')))
  " Dot above
  call Put_Dig_BS("b",".")
  call Put_Dig_BS(".","e")
  call Put_Dig_BS("a",".") " not defined
  call assert_equal(['ḃ', 'ė', '.'], getline(line('.')-2,line('.')))
  " Diaeresis
  call Put_Dig_BS("a",":")
  call Put_Dig_BS(":","u")
  call Put_Dig_BS("b",":") " not defined
  call assert_equal(['ä', 'ü', ':'], getline(line('.')-2,line('.')))
  " Cedilla
  call Put_Dig_BS("'",",")
  call Put_Dig_BS(",","C")
  call Put_Dig_BS("b",",") " not defined
  call assert_equal(['¸', 'Ç', ','], getline(line('.')-2,line('.')))
  " Underline
  call Put_Dig_BS("B","_")
  call Put_Dig_BS("_","t")
  call Put_Dig_BS("a","_") " not defined
  call assert_equal(['Ḇ', 'ṯ', '_'], getline(line('.')-2,line('.')))
  " Stroke
  call Put_Dig_BS("j","/")
  call Put_Dig_BS("/","l")
  call Put_Dig_BS("b","/") " not defined
  call assert_equal(['/', 'ł', '/'], getline(line('.')-2,line('.')))
  " Double acute
  call Put_Dig_BS('O','"')
  call Put_Dig_BS('"','y')
  call Put_Dig_BS('b','"') " not defined
  call assert_equal(['Ő', 'ÿ', '"'], getline(line('.')-2,line('.')))
  " Ogonek
  call Put_Dig_BS('u',';')
  call Put_Dig_BS(';','E')
  call Put_Dig_BS('b',';') " not defined
  call assert_equal(['ų', 'Ę', ';'], getline(line('.')-2,line('.')))
  " Caron
  call Put_Dig_BS('u','<')
  call Put_Dig_BS('<','E')
  call Put_Dig_BS('b','<') " not defined
  call assert_equal(['ǔ', 'Ě', '<'], getline(line('.')-2,line('.')))
  " Ring above
  call Put_Dig_BS('u','0')
  call Put_Dig_BS('0','E') " not defined
  call Put_Dig_BS('b','0') " not defined
  call assert_equal(['ů', 'E', '0'], getline(line('.')-2,line('.')))
  " Hook
  call Put_Dig_BS('u','2')
  call Put_Dig_BS('2','E')
  call Put_Dig_BS('b','2') " not defined
  call assert_equal(['ủ', 'Ẻ', '2'], getline(line('.')-2,line('.')))
  " Horn
  call Put_Dig_BS('u','9')
  call Put_Dig_BS('9','E') " not defined
  call Put_Dig_BS('b','9') " not defined
  call assert_equal(['ư', 'E', '9'], getline(line('.')-2,line('.')))
  " Cyrillic
  call Put_Dig_BS('u','=')
  call Put_Dig_BS('=','b')
  call Put_Dig_BS('=','_')
  call assert_equal(['у', 'б', '〓'], getline(line('.')-2,line('.')))
  " Greek
  call Put_Dig_BS('u','*')
  call Put_Dig_BS('*','b')
  call Put_Dig_BS('*','_')
  call assert_equal(['υ', 'β', '々'], getline(line('.')-2,line('.')))
  " Greek/Cyrillic special
  call Put_Dig_BS('u','%')
  call Put_Dig_BS('%','b') " not defined
  call Put_Dig_BS('%','_') " not defined
  call assert_equal(['ύ', 'b', '_'], getline(line('.')-2,line('.')))
  " Arabic
  call Put_Dig_BS('u','+')
  call Put_Dig_BS('+','b')
  call Put_Dig_BS('+','_') " japanese industrial symbol
  call assert_equal(['+', 'ب', '〄'], getline(line('.')-2,line('.')))
  " Hebrew
  call Put_Dig_BS('Q','+')
  call Put_Dig_BS('+','B')
  call Put_Dig_BS('+','X')
  call assert_equal(['ק', 'ב', 'ח'], getline(line('.')-2,line('.')))
  " Latin
  call Put_Dig_BS('a','3')
  call Put_Dig_BS('A','3')
  call Put_Dig_BS('3','X')
  call assert_equal(['ǣ', 'Ǣ', 'X'], getline(line('.')-2,line('.')))
  " Bopomofo
  call Put_Dig_BS('a','4')
  call Put_Dig_BS('A','4')
  call Put_Dig_BS('4','X')
  call assert_equal(['ㄚ', '4', 'X'], getline(line('.')-2,line('.')))
  " Hiragana
  call Put_Dig_BS('a','5')
  call Put_Dig_BS('A','5')
  call Put_Dig_BS('5','X')
  call assert_equal(['あ', 'ぁ', 'X'], getline(line('.')-2,line('.')))
  " Katakana
  call Put_Dig_BS('a','6')
  call Put_Dig_BS('A','6')
  call Put_Dig_BS('6','X')
  call assert_equal(['ァ', 'ア', 'X'], getline(line('.')-2,line('.')))
  " Superscripts
  call Put_Dig_BS('1','S')
  call Put_Dig_BS('2','S')
  call Put_Dig_BS('3','S')
  call assert_equal(['¹', '²', '³'], getline(line('.')-2,line('.')))
  " Subscripts
  call Put_Dig_BS('1','s')
  call Put_Dig_BS('2','s')
  call Put_Dig_BS('3','s')
  call assert_equal(['₁', '₂', '₃'], getline(line('.')-2,line('.')))
  " Eszet (only lowercase)
  call Put_Dig_BS("s","s")
  call Put_Dig_BS("S","S") " start of string
  call assert_equal(["ß", ""], getline(line('.')-1,line('.')))
  " High bit set (different from <c-k>)
  call Put_Dig_BS("a"," ")
  call Put_Dig_BS(" ","A")
  call assert_equal([' ', 'A'], getline(line('.')-1,line('.')))
  " Escape is not part of a digraph (different from <c-k>)
  call Put_Dig_BS("a","\<esc>")
  call Put_Dig_BS("\<esc>","A")
  call assert_equal(['', ''], getline(line('.')-1,line('.')))
  " define some custom digraphs
  " old: 00 ∞
  " old: el l
  digraph 00 9216
  digraph el 0252
  call Put_Dig_BS("0","0")
  call Put_Dig_BS("e","l")
  " Reset digraphs
  digraph 00 8734
  digraph el 108
  call Put_Dig_BS("0","0")
  call Put_Dig_BS("e","l")
  call assert_equal(['␀', 'ü', '∞', 'l'], getline(line('.')-3,line('.')))
  set nodigraph ww&vim
  bw!
endfunc

func Test_digraphs_output()
  new
  let out = execute(':digraph')
  call assert_equal('Eu €  8364',  matchstr(out, '\C\<Eu\D*8364\>'))
  call assert_equal('=e €  8364',  matchstr(out, '\C=e\D*8364\>'))
  call assert_equal('=R ₽  8381',  matchstr(out, '\C=R\D*8381\>'))
  call assert_equal('=P ₽  8381',  matchstr(out, '\C=P\D*8381\>'))
  call assert_equal('o: ö  246',   matchstr(out, '\C\<o:\D*246\>'))
  call assert_equal('v4 ㄪ 12586', matchstr(out, '\C\<v4\D*12586\>'))
  call assert_equal("'0 ˚  730",   matchstr(out, '\C''0\D*730\>'))
  call assert_equal('Z% Ж  1046',  matchstr(out, '\C\<Z%\D*1046\>'))
  call assert_equal('u- ū  363',   matchstr(out, '\C\<u-\D*363\>'))
  call assert_equal('SH ^A   1',   matchstr(out, '\C\<SH\D*1\>'))
  call assert_notmatch('Latin supplement', out)

  let out_bang_without_custom = execute(':digraph!')
  digraph lt 60
  let out_bang_with_custom = execute(':digraph!')
  call assert_notmatch('lt', out_bang_without_custom)
  call assert_match("^\n"
        \        .. "NU ^@  10 .*\n"
        \        .. "Latin supplement\n"
        \        .. "!I ¡  161 .*\n"
        \        .. ".*\n"
        \        .. 'Custom\n.*\<lt <   60\>', out_bang_with_custom)
  bw!
endfunc

func Test_loadkeymap()
  CheckFeature keymap
  new
  set keymap=czech
  set iminsert=0
  call feedkeys("o|\<c-^>|01234567890|\<esc>", 'tx')
  call assert_equal("|'é+ěščřžýáíé'", getline('.'))
  " reset keymap and encoding option
  set keymap=
  bw!
endfunc

func Test_digraph_cmndline()
  " Create digraph on commandline
  call feedkeys(":\"\<c-k>Eu\<cr>", 'xt')
  call assert_equal('"€', @:)

  " Canceling a CTRL-K on the cmdline
  call feedkeys(":\"a\<c-k>\<esc>b\<cr>", 'xt')
  call assert_equal('"ab', @:)
endfunc

func Test_show_digraph()
  new
  call Put_Dig("e=")
  call assert_equal("\n<е> 1077, Hex 0435, Oct 2065, Digr e=", execute('ascii'))
  bwipe!
endfunc

func Test_show_digraph_cp1251()
  throw 'skipped: Nvim supports ''utf8'' encoding only'
  new
  set encoding=cp1251
  call Put_Dig("='")
  call assert_equal("\n<\xfa>  <|z>  <M-z>  250,  Hex fa,  Oct 372, Digr ='", execute('ascii'))
  set encoding=utf-8
  bwipe!
endfunc

" Test for error in a keymap file
func Test_loadkeymap_error()
  CheckFeature keymap
  call assert_fails('loadkeymap', 'E105:')
  call writefile(['loadkeymap', 'a'], 'Xkeymap', 'D')
  call assert_fails('source Xkeymap', 'E791:')
endfunc

" Test for the characters displayed on the screen when entering a digraph
func Test_entering_digraph()
  CheckRunVimInTerminal
  let buf = RunVimInTerminal('', {'rows': 6})
  call term_sendkeys(buf, "i\<C-K>")
  call term_wait(buf)
  call assert_equal('?', term_getline(buf, 1))
  call term_sendkeys(buf, "1")
  call term_wait(buf)
  call assert_equal('1', term_getline(buf, 1))
  call term_sendkeys(buf, "2")
  call term_wait(buf)
  call assert_equal('½', term_getline(buf, 1))
  call StopVimInTerminal(buf)
endfunc

func Test_digraph_set_function()
  new
  call digraph_set('aa', 'あ')
  call Put_Dig('aa')
  call assert_equal('あ', getline('$'))
  call digraph_set(' i', 'い')
  call Put_Dig(' i')
  call assert_equal('い', getline('$'))
  call digraph_set('  ', 'う')
  call Put_Dig('  ')
  call assert_equal('う', getline('$'))

  eval 'aa'->digraph_set('え')
  call Put_Dig('aa')
  call assert_equal('え', getline('$'))

  call assert_fails('call digraph_set("aaa", "あ")', 'E1214: Digraph must be just two characters: aaa')
  call assert_fails('call digraph_set("b", "あ")', 'E1214: Digraph must be just two characters: b')
  call assert_fails('call digraph_set("あ", "あ")', 'E1214: Digraph must be just two characters: あ')
  call assert_fails('call digraph_set("aa", "ああ")', 'E1215: Digraph must be one character: ああ')
  call assert_fails('call digraph_set("aa", "か" .. nr2char(0x3099))',  'E1215: Digraph must be one character: か' .. nr2char(0x3099))
  call assert_fails('call digraph_set(v:_null_string, "い")',  'E1214: Digraph must be just two characters')
  call assert_fails('call digraph_set("aa", 0z10)',  'E976: Using a Blob as a String')
  bwipe!
endfunc

func Test_digraph_get_function()
  " Built-in digraphs
  call assert_equal('∞', digraph_get('00'))

  " User-defined digraphs
  call digraph_set('aa', 'あ')
  call digraph_set(' i', 'い')
  call digraph_set('  ', 'う')
  call assert_equal('あ', digraph_get('aa'))
  call assert_equal('あ', 'aa'->digraph_get())
  call assert_equal('い', digraph_get(' i'))
  call assert_equal('う', digraph_get('  '))
  call assert_fails('call digraph_get("aaa")', 'E1214: Digraph must be just two characters: aaa')
  call assert_fails('call digraph_get("b")', 'E1214: Digraph must be just two characters: b')
  call assert_fails('call digraph_get(v:_null_string)', 'E1214: Digraph must be just two characters:')
  call assert_fails('call digraph_get(0z10)', 'E976: Using a Blob as a String')
endfunc

func Test_digraph_get_function_encode()
  throw 'Skipped: Nvim does not support setting encoding=japan'
  CheckFeature iconv

  let testcases = {
        \'00': '∞',
        \'aa': 'あ',
        \}
  for [key, ch] in items(testcases)
    call digraph_set(key, ch)
    set encoding=japan
    call assert_equal(iconv(ch, 'utf-8', 'japan'), digraph_get(key))
    set encoding=utf-8
  endfor
endfunc

func Test_digraph_setlist_function()
  call digraph_setlist([['aa', 'き'], ['bb', 'く']])
  call assert_equal('き', digraph_get('aa'))
  call assert_equal('く', digraph_get('bb'))

  call assert_fails('call digraph_setlist([[]])', 'E1216:')
  call assert_fails('call digraph_setlist([["aa", "b", "cc"]])', 'E1216:')
  call assert_fails('call digraph_setlist([["あ", "あ"]])', 'E1214: Digraph must be just two characters: あ')
  call assert_fails('call digraph_setlist([v:_null_list])', 'E1216:')
  call assert_fails('call digraph_setlist({})', 'E1216:')
  call assert_fails('call digraph_setlist([{}])', 'E1216:')
  call assert_true(digraph_setlist(v:_null_list))
endfunc

func Test_digraph_getlist_function()
  " Make sure user-defined digraphs are defined
  call digraph_setlist([['aa', 'き'], ['bb', 'く']])

  for pair in digraph_getlist(1)
    call assert_equal(pair[1], digraph_get(pair[0]))
  endfor

  " We don't know how many digraphs are registered before, so check the number
  " of digraphs returned.
  call assert_equal(digraph_getlist()->len(), digraph_getlist(0)->len())
  call assert_notequal(digraph_getlist()->len(), digraph_getlist(1)->len())
  call assert_equal(digraph_getlist()->len(), digraph_getlist(v:false)->len())
  call assert_notequal(digraph_getlist()->len(), digraph_getlist(v:true)->len())

  call assert_fails('call digraph_getlist(0z12)', 'E1212: Bool required for argument 1')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
