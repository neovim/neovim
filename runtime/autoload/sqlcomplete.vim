" Vim OMNI completion script for SQL
" Language:    SQL
" Maintainer:  David Fishburn <dfishburn dot vim at gmail dot com>
" Version:     15.0
" Last Change: 2013 May 13
" Homepage:    http://www.vim.org/scripts/script.php?script_id=1572
" Usage:       For detailed help
"              ":help sql.txt"
"              or ":help ft-sql-omni"
"              or read $VIMRUNTIME/doc/sql.txt

" History
"
" TODO
"     - Jonas Enberg - if no table is found when using column completion
"       look backwards to a FROM clause and find the first table
"       and complete it.
"
" Version 15.0 (May 2013)
"     - NF: Changed the SQL precached syntax items, omni_sql_precache_syntax_groups,
"           to use regular expressions to pick up extended syntax group names.
"           This requires an updated SyntaxComplete plugin version 13.0.
"           If the required versions have not been installed, previous
"           behaviour will not be impacted.
"
" Version 14.0 (Dec 2012)
"     - BF: Added check for cpo
"
" Version 13.0 (Dec 2012)
"     - NF: When completing column lists or drilling into a table
"           and g:omni_sql_include_owner is enabled, the
"           only the table name would be replaced with the column
"           list instead of the table name and owner (if specified).
"     - NF: When completing column lists using table aliases
"           and g:omni_sql_include_owner is enabled, account
"           for the owner name when looking up the table
"           list instead of the table name and owner (if specified).
"     - BF: When completing column lists or drilling into a table
"           and g:omni_sql_include_owner is enabled, the
"           column list could often not be found for the table.
"     - BF: When OMNI popped up, possibly the wrong word
"           would be replaced for column and column list options.
"
" Version 12.0 (Feb 2012)
"     - Partial column name completion did not work when a table
"       name or table alias was provided (Jonas Enberg).
"     - Improved the handling of column completion.  First we match any
"       columns from a previous completion.  If not matches are found, we
"       consider the partial name to be a table or table alias for the
"       query and attempt to match on it.
"
" Version 11.0 (Jan 2012)
"     Added g:omni_sql_default_compl_type variable
"         - You can specify which type of completion to default to
"           when pressing <C-X><C-O>.  The entire list of available
"           choices can be found in the calls to sqlcomplete#Map in:
"               ftplugin/sql.vim
"
" Version 10.0
"     Updated PreCacheSyntax()
"         - Now returns a List of the syntax items it finds.
"           This allows other plugins / scripts to use this list for their own
"           purposes.  In this case XPTemplate can use them for a Choose list.
"         - Verifies the parameters are the correct type and displays a
"           warning if not.
"         - Verifies the parameters are the correct type and displays a
"           warning if not.
"     Updated SQLCWarningMsg()
"         - Prepends warning message with SQLComplete so you know who issued
"           the warning.
"     Updated SQLCErrorMsg()
"         - Prepends error message with SQLComplete so you know who issued
"           the error.
"
" Version 9.0 (May 2010)
"     This change removes some of the support for tables with spaces in their
"     names in order to simplify the regexes used to pull out query table
"     aliases for more robust table name and column name code completion.
"     Full support for "table names with spaces" can be added in again
"     after 7.3.
"
" Version 8.0
"     Incorrectly re-executed the g:ftplugin_sql_omni_key_right and g:ftplugin_sql_omni_key_left
"     when drilling in and out of a column list for a table.
"
" Version 7.0 (Jan 2010)
"     Better handling of object names
"
" Version 6.0 (Apr 2008)
"     Supports object names with spaces "my table name"
"
" Set completion with CTRL-X CTRL-O to autoloaded function.
" This check is in place in case this script is
" sourced directly instead of using the autoload feature.
if exists('&omnifunc')
    " Do not set the option if already set since this
    " results in an E117 warning.
    if &omnifunc == ""
        setlocal omnifunc=sqlcomplete#Complete
    endif
endif

if exists('g:loaded_sql_completion')
    finish
endif
let g:loaded_sql_completion = 150
let s:keepcpo= &cpo
set cpo&vim

" Maintains filename of dictionary
let s:sql_file_table        = ""
let s:sql_file_procedure    = ""
let s:sql_file_view         = ""

" Define various arrays to be used for caching
let s:tbl_name              = []
let s:tbl_alias             = []
let s:tbl_cols              = []
let s:syn_list              = []
let s:syn_value             = []

