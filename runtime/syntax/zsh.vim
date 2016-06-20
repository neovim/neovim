" Vim syntax file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2016-02-15
" License:              Vim (see :h license)
" Repository:		https://github.com/chrisbra/vim-zsh

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

if v:version > 704 || (v:version == 704 && has("patch1142"))
    syn iskeyword @,48-57,_,192-255,#,-
else
    setlocal iskeyword+=-
endif
if get(g:, 'zsh_fold_enable', 0)
    setlocal foldmethod=syntax
endif

syn keyword zshTodo             contained TODO FIXME XXX NOTE

syn region  zshComment          oneline start='\%(^\|\s*\)#' end='$'
                                \ contains=zshTodo,@Spell fold

syn region  zshComment          start='^\s*#' end='^\%(\s*#\)\@!'
                                \ contains=zshTodo,@Spell fold

syn match   zshPreProc          '^\%1l#\%(!\|compdef\|autoload\).*$'

syn match   zshQuoted           '\\.'
syn region  zshString           matchgroup=zshStringDelimiter start=+"+ end=+"+
                                \ contains=zshQuoted,@zshDerefs,@zshSubst fold
syn region  zshString           matchgroup=zshStringDelimiter start=+'+ end=+'+ fold
" XXX: This should probably be more precise, but Zsh seems a bit confused about it itself
syn region  zshPOSIXString      matchgroup=zshStringDelimiter start=+\$'+
                                \ end=+'+ contains=zshQuoted
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
                                \ contains=@zshSubst
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start='<\@<!<<\s*\\\z(\S\+\)'
                                \ end='^\z1\>'
                                \ contains=@zshSubst
syn region  zshHereDoc          matchgroup=zshRedir
                                \ start='<\@<!<<-\s*\\\=\z(\S\+\)'
                                \ end='^\s*\z1\>'
                                \ contains=@zshSubst
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
                                \ start='\$\@<!\<\h\w*\[' end='\]\ze+\=='
                                \ contains=@zshSubst

syn cluster zshDerefs           contains=zshShortDeref,zshLongDeref,zshDeref

if !exists("g:zsh_syntax_variables")
  let s:zsh_syntax_variables = 'all'
else
  let s:zsh_syntax_variables = g:zsh_syntax_variables
endif

if s:zsh_syntax_variables =~ 'short\|all'
  syn match zshShortDeref       '\$[!#$*@?_-]\w\@!'
  syn match zshShortDeref       '\$[=^~]*[#+]*\d\+\>'
endif

if s:zsh_syntax_variables =~ 'long\|all'
  syn match zshLongDeref        '\$\%(ARGC\|argv\|status\|pipestatus\|CPUTYPE\|EGID\|EUID\|ERRNO\|GID\|HOST\|LINENO\|LOGNAME\)'
  syn match zshLongDeref        '\$\%(MACHTYPE\|OLDPWD OPTARG\|OPTIND\|OSTYPE\|PPID\|PWD\|RANDOM\|SECONDS\|SHLVL\|signals\)'
  syn match zshLongDeref        '\$\%(TRY_BLOCK_ERROR\|TTY\|TTYIDLE\|UID\|USERNAME\|VENDOR\|ZSH_NAME\|ZSH_VERSION\|REPLY\|reply\|TERM\)'
endif

if s:zsh_syntax_variables =~ 'all'
  syn match zshDeref            '\$[=^~]*[#+]*\h\w*\>'
else
  syn match zshDeref            transparent contains=NONE '\$[=^~]*[#+]*\h\w*\>'
endif

