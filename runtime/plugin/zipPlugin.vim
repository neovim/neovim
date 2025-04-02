" zipPlugin.vim: Handles browsing zipfiles
"            PLUGIN PORTION
" Date:			Dec 07, 2021
" Maintainer:	This runtime file is looking for a new maintainer.
" Former Maintainer:	Charles E Campbell
" Last Change:
" 2025 Apr 02 by Vim Project: add *.whl to list of zip extensions (#17038)
" License:		Vim License  (see vim's :help license)
" Copyright:    Copyright (C) 2005-2016 Charles E. Campbell {{{1
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               zipPlugin.vim is provided *as is* and comes with no warranty
"               of any kind, either expressed or implied. By using this
"               plugin, you agree that in no event will the copyright
"               holder be liable for any damages resulting from the use
"               of this software.
"
" (James 4:8 WEB) Draw near to God, and he will draw near to you.
" Cleanse your hands, you sinners; and purify your hearts, you double-minded.
" ---------------------------------------------------------------------
" Load Once: {{{1
if &cp || exists("g:loaded_zipPlugin")
 finish
endif
let g:loaded_zipPlugin = "v33"
let s:keepcpo          = &cpo
set cpo&vim

" ---------------------------------------------------------------------
" Options: {{{1
if !exists("g:zipPlugin_ext")
 let g:zipPlugin_ext='*.aar,*.apk,*.celzip,*.crtx,*.docm,*.docx,*.dotm,*.dotx,*.ear,*.epub,*.gcsx,*.glox,*.gqsx,*.ja,*.jar,*.kmz,*.odb,*.odc,*.odf,*.odg,*.odi,*.odm,*.odp,*.ods,*.odt,*.otc,*.otf,*.otg,*.oth,*.oti,*.otp,*.ots,*.ott,*.oxt,*.potm,*.potx,*.ppam,*.ppsm,*.ppsx,*.pptm,*.pptx,*.sldx,*.thmx,*.vdw,*.war,*.whl,*.wsz,*.xap,*.xlam,*.xlsb,*.xlsm,*.xlsx,*.xltm,*.xltx,*.xpi,*.zip'
endif

" ---------------------------------------------------------------------
" Public Interface: {{{1
augroup zip
 au!
 au BufReadCmd   zipfile:*	call zip#Read(expand("<amatch>"), 1)
 au FileReadCmd  zipfile:*	call zip#Read(expand("<amatch>"), 0)
 au BufWriteCmd  zipfile:*	call zip#Write(expand("<amatch>"))
 au FileWriteCmd zipfile:*	call zip#Write(expand("<amatch>"))

 if has("unix")
  au BufReadCmd   zipfile:*/*	call zip#Read(expand("<amatch>"), 1)
  au FileReadCmd  zipfile:*/*	call zip#Read(expand("<amatch>"), 0)
  au BufWriteCmd  zipfile:*/*	call zip#Write(expand("<amatch>"))
  au FileWriteCmd zipfile:*/*	call zip#Write(expand("<amatch>"))
 endif

 exe "au BufReadCmd ".g:zipPlugin_ext.' call zip#Browse(expand("<amatch>"))'
augroup END

" ---------------------------------------------------------------------
"  Restoration And Modelines: {{{1
"  vim: fdm=marker
let &cpo= s:keepcpo
unlet s:keepcpo
