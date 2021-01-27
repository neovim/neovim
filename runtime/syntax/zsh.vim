" Vim syntax file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2020-01-23
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

syn keyword zshTodo             contained TODO FIXME XXX NOTE

syn region  zshComment          oneline start='\%(^\|\s\+\)#' end='$'
                                \ contains=zshTodo,@Spell fold

syn region  zshComment          start='^\s*#' end='^\%(\s*#\)\@!'
                                \ contains=zshTodo,@Spell fold

syn match   zshPreProc          '^\%1l#\%(!\|compdef\|autoload\).*$'

syn match   zshPOSIXQuoted      '\\[xX][0-9a-fA-F]\{1,2}'
syn match   zshPOSIXQuoted      '\\[0-7]\{1,3}'
syn match   zshPOSIXQuoted      '\\u[0-9a-fA-F]\{1,4}'
syn match   zshPOSIXQuoted      '\\U[1-9a-fA-F]\{1,8}'
syn match   zshQuoted           '\\.'
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

" Options, generated by: echo ${(j:\n:)options[(I)*]} | sort
" Create a list of option names from zsh source dir:
"     #!/bin/zsh
"    topdir=/path/to/zsh-xxx
"    grep '^pindex([A-Za-z_]*)$' $topdir/Doc/Zsh/options.yo |
"    while read opt
"    do
"        echo ${${(L)opt#pindex\(}%\)}
"    done

syn case ignore

