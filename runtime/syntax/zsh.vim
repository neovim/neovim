" Vim syntax file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2020-11-21
" License:              Vim (see :h license)
" Repository:           https://github.com/chrisbra/vim-zsh

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

function! s:ContainedGroup()
  " needs 7.4.2008 for execute() function
  let result='TOP'
    " vim-pandoc syntax defines the @langname cluster for embedded syntax languages
    " However, if no syntax is defined yet, `syn list @zsh` will return
    " "No syntax items defined", so make sure the result is actually a valid syn cluster
    for cluster in ['markdownHighlightzsh', 'zsh']
      try
      " markdown syntax defines embedded clusters as @markdownhighlight<lang>,
      " pandoc just uses @<lang>, so check both for both clusters
        let a=split(execute('syn list @'. cluster), "\n")
        if len(a) == 2 && a[0] =~# '^---' && a[1] =~? cluster
          return  '@'. cluster
        endif
      catch /E392/
        " ignore
      endtry
    endfor
    return result
endfunction

let s:contained=s:ContainedGroup()

syn iskeyword @,48-57,_,192-255,#,-
if get(g:, 'zsh_fold_enable', 0)
    setlocal foldmethod=syntax
endif

syn match   zshQuoted           '\\.'
syn match   zshPOSIXQuoted      '\\[xX][0-9a-fA-F]\{1,2}'
syn match   zshPOSIXQuoted      '\\[0-7]\{1,3}'
syn match   zshPOSIXQuoted      '\\u[0-9a-fA-F]\{1,4}'
syn match   zshPOSIXQuoted      '\\U[1-9a-fA-F]\{1,8}'

syn region  zshString           matchgroup=zshStringDelimiter start=+"+ end=+"+
                                \ contains=zshQuoted,@zshDerefs,@zshSubst fold
