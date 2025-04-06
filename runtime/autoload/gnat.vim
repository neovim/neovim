"------------------------------------------------------------------------------
"  Description: Vim Ada/GNAT compiler file
"     Language: Ada (GNAT)
"          $Id: gnat.vim 887 2008-07-08 14:29:01Z krischik $
"    Copyright: Copyright (C) 2006 Martin Krischik
"   Maintainer:	Martin Krischi <krischik@users.sourceforge.net>k
"		Ned Okie <nokie@radford.edu>
"      $Author: krischik $
"        $Date: 2008-07-08 16:29:01 +0200 (Di, 08 Jul 2008) $
"      Version: 4.6
"    $Revision: 887 $
"     $HeadURL: https://gnuada.svn.sourceforge.net/svnroot/gnuada/trunk/tools/vim/autoload/gnat.vim $
"      History: 24.05.2006 MK Unified Headers
"		16.07.2006 MK Ada-Mode as vim-ball
"		05.08.2006 MK Add session support
"               15.10.2006 MK Bram's suggestion for runtime integration
"               05.11.2006 MK Bram suggested not to use include protection for
"                             autoload
"		05.11.2006 MK Bram suggested to save on spaces
"		19.09.2007 NO use project file only when there is a project
"    Help Page: compiler-gnat
"------------------------------------------------------------------------------

if version < 700
    finish
endif

function gnat#Make () dict					     " {{{1
   let &l:makeprg	 = self.Get_Command('Make')
   let &l:errorformat = self.Error_Format
   wall
   make
   copen
   set wrap
   wincmd W
endfunction gnat#Make						     " }}}1

function gnat#Pretty () dict					     " {{{1
   execute "!" . self.Get_Command('Pretty')
endfunction gnat#Make						     " }}}1

function gnat#Find () dict					     " {{{1
   execute "!" . self.Get_Command('Find')
endfunction gnat#Find						     " }}}1

function gnat#Tags () dict					     " {{{1
   execute "!" . self.Get_Command('Tags')
   edit tags
   call gnat#Insert_Tags_Header ()
   update
   quit
endfunction gnat#Tags						     " }}}1

function gnat#Set_Project_File (...) dict			     " {{{1
   if a:0 > 0
      let self.Project_File = a:1

      if ! filereadable (self.Project_File)
	 let self.Project_File = findfile (
	    \ fnamemodify (self.Project_File, ':r'),
	    \ $ADA_PROJECT_PATH,
	    \ 1)
      endif
   elseif strlen (self.Project_File) > 0
      let self.Project_File = browse (0, 'GNAT Project File?', '', self.Project_File)
   elseif expand ("%:e") == 'gpr'
      let self.Project_File = browse (0, 'GNAT Project File?', '', expand ("%:e"))
   else
      let self.Project_File = browse (0, 'GNAT Project File?', '', 'default.gpr')
   endif

   if strlen (v:this_session) > 0
      execute 'mksession! ' . v:this_session
   endif

   "if strlen (self.Project_File) > 0
      "if has("vms")
	 "call ada#Switch_Session (
	    "\ expand('~')[0:-2] . ".vimfiles.session]gnat_" .
	    "\ fnamemodify (self.Project_File, ":t:r") . ".vim")
      "else
	 "call ada#Switch_Session (
	    "\ expand('~') . "/vimfiles/session/gnat_" .
	    "\ fnamemodify (self.Project_File, ":t:r") . ".vim")
      "endif
   "else
      "call ada#Switch_Session ('')
   "endif

   return
endfunction gnat#Set_Project_File				     " }}}1

function gnat#Get_Command (Command) dict			     " {{{1
   let l:Command = eval ('self.' . a:Command . '_Command')
   return eval (l:Command)
endfunction gnat#Get_Command					     " }}}1

function gnat#Set_Session (...) dict				     " {{{1
   if argc() == 1 && fnamemodify (argv(0), ':e') == 'gpr'
      call self.Set_Project_File (argv(0))
   elseif  strlen (v:servername) > 0
      call self.Set_Project_File (v:servername . '.gpr')
   endif
endfunction gnat#Set_Session					     " }}}1

function gnat#New ()						     " {{{1
   let l:Retval = {
      \ 'Make'	      : function ('gnat#Make'),
      \ 'Pretty'	      : function ('gnat#Pretty'),
      \ 'Find'	      : function ('gnat#Find'),
      \ 'Tags'	      : function ('gnat#Tags'),
      \ 'Set_Project_File' : function ('gnat#Set_Project_File'),
      \ 'Set_Session'      : function ('gnat#Set_Session'),
      \ 'Get_Command'      : function ('gnat#Get_Command'),
      \ 'Project_File'     : '',
      \ 'Make_Command'     : '"gnat make -P " . self.Project_File . "  -F -gnatef  "',
      \ 'Pretty_Command'   : '"gnat pretty -P " . self.Project_File . " "',
      \ 'Find_Program'     : '"gnat find -P " . self.Project_File . " -F "',
      \ 'Tags_Command'     : '"gnat xref -P " . self.Project_File . " -v  *.AD*"',
      \ 'Error_Format'     : '%f:%l:%c: %trror: %m,'   .
			   \ '%f:%l:%c: %tarning: %m,' .
			   \ '%f:%l:%c: (%ttyle) %m'}

   return l:Retval
endfunction gnat#New						  " }}}1

function gnat#Insert_Tags_Header ()				  " {{{1
   1insert
!_TAG_FILE_FORMAT       1	 /extended format; --format=1 will not append ;" to lines/
!_TAG_FILE_SORTED       1	 /0=unsorted, 1=sorted, 2=foldcase/
!_TAG_PROGRAM_AUTHOR    AdaCore	 /info@adacore.com/
!_TAG_PROGRAM_NAME      gnatxref //
!_TAG_PROGRAM_URL       http://www.adacore.com  /official site/
!_TAG_PROGRAM_VERSION   5.05w   //
.
   return
endfunction gnat#Insert_Tags_Header				  " }}}1

finish " 1}}}

"------------------------------------------------------------------------------
"   Copyright (C) 2006  Martin Krischik
"
"   Vim is Charityware - see ":help license" or uganda.txt for licence details.
"------------------------------------------------------------------------------
" vim: textwidth=0 wrap tabstop=8 shiftwidth=3 softtabstop=3 noexpandtab
" vim: foldmethod=marker