syn match   zshCommands         '\%(^\|\s\)[.:]\ze\s'
syn keyword zshCommands         alias autoload bg bindkey break bye cap cd
                                \ chdir clone comparguments compcall compctl
                                \ compdescribe compfiles compgroups compquote
                                \ comptags comptry compvalues continue dirs
                                \ disable disown echo echotc echoti emulate
                                \ enable eval exec exit export false fc fg
                                \ functions getcap getln getopts hash history
                                \ jobs kill let limit log logout popd print
                                \ printf pushd pushln pwd r read readonly
                                \ rehash return sched set setcap setopt shift
                                \ source stat suspend test times trap true
                                \ ttyctl type ulimit umask unalias unfunction
                                \ unhash unlimit unset unsetopt vared wait
                                \ whence where which zcompile zformat zftp zle
                                \ zmodload zparseopts zprof zpty zregexparse
                                \ zsocket zstyle ztcp

" Options, generated by: echo ${(j:\n:)options[(I)*]} | sort
" Create a list of option names from zsh source dir:
"     #!/bin/zsh
"    topdir=/path/to/zsh-xxx
"    grep '^pindex([A-Za-z_]*)$' $topdir/Src/Doc/Zsh/optionsyo |
"    while read opt
"    do
"        echo ${${(L)opt#pindex\(}%\)}
"    done

syn case ignore
syn keyword zshOptions          aliases allexport all_export alwayslastprompt
                                \ always_last_prompt always_lastprompt alwaystoend always_to_end appendcreate
                                \ append_create appendhistory append_history autocd auto_cd autocontinue
                                \ auto_continue autolist auto_list
                                \ automenu auto_menu autonamedirs auto_name_dirs
                                \ autoparamkeys auto_param_keys autoparamslash
                                \ auto_param_slash autopushd auto_pushd autoremoveslash
                                \ auto_remove_slash autoresume auto_resume badpattern bad_pattern
                                \ banghist bang_hist bareglobqual bare_glob_qual
                                \ bashautolist bash_auto_list bashrematch bash_rematch
                                \ beep bgnice bg_nice braceccl brace_ccl braceexpand brace_expand
                                \ bsdecho bsd_echo caseglob case_glob casematch case_match
                                \ cbases c_bases cdablevars cdable_vars cd_able_vars chasedots chase_dots
                                \ chaselinks chase_links checkjobs check_jobs
                                \ clobber combiningchars combining_chars completealiases
                                \ complete_aliases completeinword complete_in_word
                                \ continueonerror continue_on_error correct
                                \ correctall correct_all cprecedences c_precedences
                                \ cshjunkiehistory csh_junkie_history cshjunkieloops
                                \ csh_junkie_loops cshjunkiequotes csh_junkie_quotes
                                \ csh_nullcmd csh_null_cmd cshnullcmd csh_null_cmd cshnullglob csh_null_glob
                                \ debugbeforecmd debug_before_cmd dotglob dot_glob dvorak
                                \ emacs equals errexit err_exit errreturn err_return evallineno
                                \ eval_lineno exec extendedglob extended_glob extendedhistory
                                \ extended_history flowcontrol flow_control forcefloat
                                \ force_float functionargzero function_argzero function_arg_zero glob globalexport
                                \ global_export globalrcs global_rcs globassign glob_assign
                                \ globcomplete glob_complete globdots glob_dots glob_subst
                                \ globsubst globstarshort glob_star_short hashall hash_all hashcmds
                                \ hash_cmds hashdirs hash_dirs hashexecutablesonly hash_executables_only
                                \ hashlistall hash_list_all histallowclobber hist_allow_clobber histappend
                                \ hist_append histbeep hist_beep hist_expand hist_expire_dups_first
                                \ histexpand histexpiredupsfirst histfcntllock hist_fcntl_lock
                                \ histfindnodups hist_find_no_dups histignorealldups
                                \ hist_ignore_all_dups histignoredups hist_ignore_dups
                                \ histignorespace hist_ignore_space histlexwords hist_lex_words
                                \ histnofunctions hist_no_functions histnostore hist_no_store
                                \ histreduceblanks hist_reduce_blanks histsavebycopy
                                \ hist_save_by_copy histsavenodups hist_save_no_dups
                                \ histsubstpattern hist_subst_pattern histverify hist_verify
                                \ hup ignorebraces ignore_braces ignoreclosebraces ignore_close_braces
                                \ ignoreeof ignore_eof incappendhistory inc_append_history
                                \ incappendhistorytime inc_append_history_time interactive
                                \ interactivecomments interactive_comments ksharrays ksh_arrays
                                \ kshautoload ksh_autoload kshglob ksh_glob kshoptionprint
                                \ ksh_option_print kshtypeset ksh_typeset kshzerosubscript
                                \ ksh_zero_subscript listambiguous list_ambiguous listbeep
                                \ list_beep listpacked list_packed listrowsfirst list_rows_first
                                \ listtypes list_types localloops local_loops localoptions
                                \ local_options localpatterns local_patterns localtraps
                                \ local_traps log login longlistjobs long_list_jobs magicequalsubst
                                \ magic_equal_subst mailwarn mail_warn mail_warning mark_dirs
                                \ mailwarning markdirs menucomplete menu_complete monitor
                                \ multibyte multi_byte multifuncdef multi_func_def multios
                                \ multi_os nomatch no_match notify nullglob null_glob numericglobsort
                                \ numeric_glob_sort octalzeroes octal_zeroes onecmd one_cmd
                                \ overstrike over_strike pathdirs path_dirs pathscript
                                \ path_script physical pipefail pipe_fail posixaliases
                                \ posix_aliases posixargzero posix_arg_zero posix_argzero posixbuiltins 
                                \ posix_builtins posixcd posix_cd posixidentifiers posix_identifiers
                                \ posixjobs posix_jobs posixstrings posix_strings posixtraps
                                \ posix_traps printeightbit print_eight_bit printexitvalue
                                \ print_exit_value privileged promptbang prompt_bang promptcr
                                \ prompt_cr promptpercent prompt_percent promptsp prompt_sp
                                \ promptsubst prompt_subst promptvars prompt_vars pushdignoredups
                                \ pushd_ignore_dups pushdminus pushd_minus pushdsilent pushd_silent
                                \ pushdtohome pushd_to_home rcexpandparam rc_expandparam rc_expand_param rcquotes
                                \ rc_quotes rcs recexact rec_exact rematchpcre re_match_pcre rematch_pcre
                                \ restricted rmstarsilent rm_star_silent rmstarwait rm_star_wait
                                \ sharehistory share_history shfileexpansion sh_file_expansion
                                \ shglob sh_glob shinstdin shin_stdin shnullcmd sh_nullcmd
                                \ shoptionletters sh_option_letters shortloops short_loops shwordsplit
                                \ sh_word_split singlecommand single_command singlelinezle single_line_zle
                                \ sourcetrace source_trace stdin sunkeyboardhack sun_keyboard_hack
                                \ trackall track_all transientrprompt transient_rprompt
                                \ trapsasync traps_async typesetsilent type_set_silent typeset_silent unset verbose vi
                                \ warncreateglobal warn_create_global xtrace zle

