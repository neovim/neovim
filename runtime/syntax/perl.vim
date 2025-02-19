" Vim syntax file
" Language:      Perl
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2022 Jun 13
" Contributors:  Andy Lester <andy@petdance.com>
"                Hinrik Örn Sigurðsson <hinrik.sig@gmail.com>
"                Lukas Mai <l.mai.web.de>
"                Nick Hibma <nick@van-laarhoven.org>
"                Sonia Heimann <niania@netsurf.org>
"                Rob Hoelz <rob@hoelz.ro>
"                Doug Kearns <dougkearns@gmail.com>
"                and many others.
"
" Please download the most recent version first, before mailing
" any comments.
"
" The following parameters are available for tuning the
" perl syntax highlighting, with defaults given:
"
" let perl_include_pod = 1
" unlet perl_no_scope_in_variables
" unlet perl_no_extended_vars
" unlet perl_string_as_statement
" unlet perl_no_sync_on_sub
" unlet perl_no_sync_on_global_var
" let perl_sync_dist = 100
" unlet perl_fold
" unlet perl_fold_blocks
" unlet perl_nofold_packages
" unlet perl_nofold_subs
" unlet perl_fold_anonymous_subs
" unlet perl_no_subprototype_error

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" POD starts with ^=<word> and ends with ^=cut

if get(g:, 'perl_include_pod', 1)
  " Include a while extra syntax file
  syn include @Pod syntax/pod.vim
  unlet b:current_syntax
  if get(g:, 'perl_fold', 1)
    syn region perlPOD start="^=[a-z]" end="^=cut" contains=@Pod,@Spell,perlTodo keepend fold extend
    syn region perlPOD start="^=cut" end="^=cut" contains=perlTodo keepend fold extend
  else
    syn region perlPOD start="^=[a-z]" end="^=cut" contains=@Pod,@Spell,perlTodo keepend
    syn region perlPOD start="^=cut" end="^=cut" contains=perlTodo keepend
  endif
else
  " Use only the bare minimum of rules
  if get(g:, 'perl_fold', 1)
    syn region perlPOD start="^=[a-z]" end="^=cut" fold
  else
    syn region perlPOD start="^=[a-z]" end="^=cut"
  endif
endif


syn cluster perlTop		contains=TOP

syn region perlBraces start="{" end="}" transparent extend

" All keywords
"
syn match perlConditional		"\<\%(if\|elsif\|unless\|given\|when\|default\)\>"
syn match perlConditional		"\<else\%(\%(\_s\*if\>\)\|\>\)" contains=perlElseIfError skipwhite skipnl skipempty
syn match perlRepeat			"\<\%(while\|for\%(each\)\=\|do\|until\|continue\)\>"
syn match perlOperator			"\<\%(defined\|undef\|eq\|ne\|[gl][et]\|cmp\|not\|and\|or\|xor\|not\|bless\|ref\|do\)\>"
" for some reason, adding this as the nextgroup for perlControl fixes BEGIN
" folding issues...
syn match perlFakeGroup 		"" contained
syn match perlControl			"\<\%(BEGIN\|CHECK\|INIT\|END\|UNITCHECK\)\>\_s*" nextgroup=perlFakeGroup

syn match perlStatementStorage		"\<\%(my\|our\|local\|state\)\>"
syn match perlStatementControl		"\<\%(return\|last\|next\|redo\|goto\|break\)\>"
syn match perlStatementScalar		"\<\%(chom\=p\|chr\|crypt\|r\=index\|lc\%(first\)\=\|length\|ord\|pack\|sprintf\|substr\|fc\|uc\%(first\)\=\)\>"
syn match perlStatementRegexp		"\<\%(pos\|quotemeta\|split\|study\)\>"
syn match perlStatementNumeric		"\<\%(abs\|atan2\|cos\|exp\|hex\|int\|log\|oct\|rand\|sin\|sqrt\|srand\)\>"
syn match perlStatementList		"\<\%(splice\|unshift\|shift\|push\|pop\|join\|reverse\|grep\|map\|sort\|unpack\)\>"
syn match perlStatementHash		"\<\%(delete\|each\|exists\|keys\|values\)\>"
syn match perlStatementIOfunc		"\<\%(syscall\|dbmopen\|dbmclose\)\>"
syn match perlStatementFiledesc		"\<\%(binmode\|close\%(dir\)\=\|eof\|fileno\|getc\|lstat\|printf\=\|read\%(dir\|line\|pipe\)\|rewinddir\|say\|select\|stat\|tell\%(dir\)\=\|write\)\>" nextgroup=perlFiledescStatementNocomma skipwhite
syn match perlStatementFiledesc		"\<\%(fcntl\|flock\|ioctl\|open\%(dir\)\=\|read\|seek\%(dir\)\=\|sys\%(open\|read\|seek\|write\)\|truncate\)\>" nextgroup=perlFiledescStatementComma skipwhite
syn match perlStatementVector		"\<vec\>"
syn match perlStatementFiles		"\<\%(ch\%(dir\|mod\|own\|root\)\|glob\|link\|mkdir\|readlink\|rename\|rmdir\|symlink\|umask\|unlink\|utime\)\>"
syn match perlStatementFiles		"-[rwxoRWXOezsfdlpSbctugkTBMAC]\>"
syn match perlStatementFlow		"\<\%(caller\|die\|dump\|eval\|exit\|wantarray\|evalbytes\)\>"
syn match perlStatementInclude		"\<\%(require\|import\|unimport\)\>"
syn match perlStatementInclude		"\<\%(use\|no\)\s\+\%(\%(attributes\|attrs\|autodie\%(::\%(exception\%(::system\)\=\|hints\|skip\)\)\=\|autouse\|parent\|base\|big\%(int\|num\|rat\)\|blib\|bytes\|charnames\|constant\|deprecate\|diagnostics\|encoding\%(::warnings\)\=\|experimental\|feature\|fields\|filetest\|if\|integer\|less\|lib\|locale\|mro\|ok\|open\|ops\|overload\|overloading\|re\|sigtrap\|sort\|strict\|subs\|threads\%(::shared\)\=\|utf8\|vars\|version\|vmsish\|warnings\%(::register\)\=\)\>\)\="
syn match perlStatementProc		"\<\%(alarm\|exec\|fork\|get\%(pgrp\|ppid\|priority\)\|kill\|pipe\|set\%(pgrp\|priority\)\|sleep\|system\|times\|wait\%(pid\)\=\)\>"
syn match perlStatementSocket		"\<\%(accept\|bind\|connect\|get\%(peername\|sock\%(name\|opt\)\)\|listen\|recv\|send\|setsockopt\|shutdown\|socket\%(pair\)\=\)\>"
syn match perlStatementIPC		"\<\%(msg\%(ctl\|get\|rcv\|snd\)\|sem\%(ctl\|get\|op\)\|shm\%(ctl\|get\|read\|write\)\)\>"
syn match perlStatementNetwork		"\<\%(\%(end\|[gs]et\)\%(host\|net\|proto\|serv\)ent\|get\%(\%(host\|net\)by\%(addr\|name\)\|protoby\%(name\|number\)\|servby\%(name\|port\)\)\)\>"
syn match perlStatementPword		"\<\%(get\%(pw\%(uid\|nam\)\|gr\%(gid\|nam\)\|login\)\)\|\%(end\|[gs]et\)\%(pw\|gr\)ent\>"
syn match perlStatementTime		"\<\%(gmtime\|localtime\|time\)\>"

