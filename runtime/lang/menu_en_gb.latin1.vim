" Menu Translations:	UK English
" Maintainer:		Mike Williams <mrw@eandem.co.uk>
" Last Change:		2003 Feb 10

" Quit when menu translations have already been done.
if exists("did_menu_trans")
  finish
endif
let did_menu_trans = 1

" Note: there is no "scriptencoding" command here, all encodings should be
" able to handle ascii characters without conversion.

" Convert from American to UK spellings.
menutrans C&olor\ Scheme			C&olour\ Scheme
menutrans Co&lor\ test				Co&lour\ test
