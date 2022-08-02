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
"     $HeadURL: https://gnuada.svn.sourceforge.net/svnroot/gnuada/trunk/tools/vim/autoload/decada.vim $
"      History: 21.07.2006 MK New Dec Ada
"               15.10.2006 MK Bram's suggestion for runtime integration
"               05.11.2006 MK Bram suggested not to use include protection for
"                             autoload
"		05.11.2006 MK Bram suggested to save on spaces
"    Help Page: compiler-decada
"------------------------------------------------------------------------------

if version < 700
   finish
endif

function decada#Unit_Name () dict				     " {{{1
    "	Convert filename into acs unit:
    "	    1:  remove the file extension.
    "	    2:  replace all double '_' or '-' with an dot (which denotes a separate)
    "	    3:  remove a trailing '_' (which denotes a specification)
    return substitute (substitute (expand ("%:t:r"), '__\|-', ".", "g"), '_$', "", '')
endfunction decada#Unit_Name					     " }}}1

function decada#Make () dict					     " {{{1
    let l:make_prg   = substitute (g:self.Make_Command, '%<', self.Unit_Name(), '')
    let &errorformat = g:self.Error_Format
    let &makeprg     = l:make_prg
    wall
    make
    copen
    set wrap
    wincmd W
endfunction decada#Build					     " }}}1

function decada#Set_Session (...) dict				     " {{{1
   if a:0 > 0
      call ada#Switch_Session (a:1)
   elseif argc() == 0 && strlen (v:servername) > 0
      call ada#Switch_Session (
	 \ expand('~')[0:-2] . ".vimfiles.session]decada_" .
	 \ v:servername . ".vim")
   endif
   return
endfunction decada#Set_Session					     " }}}1

function decada#New ()						     " }}}1
   let Retval = {
      \ 'Make'		: function ('decada#Make'),
      \ 'Unit_Name'	: function ('decada#Unit_Name'),
      \ 'Set_Session'   : function ('decada#Set_Session'),
      \ 'Project_Dir'   : '',
      \ 'Make_Command'  : 'ACS COMPILE /Wait /Log /NoPreLoad /Optimize=Development /Debug %<',
      \ 'Error_Format'  : '%+A%%ADAC-%t-%m,%C  %#%m,%Zat line number %l in file %f,' .
			\ '%+I%%ada-I-%m,%C  %#%m,%Zat line number %l in file %f'}

   return Retval 
endfunction decada#New						     " }}}1

finish " 1}}}

"------------------------------------------------------------------------------
"   Copyright (C) 2006  Martin Krischik
"
"   Vim is Charityware - see ":help license" or uganda.txt for licence details.
"------------------------------------------------------------------------------
" vim: textwidth=78 wrap tabstop=8 shiftwidth=3 softtabstop=3 noexpandtab
" vim: foldmethod=marker
