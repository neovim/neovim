" Tests for digraphs

if !has("digraphs") || !has("multi_byte")
  finish
endif
set belloff=all

func! Put_Dig(chars)
  exe "norm! o\<c-k>".a:chars
endfu

func! Put_Dig_BS(char1, char2)
  exe "norm! o".a:char1."\<bs>".a:char2
endfu

func! Test_digraphs()
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
  " Cicumflex
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
  " Diaresis
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
  bw!
endfunc

func! Test_digraphs_option()
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
  call Put_Dig_BS("a","\<bs>")
  call Put_Dig_BS("\<bs>","a")
  call assert_equal(['','a'], getline(line('.')-1,line('.')))
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
  " Diaresis
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

func! Test_digraphs_output()
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
  bw!
endfunc

func! Test_loadkeymap()
  if !has('keymap')
    return
  endif
  new
  set keymap=czech
  set iminsert=0
  call feedkeys("o|\<c-^>|01234567890|\<esc>", 'tx')
  call assert_equal("|'é+ěščřžýáíé'", getline('.'))
  " reset keymap and encoding option
  set keymap=
  bw!
endfunc

func! Test_digraph_cmndline()
  " Create digraph on commandline
  " This is a hack, to let Vim create the digraph in commandline mode
  let s = ''
  exe "sil! norm! :let s.='\<c-k>Eu'\<cr>"
  call assert_equal("€", s)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
