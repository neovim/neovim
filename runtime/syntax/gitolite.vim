" Vim syntax file
" Language:	gitolite configuration
" URL:		https://github.com/tmatilai/gitolite.vim
" Maintainer:	Teemu Matilainen <teemu.matilainen@iki.fi>
" Last Change:	2011-12-25

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Comment
syn match	gitoliteComment		"\(^\|\s\)#.*" contains=gitoliteTodo
syn keyword	gitoliteTodo		TODO FIXME XXX NOT contained

" Groups, users and repos
syn match	gitoliteGroupDef	"\(^\s*\)\@<=@[^=]\{-1,}\(\s*=\)\@=" contains=gitoliteSpaceError,gitoliteUserError nextgroup=gitoliteGroupDefSep
syn match	gitoliteGroupDefSep	"\s*=" contained nextgroup=gitoliteRepoLine
syn match	gitoliteRepoDef		"^\s*repo\s" nextgroup=gitoliteRepoLine

syn match	gitoliteRepoLine	".*" contained transparent contains=gitoliteGroup,gitoliteWildRepo,gitoliteCreator,gitoliteExtCmdHelper,gitoliteRepoError,gitoliteComment
syn match	gitoliteUserLine	".*" contained transparent contains=gitoliteGroup,gitolitePreProc,gitoliteUserError,gitoliteComment

syn match	gitoliteWildRepo	"[ \t=]\@<=[^ \t]*[\\^$|()[\]*?{},][^ \t]*" contained contains=gitoliteCreator,gitoliteRepoError
syn match	gitoliteGroup		"[ \t=]\@<=@[^ \t]\+" contained contains=gitoliteUserError

syn keyword	gitoliteCreator		CREATER CREATOR contained
syn keyword	gitolitePreProc		CREATER CREATOR READERS WRITERS contained

syn match	gitoliteExtCmdHelper	"[ \t=]\@<=EXTCMD/" contained nextgroup=gitoliteExtCmd
syn match	gitoliteExtCmd		"rsync\(\s\|$\)" contained

" Illegal characters
syn match	gitoliteRepoError	"[^ \t0-9a-zA-Z._@+/\\^$|()[\]*?{},-]\+" contained
syn match	gitoliteUserError	"[^ \t0-9a-zA-Z._@+-]\+" contained
syn match	gitoliteSpaceError	"\s\+" contained

" Permission
syn match	gitoliteKeyword		"^\s*\(C\|R\|RW\|RW+\|RWC\|RW+C\|RWD\|RW+D\|RWCD\|RW+CD\)[ \t=]\@=" nextgroup=gitoliteRefex
syn match	gitoliteKeyword		"^\s*-[ \t=]\@=" nextgroup=gitoliteDenyRefex
syn match	gitoliteRefex		"[^=]*="he=e-1 contained contains=gitoliteSpecialRefex,gitoliteGroup nextgroup=gitoliteUserLine
syn match	gitoliteDenyRefex	"[^=]*="he=e-1 contained contains=gitoliteSpecialRefex,gitoliteGroup nextgroup=gitoliteDenyUsers
syn match	gitoliteSpecialRefex	"\sNAME/"he=e-1 contained
syn match	gitoliteSpecialRefex	"/USER/"hs=s+1,he=e-1 contained
syn match	gitoliteDenyUsers	".*" contained contains=gitoliteUserError,gitoliteComment

" Configuration
syn match	gitoliteKeyword		"^\s*config\s\+" nextgroup=gitoliteConfVariable
syn match	gitoliteConfVariable	"[^=]*" contained

" Include
syn match	gitoliteInclude		"^\s*\(include\|subconf\)\s"

" String
syn region	gitoliteString		start=+"+ end=+"+ oneline

" Define the default highlighting
hi def link gitoliteComment		Comment
hi def link gitoliteTodo		Todo
hi def link gitoliteGroupDef		gitoliteGroup
hi def link gitoliteGroup		Identifier
hi def link gitoliteWildRepo		Special
hi def link gitoliteRepoError		gitoliteError
hi def link gitoliteUserError		gitoliteError
hi def link gitoliteSpaceError		gitoliteError
hi def link gitoliteError		Error
hi def link gitoliteCreator		gitolitePreProc
hi def link gitolitePreProc		PreProc
hi def link gitoliteExtCmdHelper	PreProc
hi def link gitoliteExtCmd		Special
hi def link gitoliteRepoDef		Type
hi def link gitoliteKeyword		Keyword
hi def link gitoliteRefex		String
hi def link gitoliteDenyRefex		gitoliteRefex
hi def link gitoliteSpecialRefex	PreProc
hi def link gitoliteDenyUsers		WarningMsg
hi def link gitoliteConfVariable	Identifier
hi def link gitoliteInclude		Include
hi def link gitoliteString		String

let b:current_syntax = "gitolite"

let &cpo = s:cpo_save
unlet s:cpo_save