syn match   zshOptStart /^\s*\%(\%(\%(un\)\?setopt\)\|set\s+[-+]o\)/ nextgroup=zshOption skipwhite
syn match   zshOption /
      \ \%(\%(\<no_\?\)\?aliases\>\)\|
      \ \%(\%(\<no_\?\)\?aliasfuncdef\>\)\|\%(\%(no_\?\)\?alias_func_def\>\)\|
      \ \%(\%(\<no_\?\)\?allexport\>\)\|\%(\%(no_\?\)\?all_export\>\)\|
      \ \%(\%(\<no_\?\)\?alwayslastprompt\>\)\|\%(\%(no_\?\)\?always_last_prompt\>\)\|\%(\%(no_\?\)\?always_lastprompt\>\)\|
      \ \%(\%(\<no_\?\)\?alwaystoend\>\)\|\%(\%(no_\?\)\?always_to_end\>\)\|
      \ \%(\%(\<no_\?\)\?appendcreate\>\)\|\%(\%(no_\?\)\?append_create\>\)\|
      \ \%(\%(\<no_\?\)\?appendhistory\>\)\|\%(\%(no_\?\)\?append_history\>\)\|
      \ \%(\%(\<no_\?\)\?autocd\>\)\|\%(\%(no_\?\)\?auto_cd\>\)\|
      \ \%(\%(\<no_\?\)\?autocontinue\>\)\|\%(\%(no_\?\)\?auto_continue\>\)\|
      \ \%(\%(\<no_\?\)\?autolist\>\)\|\%(\%(no_\?\)\?auto_list\>\)\|
      \ \%(\%(\<no_\?\)\?automenu\>\)\|\%(\%(no_\?\)\?auto_menu\>\)\|
      \ \%(\%(\<no_\?\)\?autonamedirs\>\)\|\%(\%(no_\?\)\?auto_name_dirs\>\)\|
      \ \%(\%(\<no_\?\)\?autoparamkeys\>\)\|\%(\%(no_\?\)\?auto_param_keys\>\)\|
      \ \%(\%(\<no_\?\)\?autoparamslash\>\)\|\%(\%(no_\?\)\?auto_param_slash\>\)\|
      \ \%(\%(\<no_\?\)\?autopushd\>\)\|\%(\%(no_\?\)\?auto_pushd\>\)\|
      \ \%(\%(\<no_\?\)\?autoremoveslash\>\)\|\%(\%(no_\?\)\?auto_remove_slash\>\)\|
      \ \%(\%(\<no_\?\)\?autoresume\>\)\|\%(\%(no_\?\)\?auto_resume\>\)\|
      \ \%(\%(\<no_\?\)\?badpattern\>\)\|\%(\%(no_\?\)\?bad_pattern\>\)\|
      \ \%(\%(\<no_\?\)\?banghist\>\)\|\%(\%(no_\?\)\?bang_hist\>\)\|
      \ \%(\%(\<no_\?\)\?bareglobqual\>\)\|\%(\%(no_\?\)\?bare_glob_qual\>\)\|
      \ \%(\%(\<no_\?\)\?bashautolist\>\)\|\%(\%(no_\?\)\?bash_auto_list\>\)\|
      \ \%(\%(\<no_\?\)\?bashrematch\>\)\|\%(\%(no_\?\)\?bash_rematch\>\)\|
      \ \%(\%(\<no_\?\)\?beep\>\)\|
      \ \%(\%(\<no_\?\)\?bgnice\>\)\|\%(\%(no_\?\)\?bg_nice\>\)\|
      \ \%(\%(\<no_\?\)\?braceccl\>\)\|\%(\%(no_\?\)\?brace_ccl\>\)\|
      \ \%(\%(\<no_\?\)\?braceexpand\>\)\|\%(\%(no_\?\)\?brace_expand\>\)\|
      \ \%(\%(\<no_\?\)\?bsdecho\>\)\|\%(\%(no_\?\)\?bsd_echo\>\)\|
      \ \%(\%(\<no_\?\)\?caseglob\>\)\|\%(\%(no_\?\)\?case_glob\>\)\|
      \ \%(\%(\<no_\?\)\?casematch\>\)\|\%(\%(no_\?\)\?case_match\>\)\|
      \ \%(\%(\<no_\?\)\?cbases\>\)\|\%(\%(no_\?\)\?c_bases\>\)\|
      \ \%(\%(\<no_\?\)\?cdablevars\>\)\|\%(\%(no_\?\)\?cdable_vars\>\)\|\%(\%(no_\?\)\?cd_able_vars\>\)\|
      \ \%(\%(\<no_\?\)\?chasedots\>\)\|\%(\%(no_\?\)\?chase_dots\>\)\|
      \ \%(\%(\<no_\?\)\?chaselinks\>\)\|\%(\%(no_\?\)\?chase_links\>\)\|
      \ \%(\%(\<no_\?\)\?checkjobs\>\)\|\%(\%(no_\?\)\?check_jobs\>\)\|
      \ \%(\%(\<no_\?\)\?checkrunningjobs\>\)\|\%(\%(no_\?\)\?check_running_jobs\>\)\|
      \ \%(\%(\<no_\?\)\?clobber\>\)\|
      \ \%(\%(\<no_\?\)\?combiningchars\>\)\|\%(\%(no_\?\)\?combining_chars\>\)\|
      \ \%(\%(\<no_\?\)\?completealiases\>\)\|\%(\%(no_\?\)\?complete_aliases\>\)\|
      \ \%(\%(\<no_\?\)\?completeinword\>\)\|\%(\%(no_\?\)\?complete_in_word\>\)\|
      \ \%(\%(\<no_\?\)\?continueonerror\>\)\|\%(\%(no_\?\)\?continue_on_error\>\)\|
      \ \%(\%(\<no_\?\)\?correct\>\)\|
      \ \%(\%(\<no_\?\)\?correctall\>\)\|\%(\%(no_\?\)\?correct_all\>\)\|
      \ \%(\%(\<no_\?\)\?cprecedences\>\)\|\%(\%(no_\?\)\?c_precedences\>\)\|
      \ \%(\%(\<no_\?\)\?cshjunkiehistory\>\)\|\%(\%(no_\?\)\?csh_junkie_history\>\)\|
      \ \%(\%(\<no_\?\)\?cshjunkieloops\>\)\|\%(\%(no_\?\)\?csh_junkie_loops\>\)\|
      \ \%(\%(\<no_\?\)\?cshjunkiequotes\>\)\|\%(\%(no_\?\)\?csh_junkie_quotes\>\)\|
      \ \%(\%(\<no_\?\)\?csh_nullcmd\>\)\|\%(\%(no_\?\)\?csh_null_cmd\>\)\|\%(\%(no_\?\)\?cshnullcmd\>\)\|\%(\%(no_\?\)\?csh_null_cmd\>\)\|
      \ \%(\%(\<no_\?\)\?cshnullglob\>\)\|\%(\%(no_\?\)\?csh_null_glob\>\)\|
      \ \%(\%(\<no_\?\)\?debugbeforecmd\>\)\|\%(\%(no_\?\)\?debug_before_cmd\>\)\|
      \ \%(\%(\<no_\?\)\?dotglob\>\)\|\%(\%(no_\?\)\?dot_glob\>\)\|
      \ \%(\%(\<no_\?\)\?dvorak\>\)\|
      \ \%(\%(\<no_\?\)\?emacs\>\)\|
      \ \%(\%(\<no_\?\)\?equals\>\)\|
      \ \%(\%(\<no_\?\)\?errexit\>\)\|\%(\%(no_\?\)\?err_exit\>\)\|
      \ \%(\%(\<no_\?\)\?errreturn\>\)\|\%(\%(no_\?\)\?err_return\>\)\|
      \ \%(\%(\<no_\?\)\?evallineno\>\)\|\%(\%(no_\?\)\?eval_lineno\>\)\|
      \ \%(\%(\<no_\?\)\?exec\>\)\|
      \ \%(\%(\<no_\?\)\?extendedglob\>\)\|\%(\%(no_\?\)\?extended_glob\>\)\|
      \ \%(\%(\<no_\?\)\?extendedhistory\>\)\|\%(\%(no_\?\)\?extended_history\>\)\|
      \ \%(\%(\<no_\?\)\?flowcontrol\>\)\|\%(\%(no_\?\)\?flow_control\>\)\|
      \ \%(\%(\<no_\?\)\?forcefloat\>\)\|\%(\%(no_\?\)\?force_float\>\)\|
      \ \%(\%(\<no_\?\)\?functionargzero\>\)\|\%(\%(no_\?\)\?function_argzero\>\)\|\%(\%(no_\?\)\?function_arg_zero\>\)\|
      \ \%(\%(\<no_\?\)\?glob\>\)\|
      \ \%(\%(\<no_\?\)\?globalexport\>\)\|\%(\%(no_\?\)\?global_export\>\)\|
      \ \%(\%(\<no_\?\)\?globalrcs\>\)\|\%(\%(no_\?\)\?global_rcs\>\)\|
      \ \%(\%(\<no_\?\)\?globassign\>\)\|\%(\%(no_\?\)\?glob_assign\>\)\|
      \ \%(\%(\<no_\?\)\?globcomplete\>\)\|\%(\%(no_\?\)\?glob_complete\>\)\|
      \ \%(\%(\<no_\?\)\?globdots\>\)\|\%(\%(no_\?\)\?glob_dots\>\)\|
      \ \%(\%(\<no_\?\)\?glob_subst\>\)\|\%(\%(no_\?\)\?globsubst\>\)\|
      \ \%(\%(\<no_\?\)\?globstarshort\>\)\|\%(\%(no_\?\)\?glob_star_short\>\)\|
      \ \%(\%(\<no_\?\)\?hashall\>\)\|\%(\%(no_\?\)\?hash_all\>\)\|
      \ \%(\%(\<no_\?\)\?hashcmds\>\)\|\%(\%(no_\?\)\?hash_cmds\>\)\|
      \ \%(\%(\<no_\?\)\?hashdirs\>\)\|\%(\%(no_\?\)\?hash_dirs\>\)\|
      \ \%(\%(\<no_\?\)\?hashexecutablesonly\>\)\|\%(\%(no_\?\)\?hash_executables_only\>\)\|
      \ \%(\%(\<no_\?\)\?hashlistall\>\)\|\%(\%(no_\?\)\?hash_list_all\>\)\|
      \ \%(\%(\<no_\?\)\?histallowclobber\>\)\|\%(\%(no_\?\)\?hist_allow_clobber\>\)\|
      \ \%(\%(\<no_\?\)\?histappend\>\)\|\%(\%(no_\?\)\?hist_append\>\)\|
      \ \%(\%(\<no_\?\)\?histbeep\>\)\|\%(\%(no_\?\)\?hist_beep\>\)\|
      \ \%(\%(\<no_\?\)\?hist_expand\>\)\|\%(\%(no_\?\)\?histexpand\>\)\|
      \ \%(\%(\<no_\?\)\?hist_expire_dups_first\>\)\|\%(\%(no_\?\)\?histexpiredupsfirst\>\)\|
      \ \%(\%(\<no_\?\)\?histfcntllock\>\)\|\%(\%(no_\?\)\?hist_fcntl_lock\>\)\|
      \ \%(\%(\<no_\?\)\?histfindnodups\>\)\|\%(\%(no_\?\)\?hist_find_no_dups\>\)\|
      \ \%(\%(\<no_\?\)\?histignorealldups\>\)\|\%(\%(no_\?\)\?hist_ignore_all_dups\>\)\|
      \ \%(\%(\<no_\?\)\?histignoredups\>\)\|\%(\%(no_\?\)\?hist_ignore_dups\>\)\|
      \ \%(\%(\<no_\?\)\?histignorespace\>\)\|\%(\%(no_\?\)\?hist_ignore_space\>\)\|
      \ \%(\%(\<no_\?\)\?histlexwords\>\)\|\%(\%(no_\?\)\?hist_lex_words\>\)\|
      \ \%(\%(\<no_\?\)\?histnofunctions\>\)\|\%(\%(no_\?\)\?hist_no_functions\>\)\|
      \ \%(\%(\<no_\?\)\?histnostore\>\)\|\%(\%(no_\?\)\?hist_no_store\>\)\|
      \ \%(\%(\<no_\?\)\?histreduceblanks\>\)\|\%(\%(no_\?\)\?hist_reduce_blanks\>\)\|
      \ \%(\%(\<no_\?\)\?histsavebycopy\>\)\|\%(\%(no_\?\)\?hist_save_by_copy\>\)\|
      \ \%(\%(\<no_\?\)\?histsavenodups\>\)\|\%(\%(no_\?\)\?hist_save_no_dups\>\)\|
      \ \%(\%(\<no_\?\)\?histsubstpattern\>\)\|\%(\%(no_\?\)\?hist_subst_pattern\>\)\|
      \ \%(\%(\<no_\?\)\?histverify\>\)\|\%(\%(no_\?\)\?hist_verify\>\)\|
      \ \%(\%(\<no_\?\)\?hup\>\)\|
      \ \%(\%(\<no_\?\)\?ignorebraces\>\)\|\%(\%(no_\?\)\?ignore_braces\>\)\|
      \ \%(\%(\<no_\?\)\?ignoreclosebraces\>\)\|\%(\%(no_\?\)\?ignore_close_braces\>\)\|
      \ \%(\%(\<no_\?\)\?ignoreeof\>\)\|\%(\%(no_\?\)\?ignore_eof\>\)\|
      \ \%(\%(\<no_\?\)\?incappendhistory\>\)\|\%(\%(no_\?\)\?inc_append_history\>\)\|
      \ \%(\%(\<no_\?\)\?incappendhistorytime\>\)\|\%(\%(no_\?\)\?inc_append_history_time\>\)\|
      \ \%(\%(\<no_\?\)\?interactive\>\)\|
      \ \%(\%(\<no_\?\)\?interactivecomments\>\)\|\%(\%(no_\?\)\?interactive_comments\>\)\|
      \ \%(\%(\<no_\?\)\?ksharrays\>\)\|\%(\%(no_\?\)\?ksh_arrays\>\)\|
      \ \%(\%(\<no_\?\)\?kshautoload\>\)\|\%(\%(no_\?\)\?ksh_autoload\>\)\|
      \ \%(\%(\<no_\?\)\?kshglob\>\)\|\%(\%(no_\?\)\?ksh_glob\>\)\|
      \ \%(\%(\<no_\?\)\?kshoptionprint\>\)\|\%(\%(no_\?\)\?ksh_option_print\>\)\|
      \ \%(\%(\<no_\?\)\?kshtypeset\>\)\|\%(\%(no_\?\)\?ksh_typeset\>\)\|
      \ \%(\%(\<no_\?\)\?kshzerosubscript\>\)\|\%(\%(no_\?\)\?ksh_zero_subscript\>\)\|
      \ \%(\%(\<no_\?\)\?listambiguous\>\)\|\%(\%(no_\?\)\?list_ambiguous\>\)\|
      \ \%(\%(\<no_\?\)\?listbeep\>\)\|\%(\%(no_\?\)\?list_beep\>\)\|
      \ \%(\%(\<no_\?\)\?listpacked\>\)\|\%(\%(no_\?\)\?list_packed\>\)\|
      \ \%(\%(\<no_\?\)\?listrowsfirst\>\)\|\%(\%(no_\?\)\?list_rows_first\>\)\|
      \ \%(\%(\<no_\?\)\?listtypes\>\)\|\%(\%(no_\?\)\?list_types\>\)\|
      \ \%(\%(\<no_\?\)\?localloops\>\)\|\%(\%(no_\?\)\?local_loops\>\)\|
      \ \%(\%(\<no_\?\)\?localoptions\>\)\|\%(\%(no_\?\)\?local_options\>\)\|
      \ \%(\%(\<no_\?\)\?localpatterns\>\)\|\%(\%(no_\?\)\?local_patterns\>\)\|
      \ \%(\%(\<no_\?\)\?localtraps\>\)\|\%(\%(no_\?\)\?local_traps\>\)\|
      \ \%(\%(\<no_\?\)\?log\>\)\|
      \ \%(\%(\<no_\?\)\?login\>\)\|
      \ \%(\%(\<no_\?\)\?longlistjobs\>\)\|\%(\%(no_\?\)\?long_list_jobs\>\)\|
      \ \%(\%(\<no_\?\)\?magicequalsubst\>\)\|\%(\%(no_\?\)\?magic_equal_subst\>\)\|
      \ \%(\%(\<no_\?\)\?mark_dirs\>\)\|
      \ \%(\%(\<no_\?\)\?mailwarn\>\)\|\%(\%(no_\?\)\?mail_warn\>\)\|
      \ \%(\%(\<no_\?\)\?mailwarning\>\)\|\%(\%(no_\?\)\?mail_warning\>\)\|
      \ \%(\%(\<no_\?\)\?markdirs\>\)\|
      \ \%(\%(\<no_\?\)\?menucomplete\>\)\|\%(\%(no_\?\)\?menu_complete\>\)\|
      \ \%(\%(\<no_\?\)\?monitor\>\)\|
      \ \%(\%(\<no_\?\)\?multibyte\>\)\|\%(\%(no_\?\)\?multi_byte\>\)\|
      \ \%(\%(\<no_\?\)\?multifuncdef\>\)\|\%(\%(no_\?\)\?multi_func_def\>\)\|
      \ \%(\%(\<no_\?\)\?multios\>\)\|\%(\%(no_\?\)\?multi_os\>\)\|
      \ \%(\%(\<no_\?\)\?nomatch\>\)\|\%(\%(no_\?\)\?no_match\>\)\|
      \ \%(\%(\<no_\?\)\?notify\>\)\|
      \ \%(\%(\<no_\?\)\?nullglob\>\)\|\%(\%(no_\?\)\?null_glob\>\)\|
      \ \%(\%(\<no_\?\)\?numericglobsort\>\)\|\%(\%(no_\?\)\?numeric_glob_sort\>\)\|
      \ \%(\%(\<no_\?\)\?octalzeroes\>\)\|\%(\%(no_\?\)\?octal_zeroes\>\)\|
      \ \%(\%(\<no_\?\)\?onecmd\>\)\|\%(\%(no_\?\)\?one_cmd\>\)\|
      \ \%(\%(\<no_\?\)\?overstrike\>\)\|\%(\%(no_\?\)\?over_strike\>\)\|
      \ \%(\%(\<no_\?\)\?pathdirs\>\)\|\%(\%(no_\?\)\?path_dirs\>\)\|
      \ \%(\%(\<no_\?\)\?pathscript\>\)\|\%(\%(no_\?\)\?path_script\>\)\|
      \ \%(\%(\<no_\?\)\?physical\>\)\|
      \ \%(\%(\<no_\?\)\?pipefail\>\)\|\%(\%(no_\?\)\?pipe_fail\>\)\|
      \ \%(\%(\<no_\?\)\?posixaliases\>\)\|\%(\%(no_\?\)\?posix_aliases\>\)\|
      \ \%(\%(\<no_\?\)\?posixargzero\>\)\|\%(\%(no_\?\)\?posix_arg_zero\>\)\|\%(\%(no_\?\)\?posix_argzero\>\)\|
      \ \%(\%(\<no_\?\)\?posixbuiltins\>\)\|\%(\%(no_\?\)\?posix_builtins\>\)\|
      \ \%(\%(\<no_\?\)\?posixcd\>\)\|\%(\%(no_\?\)\?posix_cd\>\)\|
      \ \%(\%(\<no_\?\)\?posixidentifiers\>\)\|\%(\%(no_\?\)\?posix_identifiers\>\)\|
      \ \%(\%(\<no_\?\)\?posixjobs\>\)\|\%(\%(no_\?\)\?posix_jobs\>\)\|
      \ \%(\%(\<no_\?\)\?posixstrings\>\)\|\%(\%(no_\?\)\?posix_strings\>\)\|
      \ \%(\%(\<no_\?\)\?posixtraps\>\)\|\%(\%(no_\?\)\?posix_traps\>\)\|
      \ \%(\%(\<no_\?\)\?printeightbit\>\)\|\%(\%(no_\?\)\?print_eight_bit\>\)\|
      \ \%(\%(\<no_\?\)\?printexitvalue\>\)\|\%(\%(no_\?\)\?print_exit_value\>\)\|
      \ \%(\%(\<no_\?\)\?privileged\>\)\|
      \ \%(\%(\<no_\?\)\?promptbang\>\)\|\%(\%(no_\?\)\?prompt_bang\>\)\|
      \ \%(\%(\<no_\?\)\?promptcr\>\)\|\%(\%(no_\?\)\?prompt_cr\>\)\|
      \ \%(\%(\<no_\?\)\?promptpercent\>\)\|\%(\%(no_\?\)\?prompt_percent\>\)\|
      \ \%(\%(\<no_\?\)\?promptsp\>\)\|\%(\%(no_\?\)\?prompt_sp\>\)\|
      \ \%(\%(\<no_\?\)\?promptsubst\>\)\|\%(\%(no_\?\)\?prompt_subst\>\)\|
      \ \%(\%(\<no_\?\)\?promptvars\>\)\|\%(\%(no_\?\)\?prompt_vars\>\)\|
      \ \%(\%(\<no_\?\)\?pushdignoredups\>\)\|\%(\%(no_\?\)\?pushd_ignore_dups\>\)\|
      \ \%(\%(\<no_\?\)\?pushdminus\>\)\|\%(\%(no_\?\)\?pushd_minus\>\)\|
      \ \%(\%(\<no_\?\)\?pushdsilent\>\)\|\%(\%(no_\?\)\?pushd_silent\>\)\|
      \ \%(\%(\<no_\?\)\?pushdtohome\>\)\|\%(\%(no_\?\)\?pushd_to_home\>\)\|
      \ \%(\%(\<no_\?\)\?rcexpandparam\>\)\|\%(\%(no_\?\)\?rc_expandparam\>\)\|\%(\%(no_\?\)\?rc_expand_param\>\)\|
      \ \%(\%(\<no_\?\)\?rcquotes\>\)\|\%(\%(no_\?\)\?rc_quotes\>\)\|
      \ \%(\%(\<no_\?\)\?rcs\>\)\|
      \ \%(\%(\<no_\?\)\?recexact\>\)\|\%(\%(no_\?\)\?rec_exact\>\)\|
      \ \%(\%(\<no_\?\)\?rematchpcre\>\)\|\%(\%(no_\?\)\?re_match_pcre\>\)\|\%(\%(no_\?\)\?rematch_pcre\>\)\|
      \ \%(\%(\<no_\?\)\?restricted\>\)\|
      \ \%(\%(\<no_\?\)\?rmstarsilent\>\)\|\%(\%(no_\?\)\?rm_star_silent\>\)\|
      \ \%(\%(\<no_\?\)\?rmstarwait\>\)\|\%(\%(no_\?\)\?rm_star_wait\>\)\|
      \ \%(\%(\<no_\?\)\?sharehistory\>\)\|\%(\%(no_\?\)\?share_history\>\)\|
      \ \%(\%(\<no_\?\)\?shfileexpansion\>\)\|\%(\%(no_\?\)\?sh_file_expansion\>\)\|
      \ \%(\%(\<no_\?\)\?shglob\>\)\|\%(\%(no_\?\)\?sh_glob\>\)\|
      \ \%(\%(\<no_\?\)\?shinstdin\>\)\|\%(\%(no_\?\)\?shin_stdin\>\)\|
      \ \%(\%(\<no_\?\)\?shnullcmd\>\)\|\%(\%(no_\?\)\?sh_nullcmd\>\)\|
      \ \%(\%(\<no_\?\)\?shoptionletters\>\)\|\%(\%(no_\?\)\?sh_option_letters\>\)\|
      \ \%(\%(\<no_\?\)\?shortloops\>\)\|\%(\%(no_\?\)\?short_loops\>\)\|
      \ \%(\%(\<no_\?\)\?shwordsplit\>\)\|\%(\%(no_\?\)\?sh_word_split\>\)\|
      \ \%(\%(\<no_\?\)\?singlecommand\>\)\|\%(\%(no_\?\)\?single_command\>\)\|
      \ \%(\%(\<no_\?\)\?singlelinezle\>\)\|\%(\%(no_\?\)\?single_line_zle\>\)\|
      \ \%(\%(\<no_\?\)\?sourcetrace\>\)\|\%(\%(no_\?\)\?source_trace\>\)\|
      \ \%(\%(\<no_\?\)\?stdin\>\)\|
      \ \%(\%(\<no_\?\)\?sunkeyboardhack\>\)\|\%(\%(no_\?\)\?sun_keyboard_hack\>\)\|
      \ \%(\%(\<no_\?\)\?trackall\>\)\|\%(\%(no_\?\)\?track_all\>\)\|
      \ \%(\%(\<no_\?\)\?transientrprompt\>\)\|\%(\%(no_\?\)\?transient_rprompt\>\)\|
      \ \%(\%(\<no_\?\)\?trapsasync\>\)\|\%(\%(no_\?\)\?traps_async\>\)\|
      \ \%(\%(\<no_\?\)\?typesetsilent\>\)\|\%(\%(no_\?\)\?type_set_silent\>\)\|\%(\%(no_\?\)\?typeset_silent\>\)\|
      \ \%(\%(\<no_\?\)\?unset\>\)\|
      \ \%(\%(\<no_\?\)\?verbose\>\)\|
      \ \%(\%(\<no_\?\)\?vi\>\)\|
      \ \%(\%(\<no_\?\)\?warnnestedvar\>\)\|\%(\%(no_\?\)\?warn_nested_var\>\)\|
      \ \%(\%(\<no_\?\)\?warncreateglobal\>\)\|\%(\%(no_\?\)\?warn_create_global\>\)\|
      \ \%(\%(\<no_\?\)\?xtrace\>\)\|
      \ \%(\%(\<no_\?\)\?zle\>\)/ nextgroup=zshOption,zshComment skipwhite contained

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
                                \ start='\$((' skip='\\)' end='))'
                                \ contains=zshParentheses,@zshSubst,zshNumber,
                                \ @zshDerefs,zshString keepend fold
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
