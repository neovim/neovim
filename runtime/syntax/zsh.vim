" Vim syntax file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2022-07-26
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
    for cluster in ['markdownHighlight_zsh', 'zsh']
      try
      " markdown syntax defines embedded clusters as @markdownhighlight_<lang>,
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
                                \ contains=zshQuoted,@zshDerefs,@zshSubstQuoted fold
syn region  zshString           matchgroup=zshStringDelimiter start=+'+ end=+'+ fold
syn region  zshPOSIXString      matchgroup=zshStringDelimiter start=+\$'+
                                \ skip=+\\[\\']+ end=+'+ contains=zshPOSIXQuoted,zshQuoted
syn match   zshJobSpec          '%\(\d\+\|?\=\w\+\|[%+-]\)'

syn match   zshNumber           '[+-]\=\<\d\+\>'
syn match   zshNumber           '[+-]\=\<0x\x\+\>'
syn match   zshNumber           '[+-]\=\<0\o\+\>'
syn match   zshNumber           '[+-]\=\d\+#[-+]\=\w\+\>'
syn match   zshNumber           '[+-]\=\d\+\.\d\+\>'

syn keyword zshPrecommand       noglob nocorrect exec command builtin - time

syn keyword zshDelimiter        do done end

syn keyword zshConditional      if then elif else fi esac select

syn keyword zshCase             case nextgroup=zshCaseWord skipwhite
syn match zshCaseWord           /\S\+/ nextgroup=zshCaseIn skipwhite contained transparent
syn keyword zshCaseIn           in nextgroup=zshCasePattern skipwhite skipnl contained
syn match zshCasePattern        /\S[^)]*)/ contained

syn keyword zshRepeat           while until repeat

syn keyword zshRepeat           for foreach nextgroup=zshVariable skipwhite

syn keyword zshException        always

syn keyword zshKeyword          function nextgroup=zshKSHFunction skipwhite

syn match   zshKSHFunction      contained '\w\S\+'
syn match   zshFunction         '^\s*\k\+\ze\s*()'

syn match   zshOperator         '||\|&&\|;\|&!\='

                                " <<<, <, <>, and variants.
syn match   zshRedir            '\d\=\(<<<\|<&\s*[0-9p-]\=\|<>\?\)'
                                " >, >>, and variants.
syn match   zshRedir            '\d\=\(>&\s*[0-9p-]\=\|&>>\?\|>>\?&\?\)[|!]\='
                                " | and |&, but only if it's not preceeded or
                                " followed by a | to avoid matching ||.
