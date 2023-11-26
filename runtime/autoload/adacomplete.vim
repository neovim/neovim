"------------------------------------------------------------------------------
"  Description: Vim Ada omnicompletion file
"     Language:	Ada (2005)
"	   $Id: adacomplete.vim 887 2008-07-08 14:29:01Z krischik $
"   Maintainer:	Martin Krischik
"      $Author: krischik $
"	 $Date: 2008-07-08 16:29:01 +0200 (Di, 08 Jul 2008) $
"      Version: 4.6
"    $Revision: 887 $
"     $HeadURL: https://gnuada.svn.sourceforge.net/svnroot/gnuada/trunk/tools/vim/autoload/adacomplete.vim $
"      History: 24.05.2006 MK Unified Headers
"		26.05.2006 MK improved search for begin of word.
"		16.07.2006 MK Ada-Mode as vim-ball
"		15.10.2006 MK Bram's suggestion for runtime integration
"		05.11.2006 MK Bram suggested not to use include protection for
"			      autoload
"		05.11.2006 MK Bram suggested against using setlocal omnifunc 
"		05.11.2006 MK Bram suggested to save on spaces
"    Help Page: ft-ada-omni
"------------------------------------------------------------------------------

if version < 700
   finish
endif

" Section: adacomplete#Complete () {{{1
"
" This function is used for the 'omnifunc' option.
"
function! adacomplete#Complete (findstart, base)
   if a:findstart == 1
      return ada#User_Complete (a:findstart, a:base)
   else
      "
      " look up matches
      "
      if exists ("g:ada_omni_with_keywords")
	 call ada#User_Complete (a:findstart, a:base)
      endif
      "
      "  search tag file for matches
      "
      let l:Pattern  = '^' . a:base . '.*$'
      let l:Tag_List = taglist (l:Pattern)
      "
      " add symbols
      "
      for Tag_Item in l:Tag_List
	 if l:Tag_Item['kind'] == ''
	    "
	    " Tag created by gnat xref
	    "
	    let l:Match_Item = {
	       \ 'word':  l:Tag_Item['name'],
	       \ 'menu':  l:Tag_Item['filename'],
	       \ 'info':  "Symbol from file " . l:Tag_Item['filename'] . " line " . l:Tag_Item['cmd'],
	       \ 'kind':  's',
	       \ 'icase': 1}
	 else
	    "
	    " Tag created by ctags
	    "
	    let l:Info	= 'Symbol		 : ' . l:Tag_Item['name']  . "\n"
	    let l:Info .= 'Of type		 : ' . g:ada#Ctags_Kinds[l:Tag_Item['kind']][1]  . "\n"
	    let l:Info .= 'Defined in File	 : ' . l:Tag_Item['filename'] . "\n"

	    if has_key( l:Tag_Item, 'package')
	       let l:Info .= 'Package		    : ' . l:Tag_Item['package'] . "\n"
	       let l:Menu  = l:Tag_Item['package']
	    elseif has_key( l:Tag_Item, 'separate')
	       let l:Info .= 'Separate from Package : ' . l:Tag_Item['separate'] . "\n"
	       let l:Menu  = l:Tag_Item['separate']
	    elseif has_key( l:Tag_Item, 'packspec')
	       let l:Info .= 'Package Specification : ' . l:Tag_Item['packspec'] . "\n"
	       let l:Menu  = l:Tag_Item['packspec']
	    elseif has_key( l:Tag_Item, 'type')
	       let l:Info .= 'Datetype		    : ' . l:Tag_Item['type'] . "\n"
	       let l:Menu  = l:Tag_Item['type']
	    else
	       let l:Menu  = l:Tag_Item['filename']
	    endif

	    let l:Match_Item = {
	       \ 'word':  l:Tag_Item['name'],
	       \ 'menu':  l:Menu,
	       \ 'info':  l:Info,
	       \ 'kind':  l:Tag_Item['kind'],
	       \ 'icase': 1}
	 endif
	 if complete_add (l:Match_Item) == 0
	    return []
	 endif
	 if complete_check ()
	    return []
	 endif
      endfor
      return []
   endif
endfunction adacomplete#Complete

finish " 1}}}

"------------------------------------------------------------------------------
"   Copyright (C) 2006	Martin Krischik
"
"   Vim is Charityware - see ":help license" or uganda.txt for licence details.
"------------------------------------------------------------------------------
" vim: textwidth=78 wrap tabstop=8 shiftwidth=3 softtabstop=3 noexpandtab
" vim: foldmethod=marker