syn keyword zshOptions          noaliases no_aliases noallexport no_allexport noall_export no_all_export noalwayslastprompt no_alwayslastprompt
                                \ noalways_lastprompt no_always_lastprompt no_always_last_prompt noalwaystoend no_alwaystoend noalways_to_end no_always_to_end
                                \ noappendcreate no_appendcreate no_append_create noappendhistory no_appendhistory noappend_history no_append_history noautocd
                                \ no_autocd no_auto_cd noautocontinue no_autocontinue noauto_continue no_auto_continue noautolist no_autolist noauto_list
                                \ no_auto_list noautomenu no_automenu noauto_menu no_auto_menu noautonamedirs no_autonamedirs noauto_name_dirs
                                \ no_auto_name_dirs noautoparamkeys no_autoparamkeys noauto_param_keys no_auto_param_keys noautoparamslash no_autoparamslash
                                \ noauto_param_slash no_auto_param_slash noautopushd no_autopushd noauto_pushd no_auto_pushd noautoremoveslash no_autoremoveslash
                                \ noauto_remove_slash no_auto_remove_slash noautoresume no_autoresume noauto_resume no_auto_resume nobadpattern no_badpattern no_bad_pattern
                                \ nobanghist no_banghist nobang_hist no_bang_hist nobareglobqual no_bareglobqual nobare_glob_qual no_bare_glob_qual
                                \ nobashautolist no_bashautolist nobash_auto_list no_bash_auto_list nobashrematch no_bashrematch nobash_rematch no_bash_rematch
                                \ nobeep no_beep nobgnice no_bgnice no_bg_nice nobraceccl no_braceccl nobrace_ccl no_brace_ccl nobraceexpand no_braceexpand nobrace_expand no_brace_expand
                                \ nobsdecho no_bsdecho nobsd_echo no_bsd_echo nocaseglob no_caseglob nocase_glob no_case_glob nocasematch no_casematch nocase_match no_case_match
                                \ nocbases no_cbases no_c_bases nocdablevars no_cdablevars no_cdable_vars nocd_able_vars no_cd_able_vars nochasedots no_chasedots nochase_dots no_chase_dots
                                \ nochaselinks no_chaselinks nochase_links no_chase_links nocheckjobs no_checkjobs nocheck_jobs no_check_jobs
                                \ noclobber no_clobber nocombiningchars no_combiningchars nocombining_chars no_combining_chars nocompletealiases no_completealiases
                                \ nocomplete_aliases no_complete_aliases nocompleteinword no_completeinword nocomplete_in_word no_complete_in_word
                                \ nocontinueonerror no_continueonerror nocontinue_on_error no_continue_on_error nocorrect no_correct
                                \ nocorrectall no_correctall nocorrect_all no_correct_all nocprecedences no_cprecedences noc_precedences no_c_precedences
                                \ nocshjunkiehistory no_cshjunkiehistory nocsh_junkie_history no_csh_junkie_history nocshjunkieloops no_cshjunkieloops
                                \ nocsh_junkie_loops no_csh_junkie_loops nocshjunkiequotes no_cshjunkiequotes nocsh_junkie_quotes no_csh_junkie_quotes
                                \ nocshnullcmd no_cshnullcmd no_csh_nullcmd nocsh_null_cmd no_csh_null_cmd nocshnullglob no_cshnullglob nocsh_null_glob no_csh_null_glob
                                \ nodebugbeforecmd no_debugbeforecmd nodebug_before_cmd no_debug_before_cmd nodotglob no_dotglob nodot_glob no_dot_glob nodvorak no_dvorak
                                \ noemacs no_emacs noequals no_equals noerrexit no_errexit noerr_exit no_err_exit noerrreturn no_errreturn noerr_return no_err_return noevallineno no_evallineno
                                \ noeval_lineno no_eval_lineno noexec no_exec noextendedglob no_extendedglob noextended_glob no_extended_glob noextendedhistory no_extendedhistory
                                \ noextended_history no_extended_history noflowcontrol no_flowcontrol noflow_control no_flow_control noforcefloat no_forcefloat
                                \ noforce_float no_force_float nofunctionargzero no_functionargzero nofunction_arg_zero no_function_argzero no_function_arg_zero noglob no_glob noglobalexport no_globalexport
                                \ noglobal_export no_global_export noglobalrcs no_globalrcs noglobal_rcs no_global_rcs noglobassign no_globassign noglob_assign no_glob_assign
                                \ noglobcomplete no_globcomplete noglob_complete no_glob_complete noglobdots no_globdots noglob_dots no_glob_dots
                                \ noglobstarshort no_glob_star_short noglob_subst no_glob_subst
                                \ noglobsubst no_globsubst nohashall no_hashall nohash_all no_hash_all nohashcmds no_hashcmds nohash_cmds no_hash_cmds nohashdirs no_hashdirs
                                \ nohash_dirs no_hash_dirs nohashexecutablesonly no_hashexecutablesonly nohash_executables_only no_hash_executables_only nohashlistall no_hashlistall
                                \ nohash_list_all no_hash_list_all nohistallowclobber no_histallowclobber nohist_allow_clobber no_hist_allow_clobber nohistappend no_histappend
                                \ nohist_append no_hist_append nohistbeep no_histbeep nohist_beep no_hist_beep nohist_expand no_hist_expand nohist_expire_dups_first no_hist_expire_dups_first
                                \ nohistexpand no_histexpand nohistexpiredupsfirst no_histexpiredupsfirst nohistfcntllock no_histfcntllock nohist_fcntl_lock no_hist_fcntl_lock
                                \ nohistfindnodups no_histfindnodups nohist_find_no_dups no_hist_find_no_dups nohistignorealldups no_histignorealldups
                                \ nohist_ignore_all_dups no_hist_ignore_all_dups nohistignoredups no_histignoredups nohist_ignore_dups no_hist_ignore_dups
                                \ nohistignorespace no_histignorespace nohist_ignore_space no_hist_ignore_space nohistlexwords no_histlexwords nohist_lex_words no_hist_lex_words
                                \ nohistnofunctions no_histnofunctions nohist_no_functions no_hist_no_functions nohistnostore no_histnostore nohist_no_store no_hist_no_store
                                \ nohistreduceblanks no_histreduceblanks nohist_reduce_blanks no_hist_reduce_blanks nohistsavebycopy no_histsavebycopy
                                \ nohist_save_by_copy no_hist_save_by_copy nohistsavenodups no_histsavenodups nohist_save_no_dups no_hist_save_no_dups
                                \ nohistsubstpattern no_histsubstpattern nohist_subst_pattern no_hist_subst_pattern nohistverify no_histverify nohist_verify no_hist_verify
                                \ nohup no_hup noignorebraces no_ignorebraces noignore_braces no_ignore_braces noignoreclosebraces no_ignoreclosebraces noignore_close_braces no_ignore_close_braces
                                \ noignoreeof no_ignoreeof noignore_eof no_ignore_eof noincappendhistory no_incappendhistory noinc_append_history no_inc_append_history
                                \ noincappendhistorytime no_incappendhistorytime noinc_append_history_time no_inc_append_history_time nointeractive no_interactive
                                \ nointeractivecomments no_interactivecomments nointeractive_comments no_interactive_comments noksharrays no_ksharrays noksh_arrays no_ksh_arrays
                                \ nokshautoload no_kshautoload noksh_autoload no_ksh_autoload nokshglob no_kshglob noksh_glob no_ksh_glob nokshoptionprint no_kshoptionprint
                                \ noksh_option_print no_ksh_option_print nokshtypeset no_kshtypeset noksh_typeset no_ksh_typeset nokshzerosubscript no_kshzerosubscript
                                \ noksh_zero_subscript no_ksh_zero_subscript nolistambiguous no_listambiguous nolist_ambiguous no_list_ambiguous nolistbeep no_listbeep
                                \ nolist_beep no_list_beep nolistpacked no_listpacked nolist_packed no_list_packed nolistrowsfirst no_listrowsfirst nolist_rows_first no_list_rows_first
                                \ nolisttypes no_listtypes nolist_types no_list_types nolocalloops no_localloops nolocal_loops no_local_loops nolocaloptions no_localoptions
                                \ nolocal_options no_local_options nolocalpatterns no_localpatterns nolocal_patterns no_local_patterns nolocaltraps no_localtraps
                                \ nolocal_traps no_local_traps nolog no_log nologin no_login nolonglistjobs no_longlistjobs nolong_list_jobs no_long_list_jobs nomagicequalsubst no_magicequalsubst
                                \ nomagic_equal_subst no_magic_equal_subst nomailwarn no_mailwarn nomail_warn no_mail_warn nomail_warning no_mail_warning nomark_dirs no_mark_dirs
                                \ nomailwarning no_mailwarning nomarkdirs no_markdirs nomenucomplete no_menucomplete nomenu_complete no_menu_complete nomonitor no_monitor
                                \ nomultibyte no_multibyte nomulti_byte no_multi_byte nomultifuncdef no_multifuncdef nomulti_func_def no_multi_func_def nomultios no_multios
                                \ nomulti_os no_multi_os nonomatch no_nomatch nono_match no_no_match nonotify no_notify nonullglob no_nullglob nonull_glob no_null_glob nonumericglobsort no_numericglobsort
                                \ nonumeric_glob_sort no_numeric_glob_sort nooctalzeroes no_octalzeroes nooctal_zeroes no_octal_zeroes noonecmd no_onecmd noone_cmd no_one_cmd
                                \ nooverstrike no_overstrike noover_strike no_over_strike nopathdirs no_pathdirs nopath_dirs no_path_dirs nopathscript no_pathscript
                                \ nopath_script no_path_script nophysical no_physical nopipefail no_pipefail nopipe_fail no_pipe_fail noposixaliases no_posixaliases
                                \ noposix_aliases no_posix_aliases noposixargzero no_posixargzero no_posix_argzero noposix_arg_zero no_posix_arg_zero noposixbuiltins no_posixbuiltins 
                                \ noposix_builtins no_posix_builtins noposixcd no_posixcd noposix_cd no_posix_cd noposixidentifiers no_posixidentifiers noposix_identifiers no_posix_identifiers
                                \ noposixjobs no_posixjobs noposix_jobs no_posix_jobs noposixstrings no_posixstrings noposix_strings no_posix_strings noposixtraps no_posixtraps
                                \ noposix_traps no_posix_traps noprinteightbit no_printeightbit noprint_eight_bit no_print_eight_bit noprintexitvalue no_printexitvalue
                                \ noprint_exit_value no_print_exit_value noprivileged no_privileged nopromptbang no_promptbang noprompt_bang no_prompt_bang nopromptcr no_promptcr
                                \ noprompt_cr no_prompt_cr nopromptpercent no_promptpercent noprompt_percent no_prompt_percent nopromptsp no_promptsp noprompt_sp no_prompt_sp
                                \ nopromptsubst no_promptsubst noprompt_subst no_prompt_subst nopromptvars no_promptvars noprompt_vars no_prompt_vars nopushdignoredups no_pushdignoredups
                                \ nopushd_ignore_dups no_pushd_ignore_dups nopushdminus no_pushdminus nopushd_minus no_pushd_minus nopushdsilent no_pushdsilent nopushd_silent no_pushd_silent
                                \ nopushdtohome no_pushdtohome nopushd_to_home no_pushd_to_home norcexpandparam no_rcexpandparam norc_expandparam no_rc_expandparam no_rc_expand_param norcquotes no_rcquotes
                                \ norc_quotes no_rc_quotes norcs no_rcs norecexact no_recexact norec_exact no_rec_exact norematchpcre no_rematchpcre nore_match_pcre no_re_match_pcre no_rematch_pcre
                                \ norestricted no_restricted normstarsilent no_rmstarsilent norm_star_silent no_rm_star_silent normstarwait no_rmstarwait norm_star_wait no_rm_star_wait
                                \ nosharehistory no_sharehistory noshare_history no_share_history noshfileexpansion no_shfileexpansion nosh_file_expansion no_sh_file_expansion
                                \ noshglob no_shglob nosh_glob no_sh_glob noshinstdin no_shinstdin noshin_stdin no_shin_stdin noshnullcmd no_shnullcmd nosh_nullcmd no_sh_nullcmd
                                \ noshoptionletters no_shoptionletters nosh_option_letters no_sh_option_letters noshortloops no_shortloops noshort_loops no_short_loops noshwordsplit no_shwordsplit
                                \ nosh_word_split no_sh_word_split nosinglecommand no_singlecommand nosingle_command no_single_command nosinglelinezle no_singlelinezle nosingle_line_zle no_single_line_zle
                                \ nosourcetrace no_sourcetrace nosource_trace no_source_trace nostdin no_stdin nosunkeyboardhack no_sunkeyboardhack nosun_keyboard_hack no_sun_keyboard_hack
                                \ notrackall no_trackall notrack_all no_track_all notransientrprompt no_transientrprompt notransient_rprompt no_transient_rprompt
                                \ notrapsasync no_trapsasync notrapasync no_trapasync no_traps_async notypesetsilent no_typesetsilent notype_set_silent no_type_set_silent no_typeset_silent \nounset no_unset
                                \ noverbose no_verbose novi no_vi nowarncreateglobal no_warncreateglobal nowarn_create_global no_warn_create_global noxtrace no_xtrace nozle no_zle
