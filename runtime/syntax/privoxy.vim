" Vim syntax file
" Language:	Privoxy actions file
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" URL:		http://gus.gscit.monash.edu.au/~djkea2/vim/syntax/privoxy.vim
" Last Change:	2007 Mar 30

" Privoxy 3.0.6

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,_,-

syn keyword privoxyTodo		 contained TODO FIXME XXX NOTE
syn match   privoxyComment "#.*" contains=privoxyTodo,@Spell

syn region privoxyActionLine matchgroup=privoxyActionLineDelimiter start="^\s*\zs{" end="}\ze\s*$"
	\ contains=privoxyEnabledPrefix,privoxyDisabledPrefix

syn match privoxyEnabledPrefix	"\%(^\|\s\|{\)\@<=+\l\@=" nextgroup=privoxyAction,privoxyFilterAction contained
syn match privoxyDisabledPrefix "\%(^\|\s\|{\)\@<=-\l\@=" nextgroup=privoxyAction,privoxyFilterAction contained

syn match privoxyAction "\%(add-header\|block\|content-type-overwrite\|crunch-client-header\|crunch-if-none-match\)\>" contained
syn match privoxyAction "\%(crunch-incoming-cookies\|crunch-outgoing-cookies\|crunch-server-header\|deanimate-gifs\)\>" contained
syn match privoxyAction "\%(downgrade-http-version\|fast-redirects\|filter-client-headers\|filter-server-headers\)\>" contained
syn match privoxyAction "\%(filter\|force-text-mode\|handle-as-empty-document\|handle-as-image\)\>" contained
syn match privoxyAction "\%(hide-accept-language\|hide-content-disposition\|hide-forwarded-for-headers\)\>" contained
syn match privoxyAction "\%(hide-from-header\|hide-if-modified-since\|hide-referrer\|hide-user-agent\|inspect-jpegs\)\>" contained
syn match privoxyAction "\%(kill-popups\|limit-connect\|overwrite-last-modified\|prevent-compression\|redirect\)\>" contained
syn match privoxyAction "\%(send-vanilla-wafer\|send-wafer\|session-cookies-only\|set-image-blocker\)\>" contained
syn match privoxyAction "\%(treat-forbidden-connects-like-blocks\)\>"

syn match privoxyFilterAction "filter{[^}]*}" contained contains=privoxyFilterArg,privoxyActionBraces
syn match privoxyActionBraces "[{}]" contained
syn keyword privoxyFilterArg js-annoyances js-events html-annoyances content-cookies refresh-tags unsolicited-popups all-popups
	\ img-reorder banners-by-size banners-by-link webbugs tiny-textforms jumping-windows frameset-borders demoronizer
	\ shockwave-flash quicktime-kioskmode fun crude-parental ie-exploits site-specifics no-ping google yahoo msn blogspot
	\ x-httpd-php-to-html html-to-xml xml-to-html hide-tor-exit-notation contained

" Alternative spellings
syn match privoxyAction "\%(kill-popup\|hide-referer\|prevent-keeping-cookies\)\>" contained

" Pre-3.0 compatibility
syn match privoxyAction "\%(no-cookie-read\|no-cookie-set\|prevent-reading-cookies\|prevent-setting-cookies\)\>" contained
syn match privoxyAction "\%(downgrade\|hide-forwarded\|hide-from\|image\|image-blocker\|no-compression\)\>" contained
syn match privoxyAction "\%(no-cookies-keep\|no-cookies-read\|no-cookies-set\|no-popups\|vanilla-wafer\|wafer\)\>" contained

syn match privoxySetting "\<for-privoxy-version\>"

syn match privoxyHeader "^\s*\zs{{\%(alias\|settings\)}}\ze\s*$"

hi def link privoxyAction		Identifier
hi def link privoxyFilterAction		Identifier
hi def link privoxyActionLineDelimiter	Delimiter
hi def link privoxyDisabledPrefix	SpecialChar
hi def link privoxyEnabledPrefix	SpecialChar
hi def link privoxyHeader		PreProc
hi def link privoxySetting		Identifier
hi def link privoxyFilterArg		Constant

hi def link privoxyComment		Comment
hi def link privoxyTodo			Todo

let b:current_syntax = "privoxy"

let &cpo = s:cpo_save
unlet s:cpo_save
