" Vim syntax file
" Language:	XSLT
" Maintainer:	Christian Brabandt <cb@256bit.org>
" Repository:	https://github.com/chrisbra/vim-xml-ftplugin
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>,
"			Bogdan Barbu <l4b.bogdan.barbu@gmail.com>
" Last Change:	21 Jun 2026
" Filenames:	*.xsl

" REFERENCES:
"   [1] http://www.w3.org/TR/xslt
"   [2] http://www.w3.org/TR/xslt20

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

runtime! syntax/xml.vim

syn cluster xmlTagHook add=xslElement
syn case match

for s:element in [
    \ 'analyze-string', 'apply-imports', 'apply-templates', 'attribute',
    \ 'attribute-set', 'call-template', 'character-map', 'choose', 'comment',
    \ 'copy', 'copy-of', 'decimal-format', 'document', 'element', 'fallback',
    \ 'for-each', 'for-each-group', 'function', 'if', 'include', 'import',
    \ 'import-schema', 'key', 'message', 'namespace', 'namespace-alias',
    \ 'number', 'otherwise', 'output', 'param', 'perform-sort',
    \ 'processing-instruction', 'preserve-space', 'script', 'sequence', 'sort',
    \ 'strip-space', 'stylesheet', 'template', 'transform', 'text', 'value-of',
    \ 'variable', 'when', 'with-param',
    \ ]
    execute 'syn match xslElement contained /\%#=1\%([</]xsl:\)\@5<=' . s:element . '[^ /!?<>"'']\@!/'
endfor
unlet s:element

hi def link xslElement Statement

let b:current_syntax = 'xslt'

" vim: ts=8
