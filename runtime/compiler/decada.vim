"------------------------------------------------------------------------------
"  Description: Vim Ada/Dec Ada compiler file
"     Language: Ada (Dec Ada)
"          $Id: decada.vim 887 2008-07-08 14:29:01Z krischik $
"    Copyright: Copyright (C) 2006 Martin Krischik
"   Maintainer:	Martin Krischik <krischik@users.sourceforge.net>
"      $Author: krischik $
"        $Date: 2008-07-08 16:29:01 +0200 (Di, 08 Jul 2008) $
"      Version: 4.6
"    $Revision: 887 $
"     $HeadURL: https://gnuada.svn.sourceforge.net/svnroot/gnuada/trunk/tools/vim/compiler/decada.vim $
"      History: 21.07.2006 MK New Dec Ada
"               15.10.2006 MK Bram's suggestion for runtime integration
"               08.09.2006 MK Correct double load protection.
"    Help Page: compiler-decada
"------------------------------------------------------------------------------

if (exists("current_compiler") && current_compiler == "decada") || version < 700
   finish
endif
let s:keepcpo= &cpo
set cpo&vim

let current_compiler = "decada"

if !exists("g:decada")
   let g:decada = decada#New ()

   call ada#Map_Menu (
     \'Dec Ada.Build',
     \'<F7>',
     \'call decada.Make ()')

   call g:decada.Set_Session ()
endif

if exists(":CompilerSet") != 2
   "
   " plugin loaded by other means then the "compiler" command
   "
   command -nargs=* CompilerSet setlocal <args>
endif

execute "CompilerSet makeprg="     . escape (g:decada.Make_Command, ' ')
execute "CompilerSet errorformat=" . escape (g:decada.Error_Format, ' ')

let &cpo = s:keepcpo
unlet s:keepcpo

finish " 1}}}

"------------------------------------------------------------------------------
"   Copyright (C) 2006  Martin Krischik
"
"   Vim is Charityware - see ":help license" or uganda.txt for licence details.
"------------------------------------------------------------------------------
" vim: textwidth=78 wrap tabstop=8 shiftwidth=3 softtabstop=3 noexpandtab
" vim: foldmethod=marker
