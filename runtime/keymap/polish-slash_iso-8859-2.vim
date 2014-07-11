" Polish letters keymap for iso-8859-2
" Maintainer:	HS6_06	<hs6_06@o2.pl>
" Last Changed:	2005 Jan 12
" Current version: 1.0.2
" History: polish-slash.vim

" This keymap adds the special Polish letters
" to an existing Latin keyboard.
" All chars as usual except:
" Polish:
"   instead of AltGr+{acelnosxz} you ve to use "/" followed by {acelnosxz}

" short keymap name for statusline
let b:keymap_name = "PL-slash-ISO"

scriptencoding latin1

loadkeymap

" Polish letters
/a	<Char-177>	" LATIN SMALL LETTER A WITH OGONEK
/c	<Char-230>	" LATIN SMALL LETTER C WITH ACUTE
/e	<Char-234>	" LATIN SMALL LETTER E WITH OGONEK
/l	<Char-179>	" LATIN SMALL LETTER L WITH STROKE
/n	<Char-241>	" LATIN SMALL LETTER N WITH ACUTE
/o	<Char-243>	" LATIN SMALL LETTER O WITH ACUTE
/s	<Char-182>	" LATIN SMALL LETTER S WITH ACUTE
/x	<Char-188>	" LATIN SMALL LETTER Z WITH ACUTE
/z	<Char-191>	" LATIN SMALL LETTER Z WITH DOT ABOVE

/A	<Char-161>	" LATIN CAPITAL LETTER A WITH OGONEK
/C	<Char-198>	" LATIN CAPITAL LETTER C WITH ACUTE
/E	<Char-202>	" LATIN CAPITAL LETTER E WITH OGONEK
/L	<Char-163>	" LATIN CAPITAL LETTER L WITH STROKE
/N	<Char-209>	" LATIN CAPITAL LETTER N WITH ACUTE
/O	<Char-211>	" LATIN CAPITAL LETTER O WITH ACUTE
/S	<Char-166>	" LATIN CAPITAL LETTER S WITH ACUTE
/X	<Char-172>	" LATIN CAPITAL LETTER Z WITH ACUTE
/Z	<Char-175>	" LATIN CAPITAL LETTER Z WITH DOT ABOVE

