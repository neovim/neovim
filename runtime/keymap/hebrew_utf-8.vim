" Vim Keymap file for hebrew
" Maintainer  : Ron Aaron <ron@ronware.org>
" Last Updated: Wed 28 Feb 2001 21:28:51
" This is the standard Israeli keyboard layout with (my nonstandard locations
" for) niqud, for utf:

" Use this short name in the status line.
let b:keymap_name = "heb"
loadkeymap
a	<char-0x5e9>	" ש - shin
b	<char-0x5e0>	" נ - nun
c	<char-0x5d1>	" ב - bet
d	<char-0x5d2>	" ג - gimel
e	<char-0x5e7>	" ק - qof
f	<char-0x5db>	" כ - kaf
g	<char-0x5e2>	" ע - ayin
h	<char-0x5d9>	" י - yod
i	<char-0x5df>	" ן - final nun
j	<char-0x5d7>	" ח - het
k	<char-0x5dc>	" ל - lamed
l	<char-0x5da>	" ך - final kaf
m	<char-0x5e6>	" צ - tsadi
n	<char-0x5de>	" מ - mem
o	<char-0x5dd>	" ם - final mem
p	<char-0x5e4>	" פ - pe
q	/		" / - slash
r	<char-0x5e8>	" ר - resh
s	<char-0x5d3>	" ד - dalet
t	<char-0x5d0>	" א - alef
u	<char-0x5d5>	" ו - vav
v	<char-0x5d4>	" ה - he
w	'		" ' - single-quote
x	<char-0x5e1>	" ס - samekh
y	<char-0x5d8>	" ט - tet
z	<char-0x5d6>	" ז - zayin
,	<char-0x5ea>	" ת - tav
.	<char-0x5e5>	" ץ - final tsadi
;	<char-0x5e3>	" ף - final pe
'	,		" , - comma
/	.		" . - period
`	;		" ; - semicolon
A:	<Char-0x5b0>	" sheva
HE	<Char-0x5b1>	" hataf segol
HA	<Char-0x5b2>	" hataf patah
HO	<Char-0x5b3>	" hataf qamats
I	<Char-0x5b4>	" hiriq
AY	<Char-0x5b5>	" tsere
E	<Char-0x5b6>	" segol
AA	<Char-0x5b7>	" patah
AO	<Char-0x5b8>	" qamats
O	<Char-0x5b9>	" holam
U	<Char-0x5bb>	" qubuts
D	<Char-0x5bc>	" dagesh
]T	<Char-0x5bd>	" meteg
]Q	<Char-0x5be>	" maqaf
]R      <Char-0x5bf>	" rafe
]p      <Char-0x5c0>    " paseq
SR	<Char-0x5c1>	" shin-dot
SL	<Char-0x5c2>	" sin-dot
]P	<Char-0x5c3>	" sof-pasuq
VV	<Char-0x5f0>    " double-vav
VY	<Char-0x5f1>    " vav-yod
YY	<Char-0x5f2>    " yod-yod
" cantillation:
C:	<Char-0x591>	" etnahta
Cs <Char-0x592>   " segol
CS <Char-0x593>   " shalshelet
Cz <Char-0x594>   " zaqef qatan
CZ <Char-0x595>   " zaqef gadol
Ct <Char-0x596>   " tipeha
Cr <Char-0x597>   " revia
Cq <Char-0x598>   " zarqa
Cp <Char-0x599>   " pashta
C! <Char-0x59a>   " yetiv
Cv <Char-0x59b>   " tevir
Cg <Char-0x59c>   " geresh
C* <Char-0x59d>   " geresh qadim
CG <Char-0x59e>   " gershayim
CP <Char-0x59f>   " qarnei-parah
Cy <Char-0x5aa>   " yerach-ben-yomo
Co <Char-0x5ab>  " ole
Ci <Char-0x5ac>  " iluy
Cd <Char-0x5ad>  " dehi
Cn <Char-0x5ae>  " zinor
CC <Char-0x5af>  " masora circle
X` <Char-0xfb20>  " Alternative `ayin
X' <Char-0xfb21>  " Alternative 'alef
X-d <Char-0xfb22>  " Alternative dalet
X-h <Char-0xfb23>  " Alternative he
X-k <Char-0xfb24>  " Alternative kaf
X-l <Char-0xfb25>  " Alternative lamed
X-m <Char-0xfb26>  " Alternative mem-sofit
X-r <Char-0xfb27>  " Alternative resh
X-t <Char-0xfb28>  " Alternative tav
X-+ <Char-0xfb29>  " Alternative plus
XW <Char-0xfb2a>  " shin+shin-dot
Xw <Char-0xfb2b>  " shin+sin-dot
X..W <Char-0xfb2c>  " shin+shin-dot+dagesh
X..w <Char-0xfb2d>  " shin+sin-dot+dagesh
XA <Char-0xfb2e>  " alef+patah
XO <Char-0xfb2f>  " alef+qamats
XI <Char-0xfb30>  " alef+hiriq (mapiq)
X.b <Char-0xfb31>  " bet+dagesh
X.g <Char-0xfb32>  " gimel+dagesh
X.d <Char-0xfb33>  " dalet+dagesh
X.h <Char-0xfb34>  " he+dagesh
Xu <Char-0xfb35>  " vav+dagesh
X.z <Char-0xfb36>  " zayin+dagesh
X.T <Char-0xfb38>  " tet+dagesh
X.y <Char-0xfb39>  " yud+dagesh
X.K <Char-0xfb3a>  " kaf sofit+dagesh
X.k <Char-0xfb3b>  " kaf+dagesh
X.l <Char-0xfb3c>  " lamed+dagesh
X.m <Char-0xfb3e>  " mem+dagesh
X.n <Char-0xfb40>  " nun+dagesh
X.s <Char-0xfb41>  " samech+dagesh
X.P <Char-0xfb43>  " pe sofit+dagesh
X.p <Char-0xfb44>  " pe+dagesh
X.x <Char-0xfb46>  " tsadi+dagesh
X.q <Char-0xfb47>  " qof+dagesh
X.r <Char-0xfb48>  " resh+dagesh
X.w <Char-0xfb49>  " shin+dagesh
X.t <Char-0xfb4a>  " tav+dagesh
Xo <Char-0xfb4b>  " vav+holam
XRb <Char-0xfb4c>  " bet+rafe
XRk <Char-0xfb4d>  " kaf+rafe
XRp <Char-0xfb4e>  " pe+rafe
Xal <Char-0xfb4f>  " alef-lamed
