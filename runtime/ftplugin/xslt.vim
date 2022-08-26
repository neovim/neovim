" Vim filetype plugin file
" Language:		XSLT
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Change:		2022 Apr 25

if exists("b:did_ftplugin")
  finish
endif

runtime! ftplugin/xml.vim ftplugin/xml_*.vim ftplugin/xml/*.vim

let b:did_ftplugin = 1

" Change the :browse e filter to primarily show xsd-related files.
if (has("gui_win32") || has("gui_gtk")) && exists("b:browsefilter")
  let b:browsefilter = "XSLT Files (*.xsl,*.xslt)\t*.xsl;*.xslt\n" . b:browsefilter
endif
