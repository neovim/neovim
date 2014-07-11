" Vim filetype plugin
" Language:      ART-IM and ART*Enterprise
" Maintainer:    Dorai Sitaram <ds26@gte.com>
" URL:		 http://www.ccs.neu.edu/~dorai/vimplugins/vimplugins.html
" Last Change:   Apr 2, 2003

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

run ftplugin/lisp.vim

setl lw-=if
setl lw+=def-art-fun,deffacts,defglobal,defrule,defschema,for,schema,while
