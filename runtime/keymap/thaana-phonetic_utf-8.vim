" thaana keymap 
" Maintainer: Ibrahim fayaz <p h a y a x at gmail dot com>
" please set enc to utf-8
" thaana phonetic keyboard is used as a reference
" http://www.mcst.gov.mv/News_and_Events/xpfonts.htm
" changelog: 18th Feb 2006 - came up the initial idea of writing the keymap..
"            13th May 2006 - made some few corrections regarding < and >..

let b:keymap_name= "thaana"

" THAANA NORMAL LETTERS
loadkeymap
h	<char-0x0780> "letter haa
S	<char-0x0781> "shaviani
n	<char-0x0782> "noonu
r	<char-0x0783> "raa
b	<char-0x0784> "baa
L	<char-0x0785> "lhaviani
k	<char-0x0786> "kaafu
w	<char-0x0787> "alifu  
v	<char-0x0788> "vaavu
m	<char-0x0789> "meemu
f	<char-0x078A> "faafu
d	<char-0x078B> "dhaalu
t	<char-0x078C> "thaa
l	<char-0x078D> "laamu
g	<char-0x078E> "gaafu
N	<char-0x078F> "gnaviani
s	<char-0x0790> "seenu
D	<char-0x0791> "daviani
z	<char-0x0792> "zaviani
T	<char-0x0793> "taviani
y	<char-0x0794> "yaa
p	<char-0x0795> "paviani
j	<char-0x0796> "javiani
c	<char-0x0797> "chaviani

"THAANA DOTTED LETTERS
X	<char-0x0798> "TTAA   (thaa mathee thin thiki)
H	<char-0x0799> "HHAA   (haa thiree ehthiki)
K	<char-0x079A> "KHAA   (haa mathee ehthiki)
J	<char-0x079B> "THAALU (dhaa mathee ehthiki)
R	<char-0x079C> "ZAA    (raa mathee ehthiki)
C	<char-0x079D> "SHEENU (seenu mathee thinthiki)
M	<char-0x079E> "SAADHU (seenu thiree ehthiki)
B	<char-0x079F> "DHAADHU(seenu mathee ehthiki)
Y	<char-0x07A0> "TO     (thaa thiree ehthiki)
Z	<char-0x07A1> "ZO     (thaa mathee ehthiki)
W 	<char-0x07A2> "AINU   (alifu thiree ehthiki)
G	<char-0x07A3> "GHAINU (alifu mathee ehthiki)
Q	<char-0x07A4> "QAAFU  (gaafu mathee dhethkiki)
V	<char-0x07A5> "VAAVU  (vaavu mathee ehthiki)

"THAANA FILI (combining characters)
a	<char-0x07A6> "abafili
A	<char-0x07A7> "aabaafili
i	<char-0x07A8> "ibifili
I	<char-0x07A9> "eebeefili
u	<char-0x07AA> "ubufili
U	<char-0x07AB> "ooboofili
e	<char-0x07AC> "ebefili
E	<char-0x07AD> "ebeyfili
o	<char-0x07AE> "obofili
O	<char-0x07AF> "oaboafili
q	<char-0x07B0> "sukun

"OTHER THAANA RELATED
F	<char-0xFDF2> "arabic ligature allah isolated form
?	<char-0x061F> "arabic question mark 
"~	<char-0xFDFD> "arabic -bismillah ahrahman araheem- not in phonetic keyboard, thats why commented 
[	<char-0x005D> "english open bracket is thaana closing bracket 
]	<char-0x005B> "english close bracket = thaana open bracket
{	<char-0x007B> "braces reversed
}	<char-0x007D>
x	<char-0x00D7> " x for multiplication sign.. 
P	<char-0x00F7> " division symbol mapped to 'p'
>	<char-0x003C>
<	<char-0x003E>
<M-v>	<char-0x200D> "zwj - ZERO WIDTH JOINER      i dont know how to use these yet..
<M-b>	<char-0x200C> "zwnj - ZERO WIDTH NON JOINER
<M-n>	<char-0x200E> "lrm - LEFT TO RIGHT MARK
<M-m> 	<char-0x200F> "rlm - RIGHT TO LEFT MARK
;	<char-0x061B> "arabic semicolon
,	<char-0x060C> "arabic coma
<M-;>	;
<M-,>	,
