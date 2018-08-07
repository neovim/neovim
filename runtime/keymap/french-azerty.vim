" Last Changed: 2018 July 15

" All characters are given literally, conversion to another encoding (e.g., UTF-8) should work.
scriptencoding utf-8

let b:keymap_name = "fr"

loadkeymap

" Left rows
q	a
Q	A
a	q
A	Q
z	w
Z	W
w	z
W	Z

" Some common accents
" Top right row
[q â
[e ê
[u û
[i î
[o ô
] $
{q ä
{e ë
{u ü
{i ï
{o ö
} £

" Middle right row
;	m
'	ù
\\ *
: M
\" %
| µ

" Bottom right row
m ,
, ;
. :
/ !
M ?
? § 
< .
> /

" Numeric row
1	&
2	é
3	"
4	'
5	(
6	-
7	è
8	_
9	ç
0	à
-	)

! 1
@ 2
# 3
$ 4
% 5
^ 6
& 7
* 8
( 9
) 0
_ °

" TODO: need to prefix the numbers below with ctrl+alt
" 2	~
" 3	#
" 4	{
" 5	[
" 6	|
" 7	`
" 8	\
" 9	^
" -	@
" -	]
" =	}