syn case match

syn keyword zshTypes            float integer local typeset declare private

" XXX: this may be too much
" syn match   zshSwitches         '\s\zs--\=[a-zA-Z0-9-]\+'

syn match   zshNumber           '[+-]\=\<\d\+\>'
syn match   zshNumber           '[+-]\=\<0x\x\+\>'
syn match   zshNumber           '[+-]\=\<0\o\+\>'
syn match   zshNumber           '[+-]\=\d\+#[-+]\=\w\+\>'
syn match   zshNumber           '[+-]\=\d\+\.\d\+\>'

" TODO: $[...] is the same as $((...)), so add that as well.
syn cluster zshSubst            contains=zshSubst,zshOldSubst,zshMathSubst
syn region  zshSubst            matchgroup=zshSubstDelim transparent
                                \ start='\$(' skip='\\)' end=')' contains=TOP fold
syn region  zshParentheses      transparent start='(' skip='\\)' end=')' fold
syn region  zshMathSubst        matchgroup=zshSubstDelim transparent
                                \ start='\$((' skip='\\)'
                                \ matchgroup=zshSubstDelim end='))'
                                \ contains=zshParentheses,@zshSubst,zshNumber,
                                \ @zshDerefs,zshString keepend fold
syn region  zshBrackets         contained transparent start='{' skip='\\}'
                                \ end='}' fold