syn match perlStatementMisc		"\<\%(warn\|format\|formline\|reset\|scalar\|prototype\|lock\|tied\=\|untie\)\>"

syn keyword perlTodo			TODO TODO: TBD TBD: FIXME FIXME: XXX XXX: NOTE NOTE: contained

syn region perlStatementIndirObjWrap   matchgroup=perlStatementIndirObj start="\%(\<\%(map\|grep\|sort\|printf\=\|say\|system\|exec\)\>\s*\)\@<={" end="}" transparent extend

syn match perlLabel      "^\s*\h\w*\s*::\@!\%(\<v\d\+\s*:\)\@<!"

" Perl Identifiers.
"
" Should be cleaned up to better handle identifiers in particular situations
" (in hash keys for example)
"
" Plain identifiers: $foo, @foo, $#foo, %foo, &foo and dereferences $$foo, @$foo, etc.
" We do not process complex things such as @{${"foo"}}. Too complicated, and
" too slow. And what is after the -> is *not* considered as part of the
" variable - there again, too complicated and too slow.

" Special variables first ($^A, ...) and ($|, $', ...)
syn match  perlVarPlain		 "$^[ACDEFHILMNOPRSTVWX]\="
syn match  perlVarPlain		 "$[\\\"\[\]'&`+*.,;=%~!?@#$<>(-]"
syn match  perlVarPlain		 "@[-+]"
syn match  perlVarPlain		 "$\%(0\|[1-9]\d*\)"
" Same as above, but avoids confusion in $::foo (equivalent to $main::foo)
syn match  perlVarPlain		 "$::\@!"
" These variables are not recognized within matches.
syn match  perlVarNotInMatches	 "$[|)]"
" This variable is not recognized within matches delimited by m//.
syn match  perlVarSlash		 "$/"

" And plain identifiers
syn match  perlPackageRef	 "[$@#%*&]\%(\%(::\|'\)\=\I\i*\%(\%(::\|'\)\I\i*\)*\)\=\%(::\|'\)\I"ms=s+1,me=e-1 contained

" To not highlight packages in variables as a scope reference - i.e. in
" $pack::var, pack:: is a scope, just set "perl_no_scope_in_variables"
" If you don't want complex things like @{${"foo"}} to be processed,
" just set the variable "perl_no_extended_vars"...

if !get(g:, 'perl_no_scope_in_variables', 0)
  syn match  perlVarPlain       "\%([@$]\|\$#\)\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" contains=perlPackageRef nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
  syn match  perlVarPlain2                   "%\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" contains=perlPackageRef nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
  syn match  perlFunctionName                "&\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" contains=perlPackageRef nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
else
  syn match  perlVarPlain       "\%([@$]\|\$#\)\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
  syn match  perlVarPlain2                   "%\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
  syn match  perlFunctionName                "&\$*\%(\I\i*\)\=\%(\%(::\|'\)\I\i*\)*\%(::\|\i\@<=\)" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref
endif

syn match  perlVarPlain2	 "%[-+]"

