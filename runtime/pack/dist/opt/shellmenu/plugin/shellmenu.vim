" When you're writing shell scripts and you are in doubt which test to use,
" which shell environment variables are defined, what the syntax of the case
" statement is, and you need to invoke 'man sh'?
"
" Your problems are over now!
"
" Attached is a Vim script file for turning gvim into a shell script editor.
" It may also be used as an example how to use menus in Vim.
"
" Maintainer: Ada (Haowen) Yu <me@yuhaowen.com>
" Original author: Lennart Schultz <les@dmi.min.dk> (mail unreachable)

" Make sure the '<' and 'C' flags are not included in 'cpoptions', otherwise
" <CR> would not be recognized.  See ":help 'cpoptions'".
let s:cpo_save = &cpo
set cpo&vim

imenu ShellMenu.Statements.for	for  in <CR>do<CR><CR>done<esc>ki	<esc>kk0elli
imenu ShellMenu.Statements.case	case  in<CR>) ;;<CR>esac<esc>bki	<esc>k0elli
imenu ShellMenu.Statements.if	if   <CR>then<CR><CR>fi<esc>ki	<esc>kk0elli
imenu ShellMenu.Statements.if-else	if   <CR>then<CR><CR>else<CR><CR>fi<esc>ki	<esc>kki	<esc>kk0elli
imenu ShellMenu.Statements.elif	elif   <CR>then<CR><CR><esc>ki	<esc>kk0elli
imenu ShellMenu.Statements.while	while   do<CR><CR>done<esc>ki	<esc>kk0elli
imenu ShellMenu.Statements.break	break 
imenu ShellMenu.Statements.continue	continue 
imenu ShellMenu.Statements.function	() {<CR><CR>}<esc>ki	<esc>k0i
imenu ShellMenu.Statements.return	return 
imenu ShellMenu.Statements.return-true	return 0
imenu ShellMenu.Statements.return-false	return 1
imenu ShellMenu.Statements.exit	exit 
imenu ShellMenu.Statements.shift	shift 
imenu ShellMenu.Statements.trap	trap 
imenu ShellMenu.Test.Existence	[ -e  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ file		[ -f  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ file\ (not\ empty)	[ -s  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ directory	[ -d  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ executable	[ -x  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ readable	[ -r  ]<esc>hi
imenu ShellMenu.Test.Existence\ -\ writable	[ -w  ]<esc>hi
imenu ShellMenu.Test.String\ is\ empty [ x = "x$" ]<esc>hhi
imenu ShellMenu.Test.String\ is\ not\ empty [ x != "x$" ]<esc>hhi
imenu ShellMenu.Test.Strings\ are\ equal [ "" = "" ]<esc>hhhhhhhi
imenu ShellMenu.Test.Strings\ are\ not\ equal [ "" != "" ]<esc>hhhhhhhhi
imenu ShellMenu.Test.Value\ is\ greater\ than [  -gt  ]<esc>hhhhhhi
imenu ShellMenu.Test.Value\ is\ greater\ equal [  -ge  ]<esc>hhhhhhi
imenu ShellMenu.Test.Values\ are\ equal [  -eq  ]<esc>hhhhhhi
imenu ShellMenu.Test.Values\ are\ not\ equal [  -ne  ]<esc>hhhhhhi
imenu ShellMenu.Test.Value\ is\ less\ than [  -lt  ]<esc>hhhhhhi
imenu ShellMenu.Test.Value\ is\ less\ equal [  -le  ]<esc>hhhhhhi
imenu ShellMenu.ParmSub.Substitute\ word\ if\ parm\ not\ set ${:-}<esc>hhi
imenu ShellMenu.ParmSub.Set\ parm\ to\ word\ if\ not\ set ${:=}<esc>hhi
imenu ShellMenu.ParmSub.Substitute\ word\ if\ parm\ set\ else\ nothing ${:+}<esc>hhi
imenu ShellMenu.ParmSub.If\ parm\ not\ set\ print\ word\ and\ exit ${:?}<esc>hhi
imenu ShellMenu.SpShVars.Number\ of\ positional\ parameters ${#}
imenu ShellMenu.SpShVars.All\ positional\ parameters\ (quoted\ spaces) ${*}
imenu ShellMenu.SpShVars.All\ positional\ parameters\ (unquoted\ spaces) ${@}
imenu ShellMenu.SpShVars.Flags\ set ${-}
imenu ShellMenu.SpShVars.Return\ code\ of\ last\ command ${?}
imenu ShellMenu.SpShVars.Process\ number\ of\ this\ shell ${$}
imenu ShellMenu.SpShVars.Process\ number\ of\ last\ background\ command ${!}
imenu ShellMenu.Environ.HOME ${HOME}
imenu ShellMenu.Environ.PATH ${PATH}
imenu ShellMenu.Environ.CDPATH ${CDPATH}
imenu ShellMenu.Environ.MAIL ${MAIL}
imenu ShellMenu.Environ.MAILCHECK ${MAILCHECK}
imenu ShellMenu.Environ.PS1 ${PS1}
imenu ShellMenu.Environ.PS2 ${PS2}
imenu ShellMenu.Environ.IFS ${IFS}
imenu ShellMenu.Environ.SHACCT ${SHACCT}
imenu ShellMenu.Environ.SHELL ${SHELL}
imenu ShellMenu.Environ.LC_CTYPE ${LC_CTYPE}
imenu ShellMenu.Environ.LC_MESSAGES ${LC_MESSAGES}
imenu ShellMenu.Builtins.cd cd
imenu ShellMenu.Builtins.echo echo
imenu ShellMenu.Builtins.eval eval
imenu ShellMenu.Builtins.exec exec
imenu ShellMenu.Builtins.export export
imenu ShellMenu.Builtins.getopts getopts
imenu ShellMenu.Builtins.hash hash
imenu ShellMenu.Builtins.newgrp newgrp
imenu ShellMenu.Builtins.pwd pwd
imenu ShellMenu.Builtins.read read
imenu ShellMenu.Builtins.readonly readonly
imenu ShellMenu.Builtins.return return
imenu ShellMenu.Builtins.times times
imenu ShellMenu.Builtins.type type
imenu ShellMenu.Builtins.umask umask
imenu ShellMenu.Builtins.wait wait
imenu ShellMenu.Set.set set
imenu ShellMenu.Set.unset unset
imenu ShellMenu.Set.Mark\ created\ or\ modified\ variables\ for\ export set -a
imenu ShellMenu.Set.Exit\ when\ command\ returns\ non-zero\ status set -e
imenu ShellMenu.Set.Disable\ file\ name\ expansion set -f
imenu ShellMenu.Set.Locate\ and\ remember\ commands\ when\ being\ looked\ up set -h
imenu ShellMenu.Set.All\ assignment\ statements\ are\ placed\ in\ the\ environment\ for\ a\ command set -k
imenu ShellMenu.Set.Read\ commands\ but\ do\ not\ execute\ them set -n
imenu ShellMenu.Set.Exit\ after\ reading\ and\ executing\ one\ command set -t
imenu ShellMenu.Set.Treat\ unset\ variables\ as\ an\ error\ when\ substituting set -u
imenu ShellMenu.Set.Print\ shell\ input\ lines\ as\ they\ are\ read set -v
imenu ShellMenu.Set.Print\ commands\ and\ their\ arguments\ as\ they\ are\ executed set -x

" Restore the previous value of 'cpoptions'.
let &cpo = s:cpo_save
unlet s:cpo_save
