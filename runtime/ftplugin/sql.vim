" SQL filetype plugin file
" Language:    SQL (Common for Oracle, Microsoft SQL Server, Sybase)
" Version:     12.0
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Last Change: 2017 Mar 07
" Download:    http://vim.sourceforge.net/script.php?script_id=454

" For more details please use:
"        :h sql.txt
"
" This file should only contain values that are common to all SQL languages
" Oracle, Microsoft SQL Server, Sybase ASA/ASE, MySQL, and so on
" If additional features are required create:
"        vimfiles/after/ftplugin/sql.vim (Windows)
"        .vim/after/ftplugin/sql.vim     (Unix)
" to override and add any of your own settings.


" This file also creates a command, SQLSetType, which allows you to change
" SQL dialects on the fly.  For example, if I open an Oracle SQL file, it
" is color highlighted appropriately.  If I open an Informix SQL file, it
" will still be highlighted according to Oracles settings.  By running:
"     :SQLSetType sqlinformix
"
" All files called sqlinformix.vim will be loaded from the indent and syntax
" directories.  This allows you to easily flip SQL dialects on a per file
" basis.  NOTE: you can also use completion:
"     :SQLSetType <tab>
"
" To change the default dialect, add the following to your vimrc:
"    let g:sql_type_default = 'sqlanywhere'
"
" This file also creates a command, SQLGetType, which allows you to
" determine what the current dialect is in use.
"     :SQLGetType
"
" History
"
" Version 12.0 (April 2013)
"
" NF: Added support for "BEGIN TRY ... END TRY ... BEGIN CATCH ... END CATCH
" BF: This plugin is designed to be used with other plugins to enable the 
"     SQL completion with Perl, Python, Java, ...  The loading mechanism 
"     was not checking if the SQL objects were created, which can lead to 
"     the plugin not loading the SQL support.
"
" Version 11.0 (May 2013)
"
" NF: Updated to use SyntaxComplete's new regex support for syntax groups.
"
" Version 10.0 (Dec 2012)
"
" NF: Changed all maps to use noremap instead of must map
" NF: Changed all visual maps to use xnoremap instead of vnoremap as they
"     should only be used in visual mode and not select mode.
" BF: Most of the maps were using doubled up backslashes before they were
"     changed to using the search() function, which meant they no longer
"     worked.
"
" Version 9.0
"
" NF: Completes 'b:undo_ftplugin'
" BF: Correctly set cpoptions when creating script
"
" Version 8.0
"
" NF: Improved the matchit plugin regex (Talek)
"
" Version 7.0
"
" NF: Calls the sqlcomplete#ResetCacheSyntax() function when calling
"     SQLSetType.
"
" Version 6.0
"
" NF: Adds the command SQLGetType
"
" Version 5.0
"
" NF: Adds the ability to choose the keys to control SQL completion, just add
"     the following to your .vimrc:
"    let g:ftplugin_sql_omni_key       = '<C-C>'
"    let g:ftplugin_sql_omni_key_right = '<Right>'
"    let g:ftplugin_sql_omni_key_left  = '<Left>'
"
" BF: format-options - Auto-wrap comments using textwidth was turned off
"                      by mistake.


" Only do this when not done yet for this buffer
" This ftplugin can be used with other ftplugins.  So ensure loading
" happens if all elements of this plugin have not yet loaded.
if exists("b:did_ftplugin") && exists("b:current_ftplugin") && b:current_ftplugin == 'sql'
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

" Disable autowrapping for code, but enable for comments
" t     Auto-wrap text using textwidth
" c     Auto-wrap comments using textwidth, inserting the current comment
"       leader automatically.
setlocal formatoptions-=t
setlocal formatoptions+=c

" Functions/Commands to allow the user to change SQL syntax dialects
" through the use of :SQLSetType <tab> for completion.
" This works with both Vim 6 and 7.

if !exists("*SQL_SetType")
    " NOTE: You cannot use function! since this file can be
    " sourced from within this function.  That will result in
    " an error reported by Vim.
    function SQL_GetList(ArgLead, CmdLine, CursorPos)

        if !exists('s:sql_list')
            " Grab a list of files that contain "sql" in their names
            let list_indent   = globpath(&runtimepath, 'indent/*sql*')
            let list_syntax   = globpath(&runtimepath, 'syntax/*sql*')
            let list_ftplugin = globpath(&runtimepath, 'ftplugin/*sql*')

            let sqls = "\n".list_indent."\n".list_syntax."\n".list_ftplugin."\n"

            " Strip out everything (path info) but the filename
            " Regex
            "    From between two newline characters
            "    Non-greedily grab all characters
            "    Followed by a valid filename \w\+\.\w\+ (sql.vim)
            "    Followed by a newline, but do not include the newline
            "
            "    Replace it with just the filename (get rid of PATH)
            "
            "    Recursively, since there are many filenames that contain
            "    the word SQL in the indent, syntax and ftplugin directory
            let sqls = substitute( sqls,
                        \ '[\n]\%(.\{-}\)\(\w\+\.\w\+\)\n\@=',
                        \ '\1\n',
                        \ 'g'
                        \ )

            " Remove duplicates, since sqlanywhere.vim can exist in the
            " sytax, indent and ftplugin directory, yet we only want
            " to display the option once
            let index = match(sqls, '.\{-}\ze\n')
            while index > -1
                " Get the first filename
                let file = matchstr(sqls, '.\{-}\ze\n', index)
                " Recursively replace any *other* occurrence of that
                " filename with nothing (ie remove it)
                let sqls = substitute(sqls, '\%>'.(index+strlen(file)).'c\<'.file.'\>\n', '', 'g')
                " Move on to the next filename
                let index = match(sqls, '.\{-}\ze\n', (index+strlen(file)+1))
            endwhile

            " Sort the list if using version 7
            if v:version >= 700
                let mylist = split(sqls, "\n")
                let mylist = sort(mylist)
                let sqls   = join(mylist, "\n")
            endif

            let s:sql_list = sqls
        endif

        return s:sql_list

    endfunction

    function SQL_SetType(name)

        " User has decided to override default SQL scripts and
        " specify a vendor specific version
        " (ie Oracle, Informix, SQL Anywhere, ...)
        " So check for an remove any settings that prevent the
        " scripts from being executed, and then source the
        " appropriate Vim scripts.
        if exists("b:did_ftplugin")
            unlet b:did_ftplugin
        endif
        if exists("b:current_syntax")
            " echomsg 'SQLSetType - clearing syntax'
            syntax clear
            if exists("b:current_syntax")
                unlet b:current_syntax
            endif
        endif
        if exists("b:did_indent")
            " echomsg 'SQLSetType - clearing indent'
            unlet b:did_indent
            " Set these values to their defaults
            setlocal indentkeys&
            setlocal indentexpr&
        endif

        " Ensure the name is in the correct format
        let new_sql_type = substitute(a:name,
                    \ '\s*\([^\.]\+\)\(\.\w\+\)\?', '\L\1', '')

        " Do not specify a buffer local variable if it is
        " the default value
        if new_sql_type == 'sql'
            let new_sql_type = 'sqloracle'
        endif
        let b:sql_type_override = new_sql_type

        " Remove any cached SQL since a new sytax will have different
        " items and groups
        if !exists('g:loaded_sql_completion') || g:loaded_sql_completion >= 100
            call sqlcomplete#ResetCacheSyntax()
        endif

        " Vim will automatically source the correct files if we
        " change the filetype.  You cannot do this with setfiletype
        " since that command will only execute if a filetype has
        " not already been set.  In this case we want to override
        " the existing filetype.
        let &filetype = 'sql'

        if b:sql_compl_savefunc != ""
            " We are changing the filetype to SQL from some other filetype
            " which had OMNI completion defined.  We need to activate the
            " SQL completion plugin in order to cache some of the syntax items
            " while the syntax rules for SQL are active.
            call sqlcomplete#PreCacheSyntax()
        endif
    endfunction
    command! -nargs=* -complete=custom,SQL_GetList SQLSetType :call SQL_SetType(<q-args>)

endif

" Functions/Commands to allow the user determine current SQL syntax dialect
" This works with both Vim 6 and 7.

if !exists("*SQL_GetType")
    function SQL_GetType()
        if exists('b:sql_type_override')
            echomsg "Current SQL dialect in use:".b:sql_type_override
        else
            echomsg "Current SQL dialect in use:".g:sql_type_default
        endif
    endfunction
    command! -nargs=0 SQLGetType :call SQL_GetType()
endif

if exists("b:sql_type_override")
    " echo 'sourcing buffer ftplugin/'.b:sql_type_override.'.vim'
    if globpath(&runtimepath, 'ftplugin/'.b:sql_type_override.'.vim') != ''
        exec 'runtime ftplugin/'.b:sql_type_override.'.vim'
        " else
        "     echomsg 'ftplugin/'.b:sql_type_override.' not exist, using default'
    endif
elseif exists("g:sql_type_default")
    " echo 'sourcing global ftplugin/'.g:sql_type_default.'.vim'
    if globpath(&runtimepath, 'ftplugin/'.g:sql_type_default.'.vim') != ''
        exec 'runtime ftplugin/'.g:sql_type_default.'.vim'
        " else
        "     echomsg 'ftplugin/'.g:sql_type_default.'.vim not exist, using default'
    endif
endif

" If the above runtime command succeeded, do not load the default settings
" as they should have already been loaded from a previous run.
if exists("b:did_ftplugin") && exists("b:current_ftplugin") && b:current_ftplugin == 'sql'
    finish
endif

let b:undo_ftplugin = "setl comments< formatoptions< define< omnifunc<" .
            \ " | unlet! b:browsefilter b:match_words"

" Don't load another plugin for this buffer
let b:did_ftplugin     = 1
let b:current_ftplugin = 'sql'

" Win32 can filter files in the browse dialog
if has("gui_win32") && !exists("b:browsefilter")
    let b:browsefilter = "SQL Files (*.sql)\t*.sql\n" .
                \ "All Files (*.*)\t*.*\n"
endif

" Some standard expressions for use with the matchit strings
let s:notend = '\%(\<end\s\+\)\@<!'
let s:when_no_matched_or_others = '\%(\<when\>\%(\s\+\%(\%(\<not\>\s\+\)\?<matched\>\)\|\<others\>\)\@!\)'
let s:or_replace = '\%(or\s\+replace\s\+\)\?'

" Define patterns for the matchit macro
if !exists("b:match_words")
    " SQL is generally case insensitive
    let b:match_ignorecase = 1

    " Handle the following:
    " if
    " elseif | elsif
    " else [if]
    " end if
    "
    " [while condition] loop
    "     leave
    "     break
    "     continue
    "     exit
    " end loop
    "
    " for
    "     leave
    "     break
    "     continue
    "     exit
    " end loop
    "
    " do
    "     statements
    " doend
    "
    " case
    " when
    " when
    " default
    " end case
    "
    " merge
    " when not matched
    " when matched
    "
    " EXCEPTION
    " WHEN column_not_found THEN
    " WHEN OTHERS THEN
    "
    " begin try
    " end try
    " begin catch
    " end catch
    "
    " create[ or replace] procedure|function|event
    " \ '^\s*\<\%(do\|for\|while\|loop\)\>.*:'.

    " For ColdFusion support
    setlocal matchpairs+=<:>
    let b:match_words = &matchpairs .
                \ ',\%(\<begin\)\%(\s\+\%(try\|catch\)\>\)\@!:\<end\>\W*$,'.
                \
                \ '\<begin\s\+try\>:'.
                \ '\<end\s\+try\>:'.
                \ '\<begin\s\+catch\>:'.
                \ '\<end\s\+catch\>,'.
                \
                \ s:notend . '\<if\>:'.
                \ '\<elsif\>\|\<elseif\>\|\<else\>:'.
                \ '\<end\s\+if\>,'.
                \
                \ '\(^\s*\)\@<=\(\<\%(do\|for\|while\|loop\)\>.*\):'.
                \ '\%(\<exit\>\|\<leave\>\|\<break\>\|\<continue\>\):'.
                \ '\%(\<doend\>\|\%(\<end\s\+\%(for\|while\|loop\>\)\)\),'.
                \
                \ '\%('. s:notend . '\<case\>\):'.
                \ '\%('.s:when_no_matched_or_others.'\):'.
                \ '\%(\<when\s\+others\>\|\<end\s\+case\>\),' .
                \
                \ '\<merge\>:' .
                \ '\<when\s\+not\s\+matched\>:' .
                \ '\<when\s\+matched\>,' .
                \
                \ '\%(\<create\s\+' . s:or_replace . '\)\?'.
                \ '\%(function\|procedure\|event\):'.
                \ '\<returns\?\>'
    " \ '\<begin\>\|\<returns\?\>:'.
    " \ '\<end\>\(;\)\?\s*$'
    " \ '\<exception\>:'.s:when_no_matched_or_others.
    " \ ':\<when\s\+others\>,'.
    "
    " \ '\%(\<exception\>\|\%('. s:notend . '\<case\>\)\):'.
    " \ '\%(\<default\>\|'.s:when_no_matched_or_others.'\):'.
    " \ '\%(\%(\<when\s\+others\>\)\|\<end\s\+case\>\),' .
endif

" Define how to find the macro definition of a variable using the various
" [d, [D, [_CTRL_D and so on features
" Match these values ignoring case
" ie  DECLARE varname INTEGER
let &l:define = '\c\<\(VARIABLE\|DECLARE\|IN\|OUT\|INOUT\)\>'


" Mappings to move to the next BEGIN ... END block
" \W - no characters or digits
nnoremap <buffer> <silent> ]] :call search('\c^\s*begin\>', 'W' )<CR>
nnoremap <buffer> <silent> [[ :call search('\c^\s*begin\>', 'bW' )<CR>
nnoremap <buffer> <silent> ][ :call search('\c^\s*end\W*$', 'W' )<CR>
nnoremap <buffer> <silent> [] :call search('\c^\s*end\W*$', 'bW' )<CR>
xnoremap <buffer> <silent> ]] :<C-U>exec "normal! gv"<Bar>call search('\c^\s*begin\>', 'W' )<CR>
xnoremap <buffer> <silent> [[ :<C-U>exec "normal! gv"<Bar>call search('\c^\s*begin\>', 'bW' )<CR>
xnoremap <buffer> <silent> ][ :<C-U>exec "normal! gv"<Bar>call search('\c^\s*end\W*$', 'W' )<CR>
xnoremap <buffer> <silent> [] :<C-U>exec "normal! gv"<Bar>call search('\c^\s*end\W*$', 'bW' )<CR>


" By default only look for CREATE statements, but allow
" the user to override
if !exists('g:ftplugin_sql_statements')
    let g:ftplugin_sql_statements = 'create'
endif

" Predefined SQL objects what are used by the below mappings using
" the ]} style maps.
" This global variable allows the users to override its value
" from within their vimrc.
" Note, you cannot use \?, since these patterns can be used to search
" backwards, you must use \{,1}
if !exists('g:ftplugin_sql_objects')
    let g:ftplugin_sql_objects = 'function,procedure,event,' .
                \ '\(existing\\|global\s\+temporary\s\+\)\{,1}' .
                \ 'table,trigger' .
                \ ',schema,service,publication,database,datatype,domain' .
                \ ',index,subscription,synchronization,view,variable'
endif

" Key to trigger SQL completion
if !exists('g:ftplugin_sql_omni_key')
    let g:ftplugin_sql_omni_key = '<C-C>'
endif
" Key to trigger drill into column list
if !exists('g:ftplugin_sql_omni_key_right')
    let g:ftplugin_sql_omni_key_right = '<Right>'
endif
" Key to trigger drill out of column list
if !exists('g:ftplugin_sql_omni_key_left')
    let g:ftplugin_sql_omni_key_left = '<Left>'
endif

" Replace all ,'s with bars, except ones with numbers after them.
" This will most likely be a \{,1} string.
let s:ftplugin_sql_objects =
            \ '\c^\s*' .
            \ '\(\(' .
            \ substitute(g:ftplugin_sql_statements, ',\d\@!', '\\\\|', 'g') .
            \ '\)\s\+\(or\s\+replace\s\+\)\{,1}\)\{,1}' .
            \ '\<\(' .
            \ substitute(g:ftplugin_sql_objects, ',\d\@!', '\\\\|', 'g') .
            \ '\)\>'

" Mappings to move to the next CREATE ... block
exec "nnoremap <buffer> <silent> ]} :call search('".s:ftplugin_sql_objects."', 'W')<CR>"
exec "nnoremap <buffer> <silent> [{ :call search('".s:ftplugin_sql_objects."', 'bW')<CR>"
" Could not figure out how to use a :call search() string in visual mode
" without it ending visual mode
" Unfortunately, this will add a entry to the search history
exec 'xnoremap <buffer> <silent> ]} /'.s:ftplugin_sql_objects.'<CR>'
exec 'xnoremap <buffer> <silent> [{ ?'.s:ftplugin_sql_objects.'<CR>'

" Mappings to move to the next COMMENT
"
" Had to double the \ for the \| separator since this has a special
" meaning on maps
let b:comment_leader = '\(--\\|\/\/\\|\*\\|\/\*\\|\*\/\)'
" Find the start of the next comment
let b:comment_start  = '^\(\s*'.b:comment_leader.'.*\n\)\@<!'.
            \ '\(\s*'.b:comment_leader.'\)'
" Find the end of the previous comment
let b:comment_end = '\(^\s*'.b:comment_leader.'.*\n\)'.
            \ '\(^\s*'.b:comment_leader.'\)\@!'
" Skip over the comment
let b:comment_jump_over  = "call search('".
            \ '^\(\s*'.b:comment_leader.'.*\n\)\@<!'.
            \ "', 'W')"
let b:comment_skip_back  = "call search('".
            \ '^\(\s*'.b:comment_leader.'.*\n\)\@<!'.
            \ "', 'bW')"
" Move to the start and end of comments
exec 'nnoremap <silent><buffer> ]" :call search('."'".b:comment_start."'".', "W" )<CR>'
exec 'nnoremap <silent><buffer> [" :call search('."'".b:comment_end."'".', "W" )<CR>'
exec 'xnoremap <silent><buffer> ]" :<C-U>exec "normal! gv"<Bar>call search('."'".b:comment_start."'".', "W" )<CR>'
exec 'xnoremap <silent><buffer> [" :<C-U>exec "normal! gv"<Bar>call search('."'".b:comment_end."'".', "W" )<CR>'

" Comments can be of the form:
"   /*
"    *
"    */
" or
"   --
" or
"   //
setlocal comments=s1:/*,mb:*,ex:*/,:--,://

" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&omnifunc')
    " Since the SQL completion plugin can be used in conjunction
    " with other completion filetypes it must record the previous
    " OMNI function prior to setting up the SQL OMNI function
    let b:sql_compl_savefunc = &omnifunc

    " Source it to determine its version
    runtime autoload/sqlcomplete.vim
    " This is used by the sqlcomplete.vim plugin
    " Source it for its global functions
    runtime autoload/syntaxcomplete.vim

    setlocal omnifunc=sqlcomplete#Complete
    " Prevent the intellisense plugin from loading
    let b:sql_vis = 1
    if !exists('g:omni_sql_no_default_maps')
        let regex_extra = ''
        if exists('g:loaded_syntax_completion') && exists('g:loaded_sql_completion')
            if g:loaded_syntax_completion > 120 && g:loaded_sql_completion > 140
                let regex_extra = '\\w*'
            endif
        endif
        " Static maps which use populate the completion list
        " using Vim's syntax highlighting rules
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'a <C-\><C-O>:call sqlcomplete#Map("syntax")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'k <C-\><C-O>:call sqlcomplete#Map("sqlKeyword'.regex_extra.'")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'f <C-\><C-O>:call sqlcomplete#Map("sqlFunction'.regex_extra.'")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'o <C-\><C-O>:call sqlcomplete#Map("sqlOption'.regex_extra.'")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'T <C-\><C-O>:call sqlcomplete#Map("sqlType'.regex_extra.'")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'s <C-\><C-O>:call sqlcomplete#Map("sqlStatement'.regex_extra.'")<CR><C-X><C-O>'
        " Dynamic maps which use populate the completion list
        " using the dbext.vim plugin
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'t <C-\><C-O>:call sqlcomplete#Map("table")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'p <C-\><C-O>:call sqlcomplete#Map("procedure")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'v <C-\><C-O>:call sqlcomplete#Map("view")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'c <C-\><C-O>:call sqlcomplete#Map("column")<CR><C-X><C-O>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'l <C-\><C-O>:call sqlcomplete#Map("column_csv")<CR><C-X><C-O>'
        " The next 3 maps are only to be used while the completion window is
        " active due to the <CR> at the beginning of the map
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'L <C-Y><C-\><C-O>:call sqlcomplete#Map("column_csv")<CR><C-X><C-O>'
        " <C-Right> is not recognized on most Unix systems, so only create
        " these additional maps on the Windows platform.
        " If you would like to use these maps, choose a different key and make
        " the same map in your vimrc.
        " if has('win32')
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key_right.' <C-R>=sqlcomplete#DrillIntoTable()<CR>'
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key_left.'  <C-R>=sqlcomplete#DrillOutOfColumns()<CR>'
        " endif
        " Remove any cached items useful for schema changes
        exec 'inoremap <buffer> '.g:ftplugin_sql_omni_key.'R <C-\><C-O>:call sqlcomplete#Map("resetCache")<CR><C-X><C-O>'
    endif

    if b:sql_compl_savefunc != ""
        " We are changing the filetype to SQL from some other filetype
        " which had OMNI completion defined.  We need to activate the
        " SQL completion plugin in order to cache some of the syntax items
        " while the syntax rules for SQL are active.
        call sqlcomplete#ResetCacheSyntax()
        call sqlcomplete#PreCacheSyntax()
    endif
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:sw=4:
