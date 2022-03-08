" Vim filetype plugin file
" Language:	xslt
"
" This runtime file is looking for a new maintainer.
"
" Former maintainer:	Dan Sharp
" Last Changed: 20 Jan 2009

if exists("b:did_ftplugin") | finish | endif

runtime! ftplugin/xml.vim ftplugin/xml_*.vim ftplugin/xml/*.vim

let b:did_ftplugin = 1

" Change the :browse e filter to primarily show xsd-related files.
if has("gui_win32") && exists("b:browsefilter")
    let  b:browsefilter="XSLT Files (*.xsl,*.xslt)\t*.xsl;*.xslt\n" . b:browsefilter
endif
