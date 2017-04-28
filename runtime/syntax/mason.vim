" Vim syntax file
" Language:    Mason (Perl embedded in HTML)
" Maintainer:  Andrew Smith <andrewdsmith@yahoo.com>
" Last change: 2003 May 11
" URL:	       http://www.masonhq.com/editors/mason.vim
"
" This seems to work satisfactorily with html.vim and perl.vim for version 5.5.
" Please mail any fixes or improvements to the above address. Things that need
" doing include:
"
"  - Add match for component names in <& &> blocks.
"  - Add match for component names in <%def> and <%method> block delimiters.
"  - Fix <%text> blocks to show HTML tags but ignore Mason tags.
"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

" The HTML syntax file included below uses this variable.
"
if !exists("main_syntax")
	let main_syntax = 'mason'
endif

" First pull in the HTML syntax.
"
runtime! syntax/html.vim
unlet b:current_syntax

syn cluster htmlPreproc add=@masonTop

" Now pull in the Perl syntax.
"
syn include @perlTop syntax/perl.vim

" It's hard to reduce down to the correct sub-set of Perl to highlight in some
" of these cases so I've taken the safe option of just using perlTop in all of
" them. If you have any suggestions, please let me know.
"
syn region masonLine matchgroup=Delimiter start="^%" end="$" contains=@perlTop
syn region masonExpr matchgroup=Delimiter start="<%" end="%>" contains=@perlTop
syn region masonPerl matchgroup=Delimiter start="<%perl>" end="</%perl>" contains=@perlTop
syn region masonComp keepend matchgroup=Delimiter start="<&" end="&>" contains=@perlTop

syn region masonArgs matchgroup=Delimiter start="<%args>" end="</%args>" contains=@perlTop

syn region masonInit matchgroup=Delimiter start="<%init>" end="</%init>" contains=@perlTop
syn region masonCleanup matchgroup=Delimiter start="<%cleanup>" end="</%cleanup>" contains=@perlTop
syn region masonOnce matchgroup=Delimiter start="<%once>" end="</%once>" contains=@perlTop
syn region masonShared matchgroup=Delimiter start="<%shared>" end="</%shared>" contains=@perlTop

syn region masonDef matchgroup=Delimiter start="<%def[^>]*>" end="</%def>" contains=@htmlTop
syn region masonMethod matchgroup=Delimiter start="<%method[^>]*>" end="</%method>" contains=@htmlTop

syn region masonFlags matchgroup=Delimiter start="<%flags>" end="</%flags>" contains=@perlTop
syn region masonAttr matchgroup=Delimiter start="<%attr>" end="</%attr>" contains=@perlTop

syn region masonFilter matchgroup=Delimiter start="<%filter>" end="</%filter>" contains=@perlTop

syn region masonDoc matchgroup=Delimiter start="<%doc>" end="</%doc>"
syn region masonText matchgroup=Delimiter start="<%text>" end="</%text>"

syn cluster masonTop contains=masonLine,masonExpr,masonPerl,masonComp,masonArgs,masonInit,masonCleanup,masonOnce,masonShared,masonDef,masonMethod,masonFlags,masonAttr,masonFilter,masonDoc,masonText

" Set up default highlighting. Almost all of this is done in the included
" syntax files.
hi def link masonDoc Comment

let b:current_syntax = "mason"

if main_syntax == 'mason'
	unlet main_syntax
endif