syn region  zshString           matchgroup=zshStringDelimiter start=+'+ end=+'+ fold
syn region  zshPOSIXString      matchgroup=zshStringDelimiter start=+\$'+
                                \ skip=+\\[\\']+ end=+'+ contains=zshPOSIXQuoted,zshQuoted
syn match   zshJobSpec          '%\(\d\+\|?\=\w\+\|[%+-]\)'

syn keyword zshPrecommand       noglob nocorrect exec command builtin - time

syn keyword zshDelimiter        do done end

syn keyword zshConditional      if then elif else fi case in esac select

syn keyword zshRepeat           while until repeat

syn keyword zshRepeat           for foreach nextgroup=zshVariable skipwhite

syn keyword zshException        always

syn keyword zshKeyword          function nextgroup=zshKSHFunction skipwhite

syn match   zshKSHFunction      contained '\w\S\+'
syn match   zshFunction         '^\s*\k\+\ze\s*()'

syn match   zshOperator         '||\|&&\|;\|&!\='

syn match   zshRedir            '\d\=\(<\|<>\|<<<\|<&\s*[0-9p-]\=\)'
syn match   zshRedir            '\d\=\(>\|>>\|>&\s*[0-9p-]\=\|&>\|>>&\|&>>\)[|!]\='
syn match   zshRedir            '|&\='

syn region  zshHereDoc          matchgroup=zshRedir
                                \ start='<\@<!<<\s*\z([^<]\S*\)'
                                \ end='^\z1\>'
                                \ contains=@zshSubst,@zshDerefs,zshQuoted,zshPOSIXString
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start='<\@<!<<\s*\\\z(\S\+\)'
                                \ end='^\z1\>'
                                \ contains=@zshSubst,@zshDerefs,zshQuoted,zshPOSIXString
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start='<\@<!<<-\s*\\\=\z(\S\+\)'
                                \ end='^\s*\z1\>'
                                \ contains=@zshSubst,@zshDerefs,zshQuoted,zshPOSIXString
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start=+<\@<!<<\s*\(["']\)\z(\S\+\)\1+
                                \ end='^\z1\>'
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start=+<\@<!<<-\s*\(["']\)\z(\S\+\)\1+
                                \ end='^\s*\z1\>'

syn match   zshVariable         '\<\h\w*' contained

syn match   zshVariableDef      '\<\h\w*\ze+\=='
" XXX: how safe is this?
syn region  zshVariableDef      oneline
                                \ start='\$\@<!\<\h\w*\[' end='\]\ze+\?=\?'
                                \ contains=@zshSubst

syn cluster zshDerefs           contains=zshShortDeref,zshLongDeref,zshDeref,zshDollarVar

syn match zshShortDeref       '\$[!#$*@?_-]\w\@!'
syn match zshShortDeref       '\$[=^~]*[#+]*\d\+\>'

syn match zshLongDeref        '\$\%(ARGC\|argv\|status\|pipestatus\|CPUTYPE\|EGID\|EUID\|ERRNO\|GID\|HOST\|LINENO\|LOGNAME\)'
syn match zshLongDeref        '\$\%(MACHTYPE\|OLDPWD OPTARG\|OPTIND\|OSTYPE\|PPID\|PWD\|RANDOM\|SECONDS\|SHLVL\|signals\)'
syn match zshLongDeref        '\$\%(TRY_BLOCK_ERROR\|TTY\|TTYIDLE\|UID\|USERNAME\|VENDOR\|ZSH_NAME\|ZSH_VERSION\|REPLY\|reply\|TERM\)'

syn match zshDollarVar        '\$\h\w*'
syn match zshDeref            '\$[=^~]*[#+]*\h\w*\>'

syn match   zshCommands         '\%(^\|\s\)[.:]\ze\s'
syn keyword zshCommands         alias autoload bg bindkey break bye cap cd
                                \ chdir clone comparguments compcall compctl
                                \ compdescribe compfiles compgroups compquote
                                \ comptags comptry compvalues continue dirs
                                \ disable disown echo echotc echoti emulate
                                \ enable eval exec exit export false fc fg
                                \ functions getcap getln getopts hash history
                                \ jobs kill let limit log logout popd print
                                \ printf pushd pushln pwd r read
                                \ rehash return sched set setcap shift
                                \ source stat suspend test times trap true
                                \ ttyctl type ulimit umask unalias unfunction
                                \ unhash unlimit unset  vared wait
                                \ whence where which zcompile zformat zftp zle
                                \ zmodload zparseopts zprof zpty zrecompile
                                \ zregexparse zsocket zstyle ztcp

" Options, generated by from the zsh source with the make-options.zsh script.
syn case ignore
syn match   zshOptStart
            \ /\v^\s*%(%(un)?setopt|set\s+[-+]o)/
            \ nextgroup=zshOption skipwhite
syn match   zshOption nextgroup=zshOption,zshComment skipwhite contained /\v
            \ <%(no_?)?%(
            \ auto_?cd|auto_?pushd|cdable_?vars|cd_?silent|chase_?dots|chase_?links|posix_?cd|pushd_?ignore_?dups|pushd_?minus|pushd_?silent|pushd_?to_?home|always_?last_?prompt|always_?to_?end|auto_?list|auto_?menu|auto_?name_?dirs|auto_?param_?keys|auto_?param_?slash|auto_?remove_?slash|bash_?auto_?list|complete_?aliases|complete_?in_?word|glob_?complete|hash_?list_?all|list_?ambiguous|list_?beep|list_?packed|list_?rows_?first|list_?types|menu_?complete|rec_?exact|bad_?pattern|bare_?glob_?qual|brace_?ccl|case_?glob|case_?match|case_?paths|csh_?null_?glob|equals|extended_?glob|force_?float|glob|glob_?assign|glob_?dots|glob_?star_?short|glob_?subst|hist_?subst_?pattern|ignore_?braces|ignore_?close_?braces|ksh_?glob|magic_?equal_?subst|mark_?dirs|multibyte|nomatch|null_?glob|numeric_?glob_?sort|rc_?expand_?param|rematch_?pcre|sh_?glob|unset|warn_?create_?global|warn_?nested_?var|warnnestedvar|append_?history|bang_?hist|extended_?history|hist_?allow_?clobber|hist_?beep|hist_?expire_?dups_?first|hist_?fcntl_?lock|hist_?find_?no_?dups|hist_?ignore_?all_?dups|hist_?ignore_?dups|hist_?ignore_?space|hist_?lex_?words|hist_?no_?functions|hist_?no_?store|hist_?reduce_?blanks|hist_?save_?by_?copy|hist_?save_?no_?dups|hist_?verify|inc_?append_?history|inc_?append_?history_?time|share_?history|all_?export|global_?export|global_?rcs|rcs|aliases|clobber|clobber_?empty|correct|correct_?all|dvorak|flow_?control|ignore_?eof|interactive_?comments|hash_?cmds|hash_?dirs|hash_?executables_?only|mail_?warning|path_?dirs|path_?script|print_?eight_?bit|print_?exit_?value|rc_?quotes|rm_?star_?silent|rm_?star_?wait|short_?loops|short_?repeat|sun_?keyboard_?hack|auto_?continue|auto_?resume|bg_?nice|check_?jobs|check_?running_?jobs|hup|long_?list_?jobs|monitor|notify|posix_?jobs|prompt_?bang|prompt_?cr|prompt_?sp|prompt_?percent|prompt_?subst|transient_?rprompt|alias_?func_?def|c_?bases|c_?precedences|debug_?before_?cmd|err_?exit|err_?return|eval_?lineno|exec|function_?argzero|local_?loops|local_?options|local_?patterns|local_?traps|multi_?func_?def|multios|octal_?zeroes|pipe_?fail|source_?trace|typeset_?silent|typeset_?to_?unset|verbose|xtrace|append_?create|bash_?rematch|bsd_?echo|continue_?on_?error|csh_?junkie_?history|csh_?junkie_?loops|csh_?junkie_?quotes|csh_?nullcmd|ksh_?arrays|ksh_?autoload|ksh_?option_?print|ksh_?typeset|ksh_?zero_?subscript|posix_?aliases|posix_?argzero|posix_?builtins|posix_?identifiers|posix_?strings|posix_?traps|sh_?file_?expansion|sh_?nullcmd|sh_?option_?letters|sh_?word_?split|traps_?async|interactive|login|privileged|restricted|shin_?stdin|single_?command|beep|combining_?chars|emacs|overstrike|single_?line_?zle|vi|zle|brace_?expand|dot_?glob|hash_?all|hist_?append|hist_?expand|log|mail_?warn|one_?cmd|physical|prompt_?vars|stdin|track_?all|no_?match
            \)>/
syn case match

syn keyword zshTypes            float integer local typeset declare private readonly

" XXX: this may be too much
" syn match   zshSwitches         '\s\zs--\=[a-zA-Z0-9-]\+'

syn match   zshNumber           '[+-]\=\<\d\+\>'
syn match   zshNumber           '[+-]\=\<0x\x\+\>'
syn match   zshNumber           '[+-]\=\<0\o\+\>'
syn match   zshNumber           '[+-]\=\d\+#[-+]\=\w\+\>'
syn match   zshNumber           '[+-]\=\d\+\.\d\+\>'

" TODO: $[...] is the same as $((...)), so add that as well.
syn cluster zshSubst            contains=zshSubst,zshOldSubst,zshMathSubst
exe 'syn region  zshSubst       matchgroup=zshSubstDelim transparent start=/\$(/ skip=/\\)/ end=/)/ contains='.s:contained. '  fold'
syn region  zshParentheses      transparent start='(' skip='\\)' end=')' fold
syn region  zshGlob             start='(#' end=')'
syn region  zshMathSubst        matchgroup=zshSubstDelim transparent
                                \ start='\%(\$\?\)[<=>]\@<!((' skip='\\)' end='))'
                                \ contains=zshParentheses,@zshSubst,zshNumber,
                                \ @zshDerefs,zshString fold
" The ms=s+1 prevents matching zshBrackets several times on opening brackets
" (see https://github.com/chrisbra/vim-zsh/issues/21#issuecomment-576330348)
syn region  zshBrackets         contained transparent start='{'ms=s+1 skip='\\}'
                                \ end='}' fold
exe 'syn region  zshBrackets    transparent start=/{/ms=s+1 skip=/\\}/ end=/}/ contains='.s:contained. ' fold'

syn region  zshSubst            matchgroup=zshSubstDelim start='\${' skip='\\}'
                                \ end='}' contains=@zshSubst,zshBrackets,zshQuoted,zshString fold
exe 'syn region  zshOldSubst    matchgroup=zshSubstDelim start=/`/ skip=/\\[\\`]/ end=/`/ contains='.s:contained. ',zshOldSubst fold'

syn sync    minlines=50 maxlines=90
syn sync    match zshHereDocSync    grouphere   NONE '<<-\=\s*\%(\\\=\S\+\|\(["']\)\S\+\1\)'
syn sync    match zshHereDocEndSync groupthere  NONE '^\s*EO\a\+\>'

syn keyword zshTodo             contained TODO FIXME XXX NOTE

syn region  zshComment          oneline start='\%(^\|\s\+\)#' end='$'
                                \ contains=zshTodo,@Spell fold

syn region  zshComment          start='^\s*#' end='^\%(\s*#\)\@!'
                                \ contains=zshTodo,@Spell fold

syn match   zshPreProc          '^\%1l#\%(!\|compdef\|autoload\).*$'

hi def link zshTodo             Todo
hi def link zshComment          Comment
hi def link zshPreProc          PreProc
hi def link zshQuoted           SpecialChar
hi def link zshPOSIXQuoted      SpecialChar
hi def link zshString           String
hi def link zshStringDelimiter  zshString
hi def link zshPOSIXString      zshString
hi def link zshJobSpec          Special
hi def link zshPrecommand       Special
hi def link zshDelimiter        Keyword
hi def link zshConditional      Conditional
hi def link zshException        Exception
hi def link zshRepeat           Repeat
hi def link zshKeyword          Keyword
hi def link zshFunction         None
hi def link zshKSHFunction      zshFunction
hi def link zshHereDoc          String
hi def link zshOperator         None
hi def link zshRedir            Operator
hi def link zshVariable         None
hi def link zshVariableDef      zshVariable
hi def link zshDereferencing    PreProc
hi def link zshShortDeref       zshDereferencing
hi def link zshLongDeref        zshDereferencing
hi def link zshDeref            zshDereferencing
hi def link zshDollarVar        zshDereferencing
hi def link zshCommands         Keyword
hi def link zshOptStart         Keyword
hi def link zshOption           Constant
hi def link zshTypes            Type
hi def link zshSwitches         Special
hi def link zshNumber           Number
hi def link zshSubst            PreProc
hi def link zshMathSubst        zshSubst
hi def link zshOldSubst         zshSubst
hi def link zshSubstDelim       zshSubst
hi def link zshGlob             zshSubst

let b:current_syntax = "zsh"

let &cpo = s:cpo_save
unlet s:cpo_save
