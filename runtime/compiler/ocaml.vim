" Vim Compiler File
" Compiler:    ocaml
" Maintainer:  Markus Mottl <markus.mottl@gmail.com>
" URL:         https://github.com/rgrinberg/vim-ocaml
" Last Change:
"              2017 Nov 26 - Improved error format (Markus Mottl)
"              2013 Aug 27 - Added a new OCaml error format (Markus Mottl)
"              2013 Jun 30 - Initial version (Marc Weber)
"
" Marc Weber's comments:
" Setting makeprg doesn't make sense, because there is ocamlc, ocamlopt,
" ocamake and whatnot. So which one to use?
"
" This error format was moved from ftplugin/ocaml.vim to this file,
" because ftplugin is the wrong file to set an error format
" and the error format itself is annoying because it joins many lines in this
" error case:
"
"    Error: The implementation foo.ml does not match the interface foo.cmi:
"    Modules do not match case.
"
" So having it here makes people opt-in

if exists("current_compiler")
    finish
endif
let current_compiler = "ocaml"

let s:cpo_save = &cpo
set cpo&vim

CompilerSet errorformat =
      \%EFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d:,
      \%EFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d\ %.%#,
      \%EFile\ \"%f\"\\,\ line\ %l\\,\ character\ %c:%m,
      \%+EReference\ to\ unbound\ regexp\ name\ %m,
      \%Eocamlyacc:\ e\ -\ line\ %l\ of\ \"%f\"\\,\ %m,
      \%Wocamlyacc:\ w\ -\ %m,
      \%-Zmake%.%#,
      \%C%m,
      \%D%*\\a[%*\\d]:\ Entering\ directory\ `%f',
      \%X%*\\a[%*\\d]:\ Leaving\ directory\ `%f',
      \%D%*\\a:\ Entering\ directory\ `%f',
      \%X%*\\a:\ Leaving\ directory\ `%f',
      \%D%*\\a[%*\\d]:\ Entering\ directory\ '%f',
      \%X%*\\a[%*\\d]:\ Leaving\ directory\ '%f',
      \%D%*\\a:\ Entering\ directory\ '%f',
      \%X%*\\a:\ Leaving\ directory\ '%f',
      \%DEntering\ directory\ '%f',
      \%XLeaving\ directory\ '%f',
      \%DMaking\ %*\\a\ in\ %f

let &cpo = s:cpo_save
unlet s:cpo_save
