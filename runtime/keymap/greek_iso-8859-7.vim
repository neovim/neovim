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
A	<char-193>	" �
B	<char-194>	" �
G	<char-195>	" �
D	<char-196>	" �
E	<char-197>	" �
Z	<char-198>	" �
H	<char-199>	" �
U	<char-200>	" �
I	<char-201>	" �
K	<char-202>	" �
L	<char-203>	" �
M	<char-204>	" �
N	<char-205>	" �
J	<char-206>	" �
O	<char-207>	" �
P	<char-208>	" �
R	<char-209>	" �
S	<char-211>	" �
T	<char-212>	" �
Y	<char-213>	" �
F	<char-214>	" �
X	<char-215>	" �
C	<char-216>	" �
V	<char-217>	" �

" small
a	<char-225>	" �
b	<char-226>	" �
g	<char-227>	" �
d	<char-228>	" �
e	<char-229>	" �
z	<char-230>	" �
h	<char-231>	" �
u	<char-232>	" �
i	<char-233>	" �
k	<char-234>	" �
l	<char-235>	" �
m	<char-236>	" �
n	<char-237>	" �
j	<char-238>	" �
o	<char-239>	" �
p	<char-240>	" �
r	<char-241>	" �
w	<char-242>	" �
s	<char-243>	" �
t	<char-244>	" �
y	<char-245>	" �
f	<char-246>	" �
x	<char-247>	" �
c	<char-248>	" �
v	<char-249>	" �

" accented capital
;A	<char-182>	" �
;E	<char-184>	" �
;H	<char-185>	" �
;I	<char-186>	" �
;Y	<char-190>	" �
;O	<char-188>	" �
;V	<char-191>	" �
"
:I	<char-218>	" �
:Y	<char-219>	" �

" accented small
;a	<char-220>	" �
;e	<char-221>	" �
;h	<char-222>	" �
;i	<char-223>	" �
;y	<char-253>	" �
;o	<char-252>	" �
;v	<char-254>	" �
"
:i	<char-250>	" �
:y	<char-251>	" �
"
;:i	<char-192>	" �
:;i	<char-192>	" �
;:y	<char-224>	" �
:;y	<char-224>	" �

" symbols
q	;		" ;
Q	:		" :
W	<char-183>	" �
;	<char-180>	" �
:	<char-168>	" �
;:	<char-181>	" �
:;	<char-181>	" �

" quotes
<<	<char-171>	" �
>>	<char-187>	" �
" <char-161>	" �
" <char-162>	" �
