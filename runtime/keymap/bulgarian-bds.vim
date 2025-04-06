" Vim keymap file for Bulgarian and Russian characters, "bds" layout.
" Most of it can be used with both utf-8 and cp1251 file encodings, except
" the accented characters which can only be stored in utf-8.
" This file itself is in utf-8.

" Maintainer: Boyko Bantchev <boykobb@gmail.com>
" URI: http://www.math.bas.bg/bantchev/vim/bulgarian-bds.vim
" Last Changed: 2010 May 4

" This keymap corresponds to what is called Bulgarian standard typewriter
" keyboard layout, or "БДС".
"
" Note that, in addition to the Bulgarian alphabet, the BDS layout prescribes
" the presence of the following characters:
"     —  The Russian letters ы (small), and Э and э (capital and small).
"     —  The latin capital letters I and V – used to type Roman numerals
"        without having to leave Cyrillic mode.
"
" Some punctuation characters present in ascii are mapped in BDS to keys
" different from the ones they occupy in the QWERTY layout, because the latter
" keys are used to type other characters.
"
" In this keymap, also defined (besides BDS) are:
"     —  The Russian letters Ё and ё (capital and small), as well as the
"        Russian capital letter Ы (see above for the small counterpart).
"        This way, using the bulgarian-bds keymap, one can access both
"        the Bulgarian and the Russian alphabets.
"     —  The quotation marks „ “ ” ‘ ’ (used in the Bulgarian and English
"        quotation styles), as well as « » (Russian quotation style).
"     —  The characters §, №, – (en-dash), — (em-dash), …, •, ·, ±, °, ¬,
"        ¤, €, ‰, †, ‡, and ¶.
"
" The keymap also defines key combinations for grave and acute accents.
" (Grave accent is used in Bulgarian, acute in Russian, but both accents
" apply to other languages as well.)
"
" For details of what key or key combination maps to what character, please
" see below the map itself.
"
" See also http://www.math.bas.bg/bantchev/vim/kbdbul.html (in Bulgarian).

scriptencoding utf-8

let b:keymap_name = "bds"