" Used in conjunction with the syntaxcomplete plugin
let s:save_inc              = ""
let s:save_exc              = ""
if !exists('g:omni_syntax_group_include_sql')
    let g:omni_syntax_group_include_sql = ''
endif
if !exists('g:omni_syntax_group_exclude_sql')
    let g:omni_syntax_group_exclude_sql = ''
endif
let s:save_inc = g:omni_syntax_group_include_sql
let s:save_exc = g:omni_syntax_group_exclude_sql

" Used with the column list
let s:save_prev_table       = ""

" Default the option to verify table alias
if !exists('g:omni_sql_use_tbl_alias')
    let g:omni_sql_use_tbl_alias = 'a'
endif
" Default syntax items to precache
if !exists('g:omni_sql_precache_syntax_groups')
    let g:omni_sql_precache_syntax_groups = [
                \ 'syntax\w*',
                \ 'sqlKeyword\w*',
                \ 'sqlFunction\w*',
                \ 'sqlOption\w*',
                \ 'sqlType\w*',
                \ 'sqlStatement\w*'
                \ ]
endif
" Set ignorecase to the ftplugin standard
if !exists('g:omni_sql_ignorecase')
    let g:omni_sql_ignorecase = &ignorecase
endif
" During table completion, should the table list also
" include the owner name
if !exists('g:omni_sql_include_owner')
    let g:omni_sql_include_owner = 0
    if exists('g:loaded_dbext')
        if g:loaded_dbext >= 300
            " New to dbext 3.00, by default the table lists include the owner
            " name of the table.  This is used when determining how much of
            " whatever has been typed should be replaced as part of the
            " code replacement.
            let g:omni_sql_include_owner = 1
        endif
    endif
endif
" Default type of completion used when <C-X><C-O> is pressed
if !exists('g:omni_sql_default_compl_type')
    let g:omni_sql_default_compl_type = 'table'
endif

" This function is used for the 'omnifunc' option.
" It is called twice by omni and it is responsible
" for returning the completion list of items.
" But it must also determine context of what to complete
" and what to "replace" with the completion.
" The a:base, is replaced directly with what the user
" chooses from the choices.
" The s:prepend provides context for the completion.
function! sqlcomplete#Complete(findstart, base)

    " Default to table name completion
    let compl_type = 'table'
    " Allow maps to specify what type of object completion they want
    if exists('b:sql_compl_type')
        let compl_type = b:sql_compl_type
    endif
    let begindot = 0

    " First pass through this function determines how much of the line should
    " be replaced by whatever is chosen from the completion list
    if a:findstart
        " Locate the start of the item, including "."
        let line     = getline('.')
        let start    = col('.') - 1
        let lastword = -1
        " Check if the first character is a ".", for column completion
        if line[start - 1] == '.'
            let begindot = 1
        endif
        while start > 0
            " Additional code was required to handle objects which
            " can contain spaces like "my table name".
            if line[start - 1] !~ '\(\w\|\.\)'
                " If the previous character is not a period or word character
                break
            " elseif line[start - 1] =~ '\(\w\|\s\+\)'
            "     let start -= 1
            elseif line[start - 1] =~ '\w'
                " If the previous character is word character continue back
                let start -= 1
            elseif line[start - 1] =~ '\.' &&
                        \ compl_type =~ 'column\|table\|view\|procedure'
                " If the previous character is a period and we are completing
                " an object which can be specified with a period like this:
                "     table_name.column_name
                "     owner_name.table_name

                " If lastword has already been set for column completion
                " break from the loop, since we do not also want to pickup
                " a table name if it was also supplied.
                " Unless g:omni_sql_include_owner == 1, then we can
                " include the ownername.
                if lastword != -1 && compl_type == 'column'
                            \ && g:omni_sql_include_owner == 0
                    break
                endif
                " If column completion was specified stop at the "." if
                " a . was specified, otherwise, replace all the way up
                " to the owner name (if included).
                if lastword == -1 && compl_type == 'column' && begindot == 1
                    let lastword = start
                endif
                " If omni_sql_include_owner = 0, do not include the table
                " name as part of the substitution, so break here
                if lastword == -1 &&
                            \ compl_type =~ '\<\(table\|view\|procedure\|column\|column_csv\)\>' &&
                            \ g:omni_sql_include_owner == 0
                    let lastword = start
                    break
                endif
                let start -= 1
            else
                break
            endif
        endwhile

        " Return the column of the last word, which is going to be changed.
        " Remember the text that comes before it in s:prepended.
        if lastword == -1
            let s:prepended = ''
            return start
        endif
        let s:prepended = strpart(line, start, lastword - start)
        return lastword
    endif

    " Second pass through this function will determine what data to put inside
    " of the completion list
    " s:prepended is set by the first pass
    let base = s:prepended . a:base

    " Default the completion list to an empty list
    let compl_list = []

    " Default to table name completion
    let compl_type = g:omni_sql_default_compl_type
    " Allow maps to specify what type of object completion they want
    if exists('b:sql_compl_type')
        let compl_type = b:sql_compl_type
        unlet b:sql_compl_type
    endif

    if compl_type == 'tableReset'
        let compl_type = 'table'
        let base = ''
    endif

    if compl_type == 'table' ||
                \ compl_type == 'procedure' ||
                \ compl_type == 'view'

        " This type of completion relies upon the dbext.vim plugin
        if s:SQLCCheck4dbext() == -1
            return []
        endif

        " Allow the user to override the dbext plugin to specify whether
        " the owner/creator should be included in the list
        if g:loaded_dbext >= 300
            let saveSetting = DB_listOption('dict_show_owner')
            exec 'DBSetOption dict_show_owner='.(g:omni_sql_include_owner==1?'1':'0')
        endif

        let compl_type_uc = substitute(compl_type, '\w\+', '\u&', '')
        " Same call below, no need to do it twice
        " if s:sql_file_{compl_type} == ""
        "     let s:sql_file_{compl_type} = DB_getDictionaryName(compl_type_uc)
        " endif
        let s:sql_file_{compl_type} = DB_getDictionaryName(compl_type_uc)
        if s:sql_file_{compl_type} != ""
            if filereadable(s:sql_file_{compl_type})
                let compl_list = readfile(s:sql_file_{compl_type})
            endif
        endif

        if g:loaded_dbext > 300
            exec 'DBSetOption dict_show_owner='.saveSetting
        endif
    elseif compl_type =~? 'column'

        " This type of completion relies upon the dbext.vim plugin
        if s:SQLCCheck4dbext() == -1
            return []
        endif

        if base == ""
            " The last time we displayed a column list we stored
            " the table name.  If the user selects a column list
            " without a table name of alias present, assume they want
            " the previous column list displayed.
            let base = s:save_prev_table
        endif

        let owner  = ''
        let column = ''

        if base =~ '\.'
            " Check if the owner/creator has been specified
            let owner  = matchstr( base, '^\zs.*\ze\..*\..*' )
            let table  = matchstr( base, '^\(.*\.\)\?\zs.*\ze\..*' )
            let column = matchstr( base, '.*\.\zs.*' )

            if g:omni_sql_include_owner == 1 && owner == '' && table != '' && column != ''
                let owner  = table
                let table  = column
                let column = ''
            endif

            " It is pretty well impossible to determine if the user
            " has entered:
            "    owner.table
            "    table.column_prefix
            " So there are a couple of things we can do to mitigate
            " this issue.
            "    1.  Check if the dbext plugin has the option turned
            "        on to even allow owners
            "    2.  Based on 1, if the user is showing a table list
            "        and the DrillIntoTable (using <Right>) then
            "        this will be owner.table.  In this case, we can
            "        check to see the table.column exists in the
            "        cached table list.  If it does, then we have
            "        determined the user has actually chosen
            "        owner.table, not table.column_prefix.
            let found = -1
            if g:omni_sql_include_owner == 1 && owner == ''
                if filereadable(s:sql_file_table)
                    let tbl_list = readfile(s:sql_file_table)
                    let found    = index( tbl_list, ((table != '')?(table.'.'):'').column)
                endif
            endif
            " If the table.column was found in the table list, we can safely assume
            " the owner was not provided and shift the items appropriately.
            " OR
            " If the user has indicated not to use table owners at all and
            " the base ends in a '.' we know they are not providing a column
            " name, so we can shift the items appropriately.
            " if found != -1 || (g:omni_sql_include_owner == 0 && base !~ '\.$')
            "     let owner  = table
            "     let table  = column
            "     let column = ''
            " endif
        else
            " If no "." was provided and the user asked for
            " column level completion, first attempt the match
            " on any previous column lists.  If the user asked
            " for a list of columns comma separated, continue as usual.
            if compl_type == 'column' && s:save_prev_table != ''
                " The last time we displayed a column list we stored
                " the table name.  If the user selects a column list
                " without a table name of alias present, assume they want
                " the previous column list displayed.
                let table     = s:save_prev_table
                let list_type = ''

                let compl_list  = s:SQLCGetColumns(table, list_type)
                if ! empty(compl_list)
                    " If no column prefix has been provided and the table
                    " name was provided, append it to each of the items
                    " returned.
                    let compl_list = filter(deepcopy(compl_list), 'v:val=~"^'.base.'"' )

                    " If not empty, we have a match on columns
                    " return the list
                    if ! empty(compl_list)
                        return compl_list
                    endif
                endif
            endif
            " Since no columns were found to match the base supplied
            " assume the user is trying to complete the column list
            " for a table (and or an alias to a table).
            let table  = base
        endif

        " Get anything after the . and consider this the table name
        " If an owner has been specified, then we must consider the
        " base to be a partial column name
        " let base  = matchstr( base, '^\(.*\.\)\?\zs.*' )

        if table != ""
            let s:save_prev_table = base
            let list_type         = ''

            if compl_type == 'column_csv'
                " Return one array element, with a comma separated
                " list of values instead of multiple array entries
                " for each column in the table.
                let list_type     = 'csv'
            endif

            " If we are including the OWNER for the objects, then for
            " table completion, if we have it, it should be included
            " as there can be the same table names in a database yet
            " with different owner names.
            if g:omni_sql_include_owner == 1 && owner != '' && table != ''
                let compl_list  = s:SQLCGetColumns(owner.'.'.table, list_type)
            else
                let compl_list  = s:SQLCGetColumns(table, list_type)
            endif

            if column != ''
                " If no column prefix has been provided and the table
                " name was provided, append it to each of the items
                " returned.
                let compl_list = map(compl_list, 'table.".".v:val')
                if owner != ''
                    " If an owner has been provided append it to each of the
                    " items returned.
                    let compl_list = map(compl_list, 'owner.".".v:val')
                endif
            else
                let base = ''
            endif

            if compl_type == 'column_csv'
                " Join the column array into 1 single element array
                " but make the columns column separated
                let compl_list        = [join(compl_list, ', ')]
            endif
        endif
    elseif compl_type == 'resetCache'
        " Reset all cached items
        let s:tbl_name           = []
        let s:tbl_alias          = []
        let s:tbl_cols           = []
        let s:syn_list           = []
        let s:syn_value          = []
        let s:sql_file_table     = ""
        let s:sql_file_procedure = ""
        let s:sql_file_view      = ""

        let msg = "All SQL cached items have been removed."
        call s:SQLCWarningMsg(msg)
        " Leave time for the user to read the error message
        :sleep 2
    else
        let compl_list = s:SQLCGetSyntaxList(compl_type)
    endif

    if base != ''
        " Filter the list based on the first few characters the user entered.
        " Check if the text matches at the beginning
        "         \\(^.base.'\\)
        " or
        " Match to a owner.table or alias.column type match
        "         ^\\(\\w\\+\\.\\)\\?'.base.'\\)
        " or
        " Handle names with spaces "my table name"
        "         "\\(^'.base.'\\|^\\(\\w\\+\\.\\)\\?'.base.'\\)"'
        "
        let expr = 'v:val '.(g:omni_sql_ignorecase==1?'=~?':'=~#').' "\\(^'.base.'\\|^\\(\\w\\+\\.\\)\\?'.base.'\\)"'
        " let expr = 'v:val '.(g:omni_sql_ignorecase==1?'=~?':'=~#').' "\\(^'.base.'\\)"'
        " let expr = 'v:val '.(g:omni_sql_ignorecase==1?'=~?':'=~#').' "\\(^'.base.'\\|\\(\\.\\)\\?'.base.'\\)"'
        " let expr = 'v:val '.(g:omni_sql_ignorecase==1?'=~?':'=~#').' "\\(^'.base.'\\|\\([^.]*\\)\\?'.base.'\\)"'
        let compl_list = filter(deepcopy(compl_list), expr)

        if empty(compl_list) && compl_type == 'table' && base =~ '\.$'
            " It is possible we could be looking for column name completion
            " and the user simply hit C-X C-O to lets try it as well
            " since we had no hits with the tables.
            " If the base ends with a . it is hard to know if we are
            " completing table names or column names.
            let list_type = ''

            let compl_list  = s:SQLCGetColumns(base, list_type)
        endif
    endif

    if exists('b:sql_compl_savefunc') && b:sql_compl_savefunc != ""
        let &omnifunc = b:sql_compl_savefunc
    endif

    if empty(compl_list)
        call s:SQLCWarningMsg( 'Could not find type['.compl_type.'] using prepend[.'.s:prepended.'] base['.a:base.']' )
    endif

    return compl_list
