" Vim syntax file
" Language:		bpftrace
" Maintainer:		Stanislaw Gruszka <stf_xl@wp.pl>
" Last Change:		2025 Dec 22

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword	bpftraceConditional	if else
syn keyword	bpftraceRepeat		while for unroll
syn keyword	bpftraceStatement	break continue return
syn keyword	bpftraceKeyword		let macro import config
syn keyword	bpftraceOperator	sizeof offsetof

syn keyword	bpftraceProbe		BEGIN END begin end
syn match	bpftraceProbe		"\v<(bench|self|test)\ze:"
syn match	bpftraceProbe		"\v<(fentry|fexit|kfunc|kretfunc|kprobe|kretprobe)\ze:"
syn match	bpftraceProbe		"\v<(profile|interval|iterator|hardware|software|uprobe|uretprobe)\ze:"
syn match	bpftraceProbe		"\v<(usdt|tracepoint|rawtracepoint|watchpoint|asyncwatchpoint)\ze:"
syn match	bpftraceProbe		"\v(^|[^:])<\zs(h|i|it|f|fr|k|kr|p|rt|s|t|u|ur|U|w|aw)\ze:"

syn keyword	bpftraceType		bool int8 int16 int32 int64
syn keyword	bpftraceType		uint8 uint16 uint32 uint64
syn keyword	bpftraceType		struct

syn match	bpftraceMacro		"\<\h\w*\ze\_s*("

syn match	bpftraceNumber		display	"[+-]\=\<\d\+\>"
syn match	bpftraceNumber		display	"\<0x\x\+\>"

syn keyword	bpftraceBoolean		true false

syn region	bpftraceString		start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell extend

syn keyword	bpftraceTodo		contained TODO FIXME XXX
syn match	bpftraceShebang		/\%^#![^[].*/
syn region	bpftraceCommentLine	start="//" end="$" contains=bpftraceTodo,@Spell
syn region	bpftraceCommentBlock	matchgroup=bpftraceCommentBlock start="/\*" end="\*/" contains=bpftraceTodo,@Spell

" Define the default highlighting.
hi def link	bpftraceConditional	Conditional
hi def link	bpftraceMacro		Macro
hi def link	bpftraceRepeat		Repeat
hi def link	bpftraceKeyword		Keyword
hi def link	bpftraceNumber		Number
hi def link	bpftraceBoolean		Boolean
hi def link	bpftraceShebang		Comment
hi def link	bpftraceCommentLine	Comment
hi def link	bpftraceCommentBlock	Comment
hi def link	bpftraceString		String
hi def link	bpftraceType		Type
hi def link	bpftraceProbe		Identifier

syn sync minlines=100

let b:current_syntax = "bpftrace"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=8 noexpandtab