syn match   zshRedir            '|\@1<!|&\=|\@!'

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
                                \ printf prompt pushd pushln pwd r read
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
syn keyword zshOption nextgroup=zshOption,zshComment skipwhite contained
           \ auto_cd no_auto_cd autocd noautocd auto_pushd no_auto_pushd autopushd noautopushd cdable_vars
           \ no_cdable_vars cdablevars nocdablevars cd_silent no_cd_silent cdsilent nocdsilent chase_dots
           \ no_chase_dots chasedots nochasedots chase_links no_chase_links chaselinks nochaselinks posix_cd
           \ posixcd no_posix_cd noposixcd pushd_ignore_dups no_pushd_ignore_dups pushdignoredups
           \ nopushdignoredups pushd_minus no_pushd_minus pushdminus nopushdminus pushd_silent no_pushd_silent
           \ pushdsilent nopushdsilent pushd_to_home no_pushd_to_home pushdtohome nopushdtohome
           \ always_last_prompt no_always_last_prompt alwayslastprompt noalwayslastprompt always_to_end
           \ no_always_to_end alwaystoend noalwaystoend auto_list no_auto_list autolist noautolist auto_menu
           \ no_auto_menu automenu noautomenu auto_name_dirs no_auto_name_dirs autonamedirs noautonamedirs
           \ auto_param_keys no_auto_param_keys autoparamkeys noautoparamkeys auto_param_slash
           \ no_auto_param_slash autoparamslash noautoparamslash auto_remove_slash no_auto_remove_slash
           \ autoremoveslash noautoremoveslash bash_auto_list no_bash_auto_list bashautolist nobashautolist
           \ complete_aliases no_complete_aliases completealiases nocompletealiases complete_in_word
           \ no_complete_in_word completeinword nocompleteinword glob_complete no_glob_complete globcomplete
           \ noglobcomplete hash_list_all no_hash_list_all hashlistall nohashlistall list_ambiguous
           \ no_list_ambiguous listambiguous nolistambiguous list_beep no_list_beep listbeep nolistbeep
           \ list_packed no_list_packed listpacked nolistpacked list_rows_first no_list_rows_first listrowsfirst
           \ nolistrowsfirst list_types no_list_types listtypes nolisttypes menu_complete no_menu_complete
           \ menucomplete nomenucomplete rec_exact no_rec_exact recexact norecexact bad_pattern no_bad_pattern
           \ badpattern nobadpattern bare_glob_qual no_bare_glob_qual bareglobqual nobareglobqual brace_ccl
           \ no_brace_ccl braceccl nobraceccl case_glob no_case_glob caseglob nocaseglob case_match
           \ no_case_match casematch nocasematch case_paths no_case_paths casepaths nocasepaths csh_null_glob
           \ no_csh_null_glob cshnullglob nocshnullglob equals no_equals noequals extended_glob no_extended_glob
           \ extendedglob noextendedglob force_float no_force_float forcefloat noforcefloat glob no_glob noglob
           \ glob_assign no_glob_assign globassign noglobassign glob_dots no_glob_dots globdots noglobdots
           \ glob_star_short no_glob_star_short globstarshort noglobstarshort glob_subst no_glob_subst globsubst
           \ noglobsubst hist_subst_pattern no_hist_subst_pattern histsubstpattern nohistsubstpattern
           \ ignore_braces no_ignore_braces ignorebraces noignorebraces ignore_close_braces
           \ no_ignore_close_braces ignoreclosebraces noignoreclosebraces ksh_glob no_ksh_glob kshglob nokshglob
           \ magic_equal_subst no_magic_equal_subst magicequalsubst nomagicequalsubst mark_dirs no_mark_dirs
           \ markdirs nomarkdirs multibyte no_multibyte nomultibyte nomatch no_nomatch nonomatch null_glob
           \ no_null_glob nullglob nonullglob numeric_glob_sort no_numeric_glob_sort numericglobsort
           \ nonumericglobsort rc_expand_param no_rc_expand_param rcexpandparam norcexpandparam rematch_pcre
           \ no_rematch_pcre rematchpcre norematchpcre sh_glob no_sh_glob shglob noshglob unset no_unset nounset
           \ warn_create_global no_warn_create_global warncreateglobal nowarncreateglobal warn_nested_var
           \ no_warn_nested_var warnnestedvar no_warnnestedvar append_history no_append_history appendhistory
           \ noappendhistory bang_hist no_bang_hist banghist nobanghist extended_history no_extended_history
           \ extendedhistory noextendedhistory hist_allow_clobber no_hist_allow_clobber histallowclobber
           \ nohistallowclobber hist_beep no_hist_beep histbeep nohistbeep hist_expire_dups_first
           \ no_hist_expire_dups_first histexpiredupsfirst nohistexpiredupsfirst hist_fcntl_lock
           \ no_hist_fcntl_lock histfcntllock nohistfcntllock hist_find_no_dups no_hist_find_no_dups
           \ histfindnodups nohistfindnodups hist_ignore_all_dups no_hist_ignore_all_dups histignorealldups
           \ nohistignorealldups hist_ignore_dups no_hist_ignore_dups histignoredups nohistignoredups
           \ hist_ignore_space no_hist_ignore_space histignorespace nohistignorespace hist_lex_words
           \ no_hist_lex_words histlexwords nohistlexwords hist_no_functions no_hist_no_functions
           \ histnofunctions nohistnofunctions hist_no_store no_hist_no_store histnostore nohistnostore
           \ hist_reduce_blanks no_hist_reduce_blanks histreduceblanks nohistreduceblanks hist_save_by_copy
           \ no_hist_save_by_copy histsavebycopy nohistsavebycopy hist_save_no_dups no_hist_save_no_dups
           \ histsavenodups nohistsavenodups hist_verify no_hist_verify histverify nohistverify
           \ inc_append_history no_inc_append_history incappendhistory noincappendhistory
           \ inc_append_history_time no_inc_append_history_time incappendhistorytime noincappendhistorytime
           \ share_history no_share_history sharehistory nosharehistory all_export no_all_export allexport
           \ noallexport global_export no_global_export globalexport noglobalexport global_rcs no_global_rcs
           \ globalrcs noglobalrcs rcs no_rcs norcs aliases no_aliases noaliases clobber no_clobber noclobber
           \ clobber_empty no_clobber_empty clobberempty noclobberempty correct no_correct nocorrect correct_all
           \ no_correct_all correctall nocorrectall dvorak no_dvorak nodvorak flow_control no_flow_control
           \ flowcontrol noflowcontrol ignore_eof no_ignore_eof ignoreeof noignoreeof interactive_comments
           \ no_interactive_comments interactivecomments nointeractivecomments hash_cmds no_hash_cmds hashcmds
           \ nohashcmds hash_dirs no_hash_dirs hashdirs nohashdirs hash_executables_only
           \ no_hash_executables_only hashexecutablesonly nohashexecutablesonly mail_warning no_mail_warning
           \ mailwarning nomailwarning path_dirs no_path_dirs pathdirs nopathdirs path_script no_path_script
           \ pathscript nopathscript print_eight_bit no_print_eight_bit printeightbit noprinteightbit
           \ print_exit_value no_print_exit_value printexitvalue noprintexitvalue rc_quotes no_rc_quotes
           \ rcquotes norcquotes rm_star_silent no_rm_star_silent rmstarsilent normstarsilent rm_star_wait
           \ no_rm_star_wait rmstarwait normstarwait short_loops no_short_loops shortloops noshortloops
           \ short_repeat no_short_repeat shortrepeat noshortrepeat sun_keyboard_hack no_sun_keyboard_hack
           \ sunkeyboardhack nosunkeyboardhack auto_continue no_auto_continue autocontinue noautocontinue
           \ auto_resume no_auto_resume autoresume noautoresume bg_nice no_bg_nice bgnice nobgnice check_jobs
           \ no_check_jobs checkjobs nocheckjobs check_running_jobs no_check_running_jobs checkrunningjobs
           \ nocheckrunningjobs hup no_hup nohup long_list_jobs no_long_list_jobs longlistjobs nolonglistjobs
           \ monitor no_monitor nomonitor notify no_notify nonotify posix_jobs posixjobs no_posix_jobs
           \ noposixjobs prompt_bang no_prompt_bang promptbang nopromptbang prompt_cr no_prompt_cr promptcr
           \ nopromptcr prompt_sp no_prompt_sp promptsp nopromptsp prompt_percent no_prompt_percent
           \ promptpercent nopromptpercent prompt_subst no_prompt_subst promptsubst nopromptsubst
           \ transient_rprompt no_transient_rprompt transientrprompt notransientrprompt alias_func_def
           \ no_alias_func_def aliasfuncdef noaliasfuncdef c_bases no_c_bases cbases nocbases c_precedences
           \ no_c_precedences cprecedences nocprecedences debug_before_cmd no_debug_before_cmd debugbeforecmd
           \ nodebugbeforecmd err_exit no_err_exit errexit noerrexit err_return no_err_return errreturn
           \ noerrreturn eval_lineno no_eval_lineno evallineno noevallineno exec no_exec noexec function_argzero
           \ no_function_argzero functionargzero nofunctionargzero local_loops no_local_loops localloops
           \ nolocalloops local_options no_local_options localoptions nolocaloptions local_patterns
           \ no_local_patterns localpatterns nolocalpatterns local_traps no_local_traps localtraps nolocaltraps
           \ multi_func_def no_multi_func_def multifuncdef nomultifuncdef multios no_multios nomultios
           \ octal_zeroes no_octal_zeroes octalzeroes nooctalzeroes pipe_fail no_pipe_fail pipefail nopipefail
           \ source_trace no_source_trace sourcetrace nosourcetrace typeset_silent no_typeset_silent
           \ typesetsilent notypesetsilent typeset_to_unset no_typeset_to_unset typesettounset notypesettounset
           \ verbose no_verbose noverbose xtrace no_xtrace noxtrace append_create no_append_create appendcreate
           \ noappendcreate bash_rematch no_bash_rematch bashrematch nobashrematch bsd_echo no_bsd_echo bsdecho
           \ nobsdecho continue_on_error no_continue_on_error continueonerror nocontinueonerror
           \ csh_junkie_history no_csh_junkie_history cshjunkiehistory nocshjunkiehistory csh_junkie_loops
           \ no_csh_junkie_loops cshjunkieloops nocshjunkieloops csh_junkie_quotes no_csh_junkie_quotes
           \ cshjunkiequotes nocshjunkiequotes csh_nullcmd no_csh_nullcmd cshnullcmd nocshnullcmd ksh_arrays
           \ no_ksh_arrays ksharrays noksharrays ksh_autoload no_ksh_autoload kshautoload nokshautoload
           \ ksh_option_print no_ksh_option_print kshoptionprint nokshoptionprint ksh_typeset no_ksh_typeset
           \ kshtypeset nokshtypeset ksh_zero_subscript no_ksh_zero_subscript kshzerosubscript
           \ nokshzerosubscript posix_aliases no_posix_aliases posixaliases noposixaliases posix_argzero
           \ no_posix_argzero posixargzero noposixargzero posix_builtins no_posix_builtins posixbuiltins
           \ noposixbuiltins posix_identifiers no_posix_identifiers posixidentifiers noposixidentifiers
           \ posix_strings no_posix_strings posixstrings noposixstrings posix_traps no_posix_traps posixtraps
           \ noposixtraps sh_file_expansion no_sh_file_expansion shfileexpansion noshfileexpansion sh_nullcmd
           \ no_sh_nullcmd shnullcmd noshnullcmd sh_option_letters no_sh_option_letters shoptionletters
           \ noshoptionletters sh_word_split no_sh_word_split shwordsplit noshwordsplit traps_async
           \ no_traps_async trapsasync notrapsasync interactive no_interactive nointeractive login no_login
           \ nologin privileged no_privileged noprivileged restricted no_restricted norestricted shin_stdin
           \ no_shin_stdin shinstdin noshinstdin single_command no_single_command singlecommand nosinglecommand
           \ beep no_beep nobeep combining_chars no_combining_chars combiningchars nocombiningchars emacs
           \ no_emacs noemacs overstrike no_overstrike nooverstrike single_line_zle no_single_line_zle
           \ singlelinezle nosinglelinezle vi no_vi novi zle no_zle nozle brace_expand no_brace_expand
           \ braceexpand nobraceexpand dot_glob no_dot_glob dotglob nodotglob hash_all no_hash_all hashall
           \ nohashall hist_append no_hist_append histappend nohistappend hist_expand no_hist_expand histexpand
           \ nohistexpand log no_log nolog mail_warn no_mail_warn mailwarn nomailwarn one_cmd no_one_cmd onecmd
           \ noonecmd physical no_physical nophysical prompt_vars no_prompt_vars promptvars nopromptvars stdin
           \ no_stdin nostdin track_all no_track_all trackall notrackall
