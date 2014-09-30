" Polish letters keymap for utf-8
" Maintainer:	HS6_06	<hs6_06@o2.pl>
" Last Changed:	2005 Jan 12
" Current version: 1.0.2
" History: see polish-slash.vim

" This keymap adds the special Polish letters
" to an existing Latin keyboard.
" All chars as usual except:
" Polish:
"   instead of AltGr+{acelnosxz} you ve to use "/" followed by {acelnosxz}

" short keymap name for statusline
let b:keymap_name = "PL-slash-UTF"

scriptencoding latin1

loadkeymap

" Polish letters
/a	<Char-0x0105>	" LATIN SMALL LETTER A WITH OGONEK
/c	<Char-0x0107>	" LATIN SMALL LETTER C WITH ACUTE
/e	<Char-0x0119>	" LATIN SMALL LETTER E WITH OGONEK
/l	<Char-0x0142>	" LATIN SMALL LETTER L WITH STROKE
/n	<Char-0x0144>	" LATIN SMALL LETTER N WITH ACUTE
/o	<Char-0x00f3>	" LATIN SMALL LETTER O WITH ACUTE
/s	<Char-0x015b>	" LATIN SMALL LETTER S WITH ACUTE
/x	<Char-0x017a>	" LATIN SMALL LETTER Z WITH ACUTE
/z	<Char-0x017c>	" LATIN SMALL LETTER Z WITH DOT ABOVE

/A	<Char-0x0104>	" LATIN CAPITAL LETTER A WITH OGONEK
/C	<Char-0x0106>	" LATIN CAPITAL LETTER C WITH ACUTE
/E	<Char-0x0118>	" LATIN CAPITAL LETTER E WITH OGONEK
/L	<Char-0x0141>	" LATIN CAPITAL LETTER L WITH STROKE
/N	<Char-0x0143>	" LATIN CAPITAL LETTER N WITH ACUTE
/O	<Char-0x00d3>	" LATIN CAPITAL LETTER O WITH ACUTE
/S	<Char-0x015a>	" LATIN CAPITAL LETTER S WITH ACUTE
/X	<Char-0x0179>	" LATIN CAPITAL LETTER Z WITH ACUTE
/Z	<Char-0x017b>	" LATIN CAPITAL LETTER Z WITH DOT ABOVE

