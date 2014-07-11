" Vim syntax file
" Language:	XSD (XML Schema)
" Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Tue, 27 Apr 2004 14:54:59 CEST
" Filenames:	*.xsd
" $Id: xsd.vim,v 1.1 2004/06/13 18:20:48 vimboss Exp $

" REFERENCES:
"   [1] http://www.w3.org/TR/xmlschema-0
"

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

runtime syntax/xml.vim

syn cluster xmlTagHook add=xsdElement
syn case match

syn match xsdElement '\%(xsd:\)\@<=all'
syn match xsdElement '\%(xsd:\)\@<=annotation'
syn match xsdElement '\%(xsd:\)\@<=any'
syn match xsdElement '\%(xsd:\)\@<=anyAttribute'
syn match xsdElement '\%(xsd:\)\@<=appInfo'
syn match xsdElement '\%(xsd:\)\@<=attribute'
syn match xsdElement '\%(xsd:\)\@<=attributeGroup'
syn match xsdElement '\%(xsd:\)\@<=choice'
syn match xsdElement '\%(xsd:\)\@<=complexContent'
syn match xsdElement '\%(xsd:\)\@<=complexType'
syn match xsdElement '\%(xsd:\)\@<=documentation'
syn match xsdElement '\%(xsd:\)\@<=element'
syn match xsdElement '\%(xsd:\)\@<=enumeration'
syn match xsdElement '\%(xsd:\)\@<=extension'
syn match xsdElement '\%(xsd:\)\@<=field'
syn match xsdElement '\%(xsd:\)\@<=group'
syn match xsdElement '\%(xsd:\)\@<=import'
syn match xsdElement '\%(xsd:\)\@<=include'
syn match xsdElement '\%(xsd:\)\@<=key'
syn match xsdElement '\%(xsd:\)\@<=keyref'
syn match xsdElement '\%(xsd:\)\@<=length'
syn match xsdElement '\%(xsd:\)\@<=list'
syn match xsdElement '\%(xsd:\)\@<=maxInclusive'
syn match xsdElement '\%(xsd:\)\@<=maxLength'
syn match xsdElement '\%(xsd:\)\@<=minInclusive'
syn match xsdElement '\%(xsd:\)\@<=minLength'
syn match xsdElement '\%(xsd:\)\@<=pattern'
syn match xsdElement '\%(xsd:\)\@<=redefine'
syn match xsdElement '\%(xsd:\)\@<=restriction'
syn match xsdElement '\%(xsd:\)\@<=schema'
syn match xsdElement '\%(xsd:\)\@<=selector'
syn match xsdElement '\%(xsd:\)\@<=sequence'
syn match xsdElement '\%(xsd:\)\@<=simpleContent'
syn match xsdElement '\%(xsd:\)\@<=simpleType'
syn match xsdElement '\%(xsd:\)\@<=union'
syn match xsdElement '\%(xsd:\)\@<=unique'

hi def link xsdElement Statement

" vim: ts=8
