" Vim syntax file
" Language:	JSP (Java Server Pages)
" Maintainer:	Rafael Garcia-Suarez <rgarciasuarez@free.fr>
" URL:		http://rgarciasuarez.free.fr/vim/syntax/jsp.vim
" Last change:	2004 Feb 02
" Credits : Patch by Darren Greaves (recognizes <jsp:...> tags)
"	    Patch by Thomas Kimpton (recognizes jspExpr inside HTML tags)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'jsp'
endif

" Source HTML syntax
if version < 600
  source <sfile>:p:h/html.vim
else
  runtime! syntax/html.vim
endif
unlet b:current_syntax

" Next syntax items are case-sensitive
syn case match

" Include Java syntax
syn include @jspJava syntax/java.vim

syn region jspScriptlet matchgroup=jspTag start=/<%/  keepend end=/%>/ contains=@jspJava
syn region jspComment			  start=/<%--/	      end=/--%>/
syn region jspDecl	matchgroup=jspTag start=/<%!/ keepend end=/%>/ contains=@jspJava
syn region jspExpr	matchgroup=jspTag start=/<%=/ keepend end=/%>/ contains=@jspJava
syn region jspDirective			  start=/<%@/	      end=/%>/ contains=htmlString,jspDirName,jspDirArg

syn keyword jspDirName contained include page taglib
syn keyword jspDirArg contained file uri prefix language extends import session buffer autoFlush
syn keyword jspDirArg contained isThreadSafe info errorPage contentType isErrorPage
syn region jspCommand			  start=/<jsp:/ start=/<\/jsp:/ keepend end=/>/ end=/\/>/ contains=htmlString,jspCommandName,jspCommandArg
syn keyword jspCommandName contained include forward getProperty plugin setProperty useBean param params fallback
syn keyword jspCommandArg contained id scope class type beanName page flush name value property
syn keyword jspCommandArg contained code codebase name archive align height
syn keyword jspCommandArg contained width hspace vspace jreversion nspluginurl iepluginurl

" Redefine htmlTag so that it can contain jspExpr
syn clear htmlTag
syn region htmlTag start=+<[^/%]+ end=+>+ contains=htmlTagN,htmlString,htmlArg,htmlValue,htmlTagError,htmlEvent,htmlCssDefinition,@htmlPreproc,@htmlArgCluster,jspExpr,javaScript

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_jsp_syn_inits")
  if version < 508
    let did_jsp_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  " java.vim has redefined htmlComment highlighting
  HiLink htmlComment	 Comment
  HiLink htmlCommentPart Comment
  " Be consistent with html highlight settings
  HiLink jspComment	 htmlComment
  HiLink jspTag		 htmlTag
  HiLink jspDirective	 jspTag
  HiLink jspDirName	 htmlTagName
  HiLink jspDirArg	 htmlArg
  HiLink jspCommand	 jspTag
  HiLink jspCommandName  htmlTagName
  HiLink jspCommandArg	 htmlArg
  delcommand HiLink
endif

if main_syntax == 'jsp'
  unlet main_syntax
endif

let b:current_syntax = "jsp"

" vim: ts=8
