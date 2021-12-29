" Vim Keymap file for Russian characters
" layout English-US standard 104 key 'QWERTY', 'JCUKEN'
"
" Maintainer:	Restorer <restorers@users.sourceforge.net>
" Last Changed: 20 Jan 2019
" Description:  Раскладка сделана на основе раскладки «русская машинопись»
" (KBDRU1.DLL), поставляемой в составе ОС MS Windows. Эта раскладка позволяет
" печать практически все знаки препинания используя цифровой ряд и не требуя при
" этом нажатия дополнительных клавиш, ну и также удобное расположение буквы «Ё».
" Однако были внесены некоторые дополнения (улучшения?), в частности:
" ‐ раздельные символы круглых скобок (), расположены на тех же позициях, что и
" в US-International;
" ‐ раздельные символы типографских кавычек «», расположены на клавишах «3» и
" «4» соответственно;
" ‐ на этих же клавишах находятся внутренние кавычки “лапки”, набираемые при
" нажатой клавише «ALT»;
" ‐ возможность набирать символы, отсутствующие в русской раскладке клавиатуры,
" а именно @#$^&*{}[]"'`~<>, которые расположены на тех же местах, что и раньше.
" Для этого не требуется переключаться в латинскую раскладку клавиатуры, а
" оставаясь в русской, использовать для этого дополнительные клавиши «SHIFT» и
" «ALT»;
" ‐ и ещё несколько удобств, которые позволяют быстро и с минимальными усилиями
" набирать текст.

scriptencoding utf-8

" Переключение языка ввода со стандартного сочетания <CTRL+^> на указанные ниже
" Для режимов вставки и замены
""или SHIFT+SPACE
"        inoremap <S-Space> <C-^>
""или CTRL+SPACE"
"        inoremap <C-Space> <C-^>
" Для режима командной строки
""или SHIFT+SPACE
"        cnoremap <S-Space> <C-^>
""или CTRL+SPACE"
"        cnoremap <C-Space> <C-^>
" Одной командой для режимов вставки, замены и командной строки
"        noremap! <S-Space> <C-^>
"        noremap! <C-Space> <C-^>
"
" Стандартное переключение по CTRL+^ после этих переназначений также сохраняется

let b:keymap_name ="RUS"

loadkeymap

"	    DIGITAL ROW

"	The Shift key is not pressed
"
<char-0x0060>	    <char-0x0025>	" PERCENT SIGN
<char-0x0031>	    <char-0x0021>	" EXCLAMATION MARK
<char-0x0032>	    <char-0x2014>	" EM DASH
<char-0x0033>	    <char-0x00ab>	" LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
<char-0x0034>	    <char-0x00bb>	" RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
<char-0x0035>	    <char-0x003a>	" COLON
<char-0x0036>	    <char-0x002c>	" COMMA
<char-0x0037>	    <char-0x002e>	" FULL STOP
<char-0x0038>	    <char-0x003f>	" QUESTION MARK
<char-0x0039>	    <char-0x0028>	" LEFT PARENTHESIS
<char-0x0030>	    <char-0x0029>	" RIGHT PARENTHESIS
<char-0x002d>	    <char-0x2010>	" HYPHEN
<char-0x003d>	    <char-0x003b>	" SEMICOLON

"	The Shift key is pressed

<char-0x007e>	    <char-0x003d>	" EQUALS SIGN
<char-0x0021>	    <char-0x0031>	" DIGIT ONE
<char-0x0040>	    <char-0x0032>	" DIGIT TWO
<char-0x0023>	    <char-0x0033>	" DIGIT THREE
<char-0x0024>	    <char-0x0034>	" DIGIT FOUR
<char-0x0025>	    <char-0x0035>	" DIGIT FIVE
<char-0x005e>	    <char-0x0036>	" DIGIT SIX
<char-0x0026>	    <char-0x0037>	" DIGIT SEVEN
<char-0x002a>	    <char-0x0038>	" DIGIT EIGHT
<char-0x0028>	    <char-0x0039>	" DIGIT NINE
<char-0x0029>	    <char-0x0030>	" DIGIT ZERO
<char-0x005f>	    <char-0x002d>	" HYPHEN-MINUS
<char-0x002b>	    <char-0x002b>	" PLUS SIGN

"	    ALPHABETICAL 1st ROW