loadkeymap
D       А       CYRILLIC CAPITAL LETTER A
?       Б       CYRILLIC CAPITAL LETTER BE
L       В       CYRILLIC CAPITAL LETTER VE
H       Г       CYRILLIC CAPITAL LETTER GHE
O       Д       CYRILLIC CAPITAL LETTER DE
E       Е       CYRILLIC CAPITAL LETTER IE
E::     Ё       CYRILLIC CAPITAL LETTER IO
G       Ж       CYRILLIC CAPITAL LETTER ZHE
P       З       CYRILLIC CAPITAL LETTER ZE
R       И       CYRILLIC CAPITAL LETTER I
X       Й       CYRILLIC CAPITAL LETTER SHORT I
U       К       CYRILLIC CAPITAL LETTER KA
>       Л       CYRILLIC CAPITAL LETTER EL
:       М       CYRILLIC CAPITAL LETTER EM
K       Н       CYRILLIC CAPITAL LETTER EN
F       О       CYRILLIC CAPITAL LETTER O
M       П       CYRILLIC CAPITAL LETTER PE
<       Р       CYRILLIC CAPITAL LETTER ER
I       С       CYRILLIC CAPITAL LETTER ES
J       Т       CYRILLIC CAPITAL LETTER TE
W       У       CYRILLIC CAPITAL LETTER U
B       Ф       CYRILLIC CAPITAL LETTER EF
N       Х       CYRILLIC CAPITAL LETTER HA
{       Ц       CYRILLIC CAPITAL LETTER TSE
\"      Ч       CYRILLIC CAPITAL LETTER CHE
T       Ш       CYRILLIC CAPITAL LETTER SHA
Y       Щ       CYRILLIC CAPITAL LETTER SHCHA
C       Ъ       CYRILLIC CAPITAL LETTER HARD SIGN
CX      Ы       CYRILLIC CAPITAL LETTER YERU
A       Ь       CYRILLIC CAPITAL LETTER SOFT SIGN
V       Э       CYRILLIC CAPITAL LETTER REVERSED E
Z       Ю       CYRILLIC CAPITAL LETTER YU
S       Я       CYRILLIC CAPITAL LETTER YA
d       а       CYRILLIC SMALL LETTER A
\/      б       CYRILLIC SMALL LETTER BE
l       в       CYRILLIC SMALL LETTER VE
h       г       CYRILLIC SMALL LETTER GHE
o       д       CYRILLIC SMALL LETTER DE
e       е       CYRILLIC SMALL LETTER IE
e::     ё       CYRILLIC SMALL LETTER IO
g       ж       CYRILLIC SMALL LETTER ZHE
p       з       CYRILLIC SMALL LETTER ZE
r       и       CYRILLIC SMALL LETTER I
x       й       CYRILLIC SMALL LETTER SHORT I
u       к       CYRILLIC SMALL LETTER KA
\.      л       CYRILLIC SMALL LETTER EL
;       м       CYRILLIC SMALL LETTER EM
k       н       CYRILLIC SMALL LETTER EN
f       о       CYRILLIC SMALL LETTER O
m       п       CYRILLIC SMALL LETTER PE
,       р       CYRILLIC SMALL LETTER ER
i       с       CYRILLIC SMALL LETTER ES
j       т       CYRILLIC SMALL LETTER TE
w       у       CYRILLIC SMALL LETTER U
b       ф       CYRILLIC SMALL LETTER EF
n       х       CYRILLIC SMALL LETTER HA
[       ц       CYRILLIC SMALL LETTER TSE
'       ч       CYRILLIC SMALL LETTER CHE
t       ш       CYRILLIC SMALL LETTER SHA
y       щ       CYRILLIC SMALL LETTER SHCHA
c       ъ       CYRILLIC SMALL LETTER HARD SIGN
Q       ы       CYRILLIC SMALL LETTER YERU
a       ь       CYRILLIC SMALL LETTER SOFT SIGN
v       э       CYRILLIC SMALL LETTER REVERSED E
z       ю       CYRILLIC SMALL LETTER YU
s       я       CYRILLIC SMALL LETTER YA
_       I       LATIN CAPITAL LETTER I
+       V       LATIN CAPITAL LETTER V
$       "       QUOTATION MARK
\\      (       LEFT PARENTHESIS
|       )       RIGHT PARENTHESIS
#       +       PLUS SIGN
q       ,       COMMA
(       -       HYPHEN-MINUS
=       .       FULL STOP (PERIOD)
*       /       SOLIDUS (SLASH)
&       :       COLON
]       ;       SEMICOLON
^       =       EQUALS SIGN
@       ?       QUESTION MARK
}       §       SECTION SIGN (PARAGRAPH SIGN)
)       №       NUMERO SIGN
--      –       EN DASH
---     —       EM DASH
..      …       HORIZONTAL ELLIPSIS
``      “       LEFT DOUBLE QUOTATION MARK
''      ”       RIGHT DOUBLE QUOTATION MARK
,,      „       DOUBLE LOW-9 QUOTATION MARK
`.      ‘       LEFT SINGLE QUOTATION MARK
'.      ’       RIGHT SINGLE QUOTATION MARK
<<      «       LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
>>      »       RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
**      •       BULLET
,.      ·       MIDDLE DOT      
+-      ±       PLUS-MINUS SIGN
^o      °       DEGREE SIGN
~~      ¬       NOT SIGN
@@      ¤       CURRENCY SIGN
$$      €       EURO SIGN
%%      ‰       PER MILLE SIGN
+|      †       DAGGER
++      ‡       DOUBLE DAGGER
||      ¶       PILCROW SIGN

" Accented characters cannot map onto cp1251 – use utf-8 file encoding.
" To apply an accent to a letter, type the corresponding key combination
" to the immediate right of that letter.
^`      <char-0x300>    COMBINING GRAVE ACCENT
^'      <char-0x301>    COMBINING ACUTE ACCENT
