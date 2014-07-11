" Vim syntax file
" Language:	initng .i files
" Maintainer:	Elan Ruusamäe <glen@pld-linux.org>
" URL:		http://glen.alkohol.ee/pld/initng/
" License:	GPL v2
" Version:	0.13
" Last Change:	$Date: 2007/05/05 17:17:40 $
"
" Syntax highlighting for initng .i files. Inherits from sh.vim and adds
" in the hiliting to start/stop {} blocks. Requires vim 6.3 or later.

if &compatible || v:version < 603
	finish
endif

if exists("b:current_syntax")
	finish
endif

syn case match

let is_bash = 1
unlet! b:current_syntax
syn include @shTop syntax/sh.vim

syn region	initngService			matchgroup=initngServiceHeader start="^\s*\(service\|virtual\|daemon\|class\|cron\)\s\+\(\(\w\|[-/*]\)\+\(\s\+:\s\+\(\w\|[-/*]\)\+\)\?\)\s\+{" end="}" contains=@initngServiceCluster
syn cluster initngServiceCluster	contains=initngComment,initngAction,initngServiceOption,initngServiceHeader,initngDelim,initngVariable

syn region	initngAction			matchgroup=initngActionHeader start="^\s*\(script start\|script stop\|script run\)\s*=\s*{" end="}" contains=@initngActionCluster
syn cluster initngActionCluster		contains=@shTop

syn match	initngDelim				/[{}]/	contained

syn region	initngString			start=/"/ end=/"/ skip=/\\"/

" option = value
syn match	initngServiceOption		/.\+\s*=.\+;/ contains=initngServiceKeywords,initngSubstMacro contained
" option without value
syn match	initngServiceOption		/\w\+;/ contains=initngServiceKeywords,initngSubstMacro contained

" options with value
syn keyword	initngServiceKeywords	also_stop need use nice setuid contained
syn keyword	initngServiceKeywords	delay chdir suid sgid start_pause env_file env_parse pid_file pidfile contained
syn keyword	initngServiceKeywords	pid_of up_when_pid_set stdout stderr syncron just_before contained
syn keyword	initngServiceKeywords	provide lockfile daemon_stops_badly contained
syn match	initngServiceKeywords	/\(script\|exec\(_args\)\?\) \(start\|stop\|daemon\)/ contained
syn match	initngServiceKeywords	/env\s\+\w\+/ contained

" rlimits
syn keyword	initngServiceKeywords	rlimit_cpu_hard rlimit_core_soft contained

" single options
syn keyword	initngServiceKeywords	last respawn network_provider require_network require_file critical forks contained
" cron options
syn keyword	initngServiceKeywords	hourly contained
syn match	initngVariable			/\${\?\w\+\}\?/

" Substituted @foo@ macros:
" ==========
syn match	initngSubstMacro		/@[^@]\+@/	contained
syn cluster initngActionCluster		add=initngSubstMacro
syn cluster shCommandSubList		add=initngSubstMacro

" Comments:
" ==========
syn cluster	initngCommentGroup		contains=initngTodo,@Spell
syn keyword	initngTodo				TODO FIXME XXX contained
syn match	initngComment			/#.*$/ contains=@initngCommentGroup

" install_service #macros
" TODO: syntax check for ifd-endd pairs
" ==========
syn region	initngDefine			start="^#\(endd\|elsed\|exec\|ifd\|endexec\|endd\)\>" skip="\\$" end="$" end="#"me=s-1
syn cluster shCommentGroup			add=initngDefine
syn cluster initngCommentGroup		add=initngDefine

hi def link	initngComment			Comment
hi def link initngTodo				Todo

hi def link	initngString			String
hi def link initngServiceKeywords	Define

hi def link	initngServiceHeader		Keyword
hi def link	initngActionHeader		Type
hi def link initngDelim				Delimiter

hi def link	initngVariable			PreProc
hi def link	initngSubstMacro		Comment
hi def link	initngDefine			Macro

let b:current_syntax = "initng"
