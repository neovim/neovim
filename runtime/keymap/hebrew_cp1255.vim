" add in the vowel points, known as 'niqud', which are present in
" CP1255: Note: there are several 'standards' for placement of the vowel
" points, and I ignored all of them.  Since we can input English by simply
" pressing Ctrl-^ and eliminating this map, I saw no reason to try to use
" exotic key locations.  If you don't like it, that's just too bad :-)
let b:keymap_name = "heb"
loadkeymap
a	<char-249>	" ש - shin
b	<char-240>	" נ - nun
c	<char-225>	" ב - bet
d	<char-226>	" ג - gimel
e	<char-247>	" ק - qof
f	<char-235>	" כ - kaf
g	<char-242>	" ע - ayin
h	<char-233>	" י - yod
i	<char-239>	" ן - final nun
j	<char-231>	" ח - het
k	<char-236>	" ל - lamed
l	<char-234>	" ך - final kaf
m	<char-246>	" צ - tsadi
n	<char-238>	" מ - mem
o	<char-237>	" ם - final mem
p	<char-244>	" פ - pe
q	/		" / - slash
r	<char-248>	" ר - resh
s	<char-227>	" ד - dalet
t	<char-224>	" א - alef
u	<char-229>	" ו - vav
v	<char-228>	" ה - he
w	'		" ' - single-quote
x	<char-241>	" ס - samekh
y	<char-232>	" ט - tet
z	<char-230>	" ז - zayin
,	<char-250>	" ת - tav
.	<char-245>	" ץ - final tsadi
;	<char-243>	" ף - final pe
'	,		" , - comma
/	.		" . - period
`	;		" ; - semicolon
" vowels:
A:	<Char-192>	" sheva
HE	<Char-193>	" hataf segol
HA	<Char-194>	" hataf patah
HO	<Char-195>	" hataf qamats
I	<Char-196>	" hiriq
AY	<Char-197>	" tsere
E	<Char-198>	" segol
AA	<Char-199>	" patah
AO	<Char-200>	" qamats
O	<Char-201>	" holam
U	<Char-203>	" qubuts
D	<Char-204>	" dagesh
]T	<Char-205>	" meteg
]Q	<Char-206>	" maqaf
]R      <ּChar-207>	" rafe
]p      <Char-208>      " paseq
SR	<Char-209>	" shin-dot
SL	<Char-210>	" sin-dot
]P	<Char-211>	" sof-pasuq
VV	<Char-212>    " double-vav
VY	<Char-213>    " vav-yod
YY	<Char-214>    " yod-yod