endfunc

function! sqlcomplete#PreCacheSyntax(...)
    let syn_group_arr = []
    let syn_items     = []

    if a:0 > 0
        if type(a:1) != 3
            call s:SQLCWarningMsg("Parameter is not a list. Example:['syntaxGroup1', 'syntaxGroup2']")
            return ''
        endif
        let syn_group_arr = a:1
    else
        let syn_group_arr = g:omni_sql_precache_syntax_groups
    endif
    " For each group specified in the list, precache all
    " the sytnax items.
    if !empty(syn_group_arr)
        for group_name in syn_group_arr
            let syn_items = extend( syn_items, s:SQLCGetSyntaxList(group_name) )
        endfor
    endif

    return syn_items
endfunction

function! sqlcomplete#ResetCacheSyntax(...)
    let syn_group_arr = []

    if a:0 > 0
        if type(a:1) != 3
            call s:SQLCWarningMsg("Parameter is not a list. Example:['syntaxGroup1', 'syntaxGroup2']")
            return ''
        endif
        let syn_group_arr = a:1
    else
        let syn_group_arr = g:omni_sql_precache_syntax_groups
    endif
    " For each group specified in the list, precache all
    " the sytnax items.
    if !empty(syn_group_arr)
        for group_name in syn_group_arr
            let list_idx = index(s:syn_list, group_name, 0, &ignorecase)
            if list_idx > -1
                " Remove from list of groups
                call remove( s:syn_list, list_idx )
                " Remove from list of keywords
                call remove( s:syn_value, list_idx )
            endif
        endfor
    endif
endfunction

function! sqlcomplete#Map(type)
    " Tell the SQL plugin what you want to complete
    let b:sql_compl_type=a:type
    " Record previous omnifunc, if the SQL completion
    " is being used in conjunction with other filetype
    " completion plugins
    if &omnifunc != "" && &omnifunc != 'sqlcomplete#Complete'
        " Record the previous omnifunc, the plugin
        " will automatically set this back so that it
        " does not interfere with other ftplugins settings
        let b:sql_compl_savefunc=&omnifunc
    endif
    " Set the OMNI func for the SQL completion plugin
    let &omnifunc='sqlcomplete#Complete'
endfunction

function! sqlcomplete#DrillIntoTable()
    " If the omni popup window is visible
    if pumvisible()
        call sqlcomplete#Map('column')
        " C-Y, makes the currently highlighted entry active
        " and trigger the omni popup to be redisplayed
        call feedkeys("\<C-Y>\<C-X>\<C-O>", 'n')
    else
	" If the popup is not visible, simple perform the normal
	" key behaviour.
	" Must use exec since they key must be preceeded by "\"
	" or feedkeys will simply push each character of the string
	" rather than the "key press".
        exec 'call feedkeys("\'.g:ftplugin_sql_omni_key_right.'", "n")'
    endif
    return ""
endfunction

function! sqlcomplete#DrillOutOfColumns()
    " If the omni popup window is visible
    if pumvisible()
        call sqlcomplete#Map('tableReset')
        " Trigger the omni popup to be redisplayed
        call feedkeys("\<C-X>\<C-O>")
    else
	" If the popup is not visible, simple perform the normal
	" key behaviour.
	" Must use exec since they key must be preceeded by "\"
	" or feedkeys will simply push each character of the string
	" rather than the "key press".
        exec 'call feedkeys("\'.g:ftplugin_sql_omni_key_left.'", "n")'
    endif
    return ""
endfunction

function! s:SQLCWarningMsg(msg)
    echohl WarningMsg
    echomsg 'SQLComplete:'.a:msg
    echohl None
endfunction

function! s:SQLCErrorMsg(msg)
    echohl ErrorMsg
    echomsg 'SQLComplete:'.a:msg
    echohl None
endfunction

function! s:SQLCGetSyntaxList(syn_group)
    let syn_group  = a:syn_group
    let compl_list = []

    " Check if we have already cached the syntax list
    let list_idx = index(s:syn_list, syn_group, 0, &ignorecase)
    if list_idx > -1
        " Return previously cached value
        let compl_list = s:syn_value[list_idx]
    else
        let s:save_inc = g:omni_syntax_group_include_sql
        let s:save_exc = g:omni_syntax_group_exclude_sql
        let g:omni_syntax_group_include_sql = ''
        let g:omni_syntax_group_exclude_sql = ''

        " Request the syntax list items from the
        " syntax completion plugin
        if syn_group == 'syntax'
            " Handle this special case.  This allows the user
            " to indicate they want all the syntax items available,
            " so do not specify a specific include list.
            let syn_value                       = syntaxcomplete#OmniSyntaxList()
        else
            " The user has specified a specific syntax group
            let g:omni_syntax_group_include_sql = syn_group
            let syn_value                       = syntaxcomplete#OmniSyntaxList(syn_group)
        endif
        let g:omni_syntax_group_include_sql = s:save_inc
        let g:omni_syntax_group_exclude_sql = s:save_exc
        " Cache these values for later use
        let s:syn_list  = add( s:syn_list,  syn_group )
        let s:syn_value = add( s:syn_value, syn_value )
        let compl_list  = syn_value
    endif

    return compl_list
endfunction

function! s:SQLCCheck4dbext()
    if !exists('g:loaded_dbext')
        let msg = "The dbext plugin must be loaded for dynamic SQL completion"
        call s:SQLCErrorMsg(msg)
        " Leave time for the user to read the error message
        :sleep 2
        return -1
    elseif g:loaded_dbext < 600
        let msg = "The dbext plugin must be at least version 5.30 " .
                    \ " for dynamic SQL completion"
        call s:SQLCErrorMsg(msg)
        " Leave time for the user to read the error message
        :sleep 2
        return -1
    endif
    return 1
endfunction

function! s:SQLCAddAlias(table_name, table_alias, cols)
    " Strip off the owner if included
    let table_name  = matchstr(a:table_name, '\%(.\{-}\.\)\?\zs\(.*\)' )
    let table_alias = a:table_alias
    let cols        = a:cols

    if g:omni_sql_use_tbl_alias != 'n'
        if table_alias == ''
            if 'da' =~? g:omni_sql_use_tbl_alias
                if table_name =~ '_'
                    " Treat _ as separators since people often use these
                    " for word separators
                    let save_keyword = &iskeyword
                    setlocal iskeyword-=_

                    " Get the first letter of each word
                    " [[:alpha:]] is used instead of \w
                    " to catch extended accented characters
                    "
                    let table_alias = substitute(
                                \ table_name,
                                \ '\<[[:alpha:]]\+\>_\?',
                                \ '\=strpart(submatch(0), 0, 1)',
                                \ 'g'
                                \ )
                    " Restore original value
                    let &iskeyword = save_keyword
                elseif table_name =~ '\u\U'
                    let table_alias = substitute(
                                \ table_name, '\(\u\)\U*', '\1', 'g')
                else
                    let table_alias = strpart(table_name, 0, 1)
                endif
            endif
        endif
        if table_alias != ''
            " Following a word character, make sure there is a . and no spaces
            let table_alias = substitute(table_alias, '\w\zs\.\?\s*$', '.', '')
            if 'a' =~? g:omni_sql_use_tbl_alias && a:table_alias == ''
                let table_alias = inputdialog("Enter table alias:", table_alias)
            endif
        endif
        if table_alias != ''
            let cols = substitute(cols, '\<\w', table_alias.'&', 'g')
        endif
    endif

    return cols
endfunction

function! s:SQLCGetObjectOwner(object)
    " The owner regex matches a word at the start of the string which is
    " followed by a dot, but doesn't include the dot in the result.
    " ^           - from beginning of line
    " \("\|\[\)\? - ignore any quotes
    " \zs         - start the match now
    " .\{-}       - get owner name
    " \ze         - end the match
    " \("\|\[\)\? - ignore any quotes
    " \.          - must by followed by a .
    " let owner = matchstr( a:object, '^\s*\zs.*\ze\.' )
    let owner = matchstr( a:object, '^\("\|\[\)\?\zs\.\{-}\ze\("\|\]\)\?\.' )
    return owner
endfunction

