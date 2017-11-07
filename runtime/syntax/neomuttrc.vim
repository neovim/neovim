" Vim syntax file
" Language:	NeoMutt setup files
" Maintainer:	Guillaume Brogi <gui-gui@netcourrier.com>
" Last Change:	2017 Oct 28
" Original version based on syntax/muttrc.vim

" This file covers NeoMutt 20170912

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Set the keyword characters
setlocal isk=@,48-57,_,-

" handling optional variables
syntax match muttrcComment		"^# .*$" contains=@Spell
syntax match muttrcComment		"^#[^ ].*$"
syntax match muttrcComment		"^#$"
syntax match muttrcComment		"[^\\]#.*$"lc=1

" Escape sequences (back-tick and pipe goes here too)
syntax match muttrcEscape		+\\[#tnr"'Cc ]+
syntax match muttrcEscape		+[`|]+
syntax match muttrcEscape		+\\$+

" The variables takes the following arguments
"syn match  muttrcString		contained "=\s*[^ #"'`]\+"lc=1 contains=muttrcEscape
syntax region muttrcString		contained keepend start=+"+ms=e skip=+\\"+ end=+"+ contains=muttrcEscape,muttrcCommand,muttrcAction,muttrcShellString
syntax region muttrcString		contained keepend start=+'+ms=e skip=+\\'+ end=+'+ contains=muttrcEscape,muttrcCommand,muttrcAction
syntax match muttrcStringNL	contained skipwhite skipnl "\s*\\$" nextgroup=muttrcString,muttrcStringNL

syntax region muttrcShellString	matchgroup=muttrcEscape keepend start=+`+ skip=+\\`+ end=+`+ contains=muttrcVarStr,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcCommand,muttrcVarDeprecatedStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad

syntax match  muttrcRXChars	contained /[^\\][][.*?+]\+/hs=s+1
syntax match  muttrcRXChars	contained /[][|()][.*?+]*/
syntax match  muttrcRXChars	contained /['"]^/ms=s+1
syntax match  muttrcRXChars	contained /$['"]/me=e-1
syntax match  muttrcRXChars	contained /\\/
" Why does muttrcRXString2 work with one \ when muttrcRXString requires two?
syntax region muttrcRXString	contained skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXChars
syntax region muttrcRXString	contained skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXChars
syntax region muttrcRXString	contained skipwhite start=+[^ 	"'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXChars
" For some reason, skip refuses to match backslashes here...
syntax region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXChars
syntax region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXChars
syntax region muttrcRXString2	contained skipwhite start=+'+ skip=+\'+ end=+'+ contains=muttrcRXChars
syntax region muttrcRXString2	contained skipwhite start=+"+ skip=+\"+ end=+"+ contains=muttrcRXChars

" these must be kept synchronized with muttrcRXString, but are intended for
" muttrcRXHooks
syntax region muttrcRXHookString	contained keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+[^ 	"'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax match muttrcRXHookStringNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcRXHookString,muttrcRXHookStringNL

" these are exclusively for args lists (e.g. -rx pat pat pat ...)
syntax region muttrcRXPat		contained keepend skipwhite start=+'+ skip=+\\'+ end=+'\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syntax region muttrcRXPat		contained keepend skipwhite start=+"+ skip=+\\"+ end=+"\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syntax match muttrcRXPat		contained /[^-'"#!]\S\+/ skipwhite contains=muttrcRXChars nextgroup=muttrcRXPat
syntax match muttrcRXDef 		contained "-rx\s\+" skipwhite nextgroup=muttrcRXPat

syntax match muttrcSpecial		+\(['"]\)!\1+

syntax match muttrcSetStrAssignment contained skipwhite /=\s*\%(\\\?\$\)\?[0-9A-Za-z_-]\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcVariable,muttrcEscapedVariable
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*"+hs=s+1 end=+"+ skip=+\\"+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcString
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*'+hs=s+1 end=+'+ skip=+\\'+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcString
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*"\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*'\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\%(ask-\)\?\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*"\%(ask-\)\?\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*'\%(ask-\)\?\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetNumAssignment contained skipwhite /=\s*\d\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*"\d\+"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*'\d\+'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr

" Now catch some email addresses and headers (purified version from mail.vim)
syntax match muttrcEmail		"[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+"
syntax match muttrcHeader		"\<\c\%(From\|To\|C[Cc]\|B[Cc][Cc]\|Reply-To\|Subject\|Return-Path\|Received\|Date\|Replied\|Attach\)\>:\="

syntax match   muttrcKeySpecial	contained +\%(\\[Cc'"]\|\^\|\\[01]\d\{2}\)+
syntax match   muttrcKey		contained "\S\+"			contains=muttrcKeySpecial,muttrcKeyName
syntax region  muttrcKey		contained start=+"+ skip=+\\\\\|\\"+ end=+"+	contains=muttrcKeySpecial,muttrcKeyName
syntax region  muttrcKey		contained start=+'+ skip=+\\\\\|\\'+ end=+'+	contains=muttrcKeySpecial,muttrcKeyName
syntax match   muttrcKeyName	contained "\\[trne]"
syntax match   muttrcKeyName	contained "\c<\%(BackSpace\|BackTab\|Delete\|Down\|End\|Enter\|Esc\|Home\|Insert\|Left\|Next\|PageDown\|PageUp\|Return\|Right\|Space\|Tab\|Up\)>"
syntax match   muttrcKeyName	contained "\c<F\d\+>"

syntax match muttrcFormatErrors contained /%./

syntax match muttrcStrftimeEscapes contained /%[AaBbCcDdeFGgHhIjklMmnpRrSsTtUuVvWwXxYyZz+%]/
syntax match muttrcStrftimeEscapes contained /%E[cCxXyY]/
syntax match muttrcStrftimeEscapes contained /%O[BdeHImMSuUVwWy]/

syntax region muttrcIndexFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcIndexFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcGroupIndexFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcGroupIndexFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcSidebarFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcSidebarFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcQueryFormatStr contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcAliasFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAliasFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcAliasFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAliasFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcAttachFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcAttachFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcComposeFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcComposeFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcComposeFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcComposeFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcFolderFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcFolderFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcMixFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcMixFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPCmdFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPCmdFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcStatusFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcStatusFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPGetKeysFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPGetKeysFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcPGPGetKeysFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPGetKeysFormatEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcSmimeFormatStr	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcSmimeFormatStr	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcStrftimeFormatStr contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStrftimeEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax region muttrcStrftimeFormatStr contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStrftimeEscapes,muttrcFormatErrors nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr

" Format escapes and conditionals
syntax match muttrcFormatConditionals2 contained /[^?]*?/
function s:escapesConditionals(baseName, sequence, alignment, secondary)
	exec 'syntax match muttrc' . a:baseName . 'Escapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?\%(' . a:sequence . '\|%\)/'
	if a:alignment
		exec 'syntax match muttrc' . a:baseName . 'Escapes contained /%[>|*]./'
	endif
	if a:secondary
		exec 'syntax match muttrc' . a:baseName . 'Conditionals contained /%?\%(' . a:sequence . '\)?/ nextgroup=muttrcFormatConditionals2'
	else
		exec 'syntax match muttrc' . a:baseName . 'Conditionals contained /%?\%(' . a:sequence . '\)?/'
	endif
endfunction

" flatcap compiled a list of formats here: https://pastebin.com/raw/5QXhiP6L
" UPDATE
" The following info was pulled from hdr_format_str in hdrline.c
call s:escapesConditionals('IndexFormat', '[AaBbCcDdEeFfgHIiJKLlMmNnOPqrSsTtuvWXxYyZz(<[{]\|G[a-zA-Z]\+', 1, 1)
" The following info was pulled from alias_format_str in addrbook.c
syntax match muttrcAliasFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[afnrt%]/
" The following info was pulled from newsgroup_format_str in browser.c
call s:escapesConditionals('GroupIndexFormat', '[CdfMNns]', 1, 1)
" The following info was pulled from cb_format_str in sidebar.c
call s:escapesConditionals('SidebarFormat', '[BdFLNnSt!]', 1, 1)
" The following info was pulled from query_format_str in query.c
call s:escapesConditionals('QueryFormat', '[acent]', 0, 1)
" The following info was pulled from mutt_attach_fmt in recvattach.c
call s:escapesConditionals('AttachFormat', '[CcDdeFfIMmnQsTtuX]', 1, 1)
" The following info was pulled from compose_format_str in compose.c
syntax match muttrcComposeFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[ahlv%]/
syntax match muttrcComposeFormatEscapes contained /%[>|*]./
" The following info was pulled from folder_format_str in browser.c
call s:escapesConditionals('FolderFormat', '[CDdfFglNstu]', 1, 0)
" The following info was pulled from mix_entry_fmt in remailer.c
call s:escapesConditionals('MixFormat', '[acns]', 0, 0)
" The following info was pulled from crypt_entry_fmt in crypt-gpgme.c 
" and pgp_entry_fmt in pgpkey.c (note that crypt_entry_fmt supports 
" 'p', but pgp_entry_fmt does not).
call s:escapesConditionals('PGPFormat', '[acfklnptu[]', 0, 0)
" The following info was pulled from _mutt_fmt_pgp_command in 
" pgpinvoke.c
call s:escapesConditionals('PGPCmdFormat', '[afprs]', 0, 1)
" The following info was pulled from status_format_str in status.c
call s:escapesConditionals('StatusFormat', '[bdFfhLlMmnoPprSstuVu]', 1, 1)
" This matches the documentation, but directly contradicts the code 
" (according to the code, this should be identical to the 
" muttrcPGPCmdFormatEscapes
syntax match muttrcPGPGetKeysFormatEscapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?[acfklntu[%]/
" The following info was pulled from _mutt_fmt_smime_command in 
" smime.c
call s:escapesConditionals('SmimeFormat', '[aCcdfiks]', 0, 1)

syntax region muttrcTimeEscapes contained start=+%{+ end=+}+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes contained start=+%(+ end=+)+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes contained start=+%<+ end=+>+ contains=muttrcStrftimeEscapes
syntax region muttrcPGPTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes

syntax match muttrcVarEqualsAliasFmt contained skipwhite "=" nextgroup=muttrcAliasFormatStr
syntax match muttrcVarEqualsAttachFmt contained skipwhite "=" nextgroup=muttrcAttachFormatStr
syntax match muttrcVarEqualsComposeFmt contained skipwhite "=" nextgroup=muttrcComposeFormatStr
syntax match muttrcVarEqualsFolderFmt contained skipwhite "=" nextgroup=muttrcFolderFormatStr
syntax match muttrcVarEqualsIdxFmt contained skipwhite "=" nextgroup=muttrcIndexFormatStr
syntax match muttrcVarEqualsGrpIdxFmt contained skipwhite "=" nextgroup=muttrcGroupIndexFormatStr
syntax match muttrcVarEqualsMixFmt contained skipwhite "=" nextgroup=muttrcMixFormatStr
syntax match muttrcVarEqualsPGPFmt contained skipwhite "=" nextgroup=muttrcPGPFormatStr
syntax match muttrcVarEqualsQueryFmt contained skipwhite "=" nextgroup=muttrcQueryFormatStr
syntax match muttrcVarEqualsPGPCmdFmt contained skipwhite "=" nextgroup=muttrcPGPCmdFormatStr
syntax match muttrcVarEqualsSdbFmt contained skipwhite "=" nextgroup=muttrcSidebarFormatStr
syntax match muttrcVarEqualsStatusFmt contained skipwhite "=" nextgroup=muttrcStatusFormatStr
syntax match muttrcVarEqualsPGPGetKeysFmt contained skipwhite "=" nextgroup=muttrcPGPGetKeysFormatStr
syntax match muttrcVarEqualsSmimeFmt contained skipwhite "=" nextgroup=muttrcSmimeFormatStr
syntax match muttrcVarEqualsStrftimeFmt contained skipwhite "=" nextgroup=muttrcStrftimeFormatStr

syntax match muttrcVPrefix contained /[?&]/ nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr

" List of the different screens in mutt
" UPDATE
syntax keyword muttrcMenu contained alias attach browser compose editor index pager postpone pgp mix query generic
syntax match muttrcMenuList "\S\+" contained contains=muttrcMenu
syntax match muttrcMenuCommas /,/ contained

" List of hooks in Commands in init.h
" UPDATE
syntax keyword muttrcHooks contained skipwhite
			\ account-hook append-hook charset-hook
			\ close-hook crypt-hook fcc-hook fcc-save-hook folder-hook iconv-hook mbox-hook
			\ message-hook open-hook pgp-hook reply-hook save-hook send-hook send2-hook
syntax keyword muttrcHooks skipwhite shutdown-hook startup-hook timeout-hook nextgroup=muttrcCommand

syntax region muttrcSpamPattern	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPattern nextgroup=muttrcString,muttrcStringNL
syntax region muttrcSpamPattern	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPattern nextgroup=muttrcString,muttrcStringNL

syntax region muttrcNoSpamPattern	contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPattern
syntax region muttrcNoSpamPattern	contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPattern

syntax match muttrcAttachmentsMimeType contained "[*a-z0-9_-]\+/[*a-z0-9._-]\+\s*" skipwhite nextgroup=muttrcAttachmentsMimeType
syntax match muttrcAttachmentsFlag contained "[+-]\%([AI]\|inline\|attachment\)\s\+" skipwhite nextgroup=muttrcAttachmentsMimeType
syntax match muttrcAttachmentsLine "^\s*\%(un\)\?attachments\s\+" skipwhite nextgroup=muttrcAttachmentsFlag

syntax match muttrcUnHighlightSpace contained "\%(\s\+\|\\$\)"

syntax keyword muttrcAsterisk	contained *
syntax keyword muttrcListsKeyword	lists skipwhite nextgroup=muttrcGroupDef,muttrcComment
syntax keyword muttrcListsKeyword	unlists skipwhite nextgroup=muttrcAsterisk,muttrcComment

syntax keyword muttrcSubscribeKeyword	subscribe nextgroup=muttrcGroupDef,muttrcComment
syntax keyword muttrcSubscribeKeyword	unsubscribe nextgroup=muttrcAsterisk,muttrcComment

syntax keyword muttrcAlternateKeyword contained alternates unalternates
syntax region muttrcAlternatesLine keepend start=+^\s*\%(un\)\?alternates\s+ skip=+\\$+ end=+$+ contains=muttrcAlternateKeyword,muttrcGroupDef,muttrcRXPat,muttrcUnHighlightSpace,muttrcComment

" muttrcVariable includes a prefix because partial strings are considered
" valid.
syntax match muttrcVariable	contained "\\\@<![a-zA-Z_-]*\$[a-zA-Z_-]\+" contains=muttrcVariableInner
syntax match muttrcVariableInner	contained "\$[a-zA-Z_-]\+"
syntax match muttrcEscapedVariable	contained "\\\$[a-zA-Z_-]\+"

syntax match muttrcBadAction	contained "[^<>]\+" contains=muttrcEmail
syntax match muttrcAction		contained "<[^>]\{-}>" contains=muttrcBadAction,muttrcFunction,muttrcKeyName

" First, functions that take regular expressions:
syntax match  muttrcRXHookNot	contained /!\s*/ skipwhite nextgroup=muttrcRXHookString,muttrcRXHookStringNL
syntax match  muttrcRXHooks	/\<\%(account\|append\|close\|crypt\|folder\|mbox\|open\|pgp\)-hook\>/ skipwhite nextgroup=muttrcRXHookNot,muttrcRXHookString,muttrcRXHookStringNL

" Now, functions that take patterns
syntax match muttrcPatHookNot	contained /!\s*/ skipwhite nextgroup=muttrcPattern
syntax match muttrcPatHooks	/\<\%(charset\|iconv\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcPattern
syntax match muttrcPatHooks	/\<\%(message\|reply\|send\|send2\|save\|fcc\|fcc-save\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcOptPattern

syntax match muttrcBindFunction	contained /\S\+\>/ skipwhite contains=muttrcFunction
syntax match muttrcBindFunctionNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syntax match muttrcBindKey		contained /\S\+/ skipwhite contains=muttrcKey nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syntax match muttrcBindKeyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindKey,muttrcBindKeyNL
syntax match muttrcBindMenuList	contained /\S\+/ skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcBindKey,muttrcBindKeyNL
syntax match muttrcBindMenuListNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindMenuList,muttrcBindMenuListNL

syntax region muttrcMacroDescr	contained keepend skipwhite start=+\s*\S+ms=e skip=+\\ + end=+ \|$+me=s
syntax region muttrcMacroDescr	contained keepend skipwhite start=+'+ms=e skip=+\\'+ end=+'+me=s
syntax region muttrcMacroDescr	contained keepend skipwhite start=+"+ms=e skip=+\\"+ end=+"+me=s
syntax match muttrcMacroDescrNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax region muttrcMacroBody	contained skipwhite start="\S" skip='\\ \|\\$' end=' \|$' contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcCommand,muttrcAction nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax region muttrcMacroBody matchgroup=Type contained skipwhite start=+'+ms=e skip=+\\'+ end=+'\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax region muttrcMacroBody matchgroup=Type contained skipwhite start=+"+ms=e skip=+\\"+ end=+"\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax match muttrcMacroBodyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syntax match muttrcMacroKey	contained /\S\+/ skipwhite contains=muttrcKey nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syntax match muttrcMacroKeyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syntax match muttrcMacroMenuList	contained /\S\+/ skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syntax match muttrcMacroMenuListNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL

syntax match muttrcAddrContent	contained "[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+\s*" skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax region muttrcAddrContent	contained start=+'+ end=+'\s*+ skip=+\\'+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax region muttrcAddrContent	contained start=+"+ end=+"\s*+ skip=+\\"+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax match muttrcAddrDef 	contained "-addr\s\+" skipwhite nextgroup=muttrcAddrContent

syntax match muttrcGroupFlag	contained "-group"
syntax region muttrcGroupDef	contained start="-group\s\+" skip="\\$" end="\s" skipwhite keepend contains=muttrcGroupFlag,muttrcUnHighlightSpace

syntax keyword muttrcGroupKeyword	contained group ungroup
syntax region muttrcGroupLine	keepend start=+^\s*\%(un\)\?group\s+ skip=+\\$+ end=+$+ contains=muttrcGroupKeyword,muttrcGroupDef,muttrcAddrDef,muttrcRXDef,muttrcUnHighlightSpace,muttrcComment

syntax match muttrcAliasGroupName	contained /\w\+/ skipwhite nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syntax match muttrcAliasGroupDefNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasGroupName,muttrcAliasGroupDefNL
syntax match muttrcAliasGroupDef	contained /\s*-group/ skipwhite nextgroup=muttrcAliasGroupName,muttrcAliasGroupDefNL contains=muttrcGroupFlag
syntax match muttrcAliasComma	contained /,/ skipwhite nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syntax match muttrcAliasEmail	contained /\S\+@\S\+/ contains=muttrcEmail nextgroup=muttrcAliasName,muttrcAliasNameNL skipwhite
syntax match muttrcAliasEncEmail	contained /<[^>]\+>/ contains=muttrcEmail nextgroup=muttrcAliasComma
syntax match muttrcAliasEncEmailNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasEncEmail,muttrcAliasEncEmailNL
syntax match muttrcAliasNameNoParens contained /[^<(@]\+\s\+/ nextgroup=muttrcAliasEncEmail,muttrcAliasEncEmailNL
syntax region muttrcAliasName	contained matchgroup=Type start=/(/ end=/)/ skipwhite
syntax match muttrcAliasNameNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasName,muttrcAliasNameNL
syntax match muttrcAliasENNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syntax match muttrcAliasKey	contained /\s*[^- \t]\S\+/ skipwhite nextgroup=muttrcAliasEmail,muttrcAliasEncEmail,muttrcAliasNameNoParens,muttrcAliasENNL
syntax match muttrcAliasNL		contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL

syntax match muttrcUnAliasKey	contained "\s*\w\+\s*" skipwhite nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syntax match muttrcUnAliasNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcUnAliasKey,muttrcUnAliasNL

syntax match muttrcSimplePat contained "!\?\^\?[~][ADEFgGklNOpPQRSTuUvV=$]"
syntax match muttrcSimplePat contained "!\?\^\?[~][mnXz]\s*\%([<>-][0-9]\+[kM]\?\|[0-9]\+[kM]\?[-]\%([0-9]\+[kM]\?\)\?\)"
syntax match muttrcSimplePat contained "!\?\^\?[~][dr]\s*\%(\%(-\?[0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)\|\%(\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)-\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)\?\)\?\)\|\%([<>=][0-9]\+[ymwd]\)\|\%(`[^`]\+`\)\|\%(\$[a-zA-Z0-9_-]\+\)\)" contains=muttrcShellString,muttrcVariable
syntax match muttrcSimplePat contained "!\?\^\?[~][bBcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatRXContainer
syntax match muttrcSimplePat contained "!\?\^\?[%][bBcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
syntax match muttrcSimplePat contained "!\?\^\?[=][bcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
syntax region muttrcSimplePat contained keepend start=+!\?\^\?[~](+ end=+)+ contains=muttrcSimplePat
"syn match muttrcSimplePat contained /'[^~=%][^']*/ contains=muttrcRXString
syntax region muttrcSimplePatString contained keepend start=+"+ end=+"+ skip=+\\"+
syntax region muttrcSimplePatString contained keepend start=+'+ end=+'+ skip=+\\'+
syntax region muttrcSimplePatString contained keepend start=+[^ 	"']+ skip=+\\ + end=+\s+re=e-1
syntax region muttrcSimplePatRXContainer contained keepend start=+"+ end=+"+ skip=+\\"+ contains=muttrcRXString
syntax region muttrcSimplePatRXContainer contained keepend start=+'+ end=+'+ skip=+\\'+ contains=muttrcRXString
syntax region muttrcSimplePatRXContainer contained keepend start=+[^ 	"']+ skip=+\\ + end=+\s+re=e-1 contains=muttrcRXString
syntax match muttrcSimplePatMetas contained /[(|)]/

syntax match muttrcOptSimplePat contained skipwhite /[~=%!(^].*/ contains=muttrcSimplePat,muttrcSimplePatMetas
syntax match muttrcOptSimplePat contained skipwhite /[^~=%!(^].*/ contains=muttrcRXString
syntax region muttrcOptPattern contained matchgroup=Type keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcOptSimplePat,muttrcUnHighlightSpace nextgroup=muttrcString,muttrcStringNL
syntax region muttrcOptPattern contained matchgroup=Type keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcOptSimplePat,muttrcUnHighlightSpace nextgroup=muttrcString,muttrcStringNL
syntax region muttrcOptPattern contained keepend skipwhite start=+[~](+ end=+)+ skip=+\\)+ contains=muttrcSimplePat nextgroup=muttrcString,muttrcStringNL
syntax match muttrcOptPattern contained skipwhite /[~][A-Za-z]/ contains=muttrcSimplePat nextgroup=muttrcString,muttrcStringNL
syntax match muttrcOptPattern contained skipwhite /[.]/ nextgroup=muttrcString,muttrcStringNL
" Keep muttrcPattern and muttrcOptPattern synchronized
syntax region muttrcPattern contained matchgroup=Type keepend skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syntax region muttrcPattern contained matchgroup=Type keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syntax region muttrcPattern contained keepend skipwhite start=+[~](+ end=+)+ skip=+\\)+ contains=muttrcSimplePat
syntax match muttrcPattern contained skipwhite /[~][A-Za-z]/ contains=muttrcSimplePat
syntax match muttrcPattern contained skipwhite /[.]/
syntax region muttrcPatternInner contained keepend start=+"[~=%!(^]+ms=s+1 skip=+\\"+ end=+"+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas
syntax region muttrcPatternInner contained keepend start=+'[~=%!(^]+ms=s+1 skip=+\\'+ end=+'+me=e-1 contains=muttrcSimplePat,muttrcUnHighlightSpace,muttrcSimplePatMetas

" Colour definitions takes object, foreground and background arguments (regexps excluded).
syntax match muttrcColorMatchCount	contained "[0-9]\+"
syntax match muttrcColorMatchCountNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax region muttrcColorRXPat	contained start=+\s*'+ skip=+\\'+ end=+'\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax region muttrcColorRXPat	contained start=+\s*"+ skip=+\\"+ end=+"\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax keyword muttrcColor	contained black blue cyan default green magenta red white yellow
syntax keyword muttrcColor	contained brightblack brightblue brightcyan brightdefault brightgreen brightmagenta brightred brightwhite brightyellow
syntax match   muttrcColor	contained "\<\%(bright\)\=color\d\{1,3}\>"
" Now for the structure of the color line
syntax match muttrcColorRXNL	contained skipnl "\s*\\$" nextgroup=muttrcColorRXPat,muttrcColorRXNL
syntax match muttrcColorBG 	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorRXPat,muttrcColorRXNL
syntax match muttrcColorBGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFG 	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorFG,muttrcColorFGNL
syntax match muttrcColorContext 	contained /\s*[$]\?\w\+/ contains=muttrcColorField,muttrcVariable,muttrcUnHighlightSpace,muttrcColorCompose nextgroup=muttrcColorFG,muttrcColorFGNL
syntax match muttrcColorNL 	contained skipnl "\s*\\$" nextgroup=muttrcColorContext,muttrcColorNL,muttrcColorCompose
syntax match muttrcColorKeyword	contained /^\s*color\s\+/ nextgroup=muttrcColorContext,muttrcColorNL,muttrcColorCompose
" And now color's brother:
syntax region muttrcUnColorPatterns contained skipwhite start=+\s*'+ end=+'+ skip=+\\'+ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syntax region muttrcUnColorPatterns contained skipwhite start=+\s*"+ end=+"+ skip=+\\"+ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syntax match muttrcUnColorPatterns contained skipwhite /\s*[^'"\s]\S\*/ contains=muttrcPattern nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syntax match muttrcUnColorPatNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorPatterns,muttrcUnColorPatNL
syntax match muttrcUnColorAll	contained skipwhite /[*]/
syntax match muttrcUnColorAPNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorPatterns,muttrcUnColorAll,muttrcUnColorAPNL
syntax match muttrcUnColorIndex	contained skipwhite /\s*index\s\+/ nextgroup=muttrcUnColorPatterns,muttrcUnColorAll,muttrcUnColorAPNL
syntax match muttrcUnColorIndexNL	contained skipwhite skipnl /\s*\\$/ nextgroup=muttrcUnColorIndex,muttrcUnColorIndexNL
syntax match muttrcUnColorKeyword	contained skipwhite /^\s*uncolor\s\+/ nextgroup=muttrcUnColorIndex,muttrcUnColorIndexNL
syntax region muttrcUnColorLine keepend start=+^\s*uncolor\s+ skip=+\\$+ end=+$+ contains=muttrcUnColorKeyword,muttrcComment,muttrcUnHighlightSpace

syntax keyword muttrcMonoAttrib	contained bold none normal reverse standout underline
syntax keyword muttrcMono	contained mono		skipwhite nextgroup=muttrcColorField,muttrcColorCompose
syntax match   muttrcMonoLine	"^\s*mono\s\+\S\+"	skipwhite nextgroup=muttrcMonoAttrib contains=muttrcMono

" List of fields in Fields in color.c
" UPDATE
syntax keyword muttrcColorField skipwhite contained 
			\ attach_headers attachment bold error hdrdefault index_author index_collapsed
			\ index_date index_label index_number index_size index_subject index_tags
			\ indicator markers message normal progress prompt quoted search sidebar_divider
			\ sidebar_flagged sidebar_highlight sidebar_indicator sidebar_new
			\ sidebar_ordinary sidebar_spoolfile signature status tilde tree underline
			\ body header index index_flags index_tag
			\ nextgroup=muttrcColor
syntax match   muttrcColorField	contained "\<quoted\d\=\>"

syntax match muttrcColorCompose skipwhite contained /\s*compose\s*/ nextgroup=muttrcColorComposeField
" List of fields in ComposeFields in color.c
" UPDATE
syntax keyword muttrcColorComposeField skipwhite contained
			\ header security_encrypt security_sign security_both security_none
			\ nextgroup=muttrcColorFG,muttrcColorFGNL
syntax region muttrcColorLine keepend start=/^\s*color\s\+/ skip=+\\$+ end=+$+ contains=muttrcColorKeyword,muttrcComment,muttrcUnHighlightSpace


function s:boolQuadGen(type, vars, deprecated)
	let l:novars = copy(a:vars)
	call map(l:novars, '"no" . v:val')
	let l:invvars = copy(a:vars)
	call map(l:invvars, '"inv" . v:val')

	let l:orig_type = copy(a:type)
	if a:deprecated
		let l:type = 'Deprecated' . a:type
	else
		let l:type = a:type
	endif

	exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(a:vars) . ' nextgroup=muttrcSet' . l:orig_type . 'Assignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr'
	exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:novars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr'
	exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:invvars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr'
endfunction

" List of DT_BOOL in MuttVars in init.h
" UPDATE
call s:boolQuadGen('Bool', [
			\ 'allow_8bit', 'allow_ansi', 'arrow_cursor', 'ascii_chars', 'askbcc', 'askcc',
			\ 'ask_follow_up', 'ask_x_comment_to', 'attach_split', 'autoedit', 'auto_tag',
			\ 'beep', 'beep_new', 'bounce_delivered', 'braille_friendly', 'check_mbox_size',
			\ 'check_new', 'collapse_all', 'collapse_flagged', 'collapse_unread',
			\ 'confirmappend', 'confirmcreate', 'crypt_autoencrypt', 'crypt_autopgp',
			\ 'crypt_autosign', 'crypt_autosmime', 'crypt_confirmhook',
			\ 'crypt_opportunistic_encrypt', 'crypt_replyencrypt', 'crypt_replysign',
			\ 'crypt_replysignencrypted', 'crypt_timestamp', 'crypt_use_gpgme',
			\ 'crypt_use_pka', 'delete_untag', 'digest_collapse', 'duplicate_threads',
			\ 'edit_headers', 'encode_from', 'fast_reply', 'fcc_clear', 'flag_safe',
			\ 'followup_to', 'force_name', 'forward_decode', 'forward_decrypt',
			\ 'forward_quote', 'forward_references', 'hdrs', 'header',
			\ 'header_cache_compress', 'header_color_partial', 'help', 'hidden_host',
			\ 'hide_limited', 'hide_missing', 'hide_thread_subject', 'hide_top_limited',
			\ 'hide_top_missing', 'history_remove_dups', 'honor_disposition', 'idn_decode',
			\ 'idn_encode', 'ignore_linear_white_space', 'ignore_list_reply_to',
			\ 'imap_check_subscribed', 'imap_idle', 'imap_list_subscribed', 'imap_passive',
			\ 'imap_peek', 'imap_servernoise', 'implicit_autoview', 'include_onlyfirst',
			\ 'keep_flagged', 'keywords_legacy', 'keywords_standard', 'mailcap_sanitize',
			\ 'mail_check_recent', 'mail_check_stats', 'maildir_check_cur',
			\ 'maildir_header_cache_verify', 'maildir_trash', 'markers', 'mark_old',
			\ 'menu_move_off', 'menu_scroll', 'message_cache_clean', 'meta_key', 'metoo',
			\ 'mh_purge', 'mime_forward_decode', 'mime_subject', 'mime_type_query_first',
			\ 'narrow_tree', 'nm_record', 'nntp_listgroup', 'nntp_load_description',
			\ 'pager_stop', 'pgp_auto_decode', 'pgp_autoinline', 'pgp_check_exit',
			\ 'pgp_ignore_subkeys', 'pgp_long_ids', 'pgp_replyinline',
			\ 'pgp_retainable_sigs', 'pgp_self_encrypt', 'pgp_show_unusable',
			\ 'pgp_strict_enc', 'pgp_use_gpg_agent', 'pipe_decode', 'pipe_split',
			\ 'pop_auth_try_all', 'pop_last', 'postpone_encrypt', 'print_decode',
			\ 'print_split', 'prompt_after', 'read_only', 'reflow_space_quotes',
			\ 'reflow_text', 'reply_self', 'reply_with_xorig', 'resolve',
			\ 'resume_draft_files', 'resume_edited_draft_files', 'reverse_alias',
			\ 'reverse_name', 'reverse_realname', 'rfc2047_parameters', 'save_address',
			\ 'save_empty', 'save_name', 'save_unsubscribed', 'score', 'show_new_news',
			\ 'show_only_unread', 'sidebar_folder_indent', 'sidebar_new_mail_only',
			\ 'sidebar_next_new_wrap', 'sidebar_on_right', 'sidebar_short_path',
			\ 'sidebar_visible', 'sig_dashes', 'sig_on_top', 'smart_wrap',
			\ 'smime_ask_cert_label', 'smime_decrypt_use_default_key', 'smime_is_default',
			\ 'smime_self_encrypt', 'sort_re', 'ssl_force_tls', 'ssl_use_sslv2',
			\ 'ssl_use_sslv3', 'ssl_usesystemcerts', 'ssl_use_tlsv1', 'ssl_use_tlsv1_1',
			\ 'ssl_use_tlsv1_2', 'ssl_verify_dates', 'ssl_verify_host',
			\ 'ssl_verify_partial_chains', 'status_on_top', 'strict_threads', 'suspend',
			\ 'text_flowed', 'thorough_search', 'thread_received', 'tilde', 'ts_enabled',
			\ 'uncollapse_jump', 'uncollapse_new', 'use_8bitmime', 'use_domain',
			\ 'use_envelope_from', 'use_from', 'use_ipv6', 'user_agent',
			\ 'virtual_spoolfile', 'wait_key', 'weed', 'wrap_search', 'write_bcc',
			\ 'x_comment_to'
			\ ], 0)

" Deprecated Bools
" UPDATE
" List of DT_SYNONYM synonyms of Bools in MuttVars in init.h
call s:boolQuadGen('Bool', [
			\ 'edit_hdrs', 'envelope_from', 'forw_decode', 'forw_decrypt', 'forw_quote',
			\ 'pgp_autoencrypt', 'pgp_autosign', 'pgp_auto_traditional',
			\ 'pgp_create_traditional', 'pgp_replyencrypt', 'pgp_replysign',
			\ 'pgp_replysignencrypted', 'xterm_set_titles'
			\ ], 1)

" List of DT_QUAD in MuttVars in init.h
" UPDATE
call s:boolQuadGen('Quad', [
			\ 'abort_noattach', 'abort_nosubject', 'abort_unmodified', 'bounce',
			\ 'catchup_newsgroup', 'copy', 'crypt_verify_sig', 'delete', 'fcc_attach',
			\ 'followup_to_poster', 'forward_edit', 'honor_followup_to', 'include',
			\ 'mime_forward', 'mime_forward_rest', 'move', 'pgp_encrypt_self',
			\ 'pgp_mime_auto', 'pop_delete', 'pop_reconnect', 'post_moderated', 'postpone',
			\ 'print', 'quit', 'recall', 'reply_to', 'smime_encrypt_self', 'ssl_starttls',
			\ ], 0)

" Deprecated Quads
" UPDATE
" List of DT_SYNONYM synonyms of Quads in MuttVars in init.h
call s:boolQuadGen('Quad', [
			\ 'mime_fwd', 'pgp_verify_sig'
			\ ], 1)

" List of DT_NUMBER in MuttVars in init.h
" UPDATE
syntax keyword muttrcVarNum	skipwhite contained
			\ connect_timeout debug_level history imap_keepalive imap_pipeline_depth
			\ imap_poll_timeout mail_check mail_check_stats_interval menu_context net_inc
			\ nm_db_limit nm_open_timeout nm_query_window_current_position
			\ nm_query_window_duration nntp_context nntp_poll pager_context
			\ pager_index_lines pgp_timeout pop_checkinterval read_inc reflow_wrap
			\ save_history score_threshold_delete score_threshold_flag score_threshold_read
			\ search_context sendmail_wait sidebar_width skip_quoted_offset sleep_time
			\ smime_timeout ssl_min_dh_prime_bits time_inc timeout wrap wrap_headers
			\ wrapmargin write_inc
			\ nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr

" List of DT_STRING in MuttVars in init.h
" UPDATE
" Special cases first, and all the rest at the end
" A lot of special cases are format, flatcap compiled a list here https://pastebin.com/raw/5QXhiP6L
" Formats themselves must be updated in their respective groups
" See s:escapesConditionals
syntax match muttrcVarStr	contained skipwhite 'my_[a-zA-Z0-9_]\+' nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax keyword muttrcVarStr	contained skipwhite alias_format nextgroup=muttrcVarEqualsAliasFmt
syntax keyword muttrcVarStr	contained skipwhite attach_format nextgroup=muttrcVarEqualsAttachFmt
syntax keyword muttrcVarStr	contained skipwhite compose_format nextgroup=muttrcVarEqualsComposeFmt
syntax keyword muttrcVarStr	contained skipwhite folder_format vfolder_format nextgroup=muttrcVarEqualsFolderFmt
syntax keyword muttrcVarStr	contained skipwhite attribution index_format message_format pager_format nextgroup=muttrcVarEqualsIdxFmt
" Deprecated format
syntax keyword muttrcVarDeprecatedStr	contained skipwhite hdr_format msg_format nextgroup=muttrcVarEqualsIdxFmt
syntax keyword muttrcVarStr	contained skipwhite mix_entry_format nextgroup=muttrcVarEqualsMixFmt
syntax keyword muttrcVarStr	contained skipwhite 
			\ pgp_decode_command pgp_verify_command pgp_decrypt_command
			\ pgp_clearsign_command pgp_sign_command pgp_encrypt_sign_command
			\ pgp_encrypt_only_command pgp_import_command pgp_export_command
			\ pgp_verify_key_command pgp_list_secring_command pgp_list_pubring_command
			\ nextgroup=muttrcVarEqualsPGPCmdFmt
syntax keyword muttrcVarStr	contained skipwhite pgp_entry_format nextgroup=muttrcVarEqualsPGPFmt
syntax keyword muttrcVarStr	contained skipwhite pgp_getkeys_command nextgroup=muttrcVarEqualsPGPGetKeysFmt
syntax keyword muttrcVarStr	contained skipwhite query_format nextgroup=muttrcVarEqualsQueryFmt
syntax keyword muttrcVarStr	contained skipwhite
			\ smime_decrypt_command smime_verify_command smime_verify_opaque_command
			\ smime_sign_command smime_sign_opaque_command smime_encrypt_command
			\ smime_pk7out_command smime_get_cert_command smime_get_signer_cert_command
			\ smime_import_cert_command smime_get_cert_email_command
			\ nextgroup=muttrcVarEqualsSmimeFmt
syntax keyword muttrcVarStr	contained skipwhite ts_icon_format ts_status_format status_format nextgroup=muttrcVarEqualsStatusFmt
" Deprecated format
syntax keyword muttrcVarDeprecatedStr	contained skipwhite xterm_icon xterm_title nextgroup=muttrcVarEqualsStatusFmt
syntax keyword muttrcVarStr	contained skipwhite date_format nextgroup=muttrcVarEqualsStrftimeFmt
syntax keyword muttrcVarStr	contained skipwhite group_index_format nextgroup=muttrcVarEqualsGrpIdxFmt 
syntax keyword muttrcVarStr	contained skipwhite sidebar_format nextgroup=muttrcVarEqualsSdbFmt
syntax keyword muttrcVarStr	contained skipwhite
			\ assumed_charset attach_charset attach_sep attribution_locale charset
			\ config_charset content_type default_hook dsn_notify dsn_return empty_subject
			\ escape forward_attribution_intro forward_attribution_trailer forward_format
			\ header_cache_pagesize hostname imap_authenticators imap_delim_chars
			\ imap_headers imap_login imap_pass imap_user indent_string mailcap_path
			\ mark_macro_prefix mh_seq_flagged mh_seq_replied mh_seq_unseen
			\ mime_type_query_command newsgroups_charset news_server nm_default_uri
			\ nm_exclude_tags nm_hidden_tags nm_query_type nm_query_window_current_search
			\ nm_query_window_timebase nm_record_tags nm_unread_tag nntp_authenticators
			\ nntp_pass nntp_user pgp_self_encrypt_as pgp_sign_as pipe_sep
			\ pop_authenticators pop_host pop_pass pop_user post_indent_string
			\ postpone_encrypt_as preconnect realname send_charset
			\ show_multipart_alternative sidebar_delim_chars sidebar_divider_char
			\ sidebar_indent_string simple_search smime_default_key smime_encrypt_with
			\ smime_self_encrypt_as smime_sign_digest_alg smtp_authenticators smtp_pass
			\ smtp_url spam_separator ssl_ciphers tunnel xlabel_delimiter
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" Deprecated strings
syntax keyword muttrcVarDeprecatedStr	contained skipwhite
			\ forw_format indent_str post_indent_str smime_sign_as
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_ADDRESS
syntax keyword muttrcVarStr	contained skipwhite envelope_from_address from nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_HCACHE
syntax keyword muttrcVarStr	contained skipwhite header_cache_backend nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_MAGIC
syntax keyword muttrcVarStr	contained skipwhite mbox_type nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_MBTABLE
syntax keyword muttrcVarStr	contained skipwhite flag_chars from_chars status_chars to_chars nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_PATH
syntax keyword muttrcVarStr	contained skipwhite
			\ alias_file certificate_file debug_file display_filter editor entropy_file
			\ folder header_cache history_file inews ispell mbox message_cachedir mixmaster
			\ new_mail_command news_cache_dir newsrc pager postponed print_command
			\ query_command record sendmail shell signature smime_ca_location
			\ smime_certificates smime_keys spoolfile ssl_ca_certificates_file
			\ ssl_client_cert tmpdir trash visual
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of deprecated DT_PATH
syntax keyword muttrcVarDeprecatedStr	contained skipwhite print_cmd nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_REGEX
syntax keyword muttrcVarStr	contained skipwhite
			\ attach_keyword gecos_mask mask pgp_decryption_okay pgp_good_sign quote_regexp
			\ reply_regexp smileys
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
" List of DT_SORT
syntax keyword muttrcVarStr	contained skipwhite
			\ pgp_sort_keys sidebar_sort_method sort sort_alias sort_aux sort_browser
			\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr

" List of commands in Commands in init.h
" UPDATE
" Remember to remove hooks, they have already been dealt with
syntax keyword muttrcCommand	skipwhite charset-hook nextgroup=muttrcRXString
syntax keyword muttrcCommand	skipwhite unhook nextgroup=muttrcHooks
syntax keyword muttrcCommand	skipwhite spam nextgroup=muttrcSpamPattern
syntax keyword muttrcCommand	skipwhite nospam nextgroup=muttrcNoSpamPattern
syntax keyword muttrcCommand	skipwhite bind nextgroup=muttrcBindMenuList,muttrcBindMenuListNL
syntax keyword muttrcCommand	skipwhite macro	nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL
syntax keyword muttrcCommand	skipwhite alias nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syntax keyword muttrcCommand	skipwhite unalias nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syntax keyword muttrcCommand	skipwhite set unset reset toggle nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr,muttrcVarDeprecatedBool,muttrcVarDeprecatedQuad,muttrcVarDeprecatedStr
syntax keyword muttrcCommand	skipwhite exec nextgroup=muttrcFunction
syntax keyword muttrcCommand	skipwhite
			\ alternative_order attachments auto_view hdr_order ifdef ifndef ignore lua
			\ lua-source mailboxes mailto_allow mime_lookup my_hdr push score setenv
			\ sidebar_whitelist source subjectrx tag-formats tag-transforms
			\ unalternative_order unattachments unauto_view uncolor unhdr_order unignore
			\ unmailboxes unmailto_allow unmime_lookup unmono unmy_hdr unscore unsetenv
			\ unsidebar_whitelist unsubjectrx unvirtual-mailboxes virtual-mailboxes

" List of functions in functions.h
" UPDATE
syntax match muttrcFunction contained "\<accept\>"
syntax match muttrcFunction contained "\<append\>"
syntax match muttrcFunction contained "\<attach-file\>"
syntax match muttrcFunction contained "\<attach-key\>"
syntax match muttrcFunction contained "\<accept\>"
syntax match muttrcFunction contained "\<append\>"
syntax match muttrcFunction contained "\<attach-file\>"
syntax match muttrcFunction contained "\<attach-key\>"
syntax match muttrcFunction contained "\<attach-message\>"
syntax match muttrcFunction contained "\<attach-news-message\>"
syntax match muttrcFunction contained "\<backspace\>"
syntax match muttrcFunction contained "\<backward-char\>"
syntax match muttrcFunction contained "\<backward-word\>"
syntax match muttrcFunction contained "\<bol\>"
syntax match muttrcFunction contained "\<bottom\>"
syntax match muttrcFunction contained "\<bottom-page\>"
syntax match muttrcFunction contained "\<bounce-message\>"
syntax match muttrcFunction contained "\<break-thread\>"
syntax match muttrcFunction contained "\<buffy-cycle\>"
syntax match muttrcFunction contained "\<buffy-list\>"
syntax match muttrcFunction contained "\<capitalize-word\>"
syntax match muttrcFunction contained "\<catchup\>"
syntax match muttrcFunction contained "\<chain-next\>"
syntax match muttrcFunction contained "\<chain-prev\>"
syntax match muttrcFunction contained "\<change-dir\>"
syntax match muttrcFunction contained "\<change-folder\>"
syntax match muttrcFunction contained "\<change-folder-readonly\>"
syntax match muttrcFunction contained "\<change-newsgroup\>"
syntax match muttrcFunction contained "\<change-newsgroup-readonly\>"
syntax match muttrcFunction contained "\<change-vfolder\>"
syntax match muttrcFunction contained "\<check-new\>"
syntax match muttrcFunction contained "\<check-traditional-pgp\>"
syntax match muttrcFunction contained "\<clear-flag\>"
syntax match muttrcFunction contained "\<collapse-all\>"
syntax match muttrcFunction contained "\<collapse-parts\>"
syntax match muttrcFunction contained "\<collapse-thread\>"
syntax match muttrcFunction contained "\<complete\>"
syntax match muttrcFunction contained "\<complete-query\>"
syntax match muttrcFunction contained "\<compose-to-sender\>"
syntax match muttrcFunction contained "\<copy-file\>"
syntax match muttrcFunction contained "\<copy-message\>"
syntax match muttrcFunction contained "\<create-alias\>"
syntax match muttrcFunction contained "\<create-mailbox\>"
syntax match muttrcFunction contained "\<current-bottom\>"
syntax match muttrcFunction contained "\<current-middle\>"
syntax match muttrcFunction contained "\<current-top\>"
syntax match muttrcFunction contained "\<decode-copy\>"
syntax match muttrcFunction contained "\<decode-save\>"
syntax match muttrcFunction contained "\<decrypt-copy\>"
syntax match muttrcFunction contained "\<decrypt-save\>"
syntax match muttrcFunction contained "\<delete\>"
syntax match muttrcFunction contained "\<delete-char\>"
syntax match muttrcFunction contained "\<delete-entry\>"
syntax match muttrcFunction contained "\<delete-mailbox\>"
syntax match muttrcFunction contained "\<delete-message\>"
syntax match muttrcFunction contained "\<delete-pattern\>"
syntax match muttrcFunction contained "\<delete-subthread\>"
syntax match muttrcFunction contained "\<delete-thread\>"
syntax match muttrcFunction contained "\<detach-file\>"
syntax match muttrcFunction contained "\<display-address\>"
syntax match muttrcFunction contained "\<display-filename\>"
syntax match muttrcFunction contained "\<display-message\>"
syntax match muttrcFunction contained "\<display-toggle-weed\>"
syntax match muttrcFunction contained "\<downcase-word\>"
syntax match muttrcFunction contained "\<edit\>"
syntax match muttrcFunction contained "\<edit-bcc\>"
syntax match muttrcFunction contained "\<edit-cc\>"
syntax match muttrcFunction contained "\<edit-description\>"
syntax match muttrcFunction contained "\<edit-encoding\>"
syntax match muttrcFunction contained "\<edit-fcc\>"
syntax match muttrcFunction contained "\<edit-file\>"
syntax match muttrcFunction contained "\<edit-followup-to\>"
syntax match muttrcFunction contained "\<edit-from\>"
syntax match muttrcFunction contained "\<edit-headers\>"
syntax match muttrcFunction contained "\<edit-label\>"
syntax match muttrcFunction contained "\<edit-message\>"
syntax match muttrcFunction contained "\<edit-mime\>"
syntax match muttrcFunction contained "\<edit-newsgroups\>"
syntax match muttrcFunction contained "\<edit-reply-to\>"
syntax match muttrcFunction contained "\<edit-subject\>"
syntax match muttrcFunction contained "\<edit-to\>"
syntax match muttrcFunction contained "\<edit-type\>"
syntax match muttrcFunction contained "\<edit-x-comment-to\>"
syntax match muttrcFunction contained "\<end-cond\>"
syntax match muttrcFunction contained "\<enter-command\>"
syntax match muttrcFunction contained "\<enter-mask\>"
syntax match muttrcFunction contained "\<entire-thread\>"
syntax match muttrcFunction contained "\<eol\>"
syntax match muttrcFunction contained "\<exit\>"
syntax match muttrcFunction contained "\<extract-keys\>"
syntax match muttrcFunction contained "\<fetch-mail\>"
syntax match muttrcFunction contained "\<filter-entry\>"
syntax match muttrcFunction contained "\<first-entry\>"
syntax match muttrcFunction contained "\<flag-message\>"
syntax match muttrcFunction contained "\<followup-message\>"
syntax match muttrcFunction contained "\<forget-passphrase\>"
syntax match muttrcFunction contained "\<forward-char\>"
syntax match muttrcFunction contained "\<forward-message\>"
syntax match muttrcFunction contained "\<forward-to-group\>"
syntax match muttrcFunction contained "\<forward-word\>"
syntax match muttrcFunction contained "\<get-attachment\>"
syntax match muttrcFunction contained "\<get-children\>"
syntax match muttrcFunction contained "\<get-message\>"
syntax match muttrcFunction contained "\<get-parent\>"
syntax match muttrcFunction contained "\<goto-folder\>"
syntax match muttrcFunction contained "\<group-reply\>"
syntax match muttrcFunction contained "\<half-down\>"
syntax match muttrcFunction contained "\<half-up\>"
syntax match muttrcFunction contained "\<help\>"
syntax match muttrcFunction contained "\<history-down\>"
syntax match muttrcFunction contained "\<history-up\>"
syntax match muttrcFunction contained "\<imap-fetch-mail\>"
syntax match muttrcFunction contained "\<imap-logout-all\>"
syntax match muttrcFunction contained "\<insert\>"
syntax match muttrcFunction contained "\<ispell\>"
syntax match muttrcFunction contained "\<jump\>"
syntax match muttrcFunction contained "\<kill-eol\>"
syntax match muttrcFunction contained "\<kill-eow\>"
syntax match muttrcFunction contained "\<kill-line\>"
syntax match muttrcFunction contained "\<kill-word\>"
syntax match muttrcFunction contained "\<last-entry\>"
syntax match muttrcFunction contained "\<limit\>"
syntax match muttrcFunction contained "\<limit-current-thread\>"
syntax match muttrcFunction contained "\<link-threads\>"
syntax match muttrcFunction contained "\<list-reply\>"
syntax match muttrcFunction contained "\<mail\>"
syntax match muttrcFunction contained "\<mail-key\>"
syntax match muttrcFunction contained "\<mark-as-new\>"
syntax match muttrcFunction contained "\<mark-message\>"
syntax match muttrcFunction contained "\<middle-page\>"
syntax match muttrcFunction contained "\<mix\>"
syntax match muttrcFunction contained "\<modify-labels\>"
syntax match muttrcFunction contained "\<modify-labels-then-hide\>"
syntax match muttrcFunction contained "\<new-mime\>"
syntax match muttrcFunction contained "\<next-entry\>"
syntax match muttrcFunction contained "\<next-line\>"
syntax match muttrcFunction contained "\<next-new\>"
syntax match muttrcFunction contained "\<next-new-then-unread\>"
syntax match muttrcFunction contained "\<next-page\>"
syntax match muttrcFunction contained "\<next-subthread\>"
syntax match muttrcFunction contained "\<next-thread\>"
syntax match muttrcFunction contained "\<next-undeleted\>"
syntax match muttrcFunction contained "\<next-unread\>"
syntax match muttrcFunction contained "\<next-unread-mailbox\>"
syntax match muttrcFunction contained "\<parent-message\>"
syntax match muttrcFunction contained "\<pgp-menu\>"
syntax match muttrcFunction contained "\<pipe-entry\>"
syntax match muttrcFunction contained "\<pipe-message\>"
syntax match muttrcFunction contained "\<post-message\>"
syntax match muttrcFunction contained "\<postpone-message\>"
syntax match muttrcFunction contained "\<previous-entry\>"
syntax match muttrcFunction contained "\<previous-line\>"
syntax match muttrcFunction contained "\<previous-new\>"
syntax match muttrcFunction contained "\<previous-new-then-unread\>"
syntax match muttrcFunction contained "\<previous-page\>"
syntax match muttrcFunction contained "\<previous-subthread\>"
syntax match muttrcFunction contained "\<previous-thread\>"
syntax match muttrcFunction contained "\<previous-undeleted\>"
syntax match muttrcFunction contained "\<previous-unread\>"
syntax match muttrcFunction contained "\<print-entry\>"
syntax match muttrcFunction contained "\<print-message\>"
syntax match muttrcFunction contained "\<purge-message\>"
syntax match muttrcFunction contained "\<purge-thread\>"
syntax match muttrcFunction contained "\<quasi-delete\>"
syntax match muttrcFunction contained "\<query\>"
syntax match muttrcFunction contained "\<query-append\>"
syntax match muttrcFunction contained "\<quit\>"
syntax match muttrcFunction contained "\<quote-char\>"
syntax match muttrcFunction contained "\<read-subthread\>"
syntax match muttrcFunction contained "\<read-thread\>"
syntax match muttrcFunction contained "\<recall-message\>"
syntax match muttrcFunction contained "\<reconstruct-thread\>"
syntax match muttrcFunction contained "\<redraw-screen\>"
syntax match muttrcFunction contained "\<refresh\>"
syntax match muttrcFunction contained "\<reload-active\>"
syntax match muttrcFunction contained "\<rename-attachment\>"
syntax match muttrcFunction contained "\<rename-file\>"
syntax match muttrcFunction contained "\<rename-mailbox\>"
syntax match muttrcFunction contained "\<reply\>"
syntax match muttrcFunction contained "\<resend-message\>"
syntax match muttrcFunction contained "\<root-message\>"
syntax match muttrcFunction contained "\<save-entry\>"
syntax match muttrcFunction contained "\<save-message\>"
syntax match muttrcFunction contained "\<search\>"
syntax match muttrcFunction contained "\<search-next\>"
syntax match muttrcFunction contained "\<search-opposite\>"
syntax match muttrcFunction contained "\<search-reverse\>"
syntax match muttrcFunction contained "\<search-toggle\>"
syntax match muttrcFunction contained "\<select-entry\>"
syntax match muttrcFunction contained "\<select-new\>"
syntax match muttrcFunction contained "\<send-message\>"
syntax match muttrcFunction contained "\<set-flag\>"
syntax match muttrcFunction contained "\<shell-escape\>"
syntax match muttrcFunction contained "\<show-limit\>"
syntax match muttrcFunction contained "\<show-version\>"
syntax match muttrcFunction contained "\<sidebar-next\>"
syntax match muttrcFunction contained "\<sidebar-next-new\>"
syntax match muttrcFunction contained "\<sidebar-open\>"
syntax match muttrcFunction contained "\<sidebar-page-down\>"
syntax match muttrcFunction contained "\<sidebar-page-up\>"
syntax match muttrcFunction contained "\<sidebar-prev\>"
syntax match muttrcFunction contained "\<sidebar-prev-new\>"
syntax match muttrcFunction contained "\<sidebar-toggle-virtual\>"
syntax match muttrcFunction contained "\<sidebar-toggle-visible\>"
syntax match muttrcFunction contained "\<skip-quoted\>"
syntax match muttrcFunction contained "\<smime-menu\>"
syntax match muttrcFunction contained "\<sort\>"
syntax match muttrcFunction contained "\<sort-mailbox\>"
syntax match muttrcFunction contained "\<sort-reverse\>"
syntax match muttrcFunction contained "\<subscribe\>"
syntax match muttrcFunction contained "\<subscribe-pattern\>"
syntax match muttrcFunction contained "\<sync-mailbox\>"
syntax match muttrcFunction contained "\<tag-entry\>"
syntax match muttrcFunction contained "\<tag-message\>"
syntax match muttrcFunction contained "\<tag-pattern\>"
syntax match muttrcFunction contained "\<tag-prefix\>"
syntax match muttrcFunction contained "\<tag-prefix-cond\>"
syntax match muttrcFunction contained "\<tag-subthread\>"
syntax match muttrcFunction contained "\<tag-thread\>"
syntax match muttrcFunction contained "\<toggle-disposition\>"
syntax match muttrcFunction contained "\<toggle-mailboxes\>"
syntax match muttrcFunction contained "\<toggle-new\>"
syntax match muttrcFunction contained "\<toggle-quoted\>"
syntax match muttrcFunction contained "\<toggle-read\>"
syntax match muttrcFunction contained "\<toggle-recode\>"
syntax match muttrcFunction contained "\<toggle-subscribed\>"
syntax match muttrcFunction contained "\<toggle-unlink\>"
syntax match muttrcFunction contained "\<toggle-write\>"
syntax match muttrcFunction contained "\<top\>"
syntax match muttrcFunction contained "\<top-page\>"
syntax match muttrcFunction contained "\<transpose-chars\>"
syntax match muttrcFunction contained "\<uncatchup\>"
syntax match muttrcFunction contained "\<undelete-entry\>"
syntax match muttrcFunction contained "\<undelete-message\>"
syntax match muttrcFunction contained "\<undelete-pattern\>"
syntax match muttrcFunction contained "\<undelete-subthread\>"
syntax match muttrcFunction contained "\<undelete-thread\>"
syntax match muttrcFunction contained "\<unsubscribe\>"
syntax match muttrcFunction contained "\<unsubscribe-pattern\>"
syntax match muttrcFunction contained "\<untag-pattern\>"
syntax match muttrcFunction contained "\<upcase-word\>"
syntax match muttrcFunction contained "\<update-encoding\>"
syntax match muttrcFunction contained "\<verify-key\>"
syntax match muttrcFunction contained "\<vfolder-from-query\>"
syntax match muttrcFunction contained "\<vfolder-window-backward\>"
syntax match muttrcFunction contained "\<vfolder-window-forward\>"
syntax match muttrcFunction contained "\<view-attach\>"
syntax match muttrcFunction contained "\<view-attachments\>"
syntax match muttrcFunction contained "\<view-file\>"
syntax match muttrcFunction contained "\<view-mailcap\>"
syntax match muttrcFunction contained "\<view-name\>"
syntax match muttrcFunction contained "\<view-text\>"
syntax match muttrcFunction contained "\<what-key\>"
syntax match muttrcFunction contained "\<write-fcc\>"



" Define the default highlighting.
" Only when an item doesn't have highlighting yet

highlight def link muttrcComment			Comment
highlight def link muttrcEscape				SpecialChar
highlight def link muttrcRXChars			SpecialChar
highlight def link muttrcString				String
highlight def link muttrcRXString			String
highlight def link muttrcRXString2			String
highlight def link muttrcSpecial			Special
highlight def link muttrcHooks				Type
highlight def link muttrcGroupFlag			Type
highlight def link muttrcGroupDef			Macro
highlight def link muttrcAddrDef			muttrcGroupFlag
highlight def link muttrcRXDef				muttrcGroupFlag
highlight def link muttrcRXPat				String
highlight def link muttrcAliasGroupName			Macro
highlight def link muttrcAliasKey	        	Identifier
highlight def link muttrcUnAliasKey			Identifier
highlight def link muttrcAliasEncEmail			Identifier
highlight def link muttrcAliasParens			Type
highlight def link muttrcSetNumAssignment		Number
highlight def link muttrcSetBoolAssignment		Boolean
highlight def link muttrcSetQuadAssignment		Boolean
highlight def link muttrcSetStrAssignment		String
highlight def link muttrcEmail				Special
highlight def link muttrcVariableInner			Special
highlight def link muttrcEscapedVariable		String
highlight def link muttrcHeader				Type
highlight def link muttrcKeySpecial			SpecialChar
highlight def link muttrcKey				Type
highlight def link muttrcKeyName			SpecialChar
highlight def link muttrcVarBool			Identifier
highlight def link muttrcVarQuad			Identifier
highlight def link muttrcVarNum				Identifier
highlight def link muttrcVarStr				Identifier
highlight def link muttrcMenu				Identifier
highlight def link muttrcCommand			Keyword
highlight def link muttrcMacroDescr			String
highlight def link muttrcAction				Macro
highlight def link muttrcBadAction			Error
highlight def link muttrcBindFunction			Error
highlight def link muttrcBindMenuList			Error
highlight def link muttrcFunction			Macro
highlight def link muttrcGroupKeyword			muttrcCommand
highlight def link muttrcGroupLine			Error
highlight def link muttrcSubscribeKeyword		muttrcCommand
highlight def link muttrcSubscribeLine			Error
highlight def link muttrcListsKeyword			muttrcCommand
highlight def link muttrcListsLine			Error
highlight def link muttrcAlternateKeyword		muttrcCommand
highlight def link muttrcAlternatesLine			Error
highlight def link muttrcAttachmentsLine		muttrcCommand
highlight def link muttrcAttachmentsFlag		Type
highlight def link muttrcAttachmentsMimeType		String
highlight def link muttrcColorLine			Error
highlight def link muttrcColorContext			Error
highlight def link muttrcColorContextI			Identifier
highlight def link muttrcColorContextH			Identifier
highlight def link muttrcColorKeyword			muttrcCommand
highlight def link muttrcColorField			Identifier
highlight def link muttrcColorCompose			Identifier
highlight def link muttrcColorComposeField		Identifier
highlight def link muttrcColor				Type
highlight def link muttrcColorFG			Error
highlight def link muttrcColorFGI			Error
highlight def link muttrcColorFGH			Error
highlight def link muttrcColorBG			Error
highlight def link muttrcColorBGI			Error
highlight def link muttrcColorBGH			Error
highlight def link muttrcMonoAttrib			muttrcColor
highlight def link muttrcMono				muttrcCommand
highlight def link muttrcSimplePat			Identifier
highlight def link muttrcSimplePatString		Macro
highlight def link muttrcSimplePatMetas			Special
highlight def link muttrcPattern			Error
highlight def link muttrcUnColorLine			Error
highlight def link muttrcUnColorKeyword			muttrcCommand
highlight def link muttrcUnColorIndex			Identifier
highlight def link muttrcShellString			muttrcEscape
highlight def link muttrcRXHooks			muttrcCommand
highlight def link muttrcRXHookNot			Type
highlight def link muttrcPatHooks			muttrcCommand
highlight def link muttrcPatHookNot			Type
highlight def link muttrcFormatConditionals2		Type
highlight def link muttrcIndexFormatStr			muttrcString
highlight def link muttrcIndexFormatEscapes		muttrcEscape
highlight def link muttrcIndexFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcAliasFormatStr			muttrcString
highlight def link muttrcAliasFormatEscapes		muttrcEscape
highlight def link muttrcAttachFormatStr		muttrcString
highlight def link muttrcAttachFormatEscapes		muttrcEscape
highlight def link muttrcAttachFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcComposeFormatStr		muttrcString
highlight def link muttrcComposeFormatEscapes		muttrcEscape
highlight def link muttrcFolderFormatStr		muttrcString
highlight def link muttrcFolderFormatEscapes		muttrcEscape
highlight def link muttrcFolderFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcMixFormatStr			muttrcString
highlight def link muttrcMixFormatEscapes		muttrcEscape
highlight def link muttrcMixFormatConditionals		muttrcFormatConditionals2
highlight def link muttrcPGPFormatStr			muttrcString
highlight def link muttrcPGPFormatEscapes		muttrcEscape
highlight def link muttrcPGPFormatConditionals		muttrcFormatConditionals2
highlight def link muttrcPGPCmdFormatStr		muttrcString
highlight def link muttrcPGPCmdFormatEscapes		muttrcEscape
highlight def link muttrcPGPCmdFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcStatusFormatStr		muttrcString
highlight def link muttrcStatusFormatEscapes		muttrcEscape
highlight def link muttrcStatusFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcPGPGetKeysFormatStr		muttrcString
highlight def link muttrcPGPGetKeysFormatEscapes	muttrcEscape
highlight def link muttrcSmimeFormatStr			muttrcString
highlight def link muttrcSmimeFormatEscapes		muttrcEscape
highlight def link muttrcSmimeFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcTimeEscapes			muttrcEscape
highlight def link muttrcPGPTimeEscapes			muttrcEscape
highlight def link muttrcStrftimeEscapes		Type
highlight def link muttrcStrftimeFormatStr		muttrcString
highlight def link muttrcFormatErrors			Error

highlight def link muttrcBindFunctionNL			SpecialChar
highlight def link muttrcBindKeyNL			SpecialChar
highlight def link muttrcBindMenuListNL			SpecialChar
highlight def link muttrcMacroDescrNL			SpecialChar
highlight def link muttrcMacroBodyNL			SpecialChar
highlight def link muttrcMacroKeyNL			SpecialChar
highlight def link muttrcMacroMenuListNL		SpecialChar
highlight def link muttrcColorMatchCountNL		SpecialChar
highlight def link muttrcColorNL			SpecialChar
highlight def link muttrcColorRXNL			SpecialChar
highlight def link muttrcColorBGNL			SpecialChar
highlight def link muttrcColorFGNL			SpecialChar
highlight def link muttrcAliasNameNL			SpecialChar
highlight def link muttrcAliasENNL			SpecialChar
highlight def link muttrcAliasNL			SpecialChar
highlight def link muttrcUnAliasNL			SpecialChar
highlight def link muttrcAliasGroupDefNL		SpecialChar
highlight def link muttrcAliasEncEmailNL		SpecialChar
highlight def link muttrcPatternNL			SpecialChar
highlight def link muttrcUnColorPatNL			SpecialChar
highlight def link muttrcUnColorAPNL			SpecialChar
highlight def link muttrcUnColorIndexNL			SpecialChar
highlight def link muttrcStringNL			SpecialChar

highlight def link muttrcVarDeprecatedBool		Error
highlight def link muttrcVarDeprecatedQuad		Error
highlight def link muttrcVarDeprecatedStr		Error


let b:current_syntax = "neomuttrc"

let &cpo = s:cpo_save
unlet s:cpo_save
"EOF	vim: ts=8 noet tw=100 sw=8 sts=0 ft=vim
