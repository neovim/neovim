" Vim Keymap file for Russian characters
" layout English-US 104 key 'QWERTY'
"
" Maintainer:	 Restorer <restorer@mail2k.ru>
" Last Changed:	 25 Apr 2023
" Version:	 3.3
" Description:	 описание дано после изображений клавиатуры

" Расположение символов для русского языка при подключенном файле с раскладкой
" клавиатуры «русская типографская» (russian-typograph.vim). Версия 3.3


"		  Ни одна из клавиш модификаторов не нажата

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  | % | ! | — | « | » | : | , | . | ? | ( | ) | ‐ | ; | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| | й | ц | у | к | е | н | г | ш | щ | з | х | ъ |  /  |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps | ф | ы | в | а | п | р | о | л | д | ж | э |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | Shift  | я | ч | с | м | и | т | ь | б | ю | ё |  Shift   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | Ctrl |  | Alt |                          | Alt  |  | Ctrl |
"	  '------'  '-----'--------------------------'------'  '------'


"			    Нажата клавиша SHIFT

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  | = | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | - | + | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| | Й | Ц | У | К | Е | Н | Г | Ш | Щ | З | Х | Ъ |  §  |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps | Ф | Ы | В | А | П | Р | О | Л | Д | Ж | Э |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | SHIFT  | Я | Ч | С | М | И | Т | Ь | Б | Ю | Ё |   SHIFT  |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | Ctrl |  | Alt |                          | Alt  |  | Ctrl |
"	  '------'  '-----'--------------------------'------'  '------'


