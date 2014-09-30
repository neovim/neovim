" Vim Keymap file for Croatian characters, classical variant, iso-8859-2 encoding
" 
" Maintainer:   Paul B. Mahol <onemda@gmail.com>
" Last Changed: 2007 Oct 14

scriptencoding iso-8859-2

let b:keymap_name = "croatian-iso-8859-2"
" Uncomment line below if you prefer short name
"let b:keymap_name = "hr-iso-8859-2"

loadkeymap
" swap y and z, not important
z	y
Z	Y
y	z
Y	Z

" s<
[	¹
" S<
{	©
" D/
}	Ð
" d/
]	ð
" c<
;	è
" c'
'	æ
" C<
:	È
" C'
"	Æ
" z<
\	¾
" Z<
|	®
÷	|
ö	@
ñ	\
Û	÷
Ý	×
ý	×
§	ß
í	§
Ü	¤
ü	¤
â	{
î	}
æ	[
ç	]
@	"
^	&
&	/
*	(
(	)
)	=
_	?
-	'
=	+
+	*
/	-
<	;
>	:
?	_
±	~
²	·
´	¢
µ	°
³	^
ì	³
Ì	£
·	`
¹	´
°	½
­	¨

" you still want to be able to type <, >
¬	<
®	>

`	¸
½	¸
