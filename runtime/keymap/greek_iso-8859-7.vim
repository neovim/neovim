" Vim Keymap file for greek
" Maintainer: Grigorios Magklis <maglis@cs.rochester.edu>
" Last Updated: Tue 10 Jul 2001 16:50:50
"
" This keyboard layout allows all Greek symbols to be typed,
" including accented capitals, diaeresis & accent on the same
" vowel, and the Greek semicolon sign.
"
" accent			";" + letter
" diaeresis			":" + letter
" diaeresis + accent		";" + ":" (or ":" + ";") + letter
" semicolon			"q"
" colon				"Q"
" greek semicolon		"W"
" sigma at end of word		"w"
" greek left double-quote	"<" twice
" greek right double-quote	">" twice

" Use this short name in the status line.
let b:keymap_name = "greek"

loadkeymap
" capital
A	<char-193>	" Á
B	<char-194>	" Â
G	<char-195>	" Ã
D	<char-196>	" Ä
E	<char-197>	" Å
Z	<char-198>	" Æ
H	<char-199>	" Ç
U	<char-200>	" È
I	<char-201>	" É
K	<char-202>	" Ê
L	<char-203>	" Ë
M	<char-204>	" Ì
N	<char-205>	" Í
J	<char-206>	" Î
O	<char-207>	" Ï
P	<char-208>	" Ð
R	<char-209>	" Ñ
S	<char-211>	" Ó
T	<char-212>	" Ô
Y	<char-213>	" Õ
F	<char-214>	" Ö
X	<char-215>	" ×
C	<char-216>	" Ø
V	<char-217>	" Ù

" small
a	<char-225>	" á
b	<char-226>	" â
g	<char-227>	" ã
d	<char-228>	" ä
e	<char-229>	" å
z	<char-230>	" æ
h	<char-231>	" ç
u	<char-232>	" è
i	<char-233>	" é
k	<char-234>	" ê
l	<char-235>	" ë
m	<char-236>	" ì
n	<char-237>	" í
j	<char-238>	" î
o	<char-239>	" ï
p	<char-240>	" ð
r	<char-241>	" ñ
w	<char-242>	" ò
s	<char-243>	" ó
t	<char-244>	" ô
y	<char-245>	" õ
f	<char-246>	" ö
x	<char-247>	" ÷
c	<char-248>	" ø
v	<char-249>	" ù

" accented capital
;A	<char-182>	" ¶
;E	<char-184>	" ¸
;H	<char-185>	" ¹
;I	<char-186>	" º
;Y	<char-190>	" ¾
;O	<char-188>	" ¼
;V	<char-191>	" ¿
"
:I	<char-218>	" Ú
:Y	<char-219>	" Û

" accented small
;a	<char-220>	" Ü
;e	<char-221>	" Ý
;h	<char-222>	" Þ
;i	<char-223>	" ß
;y	<char-253>	" ý
;o	<char-252>	" ü
;v	<char-254>	" þ
"
:i	<char-250>	" ú
:y	<char-251>	" û
"
;:i	<char-192>	" À
:;i	<char-192>	" À
;:y	<char-224>	" à
:;y	<char-224>	" à

" symbols
q	;		" ;
Q	:		" :
W	<char-183>	" ·
;	<char-180>	" ´
:	<char-168>	" ¨
;:	<char-181>	" µ
:;	<char-181>	" µ

" quotes
<<	<char-171>	" «
>>	<char-187>	" »
" <char-161>	" ¡
" <char-162>	" ¢
