" When you're writing shell scripts and you are in doubt which test to use,
" which shell environment variables are defined, what the syntax of the case
" statement is, and you need to invoke 'man sh'?
"
" Your problems are over now!
"
" Attached is a Vim script file for turning gvim into a shell script editor.
" It may also be used as an example how to use menus in Vim.
"
" Written by: Lennart Schultz <les@dmi.min.dk>

imenu Stmts.for	for  in dodoneki	kk0elli
imenu Stmts.case	case  in) ;;esacbki	k0elli
imenu Stmts.if	if   thenfiki	kk0elli
imenu Stmts.if-else	if   thenelsefiki	kki	kk0elli
imenu Stmts.elif	elif   thenki	kk0elli
imenu Stmts.while	while   dodoneki	kk0elli
imenu Stmts.break	break 
imenu Stmts.continue	continue 
imenu Stmts.function	() {}ki	k0i
imenu Stmts.return	return 
imenu Stmts.return-true	return 0
imenu Stmts.return-false	return 1
imenu Stmts.exit	exit 
imenu Stmts.shift	shift 
imenu Stmts.trap	trap 
imenu Test.existence	[ -e  ]hi
imenu Test.existence - file		[ -f  ]hi
imenu Test.existence - file (not empty)	[ -s  ]hi
imenu Test.existence - directory	[ -d  ]hi
imenu Test.existence - executable	[ -x  ]hi
imenu Test.existence - readable	[ -r  ]hi
imenu Test.existence - writable	[ -w  ]hi
imenu Test.String is empty [ x = "x$" ]hhi
imenu Test.String is not empty [ x != "x$" ]hhi
imenu Test.Strings is equal [ "" = "" ]hhhhhhhi
imenu Test.Strings is not equal [ "" != "" ]hhhhhhhhi
imenu Test.Values is greater than [  -gt  ]hhhhhhi
imenu Test.Values is greater equal [  -ge  ]hhhhhhi
imenu Test.Values is equal [  -eq  ]hhhhhhi
imenu Test.Values is not equal [  -ne  ]hhhhhhi
imenu Test.Values is less than [  -lt  ]hhhhhhi
imenu Test.Values is less equal [  -le  ]hhhhhhi
imenu ParmSub.Substitute word if parm not set ${:-}hhi
imenu ParmSub.Set parm to word if not set ${:=}hhi
imenu ParmSub.Substitute word if parm set else nothing ${:+}hhi
imenu ParmSub.If parm not set print word and exit ${:?}hhi
imenu SpShVars.Number of positional parameters ${#}
imenu SpShVars.All positional parameters (quoted spaces) ${*}
imenu SpShVars.All positional parameters (unquoted spaces) ${@}
imenu SpShVars.Flags set ${-}
imenu SpShVars.Return code of last command ${?}
imenu SpShVars.Process number of this shell ${$}
imenu SpShVars.Process number of last background command ${!}
imenu Environ.HOME ${HOME}
imenu Environ.PATH ${PATH}
imenu Environ.CDPATH ${CDPATH}
imenu Environ.MAIL ${MAIL}
imenu Environ.MAILCHECK ${MAILCHECK}
imenu Environ.PS1 ${PS1}
imenu Environ.PS2 ${PS2}
imenu Environ.IFS ${IFS}
imenu Environ.SHACCT ${SHACCT}
imenu Environ.SHELL ${SHELL}
imenu Environ.LC_CTYPE ${LC_CTYPE}
imenu Environ.LC_MESSAGES ${LC_MESSAGES}
imenu Builtins.cd cd
imenu Builtins.echo echo
imenu Builtins.eval eval
imenu Builtins.exec exec
imenu Builtins.export export
imenu Builtins.getopts getopts
imenu Builtins.hash hash
imenu Builtins.newgrp newgrp
imenu Builtins.pwd pwd
imenu Builtins.read read
imenu Builtins.readonly readonly
imenu Builtins.return return
imenu Builtins.times times
imenu Builtins.type type
imenu Builtins.umask umask
imenu Builtins.wait wait
imenu Set.set set
imenu Set.unset unset
imenu Set.mark modified or modified variables set -a
imenu Set.exit when command returns non-zero exit code set -e
imenu Set.Disable file name generation set -f
imenu Set.remember function commands set -h
imenu Set.All keyword arguments are placed in the environment set -k
imenu Set.Read commands but do not execute them set -n
imenu Set.Exit after reading and executing one command set -t
imenu Set.Treat unset variables as an error when substituting set -u
imenu Set.Print shell input lines as they are read set -v
imenu Set.Print commands and their arguments as they are executed set -x
