" codepage 1255 on Windows is equal to ISO 8859-8 but it
" adds in the vowel points, known as 'niqud', which are present in
" CP1255: Note: there are several 'standards' for placement of the vowel
" points, and I ignored all of them.  Since we can input English by simply
" pressing Ctrl-^ and eliminating this map, I saw no reason to try to use
" exotic key locations.  If you don't like it, that's just too bad :-)
let b:keymap_name = "hebp"
loadkeymap
K	<char-234>	" final kaf
M	<char-237>	" final mem
N	<char-239>	" final nun
P	<char-243>	" final pe
T	<char-232>	" tet
X	<char-245>	" final tsadi
a	<char-224>	" alef
b	<char-225>	" bet
d	<char-227>	" dalet
g	<char-226>	" gimel
h	<char-228>	" he
j	<char-231>	" het
k	<char-235>	" kaf
l	<char-236>	" lamed
m	<char-238>	" mem
n	<char-240>	" nun
s	<char-241>	" samekh
p	<char-244>	" pe
q	<char-247>	" qof
r	<char-248>	" resh
t	<char-250>	" tav
u	<char-242>	" ayin
v	<char-229>	" vav
w	<char-249>	" shin
x	<char-246>	" tsadi
y	<char-233>	" yod
z	<char-230>	" zayin
" vowels:
A:    <Char-192>  " sheva
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
]R      <ÌChar-207>	" rafe
]p      <Char-208>      " paseq
SR	<Char-209>	" shin-dot
SL	<Char-210>	" sin-dot
]P	<Char-211>	" sof-pasuq
VV	<Char-212>    " double-vav
VY	<Char-213>    " vav-yod
YY	<Char-214>    " yod-yod
