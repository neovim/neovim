" Vim syntax file
" Language:	WEB
" Maintainer:	Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:	April 30, 2001

" Details of the WEB language can be found in the article by Donald E. Knuth,
" "The WEB System of Structured Documentation", included as "webman.tex" in
" the standard WEB distribution, available for anonymous ftp at
" ftp://labrea.stanford.edu/pub/tex/web/.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Although WEB is the ur-language for the "Literate Programming" paradigm,
" we base this syntax file on the modern superset, CWEB.  Note: This shortcut
" may introduce some illegal constructs, e.g., CWEB's "@c" does _not_ start a
" code section in WEB.  Anyway, I'm not a WEB programmer.
runtime! syntax/cweb.vim
unlet b:current_syntax

" Replace C/C++ syntax by Pascal syntax.
syntax include @webIncludedC <sfile>:p:h/pascal.vim

" Double-@ means single-@, anywhere in the WEB source (as in CWEB).
" Don't misinterpret "@'" as the start of a Pascal string.
syntax match webIgnoredStuff "@[@']"

let b:current_syntax = "web"

" vim: ts=8
