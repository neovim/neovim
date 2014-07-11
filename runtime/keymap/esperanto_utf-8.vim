" Esperanto keymap for utf-8
" Maintainer:	A.J.Mechelynck	<antoine.mechelynck@skynet.be>
" Last Changed:	Sat 2003 Mar 15 05:23

" This keymap adds the special consonants of Esperanto to an existing Latin
" keyboard.
"
" All keys same as usual, except:
" ^ followed by any of CcGgHhJjSs adds a circumflex on top of the letter
" ù and Ù replaces the grave accent by a breve
" any of CcGgHhJjSsUu followed by X or x maps to consonant with ^ or Uu with
" breve.

" short keymap name for statusline
let b:keymap_name = "Eo"

" make cursor bright green when keymap is active
"highlight lCursor guifg=NONE guibg=#00E000

" The following digraphs are already defined
" digraph C> 0x0108 c> 0x0109	G> 0x011C g> 0x011D	H> 0x0124 h> 0x0125
" digraph J> 0x0134 j> 0x0135	S> 0x015C s> 0x015D	U( 0x016C u( 0x016D

scriptencoding latin1

loadkeymap

^C	<Char-0x0108>	" (264)	UPPERCASE C WITH CIRCUMFLEX
^c	<Char-0x0109>	" (265) LOWERCASE c WITH CIRCUMFLEX
^G	<Char-0x011C>	" (284) UPPERCASE G WITH CIRCUMFLEX
^g	<Char-0x011D>	" (285) LOWERCASE g WITH CIRCUMFLEX
^H	<Char-0x0124>	" (292) UPPERCASE H WITH CIRCUMFLEX
^h	<Char-0x0125>	" (293) LOWERCASE h WITH CIRCUMFLEX
^J	<Char-0x0134>	" (308) UPPERCASE J WITH CIRCUMFLEX
^j	<Char-0x0135>	" (309) LOWERCASE j WITH CIRCUMFLEX
^S	<Char-0x015C>	" (348) UPPERCASE S WITH CIRCUMFLEX
^s	<Char-0x015D>	" (349) LOWERCASE s WITH CIRCUMFLEX
Ù	<Char-0x016C>	" (364) UPPERCASE U WITH BREVE
ù	<Char-0x016D>	" (365) LOWERCASE u WITH BREVE

CX	<Char-0x0108>	" (264)	UPPERCASE C WITH CIRCUMFLEX
Cx	<Char-0x0108>	" (264)	UPPERCASE C WITH CIRCUMFLEX
cx	<Char-0x0109>	" (265) LOWERCASE c WITH CIRCUMFLEX
GX	<Char-0x011C>	" (284) UPPERCASE G WITH CIRCUMFLEX
Gx	<Char-0x011C>	" (284) UPPERCASE G WITH CIRCUMFLEX
gx	<Char-0x011D>	" (285) LOWERCASE g WITH CIRCUMFLEX
HX	<Char-0x0124>	" (292) UPPERCASE H WITH CIRCUMFLEX
Hx	<Char-0x0124>	" (292) UPPERCASE H WITH CIRCUMFLEX
hx	<Char-0x0125>	" (293) LOWERCASE h WITH CIRCUMFLEX
JX	<Char-0x0134>	" (308) UPPERCASE J WITH CIRCUMFLEX
Jx	<Char-0x0134>	" (308) UPPERCASE J WITH CIRCUMFLEX
jx	<Char-0x0135>	" (309) LOWERCASE j WITH CIRCUMFLEX
SX	<Char-0x015C>	" (348) UPPERCASE S WITH CIRCUMFLEX
Sx	<Char-0x015C>	" (348) UPPERCASE S WITH CIRCUMFLEX
sx	<Char-0x015D>	" (349) LOWERCASE s WITH CIRCUMFLEX
UX	<Char-0x016C>	" (364) UPPERCASE U WITH BREVE
Ux	<Char-0x016C>	" (364) UPPERCASE U WITH BREVE
ux	<Char-0x016D>	" (365) LOWERCASE u WITH BREVE
