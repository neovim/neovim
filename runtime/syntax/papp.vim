" Vim syntax file for the "papp" file format (_p_erl _app_lication)
"
" Language:	papp
" Maintainer:	Marc Lehmann <pcg@goof.com>
" Last Change:	2009 Nov 11
" Filenames:    *.papp *.pxml *.pxsl
" URL:		http://papp.plan9.de/

" You can set the "papp_include_html" variable so that html will be
" rendered as such inside phtml sections (in case you actually put html
" there - papp does not require that). Also, rendering html tends to keep
" the clutter high on the screen - mixing three languages is difficult
" enough(!). PS: it is also slow.

" pod is, btw, allowed everywhere, which is actually wrong :(

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" source is basically xml, with included html (this is common) and perl bits
runtime! syntax/xml.vim
unlet b:current_syntax

if exists("papp_include_html")
  syn include @PAppHtml syntax/html.vim
  unlet b:current_syntax
  syntax spell default  " added by Bram
endif

syn include @PAppPerl syntax/perl.vim

syn cluster xmlFoldCluster add=papp_perl,papp_xperl,papp_phtml,papp_pxml,papp_perlPOD

" preprocessor commands
syn region papp_prep matchgroup=papp_prep start="^#\s*\(if\|elsif\)" end="$" keepend contains=@perlExpr contained
syn match papp_prep /^#\s*\(else\|endif\|??\).*$/ contained
" translation entries
syn region papp_gettext start=/__"/ end=/"/ contained contains=@papp_perlInterpDQ
syn cluster PAppHtml add=papp_gettext,papp_prep

" add special, paired xperl, perl and phtml tags
syn region papp_perl  matchgroup=xmlTag start="<perl>"  end="</perl>"  contains=papp_CDATAp,@PAppPerl keepend
syn region papp_xperl matchgroup=xmlTag start="<xperl>" end="</xperl>" contains=papp_CDATAp,@PAppPerl keepend
syn region papp_phtml matchgroup=xmlTag start="<phtml>" end="</phtml>" contains=papp_CDATAh,papp_ph_perl,papp_ph_html,papp_ph_hint,@PAppHtml keepend
syn region papp_pxml  matchgroup=xmlTag start="<pxml>"	end="</pxml>"  contains=papp_CDATAx,papp_ph_perl,papp_ph_xml,papp_ph_xint	     keepend
syn region papp_perlPOD start="^=[a-z]" end="^=cut" contains=@Pod,perlTodo keepend

" cdata sections
syn region papp_CDATAp matchgroup=xmlCdataDecl start="<!\[CDATA\[" end="\]\]>" contains=@PAppPerl					 contained keepend
syn region papp_CDATAh matchgroup=xmlCdataDecl start="<!\[CDATA\[" end="\]\]>" contains=papp_ph_perl,papp_ph_html,papp_ph_hint,@PAppHtml contained keepend
syn region papp_CDATAx matchgroup=xmlCdataDecl start="<!\[CDATA\[" end="\]\]>" contains=papp_ph_perl,papp_ph_xml,papp_ph_xint		 contained keepend

syn region papp_ph_perl matchgroup=Delimiter start="<[:?]" end="[:?]>"me=e-2 nextgroup=papp_ph_html contains=@PAppPerl		     contained keepend
syn region papp_ph_html matchgroup=Delimiter start=":>"    end="<[:?]"me=e-2 nextgroup=papp_ph_perl contains=@PAppHtml		     contained keepend
syn region papp_ph_hint matchgroup=Delimiter start="?>"    end="<[:?]"me=e-2 nextgroup=papp_ph_perl contains=@perlInterpDQ,@PAppHtml contained keepend
syn region papp_ph_xml	matchgroup=Delimiter start=":>"    end="<[:?]"me=e-2 nextgroup=papp_ph_perl contains=			     contained keepend
syn region papp_ph_xint matchgroup=Delimiter start="?>"    end="<[:?]"me=e-2 nextgroup=papp_ph_perl contains=@perlInterpDQ	     contained keepend

" synchronization is horrors!
syn sync clear
syn sync match pappSync grouphere papp_CDATAh "</\(perl\|xperl\|phtml\|macro\|module\)>"
syn sync match pappSync grouphere papp_CDATAh "^# *\(if\|elsif\|else\|endif\)"
syn sync match pappSync grouphere papp_CDATAh "</\(tr\|td\|table\|hr\|h1\|h2\|h3\)>"
syn sync match pappSync grouphere NONE	      "</\=\(module\|state\|macro\)>"

syn sync maxlines=300
syn sync minlines=5

" The default highlighting.

hi def link papp_prep		preCondit
hi def link papp_gettext	String

let b:current_syntax = "papp"
