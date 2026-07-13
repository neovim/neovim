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
  runtime! ftplugin/sgml[.]{vim,lua} ftplugin/sgml_*.{vim,lua} ftplugin/sgml/*.{vim,lua}
else
  runtime! ftplugin/xml[.]{vim,lua} ftplugin/xml_*.{vim,lua} ftplugin/xml/*.{vim,lua}
endif

let b:undo_ftplugin = "unlet! b:docbk_type"
