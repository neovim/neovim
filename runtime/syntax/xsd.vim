" Vim syntax file
" Language:	XSD (XML Schema)
" Maintainer:	Christian Brabandt <cb@256bit.org>
" Repository:	https://github.com/chrisbra/vim-xml-ftplugin
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	21 Jun 2026
" Filenames:	*.xsd
" REFERENCES:
"   [1] http://www.w3.org/TR/xmlschema-0
"

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

runtime! syntax/xml.vim

syn cluster xmlTagHook add=xsdElement
syn case match

for s:element in [
    \ 'all', 'annotation', 'any', 'anyAttribute', 'appInfo', 'attribute',
    \ 'attributeGroup', 'choice', 'complexContent', 'complexType',
    \ 'documentation', 'element', 'enumeration', 'extension', 'field', 'group',
    \ 'import', 'include', 'key', 'keyref', 'length', 'list', 'maxInclusive',
    \ 'maxLength', 'minInclusive', 'minLength', 'pattern', 'redefine',
    \ 'restriction', 'schema', 'selector', 'sequence', 'simpleContent',
    \ 'simpleType', 'union', 'unique',
    \ ]
    execute 'syn match xsdElement contained /\%#=1\%([</]xsd:\)\@5<=' . s:element . '[^ /!?<>"'']\@!/'
endfor
unlet s:element

hi def link xsdElement Statement

let b:current_syntax = 'xsd'

" vim: ts=8
