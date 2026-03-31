" Vim syntax file
" Language:	NeoMutt setup files
" Maintainer:	Richard Russon <rich@flatcap.org>
" Previous Maintainer:	Guillaume Brogi <gui-gui@netcourrier.com>
" Last Change:	2024 Oct 12
" Original version based on syntax/muttrc.vim

" This file covers NeoMutt 2024-10-02

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
syntax match muttrcComment	"[^\\]#.*$"lc=1 contains=@Spell

" Escape sequences (back-tick and pipe goes here too)
syntax match muttrcEscape	+\\[#tnr"'Cc ]+
syntax match muttrcEscape	+[`|]+
syntax match muttrcEscape	+\\$+

" The variables takes the following arguments
syntax region muttrcString	contained keepend start=+"+ms=e skip=+\\"+ end=+"+ contains=muttrcEscape,muttrcCommand,muttrcAction,muttrcShellString
syntax region muttrcString	contained keepend start=+'+ms=e skip=+\\'+ end=+'+ contains=muttrcEscape,muttrcCommand,muttrcAction
syntax match muttrcStringNL	contained skipwhite skipnl "\s*\\$" nextgroup=muttrcString,muttrcStringNL

syntax region muttrcShellString	matchgroup=muttrcEscape keepend start=+`+ skip=+\\`+ end=+`+ contains=muttrcVarString,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcCommand

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

syntax match muttrcSetStrAssignment  contained skipwhite /=\s*\%(\\\?\$\)\?[0-9A-Za-z_-]\+/hs=s+1       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcVariable,muttrcEscapedVariable
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*"+hs=s+1 end=+"+ skip=+\\"+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcString
syntax region muttrcSetStrAssignment contained skipwhite keepend start=+=\s*'+hs=s+1 end=+'+ skip=+\\'+ nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcString
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1                         nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*\%(yes\|no\)/hs=s+1                       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*"\%(yes\|no\)"/hs=s+1                     nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetBoolAssignment contained skipwhite /=\s*'\%(yes\|no\)'/hs=s+1                     nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\\\?\$\w\+/hs=s+1                         nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*\%(ask-\)\?\%(yes\|no\)/hs=s+1            nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*"\%(ask-\)\?\%(yes\|no\)"/hs=s+1          nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetQuadAssignment contained skipwhite /=\s*'\%(ask-\)\?\%(yes\|no\)'/hs=s+1          nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetNumAssignment  contained skipwhite /=\s*\\\?\$\w\+/hs=s+1                         nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString contains=muttrcVariable,muttrcEscapedVariable
syntax match muttrcSetNumAssignment  contained skipwhite /=\s*\d\+/hs=s+1                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetNumAssignment  contained skipwhite /=\s*"\d\+"/hs=s+1                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax match muttrcSetNumAssignment  contained skipwhite /=\s*'\d\+'/hs=s+1                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

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

" Defines syntax matches for muttrc[baseName]Escapes, muttrc[baseName]Conditionals
" If padding==1, also match `%>` `%|` `%*` expandos
" If conditional==1, some expandos support %X? format
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

" CHECKED 2024 Oct 12
" Ref: AliasFormatDef in alias/config.c
call s:escapesConditionals('AliasFormat', '[acfnrtY]', 1, 0)
" Ref: AttachFormatDef in mutt_config.c
call s:escapesConditionals('AttachFormat', '[CcDdeFfIMmnQsTtuX]', 1, 1)
" Ref: AutocryptFormatDef in autocrypt/config.c
call s:escapesConditionals('AutocryptFormat', '[aknps]', 1, 0)
" Ref: ComposeFormatDef in compose/config.c
call s:escapesConditionals('ComposeFormat', '[ahlv]', 1, 1)
" Ref: FolderFormatDef in browser/config.c
call s:escapesConditionals('FolderFormat', '[aCDdFfgilmNnpstu[]', 1, 1)
" Ref: GreetingFormatDef in send/config.c
call s:escapesConditionals('GreetingFormat', '[nuv]', 0, 0)
" Ref: GroupIndexFormatDef in browser/config.c
call s:escapesConditionals('GroupIndexFormat', '[aCdfMNnps]', 1, 0)
" Ref: HistoryFormatDef in history/config.c
call s:escapesConditionals('HistoryFormat', '[Cs]', 1, 0)
" Ref: IndexFormatDef in mutt_config.c
call s:escapesConditionals('IndexFormat', '[AaBbCDdEefgHIiJKLlMmNnOPqRrSsTtuvWXxYyZ(<[{]\|@\i\+@\|G[a-zA-Z]\+\|Fp\=\|z[cst]\|cr\=', 1, 1)
" Ref: PatternFormatDef in pattern/config.c
call s:escapesConditionals('PatternFormat', '[den]', 1, 0)
" Ref: PgpCommandFormatDef in ncrypt/config.c
call s:escapesConditionals('PgpCommandFormat', '[afprs]', 0, 1)
" Ref: PgpEntryFormatDef in ncrypt/config.c
call s:escapesConditionals('PgpEntryFormat', '[AaCcFfIiKkLlnptu[]', 1, 1)
" Ref: QueryFormatDef in alias/config.c
call s:escapesConditionals('QueryFormat', '[acentY]', 1, 1)
" Ref: SidebarFormatDef in sidebar/config.c
call s:escapesConditionals('SidebarFormat', '[!aBDdFLNnoprStZ]', 1, 1)
" Ref: SmimeCommandFormatDef in ncrypt/config.c
call s:escapesConditionals('SmimeCommandFormat', '[aCcdfiks]', 0, 1)
" Ref: StatusFormatDef in mutt_config.c
call s:escapesConditionals('StatusFormat', '[bDdFfhLlMmnoPpRrSsTtuVv]', 1, 1)

syntax region muttrcAliasFormatString         contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAliasFormatEscapes,muttrcAliasFormatConditionals,muttrcFormatErrors                                   nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcAliasFormatString         contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAliasFormatEscapes,muttrcAliasFormatConditionals,muttrcFormatErrors                                   nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcAttachFormatString        contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcAttachFormatString        contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAttachFormatEscapes,muttrcAttachFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcAutocryptFormatString     contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcAutocryptFormatEscapes,muttrcAutocryptFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcAutocryptFormatString     contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcAutocryptFormatEscapes,muttrcAutocryptFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcComposeFormatString       contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcComposeFormatEscapes,muttrcComposeFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcComposeFormatString       contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcComposeFormatEscapes,muttrcComposeFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcFolderFormatString        contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcFolderFormatString        contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcFolderFormatEscapes,muttrcFolderFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcGreetingFormatString      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcGreetingFormatEscapes,muttrcGreetingFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcGreetingFormatString      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcGreetingFormatEscapes,muttrcGreetingFormatConditionals,muttrcFormatErrors                             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcGroupIndexFormatString    contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcGroupIndexFormatString    contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcGroupIndexFormatEscapes,muttrcGroupIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes       nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcHistoryFormatString       contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcHistoryFormatEscapes,muttrcHistoryFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcHistoryFormatString       contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcHistoryFormatEscapes,muttrcHistoryFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcIndexFormatString         contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcIndexFormatString         contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcIndexFormatEscapes,muttrcIndexFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPatternFormatString       contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPatternFormatEscapes,muttrcPatternFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPatternFormatString       contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPatternFormatEscapes,muttrcPatternFormatConditionals,muttrcFormatErrors                               nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPgpCommandFormatString    contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPgpCommandFormatEscapes,muttrcPgpCommandFormatConditionals,muttrcVariable,muttrcFormatErrors          nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPgpCommandFormatString    contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPgpCommandFormatEscapes,muttrcPgpCommandFormatConditionals,muttrcVariable,muttrcFormatErrors          nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPgpEntryFormatString      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcPgpEntryFormatEscapes,muttrcPgpEntryFormatConditionals,muttrcFormatErrors,muttrcPgpTimeEscapes        nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcPgpEntryFormatString      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcPgpEntryFormatEscapes,muttrcPgpEntryFormatConditionals,muttrcFormatErrors,muttrcPgpTimeEscapes        nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcQueryFormatString         contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors                                   nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcQueryFormatString         contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcQueryFormatEscapes,muttrcQueryFormatConditionals,muttrcFormatErrors                                   nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcSidebarFormatString       contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcSidebarFormatString       contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSidebarFormatEscapes,muttrcSidebarFormatConditionals,muttrcFormatErrors,muttrcTimeEscapes             nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcSmimeCommandFormatString  contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcSmimeCommandFormatEscapes,muttrcSmimeCommandFormatConditionals,muttrcVariable,muttrcFormatErrors      nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcSmimeCommandFormatString  contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcSmimeCommandFormatEscapes,muttrcSmimeCommandFormatConditionals,muttrcVariable,muttrcFormatErrors      nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcStatusFormatString        contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcStatusFormatString        contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStatusFormatEscapes,muttrcStatusFormatConditionals,muttrcFormatErrors                                 nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcStrftimeFormatString      contained skipwhite keepend start=+"+ skip=+\\"+ end=+"+ contains=muttrcStrftimeEscapes,muttrcFormatErrors                                                                    nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax region muttrcStrftimeFormatString      contained skipwhite keepend start=+'+ skip=+\\'+ end=+'+ contains=muttrcStrftimeEscapes,muttrcFormatErrors                                                                    nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" Format escapes and conditionals
syntax match muttrcFormatConditionals2 contained /[^?]*?/

syntax region muttrcPgpTimeEscapes contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%(+  end=+)+  contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%<+  end=+>+  contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%\[+ end=+\]+ contains=muttrcStrftimeEscapes
syntax region muttrcTimeEscapes    contained start=+%{+  end=+}+  contains=muttrcStrftimeEscapes

syntax match muttrcVarEqualsAliasFormat         contained skipwhite "=" nextgroup=muttrcAliasFormatString
syntax match muttrcVarEqualsAttachFormat        contained skipwhite "=" nextgroup=muttrcAttachFormatString
syntax match muttrcVarEqualsAutocryptFormat     contained skipwhite "=" nextgroup=muttrcAutocryptFormatString
syntax match muttrcVarEqualsComposeFormat       contained skipwhite "=" nextgroup=muttrcComposeFormatString
syntax match muttrcVarEqualsFolderFormat        contained skipwhite "=" nextgroup=muttrcFolderFormatString
syntax match muttrcVarEqualsGreetingFormat      contained skipwhite "=" nextgroup=muttrcGreetingFormatString
syntax match muttrcVarEqualsGroupIndexFormat    contained skipwhite "=" nextgroup=muttrcGroupIndexFormatString
syntax match muttrcVarEqualsHistoryFormat       contained skipwhite "=" nextgroup=muttrcHistoryFormatString
syntax match muttrcVarEqualsIndexFormat         contained skipwhite "=" nextgroup=muttrcIndexFormatString
syntax match muttrcVarEqualsPatternFormat       contained skipwhite "=" nextgroup=muttrcPatternFormatString
syntax match muttrcVarEqualsPgpCommandFormat    contained skipwhite "=" nextgroup=muttrcPgpCommandFormatString
syntax match muttrcVarEqualsPgpEntryFormat      contained skipwhite "=" nextgroup=muttrcPgpEntryFormatString
syntax match muttrcVarEqualsQueryFormat         contained skipwhite "=" nextgroup=muttrcQueryFormatString
syntax match muttrcVarEqualsSidebarFormat       contained skipwhite "=" nextgroup=muttrcSidebarFormatString
syntax match muttrcVarEqualsSmimeCommandFormat  contained skipwhite "=" nextgroup=muttrcSmimeCommandFormatString
syntax match muttrcVarEqualsStatusFormat        contained skipwhite "=" nextgroup=muttrcStatusFormatString
syntax match muttrcVarEqualsStrftimeFormat      contained skipwhite "=" nextgroup=muttrcStrftimeFormatString

syntax match muttrcVPrefix contained /[?&]/ nextgroup=muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" CHECKED 2024 Oct 12
" List of the different screens in NeoMutt (see MenuNames in menu/type.c)
syntax keyword muttrcMenu contained alias attach autocrypt browser compose dialog editor generic index key_select_pgp key_select_smime pager pgp postpone query smime
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

" CHECKED 2024 Oct 12
" First, hooks that take regular expressions:
syntax match  muttrcRXHookNot		contained /!\s*/ skipwhite nextgroup=muttrcRXHookString,muttrcRXHookStringNL
syntax match  muttrcRXHookNoRegex	contained /-noregex/ skipwhite nextgroup=muttrcRXHookString,muttrcRXHookStringNL
syntax match  muttrcRXHooks	/\<\%(account\|append\|close\|crypt\|open\|pgp\|shutdown\|startup\|timeout\)-hook\>/ skipwhite nextgroup=muttrcRXHookNot,muttrcRXHookString,muttrcRXHookStringNL
syntax match  muttrcRXHooks	/\<\%(folder\|mbox\)-hook\>/ skipwhite nextgroup=muttrcRXHookNoRegex,muttrcRXHookNot,muttrcRXHookString,muttrcRXHookStringNL

" Now, hooks that take patterns
syntax match muttrcPatHookNot	contained /!\s*/ skipwhite nextgroup=muttrcPattern
syntax match muttrcPatHooks	/\<\%(charset\|iconv\|index-format\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcPattern
syntax match muttrcPatHooks	/\<\%(message\|reply\|send\|send2\|save\|fcc\|fcc-save\)-hook\>/ skipwhite nextgroup=muttrcPatHookNot,muttrcOptPattern

" Global hooks that take a command
syntax keyword muttrcHooks skipwhite shutdown-hook startup-hook timeout-hook nextgroup=muttrcCommand

syntax match muttrcBindFunction		contained /\S\+\>/ skipwhite contains=muttrcFunction
syntax match muttrcBindFunctionNL	contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syntax match muttrcBindKey		contained /\S\+/   skipwhite contains=muttrcKey nextgroup=muttrcBindFunction,muttrcBindFunctionNL
syntax match muttrcBindKeyNL		contained /\s*\\$/ skipwhite skipnl nextgroup=muttrcBindKey,muttrcBindKeyNL
syntax match muttrcBindMenuList		contained /\S\+/   skipwhite contains=muttrcMenu,muttrcMenuCommas nextgroup=muttrcBindKey,muttrcBindKeyNL
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

" CHECKED 2024 Oct 12
" List of letters in Flags in pattern/flags.c
" Parameter: none
syntax match muttrcSimplePat contained "!\?\^\?[~][ADEFGgklNOPpQRSTUuVv#$=]"
" Parameter: range
syntax match muttrcSimplePat contained "!\?\^\?[~][mnXz]\s*\%([<>-][0-9]\+[kM]\?\|[0-9]\+[kM]\?[-]\%([0-9]\+[kM]\?\)\?\)"
" Parameter: date
syntax match muttrcSimplePat contained "!\?\^\?[~][dr]\s*\%(\%(-\?[0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)\|\%(\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)*\)-\%([0-9]\{1,2}\%(/[0-9]\{1,2}\%(/[0-9]\{2}\%([0-9]\{2}\)\?\)\?\)\?\%([+*-][0-9]\+[ymwd]\)\?\)\?\)\|\%([<>=][0-9]\+[ymwd]\)\|\%(`[^`]\+`\)\|\%(\$[a-zA-Z0-9_-]\+\)\)" contains=muttrcShellString,muttrcVariable
" Parameter: regex
syntax match muttrcSimplePat contained "!\?\^\?[~][BbCcefHhIiKLMstwxYy]\s*" nextgroup=muttrcSimplePatRXContainer
" Parameter: pattern
syntax match muttrcSimplePat contained "!\?\^\?[%][BbCcefHhiLstxy]\s*" nextgroup=muttrcSimplePatString
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

" Colour definitions takes object, foreground and background arguments (regexes excluded).
syntax match muttrcColorMatchCount	contained "[0-9]\+"
syntax match muttrcColorMatchCountNL contained skipwhite skipnl "\s*\\$" nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax region muttrcColorRXPat	contained start=+\s*'+ skip=+\\'+ end=+'\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax region muttrcColorRXPat	contained start=+\s*"+ skip=+\\"+ end=+"\s*+ keepend skipwhite contains=muttrcRXString2 nextgroup=muttrcColorMatchCount,muttrcColorMatchCountNL
syntax keyword muttrcColor	contained black blue cyan default green magenta red white yellow
syntax keyword muttrcColor	contained brightblack brightblue brightcyan brightdefault brightgreen brightmagenta brightred brightwhite brightyellow
syntax keyword muttrcColor	contained lightblack lightblue lightcyan lightdefault lightgreen lightmagenta lightred lightwhite lightyellow
syntax keyword muttrcColor	contained alertblack alertblue alertcyan alertdefault alertgreen alertmagenta alertred alertwhite alertyellow
syntax match   muttrcColor	contained "\<\%(bright\)\=color\d\{1,3}\>"
syntax match   muttrcColor	contained "#[0-9a-fA-F]\{6}\>"

" Now for the structure of the color line
syntax match muttrcColorRXNL	contained skipnl "\s*\\$" nextgroup=muttrcColorRXPat,muttrcColorRXNL
syntax match muttrcColorBG	contained /\s*[#$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorRXPat,muttrcColorRXNL
syntax match muttrcColorBGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFG	contained /\s*[#$]\?\w\+/ contains=muttrcColor,muttrcVariable,muttrcUnHighlightSpace nextgroup=muttrcColorBG,muttrcColorBGNL
syntax match muttrcColorFGNL	contained skipnl "\s*\\$" nextgroup=muttrcColorFG,muttrcColorFGNL
syntax match muttrcColorContext	contained /\s*[#$]\?\w\+/ contains=muttrcColorField,muttrcVariable,muttrcUnHighlightSpace,muttrcColorCompose nextgroup=muttrcColorFG,muttrcColorFGNL
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

syntax keyword muttrcMonoAttrib	contained bold italic none normal reverse standout underline
syntax keyword muttrcMono	contained mono		skipwhite nextgroup=muttrcColorField,muttrcColorCompose
syntax match   muttrcMonoLine	"^\s*mono\s\+\S\+"	skipwhite nextgroup=muttrcMonoAttrib contains=muttrcMono

" CHECKED 2024 Oct 12
" List of fields in ColorFields in color/command.c
syntax keyword muttrcColorField skipwhite contained
	\ attachment attach_headers body bold error hdrdefault header index index_author
	\ index_collapsed index_date index_flags index_label index_number index_size index_subject
	\ index_tag index_tags indicator italic markers message normal options progress prompt
	\ search sidebar_background sidebar_divider sidebar_flagged sidebar_highlight
	\ sidebar_indicator sidebar_new sidebar_ordinary sidebar_spool_file sidebar_unread signature
	\ status stripe_even stripe_odd tilde tree underline warning
	\ nextgroup=muttrcColor

syntax match   muttrcColorField	contained "\<quoted\d\=\>"

syntax match muttrcColorCompose skipwhite contained /\s*compose\s*/ nextgroup=muttrcColorComposeField

" CHECKED 2024 Oct 12
" List of fields in ComposeColorFields in color/command.c
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
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(a:vars) . ' nextgroup=muttrcSet' . l:orig_type . 'Assignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString'
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:novars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString'
		exec 'syntax keyword muttrcVar' . l:type . ' skipwhite contained ' . join(l:invvars) . ' nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString'
	endif

endfunction

" CHECKED 2024 Oct 12
" List of DT_BOOL in MuttVars in mutt_config.c
call s:boolQuadGen('Bool', [
	\ 'abort_backspace', 'allow_8bit', 'allow_ansi', 'arrow_cursor', 'ascii_chars', 'ask_bcc',
	\ 'ask_cc', 'ask_followup_to', 'ask_x_comment_to', 'attach_save_without_prompting',
	\ 'attach_split', 'autocrypt', 'autocrypt_reply', 'auto_edit', 'auto_subscribe', 'auto_tag',
	\ 'beep', 'beep_new', 'bounce_delivered', 'braille_friendly',
	\ 'browser_abbreviate_mailboxes', 'browser_sort_dirs_first', 'change_folder_next',
	\ 'check_mbox_size', 'check_new', 'collapse_all', 'collapse_flagged', 'collapse_unread',
	\ 'color_directcolor', 'compose_confirm_detach_first', 'compose_show_user_headers',
	\ 'confirm_append', 'confirm_create', 'copy_decode_weed', 'count_alternatives',
	\ 'crypt_auto_encrypt', 'crypt_auto_pgp', 'crypt_auto_sign', 'crypt_auto_smime',
	\ 'crypt_confirm_hook', 'crypt_encryption_info', 'crypt_opportunistic_encrypt',
	\ 'crypt_opportunistic_encrypt_strong_keys', 'crypt_protected_headers_read',
	\ 'crypt_protected_headers_save', 'crypt_protected_headers_weed',
	\ 'crypt_protected_headers_write', 'crypt_reply_encrypt', 'crypt_reply_sign',
	\ 'crypt_reply_sign_encrypted', 'crypt_timestamp', 'crypt_use_gpgme', 'crypt_use_pka',
	\ 'delete_untag', 'digest_collapse', 'duplicate_threads', 'edit_headers', 'encode_from',
	\ 'fast_reply', 'fcc_before_send', 'fcc_clear', 'flag_safe', 'followup_to', 'force_name',
	\ 'forward_decode', 'forward_decrypt', 'forward_quote', 'forward_references', 'hdrs',
	\ 'header', 'header_color_partial', 'help', 'hidden_host', 'hide_limited', 'hide_missing',
	\ 'hide_thread_subject', 'hide_top_limited', 'hide_top_missing', 'history_remove_dups',
	\ 'honor_disposition', 'idn_decode', 'idn_encode', 'ignore_list_reply_to',
	\ 'imap_check_subscribed', 'imap_condstore', 'imap_deflate', 'imap_idle',
	\ 'imap_list_subscribed', 'imap_passive', 'imap_peek', 'imap_qresync', 'imap_rfc5161',
	\ 'imap_send_id', 'imap_server_noise', 'implicit_auto_view', 'include_encrypted',
	\ 'include_only_first', 'keep_flagged', 'local_date_header', 'mailcap_sanitize',
	\ 'maildir_check_cur', 'maildir_header_cache_verify', 'maildir_trash', 'mail_check_recent',
	\ 'mail_check_stats', 'markers', 'mark_old', 'menu_move_off', 'menu_scroll',
	\ 'message_cache_clean', 'meta_key', 'me_too', 'mh_purge', 'mime_forward_decode',
	\ 'mime_type_query_first', 'narrow_tree', 'nm_query_window_enable', 'nm_record',
	\ 'nntp_listgroup', 'nntp_load_description', 'pager_stop', 'pgp_auto_decode',
	\ 'pgp_auto_inline', 'pgp_check_exit', 'pgp_check_gpg_decrypt_status_fd',
	\ 'pgp_ignore_subkeys', 'pgp_long_ids', 'pgp_reply_inline', 'pgp_retainable_sigs',
	\ 'pgp_self_encrypt', 'pgp_show_unusable', 'pgp_strict_enc', 'pgp_use_gpg_agent',
	\ 'pipe_decode', 'pipe_decode_weed', 'pipe_split', 'pop_auth_try_all', 'pop_last',
	\ 'postpone_encrypt', 'print_decode', 'print_decode_weed', 'print_split', 'prompt_after',
	\ 'read_only', 'reflow_space_quotes', 'reflow_text', 'reply_self', 'reply_with_xorig',
	\ 'resolve', 'resume_draft_files', 'resume_edited_draft_files', 'reverse_alias',
	\ 'reverse_name', 'reverse_real_name', 'rfc2047_parameters', 'save_address', 'save_empty',
	\ 'save_name', 'save_unsubscribed', 'score', 'show_new_news', 'show_only_unread',
	\ 'sidebar_folder_indent', 'sidebar_new_mail_only', 'sidebar_next_new_wrap',
	\ 'sidebar_non_empty_mailbox_only', 'sidebar_on_right', 'sidebar_short_path',
	\ 'sidebar_visible', 'sig_dashes', 'sig_on_top', 'size_show_bytes', 'size_show_fractions',
	\ 'size_show_mb', 'size_units_on_left', 'smart_wrap', 'smime_ask_cert_label',
	\ 'smime_decrypt_use_default_key', 'smime_is_default', 'smime_self_encrypt', 'sort_re',
	\ 'ssl_force_tls', 'ssl_use_sslv2', 'ssl_use_sslv3', 'ssl_use_system_certs',
	\ 'ssl_use_tlsv1', 'ssl_use_tlsv1_1', 'ssl_use_tlsv1_2', 'ssl_use_tlsv1_3',
	\ 'ssl_verify_dates', 'ssl_verify_host', 'ssl_verify_partial_chains', 'status_on_top',
	\ 'strict_threads', 'suspend', 'text_flowed', 'thorough_search', 'thread_received', 'tilde',
	\ 'ts_enabled', 'tunnel_is_secure', 'uncollapse_jump', 'uncollapse_new', 'user_agent',
	\ 'use_8bit_mime', 'use_domain', 'use_envelope_from', 'use_from', 'use_ipv6',
	\ 'virtual_spool_file', 'wait_key', 'weed', 'wrap_search', 'write_bcc', 'x_comment_to'
	\ ], 0)

" CHECKED 2024 Oct 12
" Deprecated Bools
" List of DT_SYNONYM or DT_DEPRECATED Bools in MuttVars in mutt_config.c
call s:boolQuadGen('Bool', [
	\ 'askbcc', 'askcc', 'ask_follow_up', 'autoedit', 'confirmappend', 'confirmcreate',
	\ 'crypt_autoencrypt', 'crypt_autopgp', 'crypt_autosign', 'crypt_autosmime',
	\ 'crypt_confirmhook', 'crypt_replyencrypt', 'crypt_replysign', 'crypt_replysignencrypted',
	\ 'cursor_overlay', 'edit_hdrs', 'envelope_from', 'forw_decode', 'forw_decrypt',
	\ 'forw_quote', 'header_cache_compress', 'ignore_linear_white_space', 'imap_servernoise',
	\ 'implicit_autoview', 'include_onlyfirst', 'metoo', 'mime_subject', 'pgp_autoencrypt',
	\ 'pgp_autoinline', 'pgp_autosign', 'pgp_auto_traditional', 'pgp_create_traditional',
	\ 'pgp_replyencrypt', 'pgp_replyinline', 'pgp_replysign', 'pgp_replysignencrypted',
	\ 'pgp_self_encrypt_as', 'reverse_realname', 'smime_self_encrypt_as', 'ssl_usesystemcerts',
	\ 'use_8bitmime', 'virtual_spoolfile', 'xterm_set_titles'
	\ ], 1)

" CHECKED 2024 Oct 12
" List of DT_QUAD in MuttVars in mutt_config.c
call s:boolQuadGen('Quad', [
	\ 'abort_noattach', 'abort_nosubject', 'abort_unmodified', 'bounce', 'catchup_newsgroup',
	\ 'copy', 'crypt_verify_sig', 'delete', 'fcc_attach', 'followup_to_poster',
	\ 'forward_attachments', 'forward_edit', 'honor_followup_to', 'include', 'mime_forward',
	\ 'mime_forward_rest', 'move', 'pgp_mime_auto', 'pop_delete', 'pop_reconnect', 'postpone',
	\ 'post_moderated', 'print', 'quit', 'recall', 'reply_to', 'ssl_starttls'
	\ ], 0)

" CHECKED 2024 Oct 12
" Deprecated Quads
" List of DT_SYNONYM or DT_DEPRECATED Quads in MuttVars in mutt_config.c
call s:boolQuadGen('Quad', [
	\ 'mime_fwd', 'pgp_encrypt_self', 'pgp_verify_sig', 'smime_encrypt_self'
	\ ], 1)

" CHECKED 2024 Oct 12
" List of DT_NUMBER or DT_LONG in MuttVars in mutt_config.c
syntax keyword muttrcVarNum	skipwhite contained
	\ debug_level header_cache_compress_level history imap_fetch_chunk_size imap_keep_alive
	\ imap_pipeline_depth imap_poll_timeout mail_check mail_check_stats_interval menu_context
	\ net_inc nm_db_limit nm_open_timeout nm_query_window_current_position
	\ nm_query_window_duration nntp_context nntp_poll pager_context pager_index_lines
	\ pager_read_delay pager_skip_quoted_context pgp_timeout pop_check_interval read_inc
	\ reflow_wrap save_history score_threshold_delete score_threshold_flag score_threshold_read
	\ search_context sendmail_wait sidebar_component_depth sidebar_width sleep_time
	\ smime_timeout socket_timeout ssl_min_dh_prime_bits timeout time_inc
	\ toggle_quoted_show_levels wrap wrap_headers write_inc
	\ nextgroup=muttrcSetNumAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
" CHECKED 2024 Oct 12
" Deprecated Numbers
syntax keyword muttrcVarDeprecatedNum
	\ connect_timeout header_cache_pagesize imap_keepalive pop_checkinterval skip_quoted_offset

" CHECKED 2024 Oct 12
" List of DT_STRING in MuttVars in mutt_config.c
" Special cases first, and all the rest at the end
" Formats themselves must be updated in their respective groups
" See s:escapesConditionals
syntax match   muttrcVarString	contained skipwhite 'my_[a-zA-Z0-9_]\+' nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax keyword muttrcVarString	contained skipwhite alias_format nextgroup=muttrcVarEqualsAliasFormat
syntax keyword muttrcVarString	contained skipwhite attach_format nextgroup=muttrcVarEqualsAttachFormat
syntax keyword muttrcVarString	contained skipwhite autocrypt_acct_format nextgroup=muttrcVarEqualsAutocryptFormat
syntax keyword muttrcVarString	contained skipwhite compose_format nextgroup=muttrcVarEqualsComposeFormat
syntax keyword muttrcVarString	contained skipwhite folder_format mailbox_folder_format nextgroup=muttrcVarEqualsFolderFormat
syntax keyword muttrcVarString	contained skipwhite greeting nextgroup=muttrcVarEqualsGreetingFormat
syntax keyword muttrcVarString	contained skipwhite history_format nextgroup=muttrcVarEqualsHistoryFormat
syntax keyword muttrcVarString	contained skipwhite
	\ attribution_intro attribution_trailer forward_attribution_intro forward_attribution_trailer
	\ forward_format indent_string index_format message_format pager_format
	\ nextgroup=muttrcVarEqualsIndexFormat
syntax keyword muttrcVarString	contained skipwhite pattern_format nextgroup=muttrcVarEqualsPatternFormat
syntax keyword muttrcVarString	contained skipwhite
	\ pgp_clear_sign_command pgp_decode_command pgp_decrypt_command pgp_encrypt_only_command
	\ pgp_encrypt_sign_command pgp_export_command pgp_get_keys_command pgp_import_command
	\ pgp_list_pubring_command pgp_list_secring_command pgp_sign_command pgp_verify_command
	\ pgp_verify_key_command
	\ nextgroup=muttrcVarEqualsPgpCommandFormat
syntax keyword muttrcVarString	contained skipwhite pgp_entry_format nextgroup=muttrcVarEqualsPgpEntryFormat
syntax keyword muttrcVarString	contained skipwhite query_format nextgroup=muttrcVarEqualsQueryFormat
syntax keyword muttrcVarString	contained skipwhite
	\ smime_decrypt_command smime_encrypt_command smime_get_cert_command
	\ smime_get_cert_email_command smime_get_signer_cert_command smime_import_cert_command
	\ smime_pk7out_command smime_sign_command smime_verify_command smime_verify_opaque_command
	\ nextgroup=muttrcVarEqualsSmimeCommandFormat
syntax keyword muttrcVarString	contained skipwhite status_format ts_icon_format ts_status_format nextgroup=muttrcVarEqualsStatusFormat
syntax keyword muttrcVarString	contained skipwhite date_format nextgroup=muttrcVarEqualsStrftimeFormat
syntax keyword muttrcVarString	contained skipwhite group_index_format nextgroup=muttrcVarEqualsGroupIndexFormat
syntax keyword muttrcVarString	contained skipwhite sidebar_format nextgroup=muttrcVarEqualsSidebarFormat
syntax keyword muttrcVarString	contained skipwhite
	\ abort_key arrow_string assumed_charset attach_charset attach_sep attribution_locale
	\ charset config_charset content_type crypt_protected_headers_subject default_hook
	\ dsn_notify dsn_return empty_subject header_cache_backend header_cache_compress_method
	\ hidden_tags hostname imap_authenticators imap_delim_chars imap_headers imap_login
	\ imap_pass imap_user mailcap_path maildir_field_delimiter mark_macro_prefix mh_seq_flagged
	\ mh_seq_replied mh_seq_unseen newsgroups_charset newsrc news_server nm_config_profile
	\ nm_default_url nm_exclude_tags nm_flagged_tag nm_query_type nm_query_window_current_search
	\ nm_query_window_or_terms nm_query_window_timebase nm_record_tags nm_replied_tag
	\ nm_unread_tag nntp_authenticators nntp_pass nntp_user pgp_default_key pgp_sign_as pipe_sep
	\ pop_authenticators pop_host pop_pass pop_user postpone_encrypt_as preconnect
	\ preferred_languages real_name send_charset show_multipart_alternative sidebar_delim_chars
	\ sidebar_divider_char sidebar_indent_string simple_search smime_default_key
	\ smime_encrypt_with smime_sign_as smime_sign_digest_alg smtp_authenticators smtp_pass
	\ smtp_url smtp_user spam_separator ssl_ciphers
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" Deprecated strings
syntax keyword muttrcVarDeprecatedString
	\ abort_noattach_regexp attach_keyword attribution escape forw_format hdr_format indent_str
	\ message_cachedir mixmaster mix_entry_format msg_format nm_default_uri
	\ pgp_clearsign_command pgp_getkeys_command pgp_self_encrypt_as post_indent_str
	\ post_indent_string print_cmd quote_regexp realname reply_regexp smime_self_encrypt_as
	\ spoolfile tmpdir vfolder_format visual xterm_icon xterm_title

" CHECKED 2024 Oct 12
" List of DT_ADDRESS
syntax keyword muttrcVarString	contained skipwhite envelope_from_address from nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
" List of DT_ENUM
syntax keyword muttrcVarString	contained skipwhite mbox_type use_threads nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
" List of DT_MBTABLE
syntax keyword muttrcVarString	contained skipwhite crypt_chars flag_chars from_chars status_chars to_chars nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" CHECKED 2024 Oct 12
" List of DT_PATH or D_STRING_MAILBOX
syntax keyword muttrcVarString	contained skipwhite
	\ alias_file attach_save_dir autocrypt_dir certificate_file debug_file entropy_file folder
	\ header_cache history_file mbox message_cache_dir news_cache_dir nm_config_file postponed
	\ record signature smime_ca_location smime_certificates smime_keys spool_file
	\ ssl_ca_certificates_file ssl_client_cert tmp_dir trash
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
" List of DT_COMMAND (excluding pgp_*_command and smime_*_command)
syntax keyword muttrcVarString	contained skipwhite
	\ account_command display_filter editor external_search_command imap_oauth_refresh_command
	\ inews ispell mime_type_query_command new_mail_command pager pop_oauth_refresh_command
	\ print_command query_command sendmail shell smtp_oauth_refresh_command tunnel
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" CHECKED 2024 Oct 12
" List of DT_REGEX
syntax keyword muttrcVarString	contained skipwhite
	\ abort_noattach_regex gecos_mask mask pgp_decryption_okay pgp_good_sign quote_regex
	\ reply_regex smileys
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
" List of DT_SORT
syntax keyword muttrcVarString	contained skipwhite
	\ pgp_sort_keys sidebar_sort_method sort sort_alias sort_aux sort_browser
	\ nextgroup=muttrcSetStrAssignment,muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString

" CHECKED 2024 Oct 12
" List of commands in mutt_commands in commands.c
" Remember to remove hooks, they have already been dealt with
syntax keyword muttrcCommand	skipwhite alias nextgroup=muttrcAliasGroupDef,muttrcAliasKey,muttrcAliasNL
syntax keyword muttrcCommand	skipwhite bind nextgroup=muttrcBindMenuList,muttrcBindMenuListNL
syntax keyword muttrcCommand	skipwhite exec nextgroup=muttrcFunction
syntax keyword muttrcCommand	skipwhite macro nextgroup=muttrcMacroMenuList,muttrcMacroMenuListNL
syntax keyword muttrcCommand	skipwhite nospam nextgroup=muttrcNoSpamPattern
syntax keyword muttrcCommand	skipwhite set unset reset toggle nextgroup=muttrcVPrefix,muttrcVarBool,muttrcVarQuad,muttrcVarNum,muttrcVarString
syntax keyword muttrcCommand	skipwhite spam nextgroup=muttrcSpamPattern
syntax keyword muttrcCommand	skipwhite unalias nextgroup=muttrcUnAliasKey,muttrcUnAliasNL
syntax keyword muttrcCommand	skipwhite unhook nextgroup=muttrcHooks
syntax keyword muttrcCommand	skipwhite
	\ alternative_order attachments auto_view cd echo finish hdr_order ifdef ifndef ignore lua
	\ lua-source mailboxes mailto_allow mime_lookup my_hdr named-mailboxes push score setenv
	\ sidebar_pin sidebar_unpin source subjectrx subscribe-to tag-formats tag-transforms
	\ unalternative_order unattachments unauto_view unbind uncolor unhdr_order unignore unmacro
	\ unmailboxes unmailto_allow unmime_lookup unmono unmy_hdr unscore unsetenv unsubjectrx
	\ unsubscribe-from unvirtual-mailboxes version virtual-mailboxes

" CHECKED 2024 Oct 12
" Deprecated commands
syntax keyword muttrcDeprecatedCommand skipwhite
	\ sidebar_whitelist unsidebar_whitelist

function! s:genFunctions(functions)
	for f in a:functions
		exec 'syntax match muttrcFunction contained "\<' . l:f . '\>"'
	endfor
endfunction

" CHECKED 2024 Oct 12
" List of functions in functions.c
" Note: 'noop' is included but is elsewhere in the source
call s:genFunctions(['noop',
	\ 'alias-dialog', 'attach-file', 'attach-key', 'attach-message', 'attach-news-message',
	\ 'autocrypt-acct-menu', 'autocrypt-menu', 'backspace', 'backward-char', 'backward-word',
	\ 'bol', 'bottom', 'bottom-page', 'bounce-message', 'break-thread', 'buffy-cycle',
	\ 'buffy-list', 'capitalize-word', 'catchup', 'change-dir', 'change-folder',
	\ 'change-folder-readonly', 'change-newsgroup', 'change-newsgroup-readonly',
	\ 'change-vfolder', 'check-new', 'check-stats', 'check-traditional-pgp', 'clear-flag',
	\ 'collapse-all', 'collapse-parts', 'collapse-thread', 'complete', 'complete-query',
	\ 'compose-to-sender', 'copy-file', 'copy-message', 'create-account', 'create-alias',
	\ 'create-mailbox', 'current-bottom', 'current-middle', 'current-top', 'decode-copy',
	\ 'decode-save', 'decrypt-copy', 'decrypt-save', 'delete-account', 'delete-char',
	\ 'delete-entry', 'delete-mailbox', 'delete-message', 'delete-pattern', 'delete-subthread',
	\ 'delete-thread', 'descend-directory', 'detach-file', 'display-address',
	\ 'display-filename', 'display-message', 'display-toggle-weed', 'downcase-word', 'edit',
	\ 'edit-bcc', 'edit-cc', 'edit-content-id', 'edit-description', 'edit-encoding', 'edit-fcc',
	\ 'edit-file', 'edit-followup-to', 'edit-from', 'edit-headers', 'edit-label',
	\ 'edit-language', 'edit-message', 'edit-mime', 'edit-newsgroups',
	\ 'edit-or-view-raw-message', 'edit-raw-message', 'edit-reply-to', 'edit-subject',
	\ 'edit-to', 'edit-type', 'edit-x-comment-to', 'end-cond', 'enter-command', 'enter-mask',
	\ 'entire-thread', 'eol', 'error-history', 'exit', 'extract-keys', 'fetch-mail',
	\ 'filter-entry', 'first-entry', 'flag-message', 'followup-message', 'forget-passphrase',
	\ 'forward-char', 'forward-message', 'forward-to-group', 'forward-word', 'get-attachment',
	\ 'get-children', 'get-message', 'get-parent', 'goto-folder', 'goto-parent',
	\ 'group-alternatives', 'group-chat-reply', 'group-multilingual', 'group-related',
	\ 'group-reply', 'half-down', 'half-up', 'help', 'history-down', 'history-search',
	\ 'history-up', 'imap-fetch-mail', 'imap-logout-all', 'ispell', 'jump', 'kill-eol',
	\ 'kill-eow', 'kill-line', 'kill-whole-line', 'kill-word', 'last-entry', 'limit',
	\ 'limit-current-thread', 'link-threads', 'list-reply', 'list-subscribe',
	\ 'list-unsubscribe', 'mail', 'mail-key', 'mailbox-cycle', 'mailbox-list', 'mark-as-new',
	\ 'mark-message', 'middle-page', 'modify-labels', 'modify-labels-then-hide', 'modify-tags',
	\ 'modify-tags-then-hide', 'move-down', 'move-up', 'new-mime', 'next-entry', 'next-line',
	\ 'next-new', 'next-new-then-unread', 'next-page', 'next-subthread', 'next-thread',
	\ 'next-undeleted', 'next-unread', 'next-unread-mailbox', 'parent-message', 'pgp-menu',
	\ 'pipe-entry', 'pipe-message', 'post-message', 'postpone-message', 'previous-entry',
	\ 'previous-line', 'previous-new', 'previous-new-then-unread', 'previous-page',
	\ 'previous-subthread', 'previous-thread', 'previous-undeleted', 'previous-unread',
	\ 'print-entry', 'print-message', 'purge-message', 'purge-thread', 'quasi-delete', 'query',
	\ 'query-append', 'quit', 'quote-char', 'read-subthread', 'read-thread', 'recall-message',
	\ 'reconstruct-thread', 'redraw-screen', 'refresh', 'reload-active', 'rename-attachment',
	\ 'rename-file', 'rename-mailbox', 'reply', 'resend-message', 'root-message', 'save-entry',
	\ 'save-message', 'search', 'search-next', 'search-opposite', 'search-reverse',
	\ 'search-toggle', 'select-entry', 'select-new', 'send-message', 'set-flag', 'shell-escape',
	\ 'show-limit', 'show-log-messages', 'show-version', 'sidebar-first', 'sidebar-last',
	\ 'sidebar-next', 'sidebar-next-new', 'sidebar-open', 'sidebar-page-down',
	\ 'sidebar-page-up', 'sidebar-prev', 'sidebar-prev-new', 'sidebar-toggle-virtual',
	\ 'sidebar-toggle-visible', 'skip-headers', 'skip-quoted', 'smime-menu', 'sort',
	\ 'sort-alias', 'sort-alias-reverse', 'sort-mailbox', 'sort-reverse', 'subscribe',
	\ 'subscribe-pattern', 'sync-mailbox', 'tag-entry', 'tag-message', 'tag-pattern',
	\ 'tag-prefix', 'tag-prefix-cond', 'tag-subthread', 'tag-thread', 'toggle-active',
	\ 'toggle-disposition', 'toggle-mailboxes', 'toggle-new', 'toggle-prefer-encrypt',
	\ 'toggle-quoted', 'toggle-read', 'toggle-recode', 'toggle-subscribed', 'toggle-unlink',
	\ 'toggle-write', 'top', 'top-page', 'transpose-chars', 'uncatchup', 'undelete-entry',
	\ 'undelete-message', 'undelete-pattern', 'undelete-subthread', 'undelete-thread',
	\ 'ungroup-attachment', 'unsubscribe', 'unsubscribe-pattern', 'untag-pattern',
	\ 'upcase-word', 'update-encoding', 'verify-key', 'vfolder-from-query',
	\ 'vfolder-from-query-readonly', 'vfolder-window-backward', 'vfolder-window-forward',
	\ 'vfolder-window-reset', 'view-attach', 'view-attachments', 'view-file', 'view-mailcap',
	\ 'view-name', 'view-pager', 'view-raw-message', 'view-text', 'what-key', 'write-fcc'
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
highlight def link muttrcColorContext			Error
highlight def link muttrcColorFG			Error
highlight def link muttrcColorLine			Error
highlight def link muttrcDeprecatedCommand		Error
highlight def link muttrcFormatErrors			Error
highlight def link muttrcGroupLine			Error
highlight def link muttrcPattern			Error
highlight def link muttrcUnColorLine			Error
highlight def link muttrcVarDeprecatedBool		Error
highlight def link muttrcVarDeprecatedNum		Error
highlight def link muttrcVarDeprecatedQuad		Error
highlight def link muttrcVarDeprecatedString		Error

highlight def link muttrcAliasEncEmail			Identifier
highlight def link muttrcAliasKey			Identifier
highlight def link muttrcColorCompose			Identifier
highlight def link muttrcColorComposeField		Identifier
highlight def link muttrcColorField			Identifier
highlight def link muttrcMenu				Identifier
highlight def link muttrcSimplePat			Identifier
highlight def link muttrcUnAliasKey			Identifier
highlight def link muttrcUnColorIndex			Identifier
highlight def link muttrcVarBool			Identifier
highlight def link muttrcVarNum				Identifier
highlight def link muttrcVarQuad			Identifier
highlight def link muttrcVarString			Identifier

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
highlight def link muttrcAutocryptFormatEscapes		muttrcEscape
highlight def link muttrcComposeFormatEscapes		muttrcEscape
highlight def link muttrcFolderFormatEscapes		muttrcEscape
highlight def link muttrcGreetingFormatEscapes		muttrcEscape
highlight def link muttrcGroupIndexFormatEscapes	muttrcEscape
highlight def link muttrcHistoryFormatEscapes		muttrcEscape
highlight def link muttrcIndexFormatEscapes		muttrcEscape
highlight def link muttrcPatternFormatEscapes		muttrcEscape
highlight def link muttrcPgpCommandFormatEscapes	muttrcEscape
highlight def link muttrcPgpEntryFormatEscapes		muttrcEscape
highlight def link muttrcPgpTimeEscapes			muttrcEscape
highlight def link muttrcQueryFormatEscapes		muttrcEscape
highlight def link muttrcShellString			muttrcEscape
highlight def link muttrcSidebarFormatEscapes		muttrcEscape
highlight def link muttrcSmimeCommandFormatEscapes	muttrcEscape
highlight def link muttrcStatusFormatEscapes		muttrcEscape
highlight def link muttrcTimeEscapes			muttrcEscape

highlight def link muttrcAliasFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcAttachFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcAutocryptFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcComposeFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcFolderFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcGreetingFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcGroupIndexFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcHistoryFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcIndexFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcPatternFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcPgpCommandFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcPgpEntryFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcQueryFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcSidebarFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcSmimeCommandFormatConditionals	 muttrcFormatConditionals2
highlight def link muttrcStatusFormatConditionals	 muttrcFormatConditionals2

highlight def link muttrcAddrDef			muttrcGroupFlag
highlight def link muttrcRXDef				muttrcGroupFlag

highlight def link muttrcAliasFormatString		muttrcString
highlight def link muttrcAttachFormatString		muttrcString
highlight def link muttrcAutocryptFormatString		muttrcString
highlight def link muttrcComposeFormatString		muttrcString
highlight def link muttrcFolderFormatString		muttrcString
highlight def link muttrcGreetingFormatString		muttrcString
highlight def link muttrcGroupIndexFormatString		muttrcString
highlight def link muttrcHistoryFormatString		muttrcString
highlight def link muttrcIndexFormatString		muttrcString
highlight def link muttrcPatternFormatString		muttrcString
highlight def link muttrcPgpCommandFormatString		muttrcString
highlight def link muttrcPgpEntryFormatString		muttrcString
highlight def link muttrcQueryFormatString		muttrcString
highlight def link muttrcSidebarFormatString		muttrcString
highlight def link muttrcSmimeCommandFormatString	muttrcString
highlight def link muttrcStatusFormatString		muttrcString
highlight def link muttrcStrftimeFormatString		muttrcString

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