function! s:SQLCGetColumns(table_name, list_type)
    if a:table_name =~ '\.'
        " Check if the owner/creator has been specified
        let owner  = matchstr( a:table_name, '^\zs.*\ze\..*\..*' )
        let table  = matchstr( a:table_name, '^\(.*\.\)\?\zs.*\ze\..*' )
        let column = matchstr( a:table_name, '.*\.\zs.*' )

        if g:omni_sql_include_owner == 1 && owner == '' && table != '' && column != ''
            let owner  = table
            let table  = column
            let column = ''
        endif
    else
        let owner  = ''
        let table  = matchstr(a:table_name, '^["\[\]a-zA-Z0-9_ ]\+\ze\.\?')
        let column = ''
    endif

    " Check if the table name was provided as part of the column name
    " let table_name   = matchstr(a:table_name, '^["\[\]a-zA-Z0-9_ ]\+\ze\.\?')
    let table_name   = table
    let table_cols   = []
    let table_alias  = ''
    let move_to_top  = 1

    let table_name   = substitute(table_name, '\s*\(.\{-}\)\s*$', '\1', 'g')

    " If the table name was given as:
    "     where c.
    let table_name   = substitute(table_name, '^\c\(WHERE\|AND\|OR\)\s\+', '', '')
    if g:loaded_dbext >= 300
        let saveSettingAlias = DB_listOption('use_tbl_alias')
        exec 'DBSetOption use_tbl_alias=n'
    endif

    let table_name_stripped = substitute(table_name, '["\[\]]*', '', 'g')

    " Check if we have already cached the column list for this table
    " by its name
    let list_idx = index(s:tbl_name, table_name_stripped, 0, &ignorecase)
    if list_idx > -1
        let table_cols = split(s:tbl_cols[list_idx], '\n')
    else
        " Check if we have already cached the column list for this table
        " by its alias, assuming the table_name provided was actually
        " the alias for the table instead
        "     select *
        "       from area a
        "      where a.
        let list_idx = index(s:tbl_alias, table_name_stripped, 0, &ignorecase)
        if list_idx > -1
            let table_alias = table_name_stripped
            let table_name  = s:tbl_name[list_idx]
            let table_cols  = split(s:tbl_cols[list_idx], '\n')
        endif
    endif

    " If we have not found a cached copy of the table
    " And the table ends in a "." or we are looking for a column list
    " if list_idx == -1 && (a:table_name =~ '\.' || b:sql_compl_type =~ 'column')
    " if list_idx == -1 && (a:table_name =~ '\.' || a:list_type =~ 'csv')
    if list_idx == -1
         let saveY      = @y
         let saveSearch = @/
         let saveWScan  = &wrapscan
         let curline    = line(".")
         let curcol     = col(".")

         " Do not let searchs wrap
         setlocal nowrapscan
         " If . was entered, look at the word just before the .
         " We are looking for something like this:
         "    select *
         "      from customer c
         "     where c.
         " So when . is pressed, we need to find 'c'
         "

         " Search backwards to the beginning of the statement
         " and do NOT wrap
         " exec 'silent! normal! v?\<\(select\|update\|delete\|;\)\>'."\n".'"yy'
         exec 'silent! normal! ?\<\c\(select\|update\|delete\|;\)\>'."\n"

         " Start characterwise visual mode
         " Advance right one character
         " Search foward until one of the following:
         "     1.  Another select/update/delete statement
         "     2.  A ; at the end of a line (the delimiter)
         "     3.  The end of the file (incase no delimiter)
         " Yank the visually selected text into the "y register.
         exec 'silent! normal! vl/\c\(\<select\>\|\<update\>\|\<delete\>\|;\s*$\|\%$\)'."\n".'"yy'

         let query = @y
         let query = substitute(query, "\n", ' ', 'g')
         let found = 0

         " if query =~? '^\c\(select\)'
         if query =~? '^\(select\|update\|delete\)'
             let found = 1
             "  \(\(\<\w\+\>\)\.\)\?   -
             " '\c\(from\|join\|,\).\{-}'  - Starting at the from clause (case insensitive)
             " '\zs\(\(\<\w\+\>\)\.\)\?' - Get the owner name (optional)
             " '\<\w\+\>\ze' - Get the table name
             " '\s\+\<'.table_name.'\>' - Followed by the alias
             " '\s*\.\@!.*'  - Cannot be followed by a .
             " '\(\<where\>\|$\)' - Must be followed by a WHERE clause
             " '.*'  - Exclude the rest of the line in the match
             " let table_name_new = matchstr(@y,
             "             \ '\c\(from\|join\|,\).\{-}'.
             "             \ '\zs\(\("\|\[\)\?.\{-}\("\|\]\)\.\)\?'.
             "             \ '\("\|\[\)\?.\{-}\("\|\]\)\?\ze'.
             "             \ '\s\+\%(as\s\+\)\?\<'.
             "             \ matchstr(table_name, '.\{-}\ze\.\?$').
             "             \ '\>'.
             "             \ '\s*\.\@!.*'.
             "             \ '\(\<where\>\|$\)'.
             "             \ '.*'
             "             \ )
             "
             "
             " ''\c\(\<from\>\|\<join\>\|,\)\s*'  - Starting at the from clause (case insensitive)
             " '\zs\(\("\|\[\)\?\w\+\("\|\]\)\?\.\)\?' - Get the owner name (optional)
             " '\("\|\[\)\?\w\+\("\|\]\)\?\ze' - Get the table name
             " '\s\+\%(as\s\+\)\?\<'.matchstr(table_name, '.\{-}\ze\.\?$').'\>' - Followed by the alias
             " '\s*\.\@!.*'  - Cannot be followed by a .
             " '\(\<where\>\|$\)' - Must be followed by a WHERE clause
             " '.*'  - Exclude the rest of the line in the match
             let table_name_new = matchstr(@y,
                         \ '\c\(\<from\>\|\<join\>\|,\)\s*'.
                         \ '\zs\(\("\|\[\)\?\w\+\("\|\]\)\?\.\)\?'.
                         \ '\("\|\[\)\?\w\+\("\|\]\)\?\ze'.
                         \ '\s\+\%(as\s\+\)\?\<'.
                         \ matchstr(table_name, '.\{-}\ze\.\?$').
                         \ '\>'.
                         \ '\s*\.\@!.*'.
                         \ '\(\<where\>\|$\)'.
                         \ '.*'
                         \ )

             if table_name_new != ''
                 let table_alias = table_name
                 if g:omni_sql_include_owner == 1
                    let table_name  = matchstr( table_name_new, '^\zs\(.\{-}\.\)\?\(.\{-}\.\)\?.*\ze' )
                 else
                     " let table_name  = matchstr( table_name_new, '^\(.*\.\)\?\zs.*\ze' )
                    let table_name  = matchstr( table_name_new, '^\(.\{-}\.\)\?\zs\(.\{-}\.\)\?.*\ze' )
                 endif

                 let list_idx = index(s:tbl_name, table_name, 0, &ignorecase)
                 if list_idx > -1
                     let table_cols  = split(s:tbl_cols[list_idx])
                     let s:tbl_name[list_idx]  = table_name
                     let s:tbl_alias[list_idx] = table_alias
                 else
                     let list_idx = index(s:tbl_alias, table_name, 0, &ignorecase)
                     if list_idx > -1
                         let table_cols = split(s:tbl_cols[list_idx])
                         let s:tbl_name[list_idx]  = table_name
                         let s:tbl_alias[list_idx] = table_alias
                     endif
                 endif

             endif
         else
             " Simply assume it is a table name provided with a . on the end
             let found = 1
         endif

         let @y        = saveY
         let @/        = saveSearch
         let &wrapscan = saveWScan

         " Return to previous location
         call cursor(curline, curcol)

         if found == 0
             if g:loaded_dbext > 300
                 exec 'DBSetOption use_tbl_alias='.saveSettingAlias
             endif

             " Not a SQL statement, do not display a list
             return []
         endif
    endif

    if empty(table_cols)
        " Specify silent mode, no messages to the user (tbl, 1)
        " Specify do not comma separate (tbl, 1, 1)
        " let table_cols_str = DB_getListColumn(table_name, 1, 1)
        let table_cols_str = DB_getListColumn((owner!=''?owner.'.':'').table_name, 1, 1)

        if table_cols_str != ""
            let s:tbl_name  = add( s:tbl_name,  table_name )
            let s:tbl_alias = add( s:tbl_alias, table_alias )
            let s:tbl_cols  = add( s:tbl_cols,  table_cols_str )
            let table_cols  = split(table_cols_str, '\n')
        endif

    endif

    if g:loaded_dbext > 300
        exec 'DBSetOption use_tbl_alias='.saveSettingAlias
    endif

    " If the user has asked for a comma separate list of column
    " values, ask the user if they want to prepend each column
    " with a tablename alias.
    if a:list_type == 'csv' && !empty(table_cols)
        let cols       = join(table_cols, ', ')
        let cols       = s:SQLCAddAlias(table_name, table_alias, cols)
        let table_cols = [cols]
    endif

    return table_cols
endfunction
"  Restore:
let &cpo= s:keepcpo
unlet s:keepcpo
" vim: ts=4 fdm=marker
