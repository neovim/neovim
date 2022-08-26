" Vim filetype plugin file
" Language:	    DocBook
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2012-04-25

if exists('b:did_ftplugin')
  finish
endif

if !exists('b:docbk_type')
  if expand('%:e') == 'sgml'
    let b:docbk_type = 'sgml'
  else
    let b:docbk_type = 'xml'
  endif
endif

if b:docbk_type == 'sgml'
  runtime! ftplugin/sgml.vim ftplugin/sgml_*.vim ftplugin/sgml/*.vim
else
  runtime! ftplugin/xml.vim ftplugin/xml_*.vim ftplugin/xml/*.vim
endif

let b:undo_ftplugin = "unlet! b:docbk_type"
