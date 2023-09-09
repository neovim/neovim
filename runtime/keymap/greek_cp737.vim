" Vim Keymap file for greek DOS cp737
" Maintainer: Panagiotis Louridas <louridas@acm.org>
" Last Updated: Thu Mar 23 14:05:45 EET 2006

" This keyboard layout allows all Greek symbols to be typed,
" including accented capitals and diaeresis. It does not
" include diaeresis and accent on the same vowel, nor
" the greek quotes, as these were not included in the codepage.
" It includes the Greek semicolon sign.

"
" accent			";" + letter
" diaeresis			":" + letter
" diaeresis + accent		";" + ":" (or ":" + ";") + letter
" semicolon			"q"
" colon				"Q"
" greek semicolon		"W"
" sigma at end of word		"w"

" Use this short name in the status line.
let b:keymap_name = "greek"

loadkeymap
" capital
A	<char-128>	" Ä
B	<char-129>	" Å
G	<char-130>	" Ç
D	<char-131>	" É
E	<char-132>	" Ñ
Z	<char-133>	" Ö
H	<char-134>	" Ü
U	<char-135>	" á
I	<char-136>	" à
K	<char-137>	" â
L	<char-138>	" ä
M	<char-139>	" ã
N	<char-140>	" å
J	<char-141>	" ç
O	<char-142>	" é
P	<char-143>	" è
R	<char-144>	" ê
S	<char-145>	" ë
T	<char-146>	" í
Y	<char-147>	" ì
F	<char-148>	" î
X	<char-149>	" ï
C	<char-150>	" ñ
V	<char-151>	" ó

" small
a	<char-152>	" ò
b	<char-153>	" ô
g	<char-154>	" ö
d	<char-155>	" õ
e	<char-156>	" ú
z	<char-157>	" ù
h	<char-158>	" û
u	<char-159>	" ü
i	<char-160>	" †
k	<char-161>	" °
l	<char-162>	" ¢
m	<char-163>	" £
n	<char-164>	" §
j	<char-165>	" •
o	<char-166>	" ¶
p	<char-167>	" ß
r	<char-168>	" ®
s	<char-169>	" ©
w	<char-170>	" ™
t	<char-171>	" ´
y	<char-172>	" ¨
f	<char-173>	" ≠
x	<char-174>	" Æ
c	<char-175>	" Ø
v	<char-224>	" ‡

" accented capital
;A	<char-234>	" Í
;E	<char-235>	" Î
;H	<char-236>	" Ï
;I	<char-237>	" Ì
;O	<char-238>	" Ó
;Y	<char-239>	" Ô
;V	<char-240>	" 
"
:I	<char-244>	" Ù
:Y	<char-245>	" ı

" accented small
;a	<char-225>	" ·
;e	<char-226>	" ‚
;h	<char-227>	" „
;i	<char-229>	" Â
;o	<char-230>	" Ê
;y	<char-231>	" Á
;v	<char-233>	" È
"
:i	<char-228>	" ‰
:y	<char-232>	" Ë
"
" symbols
q	;		" ;
Q	:		" :
W	<char-250>	" ˙