syn region  zshBrackets         transparent start='{' skip='\\}'
                                \ end='}' contains=TOP fold
syn region  zshSubst            matchgroup=zshSubstDelim start='\${' skip='\\}'
                                \ end='}' contains=@zshSubst,zshBrackets,zshQuoted,zshString fold
syn region  zshOldSubst         matchgroup=zshSubstDelim start=+`+ skip=+\\`+
                                \ end=+`+ contains=TOP,zshOldSubst fold

syn sync    minlines=50 maxlines=90
syn sync    match zshHereDocSync    grouphere   NONE '<<-\=\s*\%(\\\=\S\+\|\(["']\)\S\+\1\)'
syn sync    match zshHereDocEndSync groupthere  NONE '^\s*EO\a\+\>'

hi def link zshTodo             Todo
hi def link zshComment          Comment
hi def link zshPreProc          PreProc
hi def link zshQuoted           SpecialChar
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
if s:zsh_syntax_variables =~ 'short\|all'
  hi def link zshShortDeref     zshDereferencing
else
  hi def link zshShortDeref     None
endif
if s:zsh_syntax_variables =~ 'long\|all'
  hi def link zshLongDeref      zshDereferencing
else
  hi def link zshLongDeref      None
endif
if s:zsh_syntax_variables =~ 'all'
  hi def link zshDeref          zshDereferencing
else
  hi def link zshDeref          None
endif
hi def link zshCommands         Keyword
hi def link zshOptions          Constant
hi def link zshTypes            Type
hi def link zshSwitches         Special
hi def link zshNumber           Number
hi def link zshSubst            PreProc
hi def link zshMathSubst        zshSubst
hi def link zshOldSubst         zshSubst
hi def link zshSubstDelim       zshSubst

let b:current_syntax = "zsh"

let &cpo = s:cpo_save
unlet s:cpo_save
