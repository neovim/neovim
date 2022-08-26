" Vim syntax file loader
" Language:    SQL
" Maintainer:  David Fishburn <fishburn at ianywhere dot com>
" Last Change: Thu Sep 15 2005 10:30:02 AM
" Version:     1.0

" Description: Checks for a:
"                  buffer local variable,
"                  global variable,
"              If the above exist, it will source the type specified.
"              If none exist, it will source the default sql.vim file.
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" Default to the standard Vim distribution file
let filename = 'sqloracle'

" Check for overrides.  Buffer variables have the highest priority.
if exists("b:sql_type_override")
    " Check the runtimepath to see if the file exists
    if globpath(&runtimepath, 'syntax/'.b:sql_type_override.'.vim') != ''
        let filename = b:sql_type_override
    endif
elseif exists("g:sql_type_default")
    if globpath(&runtimepath, 'syntax/'.g:sql_type_default.'.vim') != ''
        let filename = g:sql_type_default
    endif
endif

" Source the appropriate file
exec 'runtime syntax/'.filename.'.vim'

" vim:sw=4:
