" Vim syntax file
" Language:	Privoxy actions file
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2026 Jan 07

" Privoxy 4.1.0

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn region privoxyActionsBlock matchgroup=privoxyBraces start="^\s*\zs{" end="}"
	\ contains=@privoxyActionPrefix,privoxyLineContinuation

" Actions {{{
let s:actions =<< trim END
  add-header
  block
  change-x-forwarded-for
  client-header-filter
  client-body-filter
  client-body-tagger
  client-header-tagger
  content-type-overwrite
  crunch-client-header
  crunch-if-none-match
  crunch-incoming-cookies
  crunch-outgoing-cookies
  crunch-server-header
  deanimate-gifs
  delay-response
  downgrade-http-version
  external-filter
  fast-redirects
  filter
  filter-client-headers
  filter-server-headers
  force-text-mode
  forward-override
  handle-as-empty-document
  handle-as-image
  hide-accept-language
  hide-content-disposition
  hide-forwarded-for-headers
  hide-from-header
  hide-if-modified-since
  hide-referrer
  hide-referer
  hide-user-agent
  https-inspection
  ignore-certificate-errors
  limit-connect
  limit-cookie-lifetime
  prevent-compression
  prevent-keeping-cookies
  overwrite-last-modified
  redirect
  server-header-filter
  server-header-tagger
  suppress-tag
  session-cookies-only
  set-image-blocker
END

for s:action in s:actions
  exe 'syn match privoxyAction "\<' .. s:action .. '\>" contained nextgroup=privoxyParams'
endfor
unlet s:action s:actions

syn region privoxyParams matchgroup=privoxyParamBraces start="{" end="}" contained

syn match privoxyFilterAction "\<filter\>-\@!" contained nextgroup=privoxyFilterParams
syn region privoxyFilterParams matchgroup=privoxyParamBraces start="{" end="}" contained contains=privoxyFilterArg

syn cluster privoxyAction contains=privoxyAction,privoxyFilterAction
" }}}

" Filters {{{
let s:filters =<< trim END
      allow-autocompletion
      all-popups
      banners-by-link
      banners-by-size
      blogspot
      bundeswehr
      content-cookies
      crude-parental
      demoronizer
      frameset-borders
      fun
      github
      google
      html-annoyances
      ie-exploits
      iframes
      imdb
      img-reorder
      js-annoyances
      js-events
      jumping-windows
      msn
      no-ping
      quicktime-kioskmode
      refresh-tags
      shockwave-flash
      site-specifics
      sourceforge
      tiny-textforms
      unsolicited-popups
      webbugs
      yahoo
      x-httpd-php-to-html
      html-to-xml
      xml-to-html
      less-download-windows
      privoxy-control
      hide-tor-exit-notation
      no-brotli-accepted
      privoxy-control
      remove-first-byte
      remove-test
      overwrite-test-value
END

for s:filter in s:filters
  exe 'syn match privoxyFilterArg "\<' .. s:filter .. '\>" contained"'
endfor
unlet s:filter s:filters
" }}}

syn match privoxyEnablePrefix  "\%(^\|\s\|{\)\@1<=+\l\@=" nextgroup=privoxy.*Action contained
syn match privoxyDisablePrefix "\%(^\|\s\|{\)\@1<=-\l\@=" nextgroup=privoxy.*Action contained
syn cluster privoxyActionPrefix contains=privoxyDisablePrefix,privoxyEnablePrefix

syn match privoxySettingsHeader    "^\s*\zs{{settings\}}"    contains=privoxyBraces nextgroup=privoxySettingsSection skipnl skipwhite
syn match privoxyDescriptionHeader "^\s*\zs{{description\}}" contains=privoxyBraces nextgroup=privoxyDescriptionSection skipnl
syn match privoxyAliasHeader	   "^\s*\zs{{alias\}}"	     contains=privoxyBraces nextgroup=privoxyAliasSection skipnl

syn region privoxySettingsSection    start="." end="^\s*\ze{" contained contains=privoxyComment,privoxySettingName
syn region privoxyDescriptionSection start="." end="^\s*\ze{" contained
syn region privoxyAliasSection	     start="." end="^\s*\ze{" contained contains=privoxyComment,privoxyAliasName

syn match privoxySettingName "\<[a-z][a-z-]*" contained nextgroup=privoxySettingEqual
syn match privoxySettingEqual "="	      contained nextgroup=privoxySettingValue
syn match privoxySettingValue ".*"	      contained

syn match privoxyAliasName "[+-]\<[a-z][a-z-]*"	contained nextgroup=privoxyAliasEqual skipwhite
syn match privoxyAliasEqual "="			contained nextgroup=privoxyAliasValue skipwhite
syn region privoxyAliasValue start="\S" skip="\\$" end="$" contained contains=@privoxyAction,@privoxyActionPrefix,privoxyLineContinuation

syn match privoxyBraces		  "[{}]" contained
syn match privoxyLineContinuation "\\$"  contained

syn keyword privoxyTodo	   TODO FIXME XXX NOTE contained
syn match   privoxyComment "#.*" contains=privoxyTodo,@Spell

hi def link privoxyAction		Identifier
hi def link privoxyAliasEqual		Operator
hi def link privoxyAliasHeader		Title
hi def link privoxyBraces		Delimiter
hi def link privoxyComment		Comment
hi def link privoxyDescriptionHeader	Title
hi def link privoxyDisablePrefix	Added
hi def link privoxyEnablePrefix		Removed
hi def link privoxyFilterAction		privoxyAction
hi def link privoxyFilterArg		Constant
hi def link privoxyLineContinuation	Special
hi def link privoxyParamBraces		privoxyBraces
hi def link privoxySettingEqual		Operator
hi def link privoxySettingName		Keyword
hi def link privoxySettingsHeader	Title
hi def link privoxySettingValue		Constant
hi def link privoxyTodo			Todo

let b:current_syntax = "privoxy"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker
