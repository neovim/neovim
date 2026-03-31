" Polish letters keymap for cp852
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
let b:keymap_name = "PL-slash-DOS"

scriptencoding latin1

loadkeymap

" Polish letters
/a	<Char-165>	" LATIN SMALL LETTER A WITH OGONEK
/c	<Char-134>	" LATIN SMALL LETTER C WITH ACUTE
/e	<Char-169>	" LATIN SMALL LETTER E WITH OGONEK
/l	<Char-136>	" LATIN SMALL LETTER L WITH STROKE
/n	<Char-228>	" LATIN SMALL LETTER N WITH ACUTE
/o	<Char-162>	" LATIN SMALL LETTER O WITH ACUTE
/s	<Char-152>	" LATIN SMALL LETTER S WITH ACUTE
/x	<Char-171>	" LATIN SMALL LETTER Z WITH ACUTE
/z	<Char-190>	" LATIN SMALL LETTER Z WITH DOT ABOVE

/A	<Char-164>	" LATIN CAPITAL LETTER A WITH OGONEK
/C	<Char-143>	" LATIN CAPITAL LETTER C WITH ACUTE
/E	<Char-168>	" LATIN CAPITAL LETTER E WITH OGONEK
/L	<Char-157>	" LATIN CAPITAL LETTER L WITH STROKE
/N	<Char-227>	" LATIN CAPITAL LETTER N WITH ACUTE
/O	<Char-224>	" LATIN CAPITAL LETTER O WITH ACUTE
/S	<Char-151>	" LATIN CAPITAL LETTER S WITH ACUTE
/X	<Char-141>	" LATIN CAPITAL LETTER Z WITH ACUTE
/Z	<Char-189>	" LATIN CAPITAL LETTER Z WITH DOT ABOVE

