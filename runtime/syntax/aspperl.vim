" Vim syntax file
" Language:	Active State's PerlScript (ASP)
" Maintainer:	Aaron Hope <edh@brioforge.com>
" URL:		http://nim.dhs.org/~edh/aspperl.vim
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'perlscript'
endif

if version < 600
  so <sfile>:p:h/html.vim
  syn include @AspPerlScript <sfile>:p:h/perl.vim
else
  runtime! syntax/html.vim
  unlet b:current_syntax
  syn include @AspPerlScript syntax/perl.vim
endif

syn cluster htmlPreproc add=AspPerlScriptInsideHtmlTags

syn region  AspPerlScriptInsideHtmlTags keepend matchgroup=Delimiter start=+<%=\=+ skip=+".*%>.*"+ end=+%>+ contains=@AspPerlScript
syn region  AspPerlScriptInsideHtmlTags keepend matchgroup=Delimiter start=+<script\s\+language="\=perlscript"\=[^>]*>+ end=+</script>+ contains=@AspPerlScript

let b:current_syntax = "aspperl"
