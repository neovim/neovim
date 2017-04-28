" Vim syntax file
" Language:	Pyrex
" Maintainer:	Marco Barisione <marco.bari@people.it>
" URL:		http://marcobari.altervista.org/pyrex_vim.html
" Last Change:	2009 Nov 09

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the Python syntax to start with
runtime! syntax/python.vim
unlet b:current_syntax

" Pyrex extentions
syn keyword pyrexStatement      cdef typedef ctypedef sizeof
syn keyword pyrexType		int long short float double char object void
syn keyword pyrexType		signed unsigned
syn keyword pyrexStructure	struct union enum
syn keyword pyrexInclude	include cimport
syn keyword pyrexAccess		public private property readonly extern
" If someome wants Python's built-ins highlighted probably he
" also wants Pyrex's built-ins highlighted
if exists("python_highlight_builtins") || exists("pyrex_highlight_builtins")
    syn keyword pyrexBuiltin    NULL
endif

" This deletes "from" from the keywords and re-adds it as a
" match with lower priority than pyrexForFrom
syn clear   pythonInclude
syn keyword pythonInclude     import
syn match   pythonInclude     "from"

" With "for[^:]*\zsfrom" VIM does not match "for" anymore, so
" I used the slower "\@<=" form
syn match   pyrexForFrom        "\(for[^:]*\)\@<=from"

" Default highlighting
command -nargs=+ HiLink hi def link <args>
HiLink pyrexStatement		Statement
HiLink pyrexType		Type
HiLink pyrexStructure		Structure
HiLink pyrexInclude		PreCondit
HiLink pyrexAccess		pyrexStatement
if exists("python_highlight_builtins") || exists("pyrex_highlight_builtins")
HiLink pyrexBuiltin	Function
endif
HiLink pyrexForFrom		Statement

delcommand HiLink

let b:current_syntax = "pyrex"
