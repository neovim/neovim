" Vim syntax file
" Language:	XSLT
" Maintainer:   Bogdan Barbu <l4b.bogdan.barbu@gmail.com>
" Previous Maintainer:	Johannes Zellner <johannes@zellner.org>
" Last Change:	Fri, 17 Jan 2020 07:15:37 +0200
" Filenames:	*.xsl
" $Id: xslt.vim,v 1.1 2004/06/13 15:52:10 vimboss Exp $

" REFERENCES:
"   [1] http://www.w3.org/TR/xslt
"   [2] http://www.w3.org/TR/xslt20

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

runtime syntax/xml.vim

syn cluster xmlTagHook add=xslElement
syn case match

syn match xslElement '\%(xsl:\)\@<=analyze-string'
syn match xslElement '\%(xsl:\)\@<=apply-imports'
syn match xslElement '\%(xsl:\)\@<=apply-templates'
syn match xslElement '\%(xsl:\)\@<=attribute'
syn match xslElement '\%(xsl:\)\@<=attribute-set'
syn match xslElement '\%(xsl:\)\@<=call-template'
syn match xslElement '\%(xsl:\)\@<=character-map'
syn match xslElement '\%(xsl:\)\@<=choose'
syn match xslElement '\%(xsl:\)\@<=comment'
syn match xslElement '\%(xsl:\)\@<=copy'
syn match xslElement '\%(xsl:\)\@<=copy-of'
syn match xslElement '\%(xsl:\)\@<=decimal-format'
syn match xslElement '\%(xsl:\)\@<=document'
syn match xslElement '\%(xsl:\)\@<=element'
syn match xslElement '\%(xsl:\)\@<=fallback'
syn match xslElement '\%(xsl:\)\@<=for-each'
syn match xslElement '\%(xsl:\)\@<=for-each-group'
syn match xslElement '\%(xsl:\)\@<=function'
syn match xslElement '\%(xsl:\)\@<=if'
syn match xslElement '\%(xsl:\)\@<=include'
syn match xslElement '\%(xsl:\)\@<=import'
syn match xslElement '\%(xsl:\)\@<=import-schema'
syn match xslElement '\%(xsl:\)\@<=key'
syn match xslElement '\%(xsl:\)\@<=message'
syn match xslElement '\%(xsl:\)\@<=namespace'
syn match xslElement '\%(xsl:\)\@<=namespace-alias'
syn match xslElement '\%(xsl:\)\@<=number'
syn match xslElement '\%(xsl:\)\@<=otherwise'
syn match xslElement '\%(xsl:\)\@<=output'
syn match xslElement '\%(xsl:\)\@<=param'
syn match xslElement '\%(xsl:\)\@<=perform-sort'
syn match xslElement '\%(xsl:\)\@<=processing-instruction'
syn match xslElement '\%(xsl:\)\@<=preserve-space'
syn match xslElement '\%(xsl:\)\@<=script'
syn match xslElement '\%(xsl:\)\@<=sequence'
syn match xslElement '\%(xsl:\)\@<=sort'
syn match xslElement '\%(xsl:\)\@<=strip-space'
syn match xslElement '\%(xsl:\)\@<=stylesheet'
syn match xslElement '\%(xsl:\)\@<=template'
syn match xslElement '\%(xsl:\)\@<=transform'
syn match xslElement '\%(xsl:\)\@<=text'
syn match xslElement '\%(xsl:\)\@<=value-of'
syn match xslElement '\%(xsl:\)\@<=variable'
syn match xslElement '\%(xsl:\)\@<=when'
syn match xslElement '\%(xsl:\)\@<=with-param'

hi def link xslElement Statement

" vim: ts=8