<char-0x0071>	    <char-0x0439>	" CYRILLIC SMALL LETTER SHORT I
<char-0x0051>	    <char-0x0419>	" CYRILLIC CAPITAL LETTER SHORT I
<char-0x0077>	    <char-0x0446>	" CYRILLIC SMALL LETTER TSE
<char-0x0057>	    <char-0x0426>	" CYRILLIC CAPITAL LETTER TSE
<char-0x0065>	    <char-0x0443>	" CYRILLIC SMALL LETTER U
<char-0x0045>	    <char-0x0423>	" CYRILLIC CAPITAL LETTER U
<char-0x0072>	    <char-0x043a>	" CYRILLIC SMALL LETTER KA
<char-0x0052>	    <char-0x041a>	" CYRILLIC CAPITAL LETTER KA
<char-0x0074>	    <char-0x0435>	" CYRILLIC SMALL LETTER IE
<char-0x0054>	    <char-0x0415>	" CYRILLIC CAPITAL LETTER IE
<char-0x0079>	    <char-0x043d>	" CYRILLIC SMALL LETTER EN
<char-0x0059>	    <char-0x041d>	" CYRILLIC CAPITAL LETTER EN
<char-0x0075>	    <char-0x0433>	" CYRILLIC SMALL LETTER GHE
<char-0x0055>	    <char-0x0413>	" CYRILLIC CAPITAL LETTER GHE
<char-0x0069>	    <char-0x0448>	" CYRILLIC SMALL LETTER SHA
<char-0x0049>	    <char-0x0428>	" CYRILLIC CAPITAL LETTER SHA
<char-0x006f>	    <char-0x0449>	" CYRILLIC SMALL LETTER SHCHA
<char-0x004f>	    <char-0x0429>	" CYRILLIC CAPITAL LETTER SHCHA
<char-0x0070>	    <char-0x0437>	" CYRILLIC SMALL LETTER ZE
<char-0x0050>	    <char-0x0417>	" CYRILLIC CAPITAL LETTER ZE
<char-0x005b>	    <char-0x0445>	" CYRILLIC SMALL LETTER HA
<char-0x007b>	    <char-0x0425>	" CYRILLIC CAPITAL LETTER HA
<char-0x005d>	    <char-0x044a>	" CYRILLIC SMALL LETTER HARD SIGN
<char-0x007d>	    <char-0x042a>	" CYRILLIC CAPITAL LETTER HARD SIGN

"	    ALPHABETIC 2nd ROW

<char-0x0061>	    <char-0x0444>	" CYRILLIC SMALL LETTER EF
<char-0x0041>	    <char-0x0424>	" CYRILLIC CAPITAL LETTER EF
<char-0x0073>	    <char-0x044b>	" CYRILLIC SMALL LETTER YERU
<char-0x0053>	    <char-0x042b>	" CYRILLIC CAPITAL LETTER YERU
<char-0x0064>	    <char-0x0432>	" CYRILLIC SMALL LETTER VE
<char-0x0044>	    <char-0x0412>	" CYRILLIC CAPITAL LETTER VE
<char-0x0066>	    <char-0x0430>	" CYRILLIC SMALL LETTER A
<char-0x0046>	    <char-0x0410>	" CYRILLIC CAPITAL LETTER A
<char-0x0067>	    <char-0x043f>	" CYRILLIC SMALL LETTER PE
<char-0x0047>	    <char-0x041f>	" CYRILLIC CAPITAL LETTER PE
<char-0x0068>	    <char-0x0440>	" CYRILLIC SMALL LETTER ER
<char-0x0048>	    <char-0x0420>	" CYRILLIC CAPITAL LETTER ER
<char-0x006a>	    <char-0x043e>	" CYRILLIC SMALL LETTER O
<char-0x004a>	    <char-0x041e>	" CYRILLIC CAPITAL LETTER O
<char-0x006b>	    <char-0x043b>	" CYRILLIC SMALL LETTER EL
<char-0x004b>	    <char-0x041b>	" CYRILLIC CAPITAL LETTER EL
<char-0x006c>	    <char-0x0434>	" CYRILLIC SMALL LETTER DE
<char-0x004c>	    <char-0x0414>	" CYRILLIC CAPITAL LETTER DE
<char-0x003b>	    <char-0x0436>	" CYRILLIC SMALL LETTER ZHE
<char-0x003a>	    <char-0x0416>	" CYRILLIC CAPITAL LETTER ZHE
<char-0x0027>	    <char-0x044d>	" CYRILLIC SMALL LETTER E
<char-0x0022>	    <char-0x042d>	" CYRILLIC CAPITAL LETTER E

