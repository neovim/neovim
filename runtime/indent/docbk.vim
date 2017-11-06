" Vim indent file
" Language:    	    DocBook Documentation Format
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:did_indent")
  finish
endif

" Same as XML indenting for now.
runtime! indent/xml.vim

if exists('*XmlIndentGet')
  setlocal indentexpr=XmlIndentGet(v:lnum,0)
endif
