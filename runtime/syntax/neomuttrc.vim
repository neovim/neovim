" Vim syntax file
" Language:	NeoMutt setup files
" Maintainer:	Richard Russon <rich@flatcap.org>
" Previous Maintainer:	Guillaume Brogi <gui-gui@netcourrier.com>
" Last Change:	2020-06-21
" Original version based on syntax/muttrc.vim

" This file covers NeoMutt 2020-06-19

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Set the keyword characters
setlocal isk=@,48-57,_,-

" handling optional variables
syntax match muttrcComment	"^# .*$" contains=@Spell
syntax match muttrcComment	"^#[^ ].*$"
syntax match muttrcComment	"^#$"
syntax match muttrcComment	"[^\\]#.*$"lc=1

" Escape sequences (back-tick and pipe goes here too)
syntax match muttrcEscape	+\\[#tnr"'Cc ]+
syntax match muttrcEscape	+[`|]+
syntax match muttrcEscape	+\\$+

" The variables takes the following arguments
syntax region muttrcString	contained keepend start=+"+ms=e skip=+\\"+ end=+"+ contains=muttrcEscape,muttrcCommand,muttrcAction,muttrcShellString
syntax region muttrcString	contained keepend start=+'+ms=e skip=+\\'+ end=+'+ contains=muttrcEscape,muttrcCommand,muttrcAction
syntax match muttrcStringNL	contained skipwhite skipnl "\s*\\$" nextgroup=muttrcString,muttrcStringNL

syntax region muttrcShellString	matchgroup=muttrcEscape keepend start=+`+ skip=+\\`+ end=+`+ contains=muttrcVarStr,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcCommand

syntax match  muttrcRXChars	contained /[^\\][][.*?+]\+/hs=s+1
syntax match  muttrcRXChars	contained /[][|()][.*?+]*/
syntax match  muttrcRXChars	contained /['"]^/ms=s+1
syntax match  muttrcRXChars	contained /$['"]/me=e-1
syntax match  muttrcRXChars	contained /\\/
" Why does muttrcRXString2 work with one \ when muttrcRXString requires two?
syntax region muttrcRXString	contained skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXChars
syntax region muttrcRXString	contained skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXChars
syntax region muttrcRXString	contained skipwhite start=+[^	 "'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXChars
" For some reason, skip refuses to match backslashes here...
syntax region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXChars
syntax region muttrcRXString	contained matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXChars
syntax region muttrcRXString2	contained skipwhite start=+'+ skip=+\'+ end=+'+ contains=muttrcRXChars
syntax region muttrcRXString2	contained skipwhite start=+"+ skip=+\"+ end=+"+ contains=muttrcRXChars

" these must be kept synchronized with muttrcRXString, but are intended for muttrcRXHooks
syntax region muttrcRXHookString	contained keepend skipwhite start=+'+ skip=+\\'+ end=+'+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+"+ skip=+\\"+ end=+"+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+[^	 "'^]+ skip=+\\\s+ end=+\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend skipwhite start=+\^+ end=+[^\\]\s+re=e-1 contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax region muttrcRXHookString	contained keepend matchgroup=muttrcRXChars skipwhite start=+\^+ end=+$\s+ contains=muttrcRXString nextgroup=muttrcString,muttrcStringNL
syntax match muttrcRXHookStringNL	contained skipwhite skipnl "\s*\\$" nextgroup=muttrcRXHookString,muttrcRXHookStringNL

" these are exclusively for args lists (e.g. -rx pat pat pat ...)
syntax region muttrcRXPat	contained keepend skipwhite start=+'+ skip=+\\'+ end=+'\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syntax region muttrcRXPat	contained keepend skipwhite start=+"+ skip=+\\"+ end=+"\s*+ contains=muttrcRXString nextgroup=muttrcRXPat
syntax match muttrcRXPat	contained /[^-'"#!]\S\+/ skipwhite contains=muttrcRXChars nextgroup=muttrcRXPat
syntax match muttrcRXDef	contained "-rx\s\+" skipwhite nextgroup=muttrcRXPat

syntax match muttrcSpecial	+\(['"]\)!\1+

syntax match muttrcSetStrAssignment contained skipwhite /=\s*\%(\\\?\$\)\?[0-9A-Za-z_-]\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*"+hs=s+1 end=+"+ skip=+\\"+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcString
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*'+hs=s+1 end=+'+ skip=+\\'+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcString
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*"\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*'\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\%(ask-\)\?\%(yes\|no\)/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*"\%(ask-\)\?\%(yes\|no\)"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*'\%(ask-\)\?\%(yes\|no\)'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetNumAssignment contained skipwhite /=\s*\d\+/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*"\d\+"/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax match muttrcSetNumAssignment contained skipwhite /=\s*'\d\+'/hs=s+1 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" Now catch some email addresses and headers (purified version from mail.vim)
syntax match muttrcEmail	"[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+"
syntax match muttrcHeader	"\<\c\%(From\|To\|C[Cc]\|B[Cc][Cc]\|Reply-To\|Subject\|Return-Path\|Received\|Date\|Replied\|Attach\)\>:\="

syntax match   muttrcKeySpecial	contained +\%(\\[Cc'"]\|\^\|\\[01]\d\{2}\)+
syntax match   muttrcKey	contained "\S\+"			contains=muttrcKeySpecial,muttrcKeyName
syntax region  muttrcKey	contained start=+"+ skip=+\\\\\|\\"+ end=+"+	contains=muttrcKeySpecial,muttrcKeyName
syntax region  muttrcKey	contained start=+'+ skip=+\\\\\|\\'+ end=+'+	contains=muttrcKeySpecial,muttrcKeyName
syntax match   muttrcKeyName	contained "\\[trne]"
syntax match   muttrcKeyName	contained "\c<\%(BackSpace\|BackTab\|Delete\|Down\|End\|Enter\|Esc\|Home\|Insert\|Left\|Next\|PageDown\|PageUp\|Return\|Right\|Space\|Tab\|Up\)>"
syntax match   muttrcKeyName	contained "\c<F\d\+>"

syntax match muttrcFormatErrors contained /%./

syntax match muttrcStrftimeEscapes contained /%[AaBbCcDdeFGgHhIjklMmnpRrSsTtUuVvWwXxYyZz+%]/
syntax match muttrcStrftimeEscapes contained /%E[cCxXyY]/
syntax match muttrcStrftimeEscapes contained /%O[BdeHImMSuUVwWy]/

syntax region muttrcAliasFormatStr      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAliasFormatEscapes,muttrcAliasFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcAliasFormatStr      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAliasFormatEscapes,muttrcAliasFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcAttachFormatStr     contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcAttachFormatStr     contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcComposeFormatStr    contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcComposeFormatEscapes,muttrcComposeFormatConditionals,muttrcFormatErrors                         nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcComposeFormatStr    contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcComposeFormatEscapes,muttrcComposeFormatConditionals,muttrcFormatErrors                         nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcFolderFormatStr     contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcFolderFormatStr     contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcGroupIndexFormatStr contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcGroupIndexFormatStr contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcIndexFormatStr      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcIndexFormatStr      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcMixFormatStr        contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcMixFormatStr        contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcMixFormatEscapes,muttrcMixFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcPGPCmdFormatStr     contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors            nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcPGPCmdFormatStr     contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPCmdFormatEscapes,muttrcPGPCmdFormatConditionals,muttrcVariable,muttrcFormatErrors            nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcPGPFormatStr        contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes            nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcPGPFormatStr        contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPGPFormatEscapes,muttrcPGPFormatConditionals,muttrcFormatErrors,muttrcPGPTimeEscapes            nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcQueryFormatStr      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcQueryFormatStr      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcSidebarFormatStr    contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcSidebarFormatStr    contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcSmimeFormatStr      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors              nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcSmimeFormatStr      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSmimeFormatEscapes,muttrcSmimeFormatConditionals,muttrcVariable,muttrcFormatErrors              nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcStatusFormatStr     contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcStatusFormatStr     contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors                           nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcStrftimeFormatStr   contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStrftimeEscapes,muttrcFormatErrors                                                              nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax region muttrcStrftimeFormatStr   contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStrftimeEscapes,muttrcFormatErrors                                                              nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" Format escapes and conditionals
syntax match muttrcFormatConditionals2 contained /[^?]*?/
function! s:escapesConditionals(baseName, sequence, padding, conditional)
	exec 'syntax match muttrc' . a:baseName . 'Escapes contained /%\%(\%(-\?[0-9]\+\)\?\%(\.[0-9]\+\)\?\)\?[:_]\?\%(' . a:sequence . '\|%\)/'
	if a:padding
		exec 'syntax match muttrc' . a:baseName . 'Escapes contained /%[>|*]./'
	endif
	if a:conditional
		exec 'syntax match muttrc' . a:baseName . 'Conditionals contained /%?\%(' . a:sequence . '\)?/ nextgroup=muttrcFormatConditionals2'
	else
		exec 'syntax match muttrc' . a:baseName . 'Conditionals contained /%?\%(' . a:sequence . '\)?/'
	endif
endfunction

" CHECKED 2020-06-21
" Ref: alias_format_str() in alias/dlgalias.c
call s:escapesConditionals('AliasFormat', '[acfnrt]', 1, 0)
" Ref: attach_format_str() in recvattach.c
call s:escapesConditionals('AttachFormat', '[CcDdeFfIMmnQsTtuX]', 1, 1)
" Ref: compose_format_str() in compose.c
call s:escapesConditionals('ComposeFormat', '[ahlv]', 1, 1)
" Ref: folder_format_str() in browser.c
call s:escapesConditionals('FolderFormat', '[CDdFfgilmNnstu]', 1, 0)
" Ref: group_index_format_str() in browser.c
call s:escapesConditionals('GroupIndexFormat', '[CdfMNns]', 1, 1)
" Ref: index_format_str() in hdrline.c
call s:escapesConditionals('IndexFormat', '[AaBbCDdEefgHIiJKLlMmNnOPqRrSsTtuvWXxYyZ(<[{]\|@\i\+@\|G[a-zA-Z]\+\|Fp\=\|z[cst]\|cr\=', 1, 1)
" Ref: mix_format_str() in remailer.c
call s:escapesConditionals('MixFormat', '[acns]', 1, 0)
" Ref: pgp_command_format_str() in ncrypt/pgpinvoke.c
call s:escapesConditionals('PGPCmdFormat', '[afprs]', 0, 1)
" Ref: crypt_format_str() in ncrypt/crypt_gpgme.c
" Ref: pgp_entry_format_str() in ncrypt/pgpkey.c
" Note: crypt_format_str() supports 'p', but pgp_entry_fmt() does not
call s:escapesConditionals('PGPFormat', '[AaCcFfKkLlnptu[]', 0, 0)
" Ref: query_format_str() in alias/dlgquery.c
call s:escapesConditionals('QueryFormat', '[acent]', 1, 1)
" Ref: sidebar_format_str() in sidebar.c
call s:escapesConditionals('SidebarFormat', '[!BDdFLNnorStZ]', 1, 1)
" Ref: smime_command_format_str() in ncrypt/smime.c
call s:escapesConditionals('SmimeFormat', '[aCcdfiks]', 0, 1)
" Ref: status_format_str() in status.c
call s:escapesConditionals('StatusFormat', '[bDdFfhLlMmnoPpRrSstuVv]', 1, 1)

syntax region muttrcPGPTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%(+  end=+)+  contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%<+  end=+>+  contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%{+  end=+}+  contains=muttrcStrftimeEscapes

syntax match muttrcVarEqualsAliasFmt      contained skipwhite "=" nextgroup=muttrcAliasFormatStr
syntax match muttrcVarEqualsAttachFmt     contained skipwhite "=" nextgroup=muttrcAttachFormatStr
syntax match muttrcVarEqualsComposeFmt    contained skipwhite "=" nextgroup=muttrcComposeFormatStr
syntax match muttrcVarEqualsFolderFmt     contained skipwhite "=" nextgroup=muttrcFolderFormatStr
syntax match muttrcVarEqualsGrpIdxFmt     contained skipwhite "=" nextgroup=muttrcGroupIndexFormatStr
syntax match muttrcVarEqualsIdxFmt        contained skipwhite "=" nextgroup=muttrcIndexFormatStr
syntax match muttrcVarEqualsMixFmt        contained skipwhite "=" nextgroup=muttrcMixFormatStr
syntax match muttrcVarEqualsPGPCmdFmt     contained skipwhite "=" nextgroup=muttrcPGPCmdFormatStr
syntax match muttrcVarEqualsPGPFmt        contained skipwhite "=" nextgroup=muttrcPGPFormatStr
syntax match muttrcVarEqualsQueryFmt      contained skipwhite "=" nextgroup=muttrcQueryFormatStr
syntax match muttrcVarEqualsSdbFmt        contained skipwhite "=" nextgroup=muttrcSidebarFormatStr
syntax match muttrcVarEqualsSmimeFmt      contained skipwhite "=" nextgroup=muttrcSmimeFormatStr
syntax match muttrcVarEqualsStatusFmt     contained skipwhite "=" nextgroup=muttrcStatusFormatStr
syntax match muttrcVarEqualsStrftimeFmt   contained skipwhite "=" nextgroup=muttrcStrftimeFormatStr

syntax match muttrcVPrefix contained /[?&]/ nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" CHECKED 2020-06-21
" List of the different screens in mutt (see Menus in keymap.c)
syntax keyword muttrcMenu contained alias attach browser compose editor generic index key_select_pgp key_select_smime mix pager pgp postpone query smime
syntax match muttrcMenuList "\S\+" contained contains=muttrcMenu
syntax match muttrcMenuCommas /,/ contained

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

syntax keyword muttrcSubscribeKeyword	subscribe skipwhite nextgroup=muttrcGroupDef,muttrcComment
syntax keyword muttrcSubscribeKeyword	unsubscribe skipwhite nextgroup=muttrcAsterisk,muttrcComment

syntax keyword muttrcAlternateKeyword contained alternates unalternates
syntax region muttrcAlternatesLine keepend start=+^\s*\%(un\)\?alternates\s+ skip=+\\$+ end=+$+ contains=muttrcAlternateKeyword,muttrcGroupDef,muttrcRXPat,muttrcUnHighlightSpace,muttrcComment

" muttrcVariable includes a prefix because partial strings are considered valid.
syntax match muttrcVariable	contained "\\\@<![a-zA-Z_-]*\$[a-zA-Z_-]\+" contains=muttrcVariableInner
syntax match muttrcVariableInner	contained "\$[a-zA-Z_-]\+"
syntax match muttrcEscapedVariable	contained "\\\$[a-zA-Z_-]\+"

syntax match muttrcBadAction	contained "[^<>]\+" contains=muttrcEmail
syntax match muttrcAction		contained "<[^>]\{-}>" contains=muttrcBadAction,muttrcFunction,muttrcKeyName

" CHECKED 2020-06-21
" First, functions that take regular expressions:
syntax match  muttrcRXHookNot	contained /!\s*/ skipwhite nextgroup=muttrcRXHookString,muttrcRXHookStringNL
syntax match  muttrcRXHooks	/\<\%(account\|append\|close\|crypt\|folder\|mbox\|open\|pgp\)-hook\>/ skipwhite nextgroup=muttrcRXHookNot,muttrcRXHookString,muttrcRXHookStringNL

" Now, functions that take patterns
syntax match muttrcPatHookNot	contained /!\s*/ skipwhite nextgroup=muttrcPattern
syntax match muttrcPatHooks	/\<\%(charset\|iconv\|index-format\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcPattern
syntax match muttrcPatHooks	/\<\%(message\|reply\|send\|send2\|save\|fcc\|fcc-save\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcOptPattern

" Global hooks that take a command
syntax keyword muttrcHooks skipwhite shutdown-hook startup-hook timeout-hook nextgroup=muttrcCommand

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
syntax region muttrcMacroBody	matchgroup=Type contained skipwhite start=+'+ms=e skip=+\\'+ end=+'\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax region muttrcMacroBody	matchgroup=Type contained skipwhite start=+"+ms=e skip=+\\"+ end=+"\|\%(\%(\\\\\)\@<!$\)+me=s contains=muttrcEscape,muttrcSet,muttrcUnset,muttrcReset,muttrcToggle,muttrcSpam,muttrcNoSpam,muttrcCommand,muttrcAction,muttrcVariable nextgroup=muttrcMacroDescr,muttrcMacroDescrNL
syntax match muttrcMacroBodyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syntax match muttrcMacroKey	contained /\S\+/ skipwhite contains=muttrcKey nextgroup=muttrcMacroBody,muttrcMacroBodyNL
syntax match muttrcMacroKeyNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syntax match muttrcMacroMenuList	contained /\S\+/ skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcMacroKey,muttrcMacroKeyNL
syntax match muttrcMacroMenuListNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL

syntax match muttrcAddrContent	contained "[a-zA-Z0-9._-]\+@[a-zA-Z0-9./-]\+\s*" skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax region muttrcAddrContent	contained start=+'+ end=+'\s*+ skip=+\\'+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax region muttrcAddrContent	contained start=+"+ end=+"\s*+ skip=+\\"+ skipwhite contains=muttrcEmail nextgroup=muttrcAddrContent
syntax match muttrcAddrDef	contained "-addr\s\+" skipwhite nextgroup=muttrcAddrContent

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

" CHECKED 2020-06-21
" List of letters in Flags in pattern.c
" Parameter: none
syntax match muttrcSimplePat contained "!\?\^\?[~][ADEFGgklNOPpQRSTuUvV#$=]"
" Parameter: range
syntax match muttrcSimplePat contained "!\?\^\?[~][mnXz]\s*\%([<>-][0-9]\+[kM]\?\|[0-9]\+[kM]\?[-]\%([0-9]\+[kM]\?\)\?\)"
" Parameter: date
syntax match muttrcSimplePat contained "!\?\^\?[~][dr]\s*\%(\%(-\?[0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)\|\%(\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)-\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)\?\)\?\)\|\%([<>=][0-9]\+[ymwd]\)\|\%(`[^`]\+`\)\|\%(\$[a-zA-Z0-9_-]\+\)\)" contains=muttrcShellString,muttrcVariable
" Parameter: regex
syntax match muttrcSimplePat contained "!\?\^\?[~][BbCcefHhIiLMstwxYy]\s*" nextgroup=muttrcSimplePatRXContainer
" Parameter: pattern
syntax match muttrcSimplePat contained "!\?\^\?[%][bBcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
" Parameter: pattern
syntax match muttrcSimplePat contained "!\?\^\?[=][bcCefhHiLstxy]\s*" nextgroup=muttrcSimplePatString
syntax region muttrcSimplePat contained keepend start=+!\?\^\?[~](+ end=+)+ contains=muttrcSimplePat

"syn match muttrcSimplePat contained /'[^~=%][^']*/ contains=muttrcRXString
syntax region muttrcSimplePatString contained keepend start=+"+ end=+"+ skip=+\\"+
syntax region muttrcSimplePatString contained keepend start=+'+ end=+'+ skip=+\\'+
syntax region muttrcSimplePatString contained keepend start=+[^	 "']+ skip=+\\ + end=+\s+re=e-1
syntax region muttrcSimplePatRXContainer contained keepend start=+"+ end=+"+ skip=+\\"+ contains=muttrcRXString
syntax region muttrcSimplePatRXContainer contained keepend start=+'+ end=+'+ skip=+\\'+ contains=muttrcRXString
syntax region muttrcSimplePatRXContainer contained keepend start=+[^	 "']+ skip=+\\ + end=+\s+re=e-1 contains=muttrcRXString
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
syntax match muttrcColorBG	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorRXPat,muttrcColorRXNL
syntax match muttrcColorBGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFG	contained /\s*[$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorFG,muttrcColorFGNL
syntax match muttrcColorContext	contained /\s*[$]\?\w\+/ contains=muttrcColorField,muttrcVariable,muttrcUnHighlightSpace,muttrcColorCompose nextgroup=muttrcColorFG,muttrcColorFGNL
syntax match muttrcColorNL	contained skipnl "\s*\\$" nextgroup=muttrcColorContext,muttrcColorNL,muttrcColorCompose
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

" CHECKED 2020-06-21
" List of fields in Fields in color.c
syntax keyword muttrcColorField skipwhite contained
	\ attachment attach_headers body bold error hdrdefault header index index_author
	\ index_collapsed index_date index_flags index_label index_number index_size index_subject
	\ index_tag index_tags indicator markers message normal options progress prompt quoted
	\ search sidebar_divider sidebar_flagged sidebar_highlight sidebar_indicator sidebar_new
	\ sidebar_ordinary sidebar_spoolfile sidebar_unread signature status tilde tree underline
	\ warning nextgroup=muttrcColor

syntax match   muttrcColorField	contained "\<quoted\d\=\>"

syntax match muttrcColorCompose skipwhite contained /\s*compose\s*/ nextgroup=muttrcColorComposeField

" CHECKED 2020-06-21
" List of fields in ComposeFields in color.c
syntax keyword muttrcColorComposeField skipwhite contained
	\ header security_both security_encrypt security_none security_sign
	\ nextgroup=muttrcColorFG,muttrcColorFGNL
syntax region muttrcColorLine keepend start=/^\s*color\s\+/ skip=+\\$+ end=+$+ contains=muttrcColorKeyword,muttrcComment,muttrcUnHighlightSpace

function! s:boolQuadGen(type, vars, deprecated)
	let l:novars = copy(a:vars)
	call map(l:novars, '"no" . v:val')
	let l:invvars = copy(a:vars)
	call map(l:invvars, '"inv" . v:val')

	let l:orig_type = copy(a:type)
	if a:deprecated
		let l:type = 'Deprecated' . a:type
		exec 'syntax keyword muttrcVar' . l:type . ' ' . join(a:vars)
		exec 'syntax keyword muttrcVar' . l:type . ' ' . join(l:novars)
		exec 'syntax keyword muttrcVar' . l:type . ' ' . join(l:invvars)
	else
		let l:type = a:type
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(a:vars) . ' nextgroup=muttrcSet' . l:orig_type . 'Assignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr'
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:novars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr'
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:invvars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr'
	endif

endfunction

" CHECKED 2020-06-21
" List of DT_BOOL in MuttVars in mutt_config.c
call s:boolQuadGen('Bool', [
	\ 'abort_backspace', 'allow_8bit', 'allow_ansi', 'arrow_cursor', 'ascii_chars', 'askbcc',
	\ 'askcc', 'ask_follow_up', 'ask_x_comment_to', 'attach_save_without_prompting',
	\ 'attach_split', 'autocrypt', 'autocrypt_reply', 'autoedit', 'auto_subscribe', 'auto_tag',
	\ 'beep', 'beep_new', 'bounce_delivered', 'braille_friendly',
	\ 'browser_abbreviate_mailboxes', 'change_folder_next', 'check_mbox_size', 'check_new',
	\ 'collapse_all', 'collapse_flagged', 'collapse_unread', 'confirmappend', 'confirmcreate',
	\ 'crypt_autoencrypt', 'crypt_autopgp', 'crypt_autosign', 'crypt_autosmime',
	\ 'crypt_confirmhook', 'crypt_opportunistic_encrypt',
	\ 'crypt_opportunistic_encrypt_strong_keys', 'crypt_protected_headers_read',
	\ 'crypt_protected_headers_save', 'crypt_protected_headers_write', 'crypt_replyencrypt',
	\ 'crypt_replysign', 'crypt_replysignencrypted', 'crypt_timestamp', 'crypt_use_gpgme',
	\ 'crypt_use_pka', 'delete_untag', 'digest_collapse', 'duplicate_threads', 'edit_headers',
	\ 'encode_from', 'fast_reply', 'fcc_before_send', 'fcc_clear', 'flag_safe', 'followup_to',
	\ 'force_name', 'forward_decode', 'forward_decrypt', 'forward_quote', 'forward_references',
	\ 'hdrs', 'header', 'header_color_partial', 'help', 'hidden_host', 'hide_limited',
	\ 'hide_missing', 'hide_thread_subject', 'hide_top_limited', 'hide_top_missing',
	\ 'history_remove_dups', 'honor_disposition', 'idn_decode', 'idn_encode',
	\ 'ignore_list_reply_to', 'imap_check_subscribed', 'imap_condstore', 'imap_deflate',
	\ 'imap_idle', 'imap_list_subscribed', 'imap_passive', 'imap_peek', 'imap_qresync',
	\ 'imap_rfc5161', 'imap_servernoise', 'implicit_autoview', 'include_encrypted',
	\ 'include_onlyfirst', 'keep_flagged', 'mailcap_sanitize', 'maildir_check_cur',
	\ 'maildir_header_cache_verify', 'maildir_trash', 'mail_check_recent', 'mail_check_stats',
	\ 'markers', 'mark_old', 'menu_move_off', 'menu_scroll', 'message_cache_clean', 'meta_key',
	\ 'metoo', 'mh_purge', 'mime_forward_decode', 'mime_subject', 'mime_type_query_first',
	\ 'narrow_tree', 'nm_record', 'nntp_listgroup', 'nntp_load_description', 'pager_stop',
	\ 'pgp_autoinline', 'pgp_auto_decode', 'pgp_check_exit', 'pgp_check_gpg_decrypt_status_fd',
	\ 'pgp_ignore_subkeys', 'pgp_long_ids', 'pgp_replyinline', 'pgp_retainable_sigs',
	\ 'pgp_self_encrypt', 'pgp_show_unusable', 'pgp_strict_enc', 'pgp_use_gpg_agent',
	\ 'pipe_decode', 'pipe_split', 'pop_auth_try_all', 'pop_last', 'postpone_encrypt',
	\ 'print_decode', 'print_split', 'prompt_after', 'read_only', 'reflow_space_quotes',
	\ 'reflow_text', 'reply_self', 'reply_with_xorig', 'resolve', 'resume_draft_files',
	\ 'resume_edited_draft_files', 'reverse_alias', 'reverse_name', 'reverse_realname',
	\ 'rfc2047_parameters', 'save_address', 'save_empty', 'save_name', 'save_unsubscribed',
	\ 'score', 'show_new_news', 'show_only_unread', 'sidebar_folder_indent',
	\ 'sidebar_new_mail_only', 'sidebar_next_new_wrap', 'sidebar_non_empty_mailbox_only',
	\ 'sidebar_on_right', 'sidebar_short_path', 'sidebar_visible', 'sig_dashes', 'sig_on_top',
	\ 'size_show_bytes', 'size_show_fractions', 'size_show_mb', 'size_units_on_left',
	\ 'smart_wrap', 'smime_ask_cert_label', 'smime_decrypt_use_default_key', 'smime_is_default',
	\ 'smime_self_encrypt', 'sort_re', 'ssl_force_tls', 'ssl_usesystemcerts', 'ssl_use_sslv2',
	\ 'ssl_use_sslv3', 'ssl_use_tlsv1', 'ssl_use_tlsv1_1', 'ssl_use_tlsv1_2', 'ssl_use_tlsv1_3',
	\ 'ssl_verify_dates', 'ssl_verify_host', 'ssl_verify_partial_chains', 'status_on_top',
	\ 'strict_threads', 'suspend', 'text_flowed', 'thorough_search', 'thread_received', 'tilde',
	\ 'ts_enabled', 'uncollapse_jump', 'uncollapse_new', 'user_agent', 'use_8bitmime',
	\ 'use_domain', 'use_envelope_from', 'use_from', 'use_ipv6', 'virtual_spoolfile',
	\ 'wait_key', 'weed', 'wrap_search', 'write_bcc', 'x_comment_to'
	\ ], 0)

" CHECKED 2020-06-21
" Deprecated Bools
" List of DT_SYNONYM or DT_DEPRECATED Bools in MuttVars in mutt_config.c
call s:boolQuadGen('Bool', [
	\ 'edit_hdrs', 'envelope_from', 'forw_decode', 'forw_decrypt', 'forw_quote',
	\ 'header_cache_compress', 'ignore_linear_white_space', 'pgp_autoencrypt', 'pgp_autosign',
	\ 'pgp_auto_traditional', 'pgp_create_traditional', 'pgp_replyencrypt', 'pgp_replysign',
	\ 'pgp_replysignencrypted', 'xterm_set_titles'
	\ ], 1)

" CHECKED 2020-06-21
" List of DT_QUAD in MuttVars in mutt_config.c
call s:boolQuadGen('Quad', [
	\ 'abort_noattach', 'abort_nosubject', 'abort_unmodified', 'bounce', 'catchup_newsgroup',
	\ 'copy', 'crypt_verify_sig', 'delete', 'fcc_attach', 'followup_to_poster',
	\ 'forward_attachments', 'forward_edit', 'honor_followup_to', 'include', 'mime_forward',
	\ 'mime_forward_rest', 'move', 'pgp_mime_auto', 'pop_delete', 'pop_reconnect', 'postpone',
	\ 'post_moderated', 'print', 'quit', 'recall', 'reply_to', 'ssl_starttls', 
	\ ], 0)

" CHECKED 2020-06-21
" Deprecated Quads
" List of DT_SYNONYM or DT_DEPRECATED Quads in MuttVars in mutt_config.c
call s:boolQuadGen('Quad', [
	\ 'mime_fwd', 'pgp_encrypt_self', 'pgp_verify_sig', 'smime_encrypt_self'
	\ ], 1)

" CHECKED 2020-06-21
" List of DT_NUMBER or DT_LONG in MuttVars in mutt_config.c
syntax keyword muttrcVarNum	skipwhite contained
	\ connect_timeout debug_level header_cache_compress_level history
	\ imap_fetch_chunk_size imap_keepalive imap_pipeline_depth imap_poll_timeout mail_check
	\ mail_check_stats_interval menu_context net_inc nm_db_limit nm_open_timeout
	\ nm_query_window_current_position nm_query_window_duration nntp_context nntp_poll
	\ pager_context pager_index_lines pgp_timeout pop_checkinterval read_inc reflow_wrap
	\ save_history score_threshold_delete score_threshold_flag score_threshold_read
	\ search_context sendmail_wait sidebar_component_depth sidebar_width skip_quoted_offset
	\ sleep_time smime_timeout ssl_min_dh_prime_bits timeout time_inc toggle_quoted_show_levels
	\ wrap wrap_headers write_inc
	\ nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax keyword muttrcVarDeprecatedNum	contained skipwhite
	\ header_cache_pagesize wrapmargin
	\ nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" CHECKED 2020-06-21
" List of DT_STRING in MuttVars in mutt_config.c
" Special cases first, and all the rest at the end
" Formats themselves must be updated in their respective groups
" See s:escapesConditionals
syntax match muttrcVarStr	contained skipwhite 'my_[a-zA-Z0-9_]\+' nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax keyword muttrcVarStr	contained skipwhite alias_format nextgroup=muttrcVarEqualsAliasFmt
syntax keyword muttrcVarStr	contained skipwhite attach_format nextgroup=muttrcVarEqualsAttachFmt
syntax keyword muttrcVarStr	contained skipwhite compose_format nextgroup=muttrcVarEqualsComposeFmt
syntax keyword muttrcVarStr	contained skipwhite folder_format vfolder_format nextgroup=muttrcVarEqualsFolderFmt
syntax keyword muttrcVarStr	contained skipwhite attribution forward_format index_format message_format pager_format nextgroup=muttrcVarEqualsIdxFmt
syntax keyword muttrcVarStr	contained skipwhite mix_entry_format nextgroup=muttrcVarEqualsMixFmt
syntax keyword muttrcVarStr	contained skipwhite
	\ pgp_clearsign_command pgp_decode_command pgp_decrypt_command
	\ pgp_encrypt_only_command pgp_encrypt_sign_command pgp_export_command pgp_getkeys_command
	\ pgp_import_command pgp_list_pubring_command pgp_list_secring_command
	\ pgp_sign_command pgp_verify_command pgp_verify_key_command
	\ nextgroup=muttrcVarEqualsPGPCmdFmt
syntax keyword muttrcVarStr	contained skipwhite pgp_entry_format nextgroup=muttrcVarEqualsPGPFmt
syntax keyword muttrcVarStr	contained skipwhite query_format nextgroup=muttrcVarEqualsQueryFmt
syntax keyword muttrcVarStr	contained skipwhite
	\ smime_decrypt_command smime_encrypt_command smime_get_cert_command
	\ smime_get_cert_email_command smime_get_signer_cert_command
	\ smime_import_cert_command smime_pk7out_command smime_sign_command
	\ smime_verify_command smime_verify_opaque_command
	\ nextgroup=muttrcVarEqualsSmimeFmt
syntax keyword muttrcVarStr	contained skipwhite status_format ts_icon_format ts_status_format nextgroup=muttrcVarEqualsStatusFmt
syntax keyword muttrcVarStr	contained skipwhite date_format nextgroup=muttrcVarEqualsStrftimeFmt
syntax keyword muttrcVarStr	contained skipwhite group_index_format nextgroup=muttrcVarEqualsGrpIdxFmt
syntax keyword muttrcVarStr	contained skipwhite sidebar_format nextgroup=muttrcVarEqualsSdbFmt
syntax keyword muttrcVarStr	contained skipwhite
	\ abort_key arrow_string assumed_charset attach_charset attach_sep attribution_locale
	\ autocrypt_acct_format charset config_charset content_type crypt_protected_headers_subject
	\ default_hook dsn_notify dsn_return empty_subject escape forward_attribution_intro
	\ forward_attribution_trailer header_cache_backend header_cache_compress_method hidden_tags
	\ hostname imap_authenticators imap_delim_chars imap_headers imap_login imap_pass imap_user
	\ indent_string mailcap_path mark_macro_prefix mh_seq_flagged mh_seq_replied mh_seq_unseen
	\ newsgroups_charset news_server nm_default_url nm_exclude_tags nm_flagged_tag nm_query_type
	\ nm_query_window_current_search nm_query_window_timebase nm_record_tags nm_replied_tag
	\ nm_unread_tag nntp_authenticators nntp_pass nntp_user pgp_default_key pgp_sign_as pipe_sep
	\ pop_authenticators pop_host pop_pass pop_user postpone_encrypt_as post_indent_string
	\ preconnect preferred_languages realname send_charset show_multipart_alternative
	\ sidebar_delim_chars sidebar_divider_char sidebar_indent_string simple_search
	\ smime_default_key smime_encrypt_with smime_sign_as smime_sign_digest_alg
	\ smtp_authenticators smtp_pass smtp_url smtp_user spam_separator ssl_ciphers
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" Deprecated strings
syntax keyword muttrcVarDeprecatedStr
	\ abort_noattach_regexp attach_keyword forw_format hdr_format indent_str msg_format
	\ nm_default_uri pgp_self_encrypt_as post_indent_str print_cmd quote_regexp reply_regexp
	\ smime_self_encrypt_as xterm_icon xterm_title

" CHECKED 2020-06-21
" List of DT_ADDRESS
syntax keyword muttrcVarStr	contained skipwhite envelope_from_address from nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
" List of DT_ENUM
syntax keyword muttrcVarStr	contained skipwhite mbox_type nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
" List of DT_MBTABLE
syntax keyword muttrcVarStr	contained skipwhite crypt_chars flag_chars from_chars status_chars to_chars nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" CHECKED 2020-06-21
" List of DT_PATH
syntax keyword muttrcVarStr	contained skipwhite
	\ alias_file attach_save_dir autocrypt_dir certificate_file debug_file
	\ entropy_file folder header_cache history_file mbox message_cachedir newsrc
	\ news_cache_dir postponed record signature smime_ca_location
	\ smime_certificates smime_keys spoolfile ssl_ca_certificates_file
	\ ssl_client_cert tmpdir trash
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
" List of DT_COMMAND (excluding pgp_*_command and smime_*_command)
syntax keyword muttrcVarStr	contained skipwhite
	\ display_filter editor inews ispell mixmaster new_mail_command pager
	\ print_command query_command sendmail shell visual external_search_command
	\ imap_oauth_refresh_command pop_oauth_refresh_command
	\ mime_type_query_command smtp_oauth_refresh_command tunnel
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" CHECKED 2020-06-21
" List of DT_REGEX
syntax keyword muttrcVarStr	contained skipwhite
	\ abort_noattach_regex gecos_mask mask pgp_decryption_okay pgp_good_sign
	\ quote_regex reply_regex smileys
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
" List of DT_SORT
syntax keyword muttrcVarStr	contained skipwhite
	\ pgp_sort_keys sidebar_sort_method sort sort_alias sort_aux sort_browser
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr

" CHECKED 2020-06-21
" List of commands in Commands in mutt_config.c
" Remember to remove hooks, they have already been dealt with
syntax keyword muttrcCommand	skipwhite alias nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syntax keyword muttrcCommand	skipwhite bind nextgroup=muttrcBindMenuList,muttrcBindMenuListNL
syntax keyword muttrcCommand	skipwhite exec nextgroup=muttrcFunction
syntax keyword muttrcCommand	skipwhite macro nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL
syntax keyword muttrcCommand	skipwhite nospam nextgroup=muttrcNoSpamPattern
syntax keyword muttrcCommand	skipwhite set unset reset toggle nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarStr
syntax keyword muttrcCommand	skipwhite spam nextgroup=muttrcSpamPattern
syntax keyword muttrcCommand	skipwhite unalias nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syntax keyword muttrcCommand	skipwhite unhook nextgroup=muttrcHooks
syntax keyword muttrcCommand	skipwhite
	\ alternative_order attachments auto_view finish hdr_order ifdef ifndef
	\ ignore lua lua-source mailboxes mailto_allow mime_lookup my_hdr push score
	\ setenv sidebar_whitelist source subjectrx subscribe-to tag-formats
	\ tag-transforms unalternative_order unattachments unauto_view uncolor
	\ unhdr_order unignore unmailboxes unmailto_allow unmime_lookup unmono
	\ unmy_hdr unscore unsetenv unsidebar_whitelist unsubjectrx unsubscribe-from
	\ unvirtual-mailboxes virtual-mailboxes named-mailboxes
	\ echo unbind unmacro

function! s:genFunctions(functions)
	for f in a:functions
		exec 'syntax match muttrcFunction contained "\<' . l:f . '\>"'
	endfor
endfunction

" CHECKED 2020-06-21
" List of functions in functions.c
" Note: 'noop' is included but is elsewhere in the source
call s:genFunctions(['noop',
	\ 'accept', 'append', 'attach-file', 'attach-key', 'attach-message', 'attach-news-message',
	\ 'autocrypt-acct-menu', 'autocrypt-menu', 'backspace', 'backward-char', 'backward-word',
	\ 'bol', 'bottom-page', 'bottom', 'bounce-message', 'break-thread', 'buffy-cycle',
	\ 'buffy-list', 'capitalize-word', 'catchup', 'chain-next', 'chain-prev', 'change-dir',
	\ 'change-folder-readonly', 'change-folder', 'change-newsgroup-readonly',
	\ 'change-newsgroup', 'change-vfolder', 'check-new', 'check-stats',
	\ 'check-traditional-pgp', 'clear-flag', 'collapse-all', 'collapse-parts',
	\ 'collapse-thread', 'complete-query', 'complete', 'compose-to-sender', 'copy-file',
	\ 'copy-message', 'create-account', 'create-alias', 'create-mailbox', 'current-bottom',
	\ 'current-middle', 'current-top', 'decode-copy', 'decode-save', 'decrypt-copy',
	\ 'decrypt-save', 'delete-account', 'delete-char', 'delete-entry', 'delete-mailbox',
	\ 'delete-message', 'delete-pattern', 'delete-subthread', 'delete-thread', 'delete',
	\ 'descend-directory', 'detach-file', 'display-address', 'display-filename',
	\ 'display-message', 'display-toggle-weed', 'downcase-word', 'edit-bcc', 'edit-cc',
	\ 'edit-description', 'edit-encoding', 'edit-fcc', 'edit-file', 'edit-followup-to',
	\ 'edit-from', 'edit-headers', 'edit-label', 'edit-language', 'edit-message', 'edit-mime',
	\ 'edit-newsgroups', 'edit-or-view-raw-message', 'edit-raw-message', 'edit-reply-to',
	\ 'edit-subject', 'edit-to', 'edit-type', 'edit-x-comment-to', 'edit', 'end-cond',
	\ 'enter-command', 'enter-mask', 'entire-thread', 'eol', 'exit', 'extract-keys',
	\ 'fetch-mail', 'filter-entry', 'first-entry', 'flag-message', 'followup-message',
	\ 'forget-passphrase', 'forward-char', 'forward-message', 'forward-to-group',
	\ 'forward-word', 'get-attachment', 'get-children', 'get-message', 'get-parent',
	\ 'goto-folder', 'goto-parent', 'group-alternatives', 'group-chat-reply',
	\ 'group-multilingual', 'group-reply', 'half-down', 'half-up', 'help', 'history-down',
	\ 'history-search', 'history-up', 'imap-fetch-mail', 'imap-logout-all', 'insert', 'ispell',
	\ 'jump', 'kill-eol', 'kill-eow', 'kill-line', 'kill-word', 'last-entry',
	\ 'limit-current-thread', 'limit', 'link-threads', 'list-reply', 'mail-key',
	\ 'mailbox-cycle', 'mailbox-list', 'mail', 'mark-as-new', 'mark-message', 'middle-page',
	\ 'mix', 'modify-labels-then-hide', 'modify-labels', 'modify-tags-then-hide',
	\ 'modify-tags', 'move-down', 'move-up', 'new-mime', 'next-entry', 'next-line',
	\ 'next-new-then-unread', 'next-new', 'next-page', 'next-subthread', 'next-thread',
	\ 'next-undeleted', 'next-unread-mailbox', 'next-unread', 'parent-message', 'pgp-menu',
	\ 'pipe-entry', 'pipe-message', 'post-message', 'postpone-message', 'previous-entry',
	\ 'previous-line', 'previous-new-then-unread', 'previous-new', 'previous-page',
	\ 'previous-subthread', 'previous-thread', 'previous-undeleted', 'previous-unread',
	\ 'print-entry', 'print-message', 'purge-message', 'purge-thread', 'quasi-delete',
	\ 'query-append', 'query', 'quit', 'quote-char', 'read-subthread', 'read-thread',
	\ 'recall-message', 'reconstruct-thread', 'redraw-screen', 'refresh', 'reload-active',
	\ 'rename-attachment', 'rename-file', 'rename-mailbox', 'reply', 'resend-message',
	\ 'root-message', 'save-entry', 'save-message', 'search-next', 'search-opposite',
	\ 'search-reverse', 'search-toggle', 'search', 'select-entry', 'select-new',
	\ 'send-message', 'set-flag', 'shell-escape', 'show-limit', 'show-log-messages',
	\ 'show-version', 'sidebar-next-new', 'sidebar-first', 'sidebar-last', 'sidebar-next',
	\ 'sidebar-open', 'sidebar-page-down', 'sidebar-page-up', 'sidebar-prev-new',
	\ 'sidebar-prev', 'sidebar-toggle-virtual', 'sidebar-toggle-visible', 'skip-quoted',
	\ 'smime-menu', 'sort-mailbox', 'sort-reverse', 'sort', 'subscribe-pattern',
	\ 'sync-mailbox', 'tag-entry', 'tag-message', 'tag-pattern', 'tag-prefix-cond',
	\ 'tag-prefix', 'tag-subthread', 'tag-thread', 'toggle-active', 'toggle-disposition',
	\ 'toggle-mailboxes', 'toggle-new', 'toggle-prefer-encrypt', 'toggle-quoted',
	\ 'toggle-read', 'toggle-recode', 'toggle-subscribed', 'toggle-unlink', 'toggle-write',
	\ 'top-page', 'top', 'transpose-chars', 'uncatchup', 'undelete-entry', 'undelete-message',
	\ 'undelete-pattern', 'undelete-subthread', 'undelete-thread', 'unsubscribe-pattern',
	\ 'untag-pattern', 'upcase-word', 'update-encoding', 'verify-key',
	\ 'vfolder-from-query-readonly', 'vfolder-from-query', 'vfolder-window-backward',
	\ 'vfolder-window-forward', 'view-attachments', 'view-attach', 'view-file', 'view-mailcap',
	\ 'view-name', 'view-raw-message', 'view-text', 'what-key', 'write-fcc'
	\ ])

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

highlight def link muttrcSetBoolAssignment		Boolean
highlight def link muttrcSetQuadAssignment		Boolean

highlight def link muttrcComment			Comment

highlight def link muttrcAlternatesLine			Error
highlight def link muttrcBadAction			Error
highlight def link muttrcBindFunction			Error
highlight def link muttrcBindMenuList			Error
highlight def link muttrcColorBG			Error
highlight def link muttrcColorBGH			Error
highlight def link muttrcColorBGI			Error
highlight def link muttrcColorContext			Error
highlight def link muttrcColorFG			Error
highlight def link muttrcColorFGH			Error
highlight def link muttrcColorFGI			Error
highlight def link muttrcColorLine			Error
highlight def link muttrcFormatErrors			Error
highlight def link muttrcGroupLine			Error
highlight def link muttrcListsLine			Error
highlight def link muttrcPattern			Error
highlight def link muttrcSubscribeLine			Error
highlight def link muttrcUnColorLine			Error
highlight def link muttrcVarDeprecatedBool		Error
highlight def link muttrcVarDeprecatedQuad		Error
highlight def link muttrcVarDeprecatedStr		Error

highlight def link muttrcAliasEncEmail			Identifier
highlight def link muttrcAliasKey			Identifier
highlight def link muttrcColorCompose			Identifier
highlight def link muttrcColorComposeField		Identifier
highlight def link muttrcColorContextH			Identifier
highlight def link muttrcColorContextI			Identifier
highlight def link muttrcColorField			Identifier
highlight def link muttrcMenu				Identifier
highlight def link muttrcSimplePat			Identifier
highlight def link muttrcUnAliasKey			Identifier
highlight def link muttrcUnColorIndex			Identifier
highlight def link muttrcVarBool			Identifier
highlight def link muttrcVarNum				Identifier
highlight def link muttrcVarQuad			Identifier
highlight def link muttrcVarStr				Identifier

highlight def link muttrcCommand			Keyword

highlight def link muttrcAction				Macro
highlight def link muttrcAliasGroupName			Macro
highlight def link muttrcFunction			Macro
highlight def link muttrcGroupDef			Macro
highlight def link muttrcSimplePatString		Macro

highlight def link muttrcMonoAttrib			muttrcColor

highlight def link muttrcAlternateKeyword		muttrcCommand
highlight def link muttrcAttachmentsLine		muttrcCommand
highlight def link muttrcColorKeyword			muttrcCommand
highlight def link muttrcGroupKeyword			muttrcCommand
highlight def link muttrcListsKeyword			muttrcCommand
highlight def link muttrcMono				muttrcCommand
highlight def link muttrcPatHooks			muttrcCommand
highlight def link muttrcRXHooks			muttrcCommand
highlight def link muttrcSubscribeKeyword		muttrcCommand
highlight def link muttrcUnColorKeyword			muttrcCommand

highlight def link muttrcAliasFormatEscapes		muttrcEscape
highlight def link muttrcAttachFormatEscapes		muttrcEscape
highlight def link muttrcComposeFormatEscapes		muttrcEscape
highlight def link muttrcFolderFormatEscapes		muttrcEscape
highlight def link muttrcGroupIndexFormatEscapes	muttrcEscape
highlight def link muttrcIndexFormatEscapes		muttrcEscape
highlight def link muttrcMixFormatEscapes		muttrcEscape
highlight def link muttrcPGPCmdFormatEscapes		muttrcEscape
highlight def link muttrcPGPFormatEscapes		muttrcEscape
highlight def link muttrcPGPTimeEscapes			muttrcEscape
highlight def link muttrcQueryFormatEscapes		muttrcEscape
highlight def link muttrcShellString			muttrcEscape
highlight def link muttrcSidebarFormatEscapes		muttrcEscape
highlight def link muttrcSmimeFormatEscapes		muttrcEscape
highlight def link muttrcStatusFormatEscapes		muttrcEscape
highlight def link muttrcTimeEscapes			muttrcEscape

highlight def link muttrcAliasFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcAttachFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcComposeFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcFolderFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcIndexFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcMixFormatConditionals		muttrcFormatConditionals2
highlight def link muttrcPGPCmdFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcPGPFormatConditionals		muttrcFormatConditionals2
highlight def link muttrcSmimeFormatConditionals	muttrcFormatConditionals2
highlight def link muttrcStatusFormatConditionals	muttrcFormatConditionals2

highlight def link muttrcAddrDef			muttrcGroupFlag
highlight def link muttrcRXDef				muttrcGroupFlag

highlight def link muttrcAliasFormatStr			muttrcString
highlight def link muttrcAttachFormatStr		muttrcString
highlight def link muttrcComposeFormatStr		muttrcString
highlight def link muttrcFolderFormatStr		muttrcString
highlight def link muttrcGroupIndexFormatStr            muttrcString
highlight def link muttrcIndexFormatStr			muttrcString
highlight def link muttrcMixFormatStr			muttrcString
highlight def link muttrcPGPCmdFormatStr		muttrcString
highlight def link muttrcPGPFormatStr			muttrcString
highlight def link muttrcQueryFormatStr			muttrcString
highlight def link muttrcSidebarFormatStr		muttrcString
highlight def link muttrcSmimeFormatStr			muttrcString
highlight def link muttrcStatusFormatStr		muttrcString
highlight def link muttrcStrftimeFormatStr		muttrcString

highlight def link muttrcSetNumAssignment		Number

highlight def link muttrcEmail				Special
highlight def link muttrcSimplePatMetas			Special
highlight def link muttrcSpecial			Special
highlight def link muttrcVariableInner			Special

highlight def link muttrcAliasEncEmailNL		SpecialChar
highlight def link muttrcAliasENNL			SpecialChar
highlight def link muttrcAliasGroupDefNL		SpecialChar
highlight def link muttrcAliasNameNL			SpecialChar
highlight def link muttrcAliasNL			SpecialChar
highlight def link muttrcBindFunctionNL			SpecialChar
highlight def link muttrcBindKeyNL			SpecialChar
highlight def link muttrcBindMenuListNL			SpecialChar
highlight def link muttrcColorBGNL			SpecialChar
highlight def link muttrcColorFGNL			SpecialChar
highlight def link muttrcColorMatchCountNL		SpecialChar
highlight def link muttrcColorNL			SpecialChar
highlight def link muttrcColorRXNL			SpecialChar
highlight def link muttrcEscape				SpecialChar
highlight def link muttrcKeyName			SpecialChar
highlight def link muttrcKeySpecial			SpecialChar
highlight def link muttrcMacroBodyNL			SpecialChar
highlight def link muttrcMacroDescrNL			SpecialChar
highlight def link muttrcMacroKeyNL			SpecialChar
highlight def link muttrcMacroMenuListNL		SpecialChar
highlight def link muttrcPatternNL			SpecialChar
highlight def link muttrcRXChars			SpecialChar
highlight def link muttrcStringNL			SpecialChar
highlight def link muttrcUnAliasNL			SpecialChar
highlight def link muttrcUnColorAPNL			SpecialChar
highlight def link muttrcUnColorIndexNL			SpecialChar
highlight def link muttrcUnColorPatNL			SpecialChar

highlight def link muttrcAttachmentsMimeType		String
highlight def link muttrcEscapedVariable		String
highlight def link muttrcMacroDescr			String
highlight def link muttrcRXPat				String
highlight def link muttrcRXString			String
highlight def link muttrcRXString2			String
highlight def link muttrcSetStrAssignment		String
highlight def link muttrcString				String

highlight def link muttrcAliasParens			Type
highlight def link muttrcAttachmentsFlag		Type
highlight def link muttrcColor				Type
highlight def link muttrcFormatConditionals2		Type
highlight def link muttrcGroupFlag			Type
highlight def link muttrcHeader				Type
highlight def link muttrcHooks				Type
highlight def link muttrcKey				Type
highlight def link muttrcPatHookNot			Type
highlight def link muttrcRXHookNot			Type
highlight def link muttrcStrftimeEscapes		Type

let b:current_syntax = "neomuttrc"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 noet tw=100 sw=8 sts=0 ft=vim isk+=-