"	    ALPHABETIC 3rd ROW

<char-0x007a>	    <char-0x044f>	" CYRILLIC SMALL LETTER YA
<char-0x005a>	    <char-0x042f>	" CYRILLIC CAPITAL LETTER YA
<char-0x0078>	    <char-0x0447>	" CYRILLIC SMALL LETTER CHE
<char-0x0058>	    <char-0x0427>	" CYRILLIC CAPITAL LETTER CHE
<char-0x0063>	    <char-0x0441>	" CYRILLIC SMALL LETTER ES
<char-0x0043>	    <char-0x0421>	" CYRILLIC CAPITAL LETTER ES
<char-0x0076>	    <char-0x043c>	" CYRILLIC SMALL LETTER EM
<char-0x0056>	    <char-0x041c>	" CYRILLIC CAPITAL LETTER EM
<char-0x0062>	    <char-0x0438>	" CYRILLIC SMALL LETTER I
<char-0x0042>	    <char-0x0418>	" CYRILLIC CAPITAL LETTER I
<char-0x006e>	    <char-0x0442>	" CYRILLIC SMALL LETTER TE
<char-0x004e>	    <char-0x0422>	" CYRILLIC CAPITAL LETTER TE
<char-0x006d>	    <char-0x044c>	" CYRILLIC SMALL LETTER SOFT SIGN
<char-0x004d>	    <char-0x042c>	" CYRILLIC CAPITAL LETTER SOFT SIGN
<char-0x002c>	    <char-0x0431>	" CYRILLIC SMALL LETTER BE
<char-0x003c>	    <char-0x0411>	" CYRILLIC CAPITAL LETTER BE
<char-0x002e>	    <char-0x044e>	" CYRILLIC SMALL LETTER YU
<char-0x003e>	    <char-0x042e>	" CYRILLIC CAPITAL LETTER YU
<char-0x002f>	    <char-0x0451>	" CYRILLIC SMALL LETTER IO
<char-0x003f>	    <char-0x0401>	" CYRILLIC CAPITAL LETTER IO

"	    VK_OEM_5 key (scan code 2b)

"	The Shift key is not pressed
<char-0x005c>	    <char-0x002f>	" SOLIDUS
"	The Shift key is pressed
<char-0x007c>	    <char-0x005c>	" REVERSE SOLIDUS

"	    Alt key pressed

<A-char-0x0060>	    <char-0x0060>	" GRAVE ACCENT 
<A-char-0x0031>	    <char-0x2116>       " NUMERO SIGN
<A-char-0x0033>	    <char-0x201c>	" LEFT DOUBLE QUOTATION MARK
<A-char-0x0034>	    <char-0x201d>	" RIGHT DOUBLE QUOTATION MARK
<A-char-0x005b>	    <char-0x005b>       " LEFT SQUARE BRACKET
<A-char-0x005d>	    <char-0x005d>       " RIGHT SQUARE BRACKET
<A-char-0x0027>	    <char-0x0027>       " APOSTROPHE

"	    Alt and Shift keys pressed

<A-char-0x007e>	    <char-0x007e>	" TILDE
<A-char-0x0040>	    <char-0x0040>       " COMMERCIAL AT
<A-char-0x0023>	    <char-0x0023>       " NUMBER SIGN
<A-char-0x0024>	    <char-0x0024>       " DOLLAR SIGN
<A-char-0x005e>	    <char-0x005e>       " CIRCUMFLEX ACCENT
<A-char-0x0026>	    <char-0x0026>       " AMPERSAND
<A-char-0x002a>	    <char-0x002a>       " ASTERISK
<A-char-0x005f>	    <char-0x005f>       " LOW LINE
<A-char-0x007b>	    <char-0x007b>       " LEFT CURLY BRACKET
<A-char-0x007d>	    <char-0x007d>       " RIGHT CURLY BRACKET
<A-char-0x0022>	    <char-0x0022>       " QUOTATION MARK
<A-char-0x003c>	    <char-0x003c>       " LESS-THAN SIGN
<A-char-0x003e>	    <char-0x003e>       " GREATER-THAN SIGN
<A-char-0x007c>	    <char-0x007c>       " VERTICAL LINE

