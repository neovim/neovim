" Vim Keymap file for the normalized Canadian multilingual keyboard
" CAN/CSA Z243.200-92 using the latin1 encoding.
" This mapping is limited in scope, as it assumes that the AltGr
" key works as it typically does in a Windows system with a multilingual
" English keyboard.  It probably won't work with the US keyboard on US
" English versions of Windows, because those don't provide the AltGr keys.
" The mapping was tested with Win2k and WinXP.

" Maintainer: Eric Joanis <joanis@cs.toronto.edu>
" Last Change: 2004 Jan 13

" 2003 Dec 04
" Initial Revision

" 2004 Jan 13
" Added the upper case accented characters, forgotten in the initial version.

" All characters are given literally, conversion to another encoding (e.g.,
" UTF-8) should work.
scriptencoding latin1

" Use this short name in the status line.
let b:keymap_name = "canfr"

loadkeymap
<	'
>	"
/	é
?	É
'	è
\"	È
\\	à
|	À
[a	â
[e	ê
[i	î
[o	ô
[u	û
[A	Â
[E	Ê
[I	Î
[O	Ô
[U	Û
[[	^
{a	ä
{e	ë
{i	ï
{o	ö
{u	ü
{y	ÿ
{A	Ä
{E	Ë
{I	Ï
{O	Ö
{U	Ü
]	ç
}	Ç
`	/
~	\\
^	?
ú	«
ø	»
¬	<
®	>
»	°
Ûa	à
Ûe	è
Ûi	ì
Ûo	ò
Ûu	ù
ÛA	À
ÛE	È
ÛI	Ì
ÛO	Ò
ÛU	Ù
ÛÛ	`
Ýa	ã
Ýo	õ
Ýn	ñ
Ýs	ß
ÝA	Ã
ÝO	Õ
ÝN	Ñ
ÝS	ß
ÝÝ	~
à	|
·	{
¸	}
¹	[
°	]
½	¬
