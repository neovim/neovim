" Vim syntax file
" Language:	Vgrindefs
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" The Vgrindefs file is used to specify a language for vgrind

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Comments
syn match vgrindefsComment "^#.*"

" The fields that vgrind recognizes
syn match vgrindefsField ":ab="
syn match vgrindefsField ":ae="
syn match vgrindefsField ":pb="
syn match vgrindefsField ":bb="
syn match vgrindefsField ":be="
syn match vgrindefsField ":cb="
syn match vgrindefsField ":ce="
syn match vgrindefsField ":sb="
syn match vgrindefsField ":se="
syn match vgrindefsField ":lb="
syn match vgrindefsField ":le="
syn match vgrindefsField ":nc="
syn match vgrindefsField ":tl"
syn match vgrindefsField ":oc"
syn match vgrindefsField ":kw="

" Also find the ':' at the end of the line, so all ':' are highlighted
syn match vgrindefsField ":\\$"
syn match vgrindefsField ":$"
syn match vgrindefsField "\\$"

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link vgrindefsField	Statement
hi def link vgrindefsComment	Comment

let b:current_syntax = "vgrindefs"

" vim: ts=8
