" Vim filetype plugin file
" Language:	Django HTML template
" Maintainer:	Dave Hodder <dmh@dmh.org.uk>
" Last Change:	2007 Jan 25

" Only use this filetype plugin when no other was loaded.
if exists("b:did_ftplugin")
  finish
endif

" Use HTML and Django template ftplugins.
runtime! ftplugin/html.vim
runtime! ftplugin/django.vim
