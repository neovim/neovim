" Vim syntax file
" Language:    Lout
" Maintainer:  Christian V. J. Brüssow <cvjb@cvjb.de>
" Last Change: So 12 Feb 2012 15:15:03 CET
" Filenames:   *.lout,*.lt
" URL:         http://www.cvjb.de/comp/vim/lout.vim

" $Id: lout.vim,v 1.4 2012/02/12 15:16:17 bruessow Exp $
"
" Lout: Basser Lout document formatting system.

" Many Thanks to...
" 
" 2012-02-12:
" Thilo Six <T.Six at gmx dot de> send a patch for cpoptions.
" See the discussion at http://thread.gmane.org/gmane.editors.vim.devel/32151


" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let s:cpo_save=&cpo
set cpo&vim

" Lout is case sensitive
syn case match

" Synchronization, I know it is a huge number, but normal texts can be
" _very_ long ;-)
syn sync lines=1000

" Characters allowed in keywords
" I don't know if 128-255 are allowed in ANS-FORHT
setlocal iskeyword=@,48-57,.,@-@,_,192-255

" Some special keywords
syn keyword loutTodo contained TODO lout Lout LOUT
syn keyword loutDefine def macro

" Some big structures
syn keyword loutKeyword @Begin @End @Figure @Tab
syn keyword loutKeyword @Book @Doc @Document @Report
syn keyword loutKeyword @Introduction @Abstract @Appendix
syn keyword loutKeyword @Chapter @Section @BeginSections @EndSections

" All kind of Lout keywords
syn match loutFunction '\<@[^ \t{}]\+\>'

" Braces -- Don`t edit these lines!
syn match loutMBraces '[{}]'
syn match loutIBraces '[{}]'
syn match loutBBrace '[{}]'
syn match loutBIBraces '[{}]'
syn match loutHeads '[{}]'

" Unmatched braces.
syn match loutBraceError '}'

" End of multi-line definitions, like @Document, @Report and @Book.
syn match loutEOmlDef '^//$'

" Grouping of parameters and objects.
syn region loutObject transparent matchgroup=Delimiter start='{' matchgroup=Delimiter end='}' contains=ALLBUT,loutBraceError

" The NULL object has a special meaning
syn keyword loutNULL {}

" Comments
syn region loutComment start='\#' end='$' contains=loutTodo

" Double quotes
syn region loutSpecial start=+"+ skip=+\\\\\|\\"+ end=+"+

" ISO-LATIN-1 characters created with @Char, or Adobe symbols
" created with @Sym
syn match loutSymbols '@\(\(Char\)\|\(Sym\)\)\s\+[A-Za-z]\+'

" Include files
syn match loutInclude '@IncludeGraphic\s\+\k\+'
syn region loutInclude start='@\(\(SysInclude\)\|\(IncludeGraphic\)\|\(Include\)\)\s*{' end='}'

" Tags
syn match loutTag '@\(\(Tag\)\|\(PageMark\)\|\(PageOf\)\|\(NumberOf\)\)\s\+\k\+'
syn region loutTag start='@Tag\s*{' end='}'

" Equations
syn match loutMath '@Eq\s\+\k\+'
syn region loutMath matchgroup=loutMBraces start='@Eq\s*{' matchgroup=loutMBraces end='}' contains=ALLBUT,loutBraceError
"
" Fonts
syn match loutItalic '@I\s\+\k\+'
syn region loutItalic matchgroup=loutIBraces start='@I\s*{' matchgroup=loutIBraces end='}' contains=ALLBUT,loutBraceError
syn match loutBold '@B\s\+\k\+'
syn region loutBold matchgroup=loutBBraces start='@B\s*{' matchgroup=loutBBraces end='}' contains=ALLBUT,loutBraceError
syn match loutBoldItalic '@BI\s\+\k\+'
syn region loutBoldItalic matchgroup=loutBIBraces start='@BI\s*{' matchgroup=loutBIBraces end='}' contains=ALLBUT,loutBraceError
syn region loutHeadings matchgroup=loutHeads start='@\(\(Title\)\|\(Caption\)\)\s*{' matchgroup=loutHeads end='}' contains=ALLBUT,loutBraceError

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting. Can be overrriden later.
hi def link loutTodo Todo
hi def link loutDefine Define
hi def link loutEOmlDef Define
hi def link loutFunction Function
hi def link loutBraceError Error
hi def link loutNULL Special
hi def link loutComment Comment
hi def link loutSpecial Special
hi def link loutSymbols Character
hi def link loutInclude Include
hi def link loutKeyword Keyword
hi def link loutTag Tag
hi def link loutMath Number

hi def link loutMBraces loutMath
hi loutItalic term=italic cterm=italic gui=italic
hi def link loutIBraces loutItalic
hi loutBold term=bold cterm=bold gui=bold
hi def link loutBBraces loutBold
hi loutBoldItalic term=bold,italic cterm=bold,italic gui=bold,italic
hi def link loutBIBraces loutBoldItalic
hi loutHeadings term=bold cterm=bold guifg=indianred
hi def link loutHeads loutHeadings


let b:current_syntax = "lout"

let &cpo=s:cpo_save
unlet s:cpo_save

" vim:ts=8:sw=4:nocindent:smartindent:
