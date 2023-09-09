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
A	<char-128>	" �
B	<char-129>	" �
G	<char-130>	" �
D	<char-131>	" �
E	<char-132>	" �
Z	<char-133>	" �
H	<char-134>	" �
U	<char-135>	" �
I	<char-136>	" �
K	<char-137>	" �
L	<char-138>	" �
M	<char-139>	" �
N	<char-140>	" �
J	<char-141>	" �
O	<char-142>	" �
P	<char-143>	" �
R	<char-144>	" �
S	<char-145>	" �
T	<char-146>	" �
Y	<char-147>	" �
F	<char-148>	" �
X	<char-149>	" �
C	<char-150>	" �
V	<char-151>	" �

" small
a	<char-152>	" �
b	<char-153>	" �
g	<char-154>	" �
d	<char-155>	" �
e	<char-156>	" �
z	<char-157>	" �
h	<char-158>	" �
u	<char-159>	" �
i	<char-160>	" �
k	<char-161>	" �
l	<char-162>	" �
m	<char-163>	" �
n	<char-164>	" �
j	<char-165>	" �
o	<char-166>	" �
p	<char-167>	" �
r	<char-168>	" �
s	<char-169>	" �
w	<char-170>	" �
t	<char-171>	" �
y	<char-172>	" �
f	<char-173>	" �
x	<char-174>	" �
c	<char-175>	" �
v	<char-224>	" �

" accented capital
;A	<char-234>	" �
;E	<char-235>	" �
;H	<char-236>	" �
;I	<char-237>	" �
;O	<char-238>	" �
;Y	<char-239>	" �
;V	<char-240>	" �
"
:I	<char-244>	" �
:Y	<char-245>	" �

" accented small
;a	<char-225>	" �
;e	<char-226>	" �
;h	<char-227>	" �
;i	<char-229>	" �
;o	<char-230>	" �
;y	<char-231>	" �
;v	<char-233>	" �
"
:i	<char-228>	" �
:y	<char-232>	" �
"
" symbols
q	;		" ;
Q	:		" :
W	<char-250>	" �
