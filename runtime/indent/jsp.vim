" Vim filetype indent file
" Language:    JSP files
" Maintainer:  David Fishburn <fishburn@ianywhere.com>
" Version:     1.0
" Last Change: Wed Nov 08 2006 11:08:05 AM

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

" If there has been no specific JSP indent script created, 
" use the default html indent script which will handle
" html, javascript and most of the JSP constructs.
runtime! indent/html.vim