if !get(g:, 'perl_no_extended_vars', 0)
  syn cluster perlExpr		contains=perlStatementIndirObjWrap,perlStatementScalar,perlStatementRegexp,perlStatementNumeric,perlStatementList,perlStatementHash,perlStatementFiles,perlStatementTime,perlStatementMisc,perlVarPlain,perlVarPlain2,perlVarNotInMatches,perlVarSlash,perlVarBlock,perlVarBlock2,perlShellCommand,perlFloat,perlNumber,perlStringUnexpanded,perlString,perlQ,perlQQ,perlQW,perlQR,perlArrow,perlBraces
  syn region perlArrow		matchgroup=perlArrow start="->\s*(" end=")" contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref contained
  syn region perlArrow		matchgroup=perlArrow start="->\s*\[" end="\]" contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref contained
  syn region perlArrow		matchgroup=perlArrow start="->\s*{" end="}" contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref contained
  syn match  perlArrow		"->\s*{\s*\I\i*\s*}" contains=perlVarSimpleMemberName nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref contained
  syn region perlVarBlock	matchgroup=perlVarPlain start="\%($#\|[$@]\)\$*{" skip="\\}" end=+}\|\%(\%(<<\%('\|"\)\?\)\@=\)+ contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn region perlVarBlock2	matchgroup=perlVarPlain start="[%&*]\$*{" skip="\\}" end=+}\|\%(\%(<<\%('\|"\)\?\)\@=\)+ contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn match  perlVarPlain2	"[%&*]\$*{\I\i*}" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn match  perlVarPlain	"\%(\$#\|[@$]\)\$*{\I\i*}" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn region perlVarMember	matchgroup=perlVarPlain start="\%(->\)\={" skip="\\}" end="}" contained contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn match  perlVarSimpleMember	"\%(->\)\={\s*\I\i*\s*}" nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref contains=perlVarSimpleMemberName contained extend
  syn match  perlVarSimpleMemberName	"\I\i*" contained
  syn region perlVarMember	matchgroup=perlVarPlain start="\%(->\)\=\[" skip="\\]" end="]" contained contains=@perlExpr nextgroup=perlVarMember,perlVarSimpleMember,perlPostDeref extend
  syn match perlPackageConst	"__PACKAGE__" nextgroup=perlPostDeref
  syn match  perlPostDeref	"->\%($#\|[$@%&*]\)\*" contained nextgroup=perlVarSimpleMember,perlVarMember,perlPostDeref
  syn region  perlPostDeref	start="->\%($#\|[$@%&*]\)\[" skip="\\]" end="]" contained contains=@perlExpr nextgroup=perlVarSimpleMember,perlVarMember,perlPostDeref
  syn region  perlPostDeref	matchgroup=perlPostDeref start="->\%($#\|[$@%&*]\){" skip="\\}" end="}" keepend extend contained contains=@perlExpr nextgroup=perlVarSimpleMember,perlVarMember,perlPostDeref
endif

" File Descriptors
syn match  perlFiledescRead	"<\h\w*>"

syn match  perlFiledescStatementComma	"(\=\s*\<\u\w*\>\s*,"me=e-1 transparent contained contains=perlFiledescStatement
syn match  perlFiledescStatementNocomma "(\=\s*\<\u\w*\>\s*[^, \t]"me=e-1 transparent contained contains=perlFiledescStatement

syn match  perlFiledescStatement	"\<\u\w*\>" contained

" Special characters in strings and matches
syn match  perlSpecialString	"\\\%(\o\{1,3}\|x\%({\x\+}\|\x\{1,2}\)\|c.\|[^cx]\)" contained extend
syn match  perlSpecialStringU2	"\\." extend contained contains=NONE
syn match  perlSpecialStringU	"\\\\" contained
syn match  perlSpecialMatch	"\\[1-9]" contained extend
syn match  perlSpecialMatch	"\\g\%(\d\+\|{\%(-\=\d\+\|\h\w*\)}\)" contained
syn match  perlSpecialMatch	"\\k\%(<\h\w*>\|'\h\w*'\)" contained
syn match  perlSpecialMatch	"{\d\+\%(,\%(\d\+\)\=\)\=}" contained
syn match  perlSpecialMatch	"\[[]-]\=[^\[\]]*[]-]\=\]" contained extend
syn match  perlSpecialMatch	"[+*()?.]" contained
syn match  perlSpecialMatch	"(?[#:=!]" contained
syn match  perlSpecialMatch	"(?[impsx]*\%(-[imsx]\+\)\=)" contained
syn match  perlSpecialMatch	"(?\%([-+]\=\d\+\|R\))" contained
syn match  perlSpecialMatch	"(?\%(&\|P[>=]\)\h\w*)" contained
syn match  perlSpecialMatch	"(\*\%(\%(PRUNE\|SKIP\|THEN\)\%(:[^)]*\)\=\|\%(MARK\|\):[^)]*\|COMMIT\|F\%(AIL\)\=\|ACCEPT\))" contained

" Possible errors
"
" Highlight lines with only whitespace (only in blank delimited here documents) as errors
syn match  perlNotEmptyLine	"^\s\+$" contained
" Highlight "} else if (...) {", it should be "} else { if (...) { " or "} elsif (...) {"
syn match perlElseIfError	"else\_s*if" containedin=perlConditional
syn keyword perlElseIfError	elseif containedin=perlConditional

" Variable interpolation
"
" These items are interpolated inside "" strings and similar constructs.
syn cluster perlInterpDQ	contains=perlSpecialString,perlVarPlain,perlVarNotInMatches,perlVarSlash,perlVarBlock
" These items are interpolated inside '' strings and similar constructs.
syn cluster perlInterpSQ	contains=perlSpecialStringU,perlSpecialStringU2
" These items are interpolated inside m// matches and s/// substitutions.
syn cluster perlInterpSlash	contains=perlSpecialString,perlSpecialMatch,perlVarPlain,perlVarBlock
" These items are interpolated inside m## matches and s### substitutions.
syn cluster perlInterpMatch	contains=@perlInterpSlash,perlVarSlash

" Shell commands
syn region  perlShellCommand	matchgroup=perlMatchStartEnd start="`" end="`" contains=@perlInterpDQ keepend

" Constants
"
" Numbers
syn case   ignore
syn match  perlNumber	"\<\%(0\|[1-9]\%(_\=\d\)*\)\>"
syn match  perlNumber	"\<0\%(x\x\%(_\=\x\)*\|b[01]\%(_\=[01]\)*\|o\=\%(_\=\o\)*\)\>"
syn match  perlFloat	"\<\d\%(_\=\d\)*e[-+]\=\d\%(_\=\d\)*"
syn match  perlFloat	"\<\d\%(_\=\d\)*\.\%(\d\%(_\=\d\)*\)\=\%(e[-+]\=\d\%(_\=\d\)*\)\="
syn match  perlFloat    "\.\d\%(_\=\d\)*\%(e[-+]\=\d\%(_\=\d\)*\)\="
syn match  perlFloat	"\<0x\x\%(_\=\x\)*p[-+]\=\d\%(_\=\d\)*"
syn match  perlFloat	"\<0x\x\%(_\=\x\)*\.\%(\x\%(_\=\x\)*\)\=\%(p[-+]\=\d\%(_\=\d\)*\)\="
syn match  perlFloat    "\<0x\.\x\%(_\=\x\)*\%(p[-+]\=\d\%(_\=\d\)*\)\="
syn case   match

syn match  perlString	"\<\%(v\d\+\%(\.\d\+\)*\|\d\+\%(\.\d\+\)\{2,}\)\>" contains=perlVStringV
syn match  perlVStringV	"\<v" contained


syn region perlParensSQ		start=+(+ end=+)+ extend contained contains=perlParensSQ,@perlInterpSQ keepend
syn region perlBracketsSQ	start=+\[+ end=+\]+ extend contained contains=perlBracketsSQ,@perlInterpSQ keepend
syn region perlBracesSQ		start=+{+ end=+}+ extend contained contains=perlBracesSQ,@perlInterpSQ keepend
syn region perlAnglesSQ		start=+<+ end=+>+ extend contained contains=perlAnglesSQ,@perlInterpSQ keepend

syn region perlParensDQ		start=+(+ end=+)+ extend contained contains=perlParensDQ,@perlInterpDQ keepend
syn region perlBracketsDQ	start=+\[+ end=+\]+ extend contained contains=perlBracketsDQ,@perlInterpDQ keepend
syn region perlBracesDQ		start=+{+ end=+}+ extend contained contains=perlBracesDQ,@perlInterpDQ keepend
syn region perlAnglesDQ		start=+<+ end=+>+ extend contained contains=perlAnglesDQ,@perlInterpDQ keepend


" Simple version of searches and matches
syn match  perlMatchModifiers "[msixpadluncgo]\+" contained
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\>\s*\z([^[:space:]'([{<#]\)+ end=+\z1+ contains=@perlInterpMatch keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m#+ end=+#+ contains=@perlInterpMatch keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*'+ end=+'+ contains=@perlInterpSQ keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*/+ end=+/+ contains=@perlInterpSlash keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*(+ end=+)+ contains=@perlInterpMatch,perlParensDQ keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*{+ end=+}+ contains=@perlInterpMatch,perlBracesDQ extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*<+ end=+>+ contains=@perlInterpMatch,perlAnglesDQ keepend extend nextgroup=perlMatchModifiers
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!m\s*\[+ end=+\]+ contains=@perlInterpMatch,perlBracketsDQ keepend extend nextgroup=perlMatchModifiers

" Below some hacks to recognise the // variant. This is virtually impossible to catch in all
" cases as the / is used in so many other ways, but these should be the most obvious ones.
syn region perlMatch	matchgroup=perlMatchStartEnd start="\%([$@%&*]\@<!\%(\<split\|\<while\|\<if\|\<unless\|\.\.\|[-+*!~(\[{=]\)\s*\)\@<=/\%(/=\)\@!" start=+^/\%(/=\)\@!+ start=+\s\@<=/\%(/=\)\@![^[:space:][:digit:]$@%=]\@=\%(/\_s*\%([([{$@%&*[:digit:]"'`]\|\_s\w\|[[:upper:]_abd-fhjklnqrt-wyz]\)\)\@!+ skip=+\\/+ end=+/+ contains=@perlInterpSlash extend nextgroup=perlMatchModifiers


" Substitutions
" perlMatch is the first part, perlSubstitution* is the substitution part
syn match  perlSubstitutionModifiers "[msixpadluncgero]\+" contained
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\>\s*\z([^[:space:]'([{<#]\)+ end=+\z1+me=e-1 contains=@perlInterpMatch nextgroup=perlSubstitutionGQQ keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*'+  end=+'+me=e-1 contains=@perlInterpSQ nextgroup=perlSubstitutionSQ keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*/+  end=+/+me=e-1 contains=@perlInterpSlash nextgroup=perlSubstitutionGQQ keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s#+  end=+#+me=e-1 contains=@perlInterpMatch nextgroup=perlSubstitutionGQQ keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*(+ end=+)+ contains=@perlInterpMatch,perlParensDQ nextgroup=perlSubstitutionGQQ skipwhite skipempty skipnl keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*<+ end=+>+ contains=@perlInterpMatch,perlAnglesDQ nextgroup=perlSubstitutionGQQ skipwhite skipempty skipnl keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*\[+ end=+\]+ contains=@perlInterpMatch,perlBracketsDQ nextgroup=perlSubstitutionGQQ skipwhite skipempty skipnl keepend extend
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!s\s*{+ end=+}+ contains=@perlInterpMatch,perlBracesDQ nextgroup=perlSubstitutionGQQ skipwhite skipempty skipnl keepend extend
syn region perlSubstitutionGQQ		matchgroup=perlMatchStartEnd start=+\z([^[:space:]'([{<]\)+ end=+\z1+ keepend contained contains=@perlInterpDQ extend nextgroup=perlSubstitutionModifiers
syn region perlSubstitutionGQQ		matchgroup=perlMatchStartEnd start=+(+ end=+)+ contained contains=@perlInterpDQ,perlParensDQ keepend extend nextgroup=perlSubstitutionModifiers
syn region perlSubstitutionGQQ		matchgroup=perlMatchStartEnd start=+\[+ end=+\]+ contained contains=@perlInterpDQ,perlBracketsDQ keepend extend nextgroup=perlSubstitutionModifiers
syn region perlSubstitutionGQQ		matchgroup=perlMatchStartEnd start=+{+ end=+}+ contained contains=@perlInterpDQ,perlBracesDQ keepend extend extend nextgroup=perlSubstitutionModifiers
syn region perlSubstitutionGQQ		matchgroup=perlMatchStartEnd start=+<+ end=+>+ contained contains=@perlInterpDQ,perlAnglesDQ keepend extend nextgroup=perlSubstitutionModifiers
syn region perlSubstitutionSQ		matchgroup=perlMatchStartEnd start=+'+  end=+'+ contained contains=@perlInterpSQ keepend extend nextgroup=perlSubstitutionModifiers

" Translations
" perlMatch is the first part, perlTranslation* is the second, translator part.
syn match  perlTranslationModifiers "[cdsr]\+" contained
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)\>\s*\z([^[:space:]([{<#]\)+ end=+\z1+me=e-1 contains=@perlInterpSQ nextgroup=perlTranslationGQ
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)#+ end=+#+me=e-1 contains=@perlInterpSQ nextgroup=perlTranslationGQ
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)\s*\[+ end=+\]+ contains=@perlInterpSQ,perlBracketsSQ nextgroup=perlTranslationGQ skipwhite skipempty skipnl
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)\s*(+ end=+)+ contains=@perlInterpSQ,perlParensSQ nextgroup=perlTranslationGQ skipwhite skipempty skipnl
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)\s*<+ end=+>+ contains=@perlInterpSQ,perlAnglesSQ nextgroup=perlTranslationGQ skipwhite skipempty skipnl
syn region perlMatch	matchgroup=perlMatchStartEnd start=+\<\%(::\|'\|->\)\@<!\%(tr\|y\)\s*{+ end=+}+ contains=@perlInterpSQ,perlBracesSQ nextgroup=perlTranslationGQ skipwhite skipempty skipnl
syn region perlTranslationGQ		matchgroup=perlMatchStartEnd start=+\z([^[:space:]([{<]\)+ end=+\z1+ contained nextgroup=perlTranslationModifiers
syn region perlTranslationGQ		matchgroup=perlMatchStartEnd start=+(+ end=+)+ contains=perlParensSQ contained nextgroup=perlTranslationModifiers
syn region perlTranslationGQ		matchgroup=perlMatchStartEnd start=+\[+ end=+\]+ contains=perlBracketsSQ contained nextgroup=perlTranslationModifiers
syn region perlTranslationGQ		matchgroup=perlMatchStartEnd start=+{+ end=+}+ contains=perlBracesSQ contained nextgroup=perlTranslationModifiers
syn region perlTranslationGQ		matchgroup=perlMatchStartEnd start=+<+ end=+>+ contains=perlAnglesSQ contained nextgroup=perlTranslationModifiers


" Strings and q, qq, qw and qr expressions

syn region perlStringUnexpanded	matchgroup=perlStringStartEnd start="'" end="'" contains=@perlInterpSQ keepend extend
syn region perlString		matchgroup=perlStringStartEnd start=+"+  end=+"+ contains=@perlInterpDQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q\>\s*\z([^[:space:]#([{<]\)+ end=+\z1+ contains=@perlInterpSQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q#+ end=+#+ contains=@perlInterpSQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q\s*(+ end=+)+ contains=@perlInterpSQ,perlParensSQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q\s*\[+ end=+\]+ contains=@perlInterpSQ,perlBracketsSQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q\s*{+ end=+}+ contains=@perlInterpSQ,perlBracesSQ keepend extend
syn region perlQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q\s*<+ end=+>+ contains=@perlInterpSQ,perlAnglesSQ keepend extend

syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]\>\s*\z([^[:space:]#([{<]\)+ end=+\z1+ contains=@perlInterpDQ keepend extend
syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]#+ end=+#+ contains=@perlInterpDQ keepend extend
syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]\s*(+ end=+)+ contains=@perlInterpDQ,perlParensDQ keepend extend
syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]\s*\[+ end=+\]+ contains=@perlInterpDQ,perlBracketsDQ keepend extend
syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]\s*{+ end=+}+ contains=@perlInterpDQ,perlBracesDQ keepend extend
syn region perlQQ		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!q[qx]\s*<+ end=+>+ contains=@perlInterpDQ,perlAnglesDQ keepend extend

syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw\s*\z([^[:space:]#([{<]\)+  end=+\z1+ contains=@perlInterpSQ keepend extend
syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw#+  end=+#+ contains=@perlInterpSQ keepend extend
syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw\s*(+  end=+)+ contains=@perlInterpSQ,perlParensSQ keepend extend
syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw\s*\[+  end=+\]+ contains=@perlInterpSQ,perlBracketsSQ keepend extend
syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw\s*{+  end=+}+ contains=@perlInterpSQ,perlBracesSQ keepend extend
syn region perlQW		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qw\s*<+  end=+>+ contains=@perlInterpSQ,perlAnglesSQ keepend extend

syn match  perlQRModifiers "[msixpadluno]\+" contained
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\>\s*\z([^[:space:]#([{<'/]\)+  end=+\z1+ contains=@perlInterpMatch keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*/+  end=+/+ contains=@perlInterpSlash keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr#+  end=+#+ contains=@perlInterpMatch keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*'+  end=+'+ contains=@perlInterpSQ keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*(+  end=+)+ contains=@perlInterpMatch,perlParensDQ keepend extend nextgroup=perlQRModifiers

" A special case for qr{}, qr<> and qr[] which allows for comments and extra whitespace in the pattern
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*{+  end=+}+ contains=@perlInterpMatch,perlBracesDQ,perlComment keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*<+  end=+>+ contains=@perlInterpMatch,perlAnglesDQ,perlComment keepend extend nextgroup=perlQRModifiers
syn region perlQR		matchgroup=perlStringStartEnd start=+\<\%(::\|'\|->\)\@<!qr\s*\[+  end=+\]+ contains=@perlInterpMatch,perlBracketsDQ,perlComment keepend extend nextgroup=perlQRModifiers

" Constructs such as print <<EOF [...] EOF, 'here' documents
"
" XXX Any statements after the identifier are in perlString colour (i.e.
" 'if $a' in 'print <<EOF if $a'). This is almost impossible to get right it
" seems due to the 'auto-extending nature' of regions.
" XXX Indented heredocs are not perfect - they sometimes seem to take a moment
"     to update if switched from double to single quotes and vice versa.
"
" Note: bare delimiters such as << to mean <<"" are not supported. These are a
"       fatal error since 5.28 and, apparently, a rarely used feature.

syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\I\i*+                         end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\\\I\i*+                       end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*"[^\\"]*\%(\\.[^\\"]*\)*"+  end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*'[^\\']*\%(\\.[^\\']*\)*'+  end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*`[^\\`]*\%(\\.[^\\`]*\)*`+  end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*""+                         end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*''+                         end=+$+     contains=@perlTop oneline
syn region perlHereDocStart	matchgroup=perlStringStartEnd start=+<<\~\=\s*``+                         end=+$+     contains=@perlTop oneline

if get(g:, 'perl_fold', 0)
  syn region perlHereDoc	start=+<<\z(\I\i*\)+                        matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ fold extend
  syn region perlHereDoc	start=+<<\\\z(\I\i*\)+                      matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpSQ fold extend
  syn region perlHereDoc	start=+<<\s*"\z([^\\"]*\%(\\.[^\\"]*\)*\)"+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ fold extend
  syn region perlHereDoc	start=+<<\s*'\z([^\\']*\%(\\.[^\\']*\)*\)'+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpSQ fold extend
  syn region perlHereDoc	start=+<<\s*`\z([^\\`]*\%(\\.[^\\`]*\)*\)`+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ fold extend
  syn region perlHereDoc	start=+<<\s*""+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine fold extend
  syn region perlHereDoc	start=+<<\s*''+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpSQ,perlNotEmptyLine fold extend
  syn region perlHereDoc	start=+<<\s*``+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine fold extend
else
  syn region perlHereDoc	start=+<<\z(\I\i*\)+                        matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlHereDoc	start=+<<\\\z(\I\i*\)+                      matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpSQ
  syn region perlHereDoc	start=+<<\s*"\z([^\\"]*\%(\\.[^\\"]*\)*\)"+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlHereDoc	start=+<<\s*'\z([^\\']*\%(\\.[^\\']*\)*\)'+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpSQ
  syn region perlHereDoc	start=+<<\s*`\z([^\\`]*\%(\\.[^\\`]*\)*\)`+ matchgroup=perlStringStartEnd end=+^\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlHereDoc	start=+<<\s*""+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine
  syn region perlHereDoc	start=+<<\s*''+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpSQ,perlNotEmptyLine
  syn region perlHereDoc	start=+<<\s*``+                             matchgroup=perlStringStartEnd end=+^$+    contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine
endif

if get(g:, 'perl_fold', 0)
  syn region perlIndentedHereDoc	start=+<<\~\z(\I\i*\)+                        matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlIndentedHereDocStart,@perlInterpDQ fold extend
  syn region perlIndentedHereDoc	start=+<<\~\\\z(\I\i*\)+                      matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlIndentedHereDocStart,@perlInterpSQ fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*"\z([^\\"]*\%(\\.[^\\"]*\)*\)"+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlIndentedHereDocStart,@perlInterpDQ fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*'\z([^\\']*\%(\\.[^\\']*\)*\)'+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlIndentedHereDocStart,@perlInterpSQ fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*`\z([^\\`]*\%(\\.[^\\`]*\)*\)`+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlIndentedHereDocStart,@perlInterpDQ fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*""+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlIndentedHereDocStart,@perlInterpDQ,perlNotEmptyLine fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*''+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlIndentedHereDocStart,@perlInterpSQ,perlNotEmptyLine fold extend
  syn region perlIndentedHereDoc	start=+<<\~\s*``+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlIndentedHereDocStart,@perlInterpDQ,perlNotEmptyLine fold extend
else
  syn region perlIndentedHereDoc	start=+<<\~\z(\I\i*\)+                        matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlIndentedHereDoc	start=+<<\~\\\z(\I\i*\)+                      matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlHereDocStart,@perlInterpSQ
  syn region perlIndentedHereDoc	start=+<<\~\s*"\z([^\\"]*\%(\\.[^\\"]*\)*\)"+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlIndentedHereDoc	start=+<<\~\s*'\z([^\\']*\%(\\.[^\\']*\)*\)'+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlHereDocStart,@perlInterpSQ
  syn region perlIndentedHereDoc	start=+<<\~\s*`\z([^\\`]*\%(\\.[^\\`]*\)*\)`+ matchgroup=perlStringStartEnd end=+^\s*\z1$+ contains=perlHereDocStart,@perlInterpDQ
  syn region perlIndentedHereDoc	start=+<<\~\s*""+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine
  syn region perlIndentedHereDoc	start=+<<\~\s*''+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlHereDocStart,@perlInterpSQ,perlNotEmptyLine
  syn region perlIndentedHereDoc	start=+<<\~\s*``+                             matchgroup=perlStringStartEnd end=+^$+       contains=perlHereDocStart,@perlInterpDQ,perlNotEmptyLine
endif


" Class declarations
"
syn match   perlPackageDecl		"\<package\s\+\%(\h\|::\)\%(\w\|::\)*" contains=perlStatementPackage
syn keyword perlStatementPackage	package contained

" Functions
if get(g:, "perl_sub_signatures", 0)
    syn match perlSubSignature "\s*([^)]*)" contained extend
else
    syn match perlSubPrototype "\s*([\\$@%&*\[\];]*)" contained extend
endif
syn match perlSubAttribute "\s*:\s*\h\w*\%(([^)]*)\|\)" contained extend
syn match perlSubName "\%(\h\|::\|'\w\)\%(\w\|::\|'\w\)*\s*" contained extend
syn region perlSubDeclaration start="" end="[;{]" contains=perlSubName,perlSubPrototype,perlSubAttribute,perlSubSignature,perlComment contained transparent
syn match perlFunction "\<sub\>\_s*" nextgroup=perlSubDeclaration

" The => operator forces a bareword to the left of it to be interpreted as
" a string
syn match  perlString "\I\@<!-\?\I\i*\%(\s*=>\)\@="

" All other # are comments, except ^#!
syn match  perlComment		"#.*" contains=perlTodo,@Spell extend
syn match  perlSharpBang	"^#!.*"

" Formats
syn region perlFormat		matchgroup=perlStatementIOFunc start="^\s*\<format\s\+\k\+\s*=\s*$"rs=s+6 end="^\s*\.\s*$" contains=perlFormatName,perlFormatField,perlVarPlain,perlVarPlain2
syn match  perlFormatName	"format\s\+\k\+\s*="lc=7,me=e-1 contained
syn match  perlFormatField	"[@^][|<>~]\+\%(\.\.\.\)\=" contained
syn match  perlFormatField	"[@^]#[#.]*" contained
syn match  perlFormatField	"@\*" contained
syn match  perlFormatField	"@[^A-Za-z_|<>~#*]"me=e-1 contained
syn match  perlFormatField	"@$" contained

" __END__ and __DATA__ clauses

" Vim excludes empty syn-region end lines from the fold region.  This is
" probably a bug and means a DATA section ending with an empty line does not
" have that final line included in the fold.
"
" As a workaround we exploit an unterminated syntax region here with an end
" pattern that will (probably) never match.  This forces all lines to be
" included in the fold region.  Of course, if it does match then there's
" nothing to work around as it is a non-empty line.
"
" This problem also exists with empty string delimited heredocs but there's no
" known workaround for that case.
if get(g:, 'perl_fold', 0)
  syntax region perlDATA matchgroup=perlDATAStart start="^__DATA__$" end="VIM_PERL_EOF\%$" contains=@perlDATA fold
  syntax region perlEND  matchgroup=perlENDStart  start="^__END__$"  end="VIM_PERL_EOF\%$" contains=@perlDATA fold
else
  syntax region perlDATA matchgroup=perlDATAStart start="^__DATA__$" end="\%$" contains=@perlDATA
  syntax region perlEND  matchgroup=perlENDStart  start="^__END__$"  end="\%$" contains=@perlDATA
endif

" TODO: generalise this to allow other filetypes
if get(g:, 'perl_highlight_data', 0)
  syn cluster perlDATA add=perlPOD
else
  syn cluster perlDATA remove=perlPOD
endif

"
" Folding
if get(g:, 'perl_fold', 0)
  " Note: this bit must come before the actual highlighting of the "package"
  " keyword, otherwise this will screw up Pod lines that match /^package/
  if !get(g:, 'perl_nofold_packages', 0)
    syn region perlPackageFold start="^package \S\+;\s*\%(#.*\)\=$" end="^1;\=\s*\%(#.*\)\=$" end="\n\+package"me=s-1 transparent fold keepend
    syn region perlPackageFold start="^\z(\s*\)package\s*\S\+\s*{" end="^\z1}" transparent fold keepend
  endif
  if !get(g:, 'perl_nofold_subs', 0)
    if get(g:, "perl_fold_anonymous_subs", 0)
      " EXPLANATION:
      " \<sub\>                  - "sub" keyword
      " \_[^;{]*                 - any characters, including new line, but not ";" or "{", zero or more times
      " \%(([\\$@%&*\[\];]*)\)\= - prototype definition, \$@%&*[]; characters between (), zero or 1 times
      " \_[^;]*                  - any characters, including new line, but not ";" or "{", zero or more times
      " {                        - start subroutine block
      syn region perlSubFold start="\<sub\>\_[^;{]*\%(([\\$@%&*\[\];]*)\)\=\_[^;{]*{" end="}" transparent fold keepend extend
    else
      " EXPLANATION:
      " same, as above, but first non-space character after "sub" keyword must
      " be [A-Za-z_] 
      syn region perlSubFold start="\<sub\>\s*\h\_[^;{]*\%(([\\$@%&*\[\];]*)\)\=\_[^;]*{" end="}" transparent fold keepend extend
    endif

    syn region perlSubFold start="\<\%(BEGIN\|END\|CHECK\|INIT\|UNITCHECK\)\>\_s*{" end="}" transparent fold keepend
  endif

  if get(g:, 'perl_fold_blocks', 0)
    syn region perlBlockFold start="^\z(\s*\)\%(if\|elsif\|unless\|for\|while\|until\|given\)\s*(.*)\%(\s*{\)\=\s*\%(#.*\)\=$" start="^\z(\s*\)for\%(each\)\=\s*\%(\%(my\|our\)\=\s*\S\+\s*\)\=(.*)\%(\s*{\)\=\s*\%(#.*\)\=$" end="^\z1}\s*;\=\%(#.*\)\=$" transparent fold keepend

    " TODO this is works incorrectly
    syn region perlBlockFold start="^\z(\s*\)\%(do\|else\)\%(\s*{\)\=\s*\%(#.*\)\=$" end="^\z1}\s*while" end="^\z1}\s*;\=\%(#.*\)\=$" transparent fold keepend
  else
    if get(g:, 'perl_fold_do_blocks', 0)
      syn region perlDoBlockDeclaration start="" end="{" contains=perlComment contained transparent
      syn match perlOperator "\<do\>\_s*" nextgroup=perlDoBlockDeclaration

      syn region perlDoBlockFold start="\<do\>\_[^{]*{" end="}" transparent fold keepend extend
    endif
  endif

  syn sync fromstart
else
  " fromstart above seems to set minlines even if perl_fold is not set.
  syn sync minlines=0
endif

" NOTE: If you're linking new highlight groups to perlString, please also put
"       them into b:match_skip in ftplugin/perl.vim.

" The default highlighting.
hi def link perlSharpBang		PreProc
hi def link perlControl			PreProc
hi def link perlInclude			Include
hi def link perlSpecial			Special
hi def link perlString			String
hi def link perlCharacter		Character
hi def link perlNumber			Number
hi def link perlFloat			Float
hi def link perlType			Type
hi def link perlIdentifier		Identifier
hi def link perlLabel			Label
hi def link perlStatement		Statement
hi def link perlConditional		Conditional
hi def link perlRepeat			Repeat
hi def link perlOperator		Operator
hi def link perlFunction		Keyword
hi def link perlSubName			Function
hi def link perlSubPrototype		Type
hi def link perlSubSignature		Type
hi def link perlSubAttribute		PreProc
hi def link perlComment			Comment
hi def link perlTodo			Todo
if get(g:, 'perl_string_as_statement', 0)
  hi def link perlStringStartEnd	perlStatement
else
  hi def link perlStringStartEnd	perlString
endif
hi def link perlVStringV		perlStringStartEnd
hi def link perlList			perlStatement
hi def link perlMisc			perlStatement
hi def link perlVarPlain		perlIdentifier
hi def link perlVarPlain2		perlIdentifier
hi def link perlArrow			perlIdentifier
hi def link perlFiledescRead		perlIdentifier
hi def link perlFiledescStatement	perlIdentifier
hi def link perlVarSimpleMember		perlIdentifier
hi def link perlVarSimpleMemberName	perlString
hi def link perlVarNotInMatches		perlIdentifier
hi def link perlVarSlash		perlIdentifier
hi def link perlQ			perlString
hi def link perlQQ			perlString
hi def link perlQW			perlString
hi def link perlQR			perlString
hi def link perlMatchModifiers          perlMatchStartEnd
hi def link perlSubstitutionModifiers   perlMatchStartEnd
hi def link perlTranslationModifiers    perlMatchStartEnd
hi def link perlQRModifiers             perlStringStartEnd
hi def link perlHereDoc			perlString
hi def link perlIndentedHereDoc		perlString
hi def link perlStringUnexpanded	perlString
hi def link perlSubstitutionSQ		perlString
hi def link perlSubstitutionGQQ		perlString
hi def link perlTranslationGQ		perlString
hi def link perlMatch			perlString
hi def link perlMatchStartEnd		perlStatement
hi def link perlFormatName		perlIdentifier
hi def link perlFormatField		perlString
hi def link perlPackageDecl		perlType
hi def link perlStorageClass		perlType
hi def link perlPackageRef		perlType
hi def link perlStatementPackage	perlStatement
hi def link perlStatementStorage	perlStatement
hi def link perlStatementControl	perlStatement
hi def link perlStatementScalar		perlStatement
hi def link perlStatementRegexp		perlStatement
hi def link perlStatementNumeric	perlStatement
hi def link perlStatementList		perlStatement
hi def link perlStatementHash		perlStatement
hi def link perlStatementIOfunc		perlStatement
hi def link perlStatementFiledesc	perlStatement
hi def link perlStatementVector		perlStatement
hi def link perlStatementFiles		perlStatement
hi def link perlStatementFlow		perlStatement
hi def link perlStatementInclude	perlStatement
hi def link perlStatementProc		perlStatement
hi def link perlStatementSocket		perlStatement
hi def link perlStatementIPC		perlStatement
hi def link perlStatementNetwork	perlStatement
hi def link perlStatementPword		perlStatement
hi def link perlStatementTime		perlStatement
hi def link perlStatementMisc		perlStatement
hi def link perlStatementIndirObj	perlStatement
hi def link perlFunctionName		perlIdentifier
hi def link perlMethod			perlIdentifier
hi def link perlPostDeref		perlIdentifier
hi def link perlFunctionPRef		perlType

if !get(g:, 'perl_include_pod', 1)
  hi def link perlPOD		perlComment
endif
hi def link perlShellCommand		perlString
hi def link perlSpecialAscii		perlSpecial
hi def link perlSpecialDollar		perlSpecial
hi def link perlSpecialString		perlSpecial
hi def link perlSpecialStringU		perlSpecial
hi def link perlSpecialMatch		perlSpecial
hi def link perlEND			perlComment
hi def link perlENDStart		perlEND
hi def link perlDATA			perlComment
hi def link perlDATAStart		perlDATA

" NOTE: Due to a bug in Vim (or more likely, a misunderstanding on my part),
"	I had to remove the transparent property from the following regions
"	in order to get them to highlight correctly.  Feel free to remove
"	these and reinstate the transparent property if you know how.
hi def link perlParensSQ		perlString
hi def link perlBracketsSQ		perlString
hi def link perlBracesSQ		perlString
hi def link perlAnglesSQ		perlString

hi def link perlParensDQ		perlString
hi def link perlBracketsDQ		perlString
hi def link perlBracesDQ		perlString
hi def link perlAnglesDQ		perlString

hi def link perlSpecialStringU2	perlString

" Possible errors
hi def link perlNotEmptyLine		Error
hi def link perlElseIfError		Error

" Syncing to speed up processing
"
if !get(g:, 'perl_no_sync_on_sub', 0)
  syn sync match perlSync	grouphere NONE "^\s*\<package\s"
  syn sync match perlSync	grouphere NONE "^\s*\<sub\>"
  syn sync match perlSync	grouphere NONE "^}"
endif

if !get(g:, 'perl_no_sync_on_global_var', 0)
  syn sync match perlSync	grouphere NONE "^$\I[[:alnum:]_:]+\s*=\s*{"
  syn sync match perlSync	grouphere NONE "^[@%]\I[[:alnum:]_:]+\s*=\s*("
endif

if get(g:, 'perl_sync_dist', 0)
  execute "syn sync maxlines=" . perl_sync_dist
else
  syn sync maxlines=100
endif

syn sync match perlSyncPOD	grouphere perlPOD "^=pod"
syn sync match perlSyncPOD	grouphere perlPOD "^=head"
syn sync match perlSyncPOD	grouphere perlPOD "^=item"
syn sync match perlSyncPOD	grouphere NONE "^=cut"

let b:current_syntax = "perl"

let &cpo = s:cpo_save
unlet s:cpo_save

" XXX Change to sts=4:sw=4
" vim:ts=8:sts=2:sw=2:expandtab:ft=vim