syn case match

syn keyword zshTypes            float integer local typeset declare private readonly

" XXX: this may be too much
" syn match   zshSwitches         '\s\zs--\=[a-zA-Z0-9-]\+'

" TODO: $[...] is the same as $((...)), so add that as well.
syn cluster zshSubst            contains=zshSubst,zshOldSubst,zshMathSubst
syn cluster zshSubstQuoted      contains=zshSubstQuoted,zshOldSubst,zshMathSubst
exe 'syn region  zshSubst       matchgroup=zshSubstDelim transparent start=/\$(/ skip=/\\)/ end=/)/ contains='.s:contained. '  fold'
exe 'syn region  zshSubstQuoted matchgroup=zshSubstDelim transparent start=/\$(/ skip=/\\)/ end=/)/ contains='.s:contained. '  fold'
syn region  zshSubstQuoted       matchgroup=zshSubstDelim start='\${' skip='\\}' end='}' contains=@zshSubst,zshBrackets,zshQuoted fold
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
hi def link zshCase             zshConditional
hi def link zshCaseIn           zshCase
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
hi def link zshSubstQuoted      zshSubst
hi def link zshMathSubst        zshSubst
hi def link zshOldSubst         zshSubst
hi def link zshSubstDelim       zshSubst
hi def link zshGlob             zshSubst

let b:current_syntax = "zsh"

let &cpo = s:cpo_save
unlet s:cpo_save
