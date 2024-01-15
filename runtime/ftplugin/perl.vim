" Vim filetype plugin file
" Language:      Perl
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2021 Nov 10
"                2023 Sep 07 by Vim Project (safety check: don't execute perl
"                    from current directory)
"                2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

setlocal formatoptions-=t
setlocal formatoptions+=crqol
setlocal keywordprg=perldoc\ -f

setlocal comments=:#
setlocal commentstring=#%s

" Provided by Ned Konz <ned at bike-nomad dot com>
"---------------------------------------------
setlocal include=\\<\\(use\\\|require\\)\\>
" '+' is removed to support plugins in Catalyst or DBIx::Class
" where the leading plus indicates a fully-qualified module name.
setlocal includeexpr=substitute(substitute(substitute(substitute(v:fname,'+','',''),'::','/','g'),'->\*','',''),'$','.pm','')
setlocal define=[^A-Za-z_]
setlocal iskeyword+=:

" The following line changes a global variable but is necessary to make
" gf and similar commands work. Thanks to Andrew Pimlott for pointing
" out the problem.
let s:old_isfname = &isfname
set isfname+=:
let s:new_isfname = &isfname

augroup perl_global_options
  au!
  exe "au BufEnter * if &filetype == 'perl' | let &isfname = '" . s:new_isfname . "' | endif"
  exe "au BufLeave * if &filetype == 'perl' | let &isfname = '" . s:old_isfname . "' | endif"
augroup END

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal fo< kp< com< cms< inc< inex< def< isk<" .
      \               " | let &isfname = '" .  s:old_isfname . "'"

if get(g:, 'perl_fold', 0)
  setlocal foldmethod=syntax
  let b:undo_ftplugin .= " | setlocal fdm<"
endif

" Set this once, globally.
if !exists("perlpath")
    " safety check: don't execute perl binary by default
    if dist#vim#IsSafeExecutable('perl', 'perl')
      try
	if &shellxquote != '"'
	    let perlpath = system('perl -e "print join(q/,/,@INC)"')
	else
	    let perlpath = system("perl -e 'print join(q/,/,@INC)'")
	endif
	let perlpath = substitute(perlpath,',.$',',,','')
      catch /E145:/
	let perlpath = ".,,"
      endtry
    else
	" If we can't call perl to get its path, just default to using the
	" current directory and the directory of the current file.
	let perlpath = ".,,"
    endif
endif

" Append perlpath to the existing path value, if it is set.  Since we don't
" use += to do it because of the commas in perlpath, we have to handle the
" global / local settings, too.
if &l:path == ""
    if &g:path == ""
        let &l:path=perlpath
    else
        let &l:path=&g:path.",".perlpath
    endif
else
    let &l:path=&l:path.",".perlpath
endif

let b:undo_ftplugin .= " | setlocal pa<"
"---------------------------------------------

" Change the browse dialog to show mainly Perl-related files
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter = "Perl Source Files (*.pl)\t*.pl\n" .
		       \ "Perl Modules (*.pm)\t*.pm\n" .
		       \ "Perl Documentation Files (*.pod)\t*.pod\n"
    if has("win32")
	let b:browsefilter .= "All Files (*.*)\t*\n"
    else
	let b:browsefilter .= "All Files (*)\t*\n"
    endif
    let b:undo_ftplugin .= " | unlet! b:browsefilter"
endif

" Proper matching for matchit plugin
if exists("loaded_matchit") && !exists("b:match_words")
    let b:match_skip = 's:comment\|string\|perlQQ\|perlShellCommand\|perlHereDoc\|perlSubstitution\|perlTranslation\|perlMatch\|perlFormatField'
    let b:match_words = '\<if\>:\<elsif\>:\<else\>'
    let b:undo_ftplugin .= " | unlet! b:match_words b:match_skip"
endif

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo s:old_isfname s:new_isfname