"			     Нажата клавиша ALT

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  | ` | № | – | „ | “ |   |   | … |   |   |   | ‑ | ± | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| |   |   |   |   |   |   |   |   |   |   | [ | ] |  \  |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps |   |   |   |   |   | ₽ |   |   |   |   | ' |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | Shift  |   |   |   |   |   |   |   |   |   |   |  Shift   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | Ctrl |  | ALT |          NNBSP           | ALT  |  | Ctrl |
"	  '------'  '-----'--------------------------'------'  '------'


"			 Нажаты клавиши SHIFT и ALT

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  | ~ |   | @ | # | $ |   | ^ | & | * |   |   | _ |   | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| |   |   |   |   |   |   |   |   |   |   | { | } |  |  |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps |   |   |   |   |   |   |   |   |   |   | " |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | SHIFT  |   |   |   |   |   |   |   | < | > |   |  SHIFT   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | Ctrl |  | ALT |                          | ALT  |  | Ctrl |
"	  '------'  '-----'--------------------------'------'  '------'


"			 Нажаты клавиши SHIFT и CTRL

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  |   |   |   |   |   |   |   |   |   |   |   |   |   | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| |   |   |   |   |   |   |   |   |   |   |   |   |     |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps |   |   |   |   |   |   |   |   |   |   |   |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | SHIFT  |   |   |   |   |   |   |   |   |   |   |  SHIFT   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | CTRL |  | Alt |          NBSP            | Alt  |  | CTRL |
"	  '------'  '-----'--------------------------'------'  '------'


"			 Нажаты клавиши ALT и CTRL

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  |   |   |   |   |   |   |   |   |   |   |   |   |   | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| |   |   | у́ |   | е́ |   |   |   |   |   |   |   |     |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps |   | ы́ |   | а́ |   |   | о́ |   |   |   | э́ |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | Shift  | я́ |   |   |   | и́ |   |   |   | ю́ |   |  Shift   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | CTRL |  | ALT |                          | ALT  |  | CTRL |
"	  '------'  '-----'--------------------------'------'  '------'


"			 Нажаты клавиши SHIFT, ALT и CTRL

"	  ,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
"	  |   |   |   |   |   |   |   |   |   |   |   |   |   | <---  |
"	  |---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
"	  | ->| |   |   | У́ |   | Е́ |   |   |   |   |   |   |   |     |
"	  |-----',--',--',--',--',--',--',--',--',--',--',--',--'-----|
"	  | Caps |   | Ы́ |   | А́ |   |   | О́ |   |   |   | Э́ |  Enter |
"	  |------'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'--------|
"	  | SHIFT  | Я́ |   |   |   | И́ |   |   |   | Ю́ |   |  SHIFT   |
"	  |------,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
"	  | CTRL |  | ALT |                          | ALT  |  | CTRL |
"	  '------'  '-----'--------------------------'------'  '------'


" Раскладка сделана на основе раскладки «русская машинопись» (KBDRU1.DLL),
" поставляемой в составе ОС MS Windows.
"
" Как видите, принцип достаточно простой, — при наборе русского текста все
" буквы, знаки пунктуации и большинство специальных символов находятся под
" пальцами и их набор не требует нажатия каких-то дополнительных клавиш.  При
" наборе символов, которые отсутствуют в русской раскладке, но есть в раскладке
" US-International, требуется нажать или клавишу <ALT>, если в английской
" раскладке они набираются без модификаторов, или нажать <ALT>+<SHIFT>, если они
" набираются с модификатором <SHIFT>.

" scriptencoding utf-8

let b:keymap_name ="RUS"

loadkeymap

"		DIGITAL ROW

"	None of the modifier keys are pressed
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

"	The SHIFT key is pressed
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

"	The ALT key pressed
<A-char-0x0060>	    <char-0x0060>	" GRAVE ACCENT 
<A-char-0x0031>	    <char-0x2116>       " NUMERO SIGN
<A-char-0x0032>	    <char-0x2013>	" EN DASH
<A-char-0x0033>	    <char-0x201e>	" DOUBLE LOW-9 QUOTATION MARK
<A-char-0x0034>	    <char-0x201c>	" LEFT DOUBLE QUOTATION MARK
<A-char-0x0037>	    <char-0x2026>	" HORIZONTAL ELLIPSIS
<A-char-0x002d>	    <char-0x2011>	" NON-BREAKING HYPHEN
<A-char-0x003d>	    <char-0x00b1>	" PLUS-MINUS SIGN

"	The SHIFT and ALT keys pressed
<A-char-0x007e>	    <char-0x007e>	" TILDE
<A-char-0x0040>	    <char-0x0040>	" COMMERCIAL AT
<A-char-0x0023>	    <char-0x0023>	" NUMBER SIGN
<A-char-0x0024>	    <char-0x0024>	" DOLLAR SIGN
<A-char-0x005e>	    <char-0x005e>	" CIRCUMFLEX ACCENT
<A-char-0x0026>	    <char-0x0026>	" AMPERSAND
<A-char-0x002a>	    <char-0x002a>	" ASTERISK
<A-char-0x005f>	    <char-0x005f>	" LOW LINE


"		ALPHABETICAL 1st ROW

"	None of the modifier keys are pressed
<char-0x0071>	    <char-0x0439>	" CYRILLIC SMALL LETTER SHORT I
<char-0x0077>	    <char-0x0446>	" CYRILLIC SMALL LETTER TSE
<char-0x0065>	    <char-0x0443>	" CYRILLIC SMALL LETTER U
<char-0x0072>	    <char-0x043a>	" CYRILLIC SMALL LETTER KA
<char-0x0074>	    <char-0x0435>	" CYRILLIC SMALL LETTER IE
<char-0x0079>	    <char-0x043d>	" CYRILLIC SMALL LETTER EN
<char-0x0075>	    <char-0x0433>	" CYRILLIC SMALL LETTER GHE
<char-0x0069>	    <char-0x0448>	" CYRILLIC SMALL LETTER SHA
<char-0x006f>	    <char-0x0449>	" CYRILLIC SMALL LETTER SHCHA
<char-0x0070>	    <char-0x0437>	" CYRILLIC SMALL LETTER ZE
<char-0x005b>	    <char-0x0445>	" CYRILLIC SMALL LETTER HA
<char-0x005d>	    <char-0x044a>	" CYRILLIC SMALL LETTER HARD SIGN

"	The SHIFT key is pressed
<char-0x0051>	    <char-0x0419>	" CYRILLIC CAPITAL LETTER SHORT I
<char-0x0057>	    <char-0x0426>	" CYRILLIC CAPITAL LETTER TSE
<char-0x0045>	    <char-0x0423>	" CYRILLIC CAPITAL LETTER U
<char-0x0052>	    <char-0x041a>	" CYRILLIC CAPITAL LETTER KA
<char-0x0054>	    <char-0x0415>	" CYRILLIC CAPITAL LETTER IE
<char-0x0059>	    <char-0x041d>	" CYRILLIC CAPITAL LETTER EN
<char-0x0055>	    <char-0x0413>	" CYRILLIC CAPITAL LETTER GHE
<char-0x0049>	    <char-0x0428>	" CYRILLIC CAPITAL LETTER SHA
<char-0x004f>	    <char-0x0429>	" CYRILLIC CAPITAL LETTER SHCHA
<char-0x0050>	    <char-0x0417>	" CYRILLIC CAPITAL LETTER ZE
<char-0x007b>	    <char-0x0425>	" CYRILLIC CAPITAL LETTER HA
<char-0x007d>	    <char-0x042a>	" CYRILLIC CAPITAL LETTER HARD SIGN

"	The ALT key pressed
<A-char-0x005b>	    <char-0x005b>       " LEFT SQUARE BRACKET
<A-char-0x005d>	    <char-0x005d>       " RIGHT SQUARE BRACKET

"	The SHIFT and ALT keys pressed
<A-char-0x007b>	    <char-0x007b>       " LEFT CURLY BRACKET
<A-char-0x007d>	    <char-0x007d>       " RIGHT CURLY BRACKET

"	The ALT and CTRL key pressed
<A-C-char-0x0065>    <char-0x0443><char-0x0301>	" CYRILLIC SMALL LETTER U with COMBINING ACUTE ACCENT
<A-C-char-0x0074>    <char-0x0435><char-0x0301>	" CYRILLIC SMALL LETTER IE with COMBINING ACUTE ACCENT

"	The SHIFT and ALT and CTRL keys pressed
<S-A-C-char-0x0045>    <char-0x0423><char-0x0301>   " CYRILLIC CAPITAL LETTER U with COMBINING ACUTE ACCENT
<S-A-C-char-0x0054>    <char-0x0415><char-0x0301>   " CYRILLIC CAPITAL LETTER IE with COMBINING ACUTE ACCENT


"		ALPHABETIC 2st ROW

"	None of the modifier keys are pressed
<char-0x0061>	    <char-0x0444>	" CYRILLIC SMALL LETTER EF
<char-0x0073>	    <char-0x044b>	" CYRILLIC SMALL LETTER YERU
<char-0x0064>	    <char-0x0432>	" CYRILLIC SMALL LETTER VE
<char-0x0066>	    <char-0x0430>	" CYRILLIC SMALL LETTER A
<char-0x0067>	    <char-0x043f>	" CYRILLIC SMALL LETTER PE
<char-0x0068>	    <char-0x0440>	" CYRILLIC SMALL LETTER ER
<char-0x006a>	    <char-0x043e>	" CYRILLIC SMALL LETTER O
<char-0x006b>	    <char-0x043b>	" CYRILLIC SMALL LETTER EL
<char-0x006c>	    <char-0x0434>	" CYRILLIC SMALL LETTER DE
<char-0x003b>	    <char-0x0436>	" CYRILLIC SMALL LETTER ZHE
<char-0x0027>	    <char-0x044d>	" CYRILLIC SMALL LETTER E

"	The SHIFT key is pressed
<char-0x0041>	    <char-0x0424>	" CYRILLIC CAPITAL LETTER EF
<char-0x0053>	    <char-0x042b>	" CYRILLIC CAPITAL LETTER YERU
<char-0x0044>	    <char-0x0412>	" CYRILLIC CAPITAL LETTER VE
<char-0x0046>	    <char-0x0410>	" CYRILLIC CAPITAL LETTER A
<char-0x0047>	    <char-0x041f>	" CYRILLIC CAPITAL LETTER PE
<char-0x0048>	    <char-0x0420>	" CYRILLIC CAPITAL LETTER ER
<char-0x004a>	    <char-0x041e>	" CYRILLIC CAPITAL LETTER O
<char-0x004b>	    <char-0x041b>	" CYRILLIC CAPITAL LETTER EL
<char-0x004c>	    <char-0x0414>	" CYRILLIC CAPITAL LETTER DE
<char-0x003a>	    <char-0x0416>	" CYRILLIC CAPITAL LETTER ZHE
<char-0x0022>	    <char-0x042d>	" CYRILLIC CAPITAL LETTER E

"	The ALT key pressed
<A-char-0x0027>	    <char-0x0027>       " APOSTROPHE
<A-char-0x0068>	    <char-0x20bd>	" RUBLE SIGN

"	The SHIFT and ALT keys pressed
<A-char-0x0022>	    <char-0x0022>       " QUOTATION MARK

"	The ALT and CTRL key pressed
<A-C-char-0x0073>    <char-0x044b><char-0x0301>	" CYRILLIC SMALL LETTER YERU with COMBINING ACUTE ACCENT
<A-C-char-0x0066>    <char-0x0430><char-0x0301>	" CYRILLIC SMALL LETTER A with COMBINING ACUTE ACCENT
<A-C-char-0x006a>    <char-0x043e><char-0x0301>	" CYRILLIC SMALL LETTER O with COMBINING ACUTE ACCENT
<A-C-char-0x0027>    <char-0x044d><char-0x0301>	" CYRILLIC SMALL LETTER E with COMBINING ACUTE ACCENT

"	The SHIFT and ALT and CTRL keys pressed
<S-A-C-char-0x0053>    <char-0x042b><char-0x0301>   " CYRILLIC CAPITAL LETTER YERU with COMBINING ACUTE ACCENT
<S-A-C-char-0x0046>    <char-0x0410><char-0x0301>   " CYRILLIC CAPITAL LETTER A with COMBINING ACUTE ACCENT
<S-A-C-char-0x004a>    <char-0x041e><char-0x0301>   " CYRILLIC CAPITAL LETTER O with COMBINING ACUTE ACCENT
<S-A-C-char-0x0022>    <char-0x042d><char-0x0301>   " CYRILLIC CAPITAL LETTER E with COMBINING ACUTE ACCENT


"		ALPHABETIC 3st ROW

"	None of the modifier keys are pressed
<char-0x007a>	    <char-0x044f>	" CYRILLIC SMALL LETTER YA
<char-0x0078>	    <char-0x0447>	" CYRILLIC SMALL LETTER CHE
<char-0x0063>	    <char-0x0441>	" CYRILLIC SMALL LETTER ES
<char-0x0076>	    <char-0x043c>	" CYRILLIC SMALL LETTER EM
<char-0x0062>	    <char-0x0438>	" CYRILLIC SMALL LETTER I
<char-0x006e>	    <char-0x0442>	" CYRILLIC SMALL LETTER TE
<char-0x006d>	    <char-0x044c>	" CYRILLIC SMALL LETTER SOFT SIGN
<char-0x002c>	    <char-0x0431>	" CYRILLIC SMALL LETTER BE
<char-0x002e>	    <char-0x044e>	" CYRILLIC SMALL LETTER YU
<char-0x002f>	    <char-0x0451>	" CYRILLIC SMALL LETTER IO

"	The SHIFT key is pressed
<char-0x005a>	    <char-0x042f>	" CYRILLIC CAPITAL LETTER YA
<char-0x0058>	    <char-0x0427>	" CYRILLIC CAPITAL LETTER CHE
<char-0x0043>	    <char-0x0421>	" CYRILLIC CAPITAL LETTER ES
<char-0x0056>	    <char-0x041c>	" CYRILLIC CAPITAL LETTER EM
<char-0x0042>	    <char-0x0418>	" CYRILLIC CAPITAL LETTER I
<char-0x004e>	    <char-0x0422>	" CYRILLIC CAPITAL LETTER TE
<char-0x004d>	    <char-0x042c>	" CYRILLIC CAPITAL LETTER SOFT SIGN
<char-0x003c>	    <char-0x0411>	" CYRILLIC CAPITAL LETTER BE
<char-0x003e>	    <char-0x042e>	" CYRILLIC CAPITAL LETTER YU
<char-0x003f>	    <char-0x0401>	" CYRILLIC CAPITAL LETTER IO

"	The ALT key pressed


"	The SHIFT and ALT keys pressed
<A-char-0x003c>	    <char-0x003c>       " LESS-THAN SIGN
<A-char-0x003e>	    <char-0x003e>       " GREATER-THAN SIGN

"	The ALT and CTRL key pressed
<A-C-char-0x007a>    <char-0x044f><char-0x0301>	" CYRILLIC SMALL LETTER YA with COMBINING ACUTE ACCENT
<A-C-char-0x0062>    <char-0x0438><char-0x0301>	" CYRILLIC SMALL LETTER I with COMBINING ACUTE ACCENT
<A-C-char-0x002e>    <char-0x044e><char-0x0301>	" CYRILLIC SMALL LETTER YU with COMBINING ACUTE ACCENT

"	The SHIFT and ALT and CTRL keys pressed
<S-A-C-char-0x005a>    <char-0x042f><char-0x0301>   " CYRILLIC CAPITAL LETTER YA with COMBINING ACUTE ACCENT
<S-A-C-char-0x0042>    <char-0x0418><char-0x0301>   " CYRILLIC CAPITAL LETTER I with COMBINING ACUTE ACCENT
<S-A-C-char-0x003e>    <char-0x042e><char-0x0301>   " CYRILLIC CAPITAL LETTER Y with COMBINING ACUTE ACCENT


"		VK_OEM_5 key (scan code 2b)

"	None of the modifier keys are pressed
<char-0x005c>	    <char-0x002f>	" SOLIDUS

"	The SHIFT key is pressed
<char-0x007c>	    <char-0x00a7>	" SECTION SIGN

"	The ALT key is pressed
<A-char-0x005c>	    <char-0x005c>	" REVERSE SOLIDUS

"	The SHIFT and ALT keys pressed
<A-char-0x007c>	    <char-0x007c>       " VERTICAL LINE


"		SPACE BAR key

"	The ALT key pressed
<A-char-0x0020>	    <char-0x202f>	" NARROW NO-BREAK SPACE

"	The SHIFT and CTRL keys pressed
<S-C-char-0x0020>   <char-0x00A0>	" NO-BREAK SPACE

"	    \///\\

