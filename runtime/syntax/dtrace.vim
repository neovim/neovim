" DTrace D script syntax file. To avoid confusion with the D programming
" language, I call this script dtrace.vim instead of d.vim.
" Language: D script as described in "Solaris Dynamic Tracing Guide",
"           http://docs.sun.com/app/docs/doc/817-6223
" Version: 1.5
" Last Change: 2008/04/05
" Maintainer: Nicolas Weber <nicolasweber@gmx.de>

" dtrace lexer and parser are at
" http://src.opensolaris.org/source/xref/onnv/onnv-gate/usr/src/lib/libdtrace/common/dt_lex.l
" http://src.opensolaris.org/source/xref/onnv/onnv-gate/usr/src/lib/libdtrace/common/dt_grammar.y

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the C syntax to start with
runtime! syntax/c.vim
unlet b:current_syntax

syn clear cCommentL  " dtrace doesn't support // style comments

" First line may start with #!, also make sure a '-s' flag is somewhere in
" that line.
syn match dtraceComment "\%^#!.*-s.*"

" Probe descriptors need explicit matches, so that keywords in probe
" descriptors don't show up as errors. Note that this regex detects probes
" as "something with three ':' in it". This works in practice, but it's not
" really correct. Also add special case code for BEGIN, END and ERROR, since
" they are common.
" Be careful not to detect '/*some:::node*/\n/**/' as probe, as it's
" commented out.
" XXX: This allows a probe description to end with ',', even if it's not
" followed by another probe.
" XXX: This doesn't work if followed by a comment.
let s:oneProbe = '\%(BEGIN\|END\|ERROR\|\S\{-}:\S\{-}:\S\{-}:\S\{-}\)\_s*'
exec 'syn match dtraceProbe "'.s:oneProbe.'\%(,\_s*'.s:oneProbe.'\)*\ze\_s\%({\|\/[^*]\|\%$\)"'

" Note: We have to be careful to not make this match /* */ comments.
" Also be careful not to eat `c = a / b; b = a / 2;`. We use the same
" technique as the dtrace lexer: a predicate has to be followed by {, ;, or
" EOF. Also note that dtrace doesn't allow an empty predicate // (we do).
" This regex doesn't allow a division operator in the predicate.
" Make sure that this matches the empty predicate as well.
" XXX: This doesn't work if followed by a comment.
syn match dtracePredicate "/\*\@!\_[^/]*/\ze\_s*\%({\|;\|\%$\)"
  "contains=ALLBUT,dtraceOption  " this lets the region contain too much stuff

" Pragmas.
" dtrace seems not to support whitespace before or after the '='.  dtrace
" supports only one option per #pragma, and no continuations of #pragma over
" several lines with '\'.
" Note that dtrace treats units (Hz etc) as case-insenstive, we allow only
" sane unit capitalization in this script (ie 'ns', 'us', 'ms', 's' have to be
" small, Hertz can be 'Hz' or 'hz')
" XXX: "cpu" is always highlighted as builtin var, not as option

"   auto or manual: bufresize
syn match dtraceOption contained "bufresize=\%(auto\|manual\)\s*$"

"   scalar: cpu jstackframes jstackstrsize nspec stackframes stackindent ustackframes
syn match dtraceOption contained "\%(cpu\|jstackframes\|jstackstrsize\|nspec\|stackframes\|stackindent\|ustackframes\)=\d\+\s*$"

"   size: aggsize bufsize dynvarsize specsize strsize 
"   size defaults to something if no unit is given (ie., having no unit is ok)
syn match dtraceOption contained "\%(aggsize\|bufsize\|dynvarsize\|specsize\|strsize\)=\d\+\%(k\|m\|g\|t\|K\|M\|G\|T\)\=\s*$"

"   time: aggrate cleanrate statusrate switchrate
"   time defaults to hz if no unit is given
syn match dtraceOption contained "\%(aggrate\|cleanrate\|statusrate\|switchrate\)=\d\+\%(hz\|Hz\|ns\|us\|ms\|s\)\=\s*$"

"   No type: defaultargs destructive flowindent grabanon quiet rawbytes
syn match dtraceOption contained "\%(defaultargs\|destructive\|flowindent\|grabanon\|quiet\|rawbytes\)\s*$"


" Turn reserved but unspecified keywords into errors
syn keyword dtraceReservedKeyword auto break case continue counter default do
syn keyword dtraceReservedKeyword else for goto if import probe provider
syn keyword dtraceReservedKeyword register restrict return static switch while

" Add dtrace-specific stuff
syn keyword dtraceOperator   sizeof offsetof stringof xlate
syn keyword dtraceStatement  self inline xlate this translator

" Builtin variables
syn keyword dtraceIdentifier arg0 arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8 arg9 
syn keyword dtraceIdentifier args caller chip cpu curcpu curlwpsinfo curpsinfo
syn keyword dtraceIdentifier curthread cwd epid errno execname gid id ipl lgrp
syn keyword dtraceIdentifier pid ppid probefunc probemod probename probeprov
syn keyword dtraceIdentifier pset root stackdepth tid timestamp uid uregs
syn keyword dtraceIdentifier vtimestamp walltimestamp
syn keyword dtraceIdentifier ustackdepth

" Macro Variables
syn match dtraceConstant     "$[0-9]\+"
syn match dtraceConstant     "$\(egid\|euid\|gid\|pgid\|ppid\)"
syn match dtraceConstant     "$\(projid\|sid\|target\|taskid\|uid\)"

" Data Recording Actions
syn keyword dtraceFunction   trace tracemem printf printa stack ustack jstack

" Process Destructive Actions
syn keyword dtraceFunction   stop raise copyout copyoutstr system

" Kernel Destructive Actions
syn keyword dtraceFunction   breakpoint panic chill

" Special Actions
syn keyword dtraceFunction   speculate commit discard exit

" Subroutines
syn keyword dtraceFunction   alloca basename bcopy cleanpath copyin copyinstr
syn keyword dtraceFunction   copyinto dirname msgdsize msgsize mutex_owned
syn keyword dtraceFunction   mutex_owner mutex_type_adaptive progenyof
syn keyword dtraceFunction   rand rw_iswriter rw_write_held speculation
syn keyword dtraceFunction   strjoin strlen

" Aggregating Functions
syn keyword dtraceAggregatingFunction count sum avg min max lquantize quantize

syn keyword dtraceType int8_t int16_t int32_t int64_t intptr_t
syn keyword dtraceType uint8_t uint16_t uint32_t uint64_t uintptr_t
syn keyword dtraceType string
syn keyword dtraceType pid_t id_t


" Define the default highlighting.
" We use `hi def link` directly, this requires 5.8.
hi def link dtraceReservedKeyword Error
hi def link dtracePredicate String
hi def link dtraceProbe dtraceStatement
hi def link dtraceStatement Statement
hi def link dtraceConstant Constant
hi def link dtraceIdentifier Identifier
hi def link dtraceAggregatingFunction dtraceFunction
hi def link dtraceFunction Function
hi def link dtraceType Type
hi def link dtraceOperator Operator
hi def link dtraceComment Comment
hi def link dtraceNumber Number
hi def link dtraceOption Identifier

let b:current_syntax = "dtrace"
