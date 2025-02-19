" Vim indent file loader
" Language:    SQL
" Maintainer:  David Fishburn <fishburn at ianywhere dot com>
" Last Change: Thu Sep 15 2005 10:27:51 AM
" Version:     1.0
" Download:    http://vim.sourceforge.net/script.php?script_id=495

" Description: Checks for a:
"                  buffer local variable,
"                  global variable,
"              If the above exist, it will source the type specified.
"              If none exist, it will source the default sqlanywhere.vim file.


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

" Default to the standard Vim distribution file
let filename = 'sqlanywhere'

" Check for overrides.  Buffer variables have the highest priority.
if exists("b:sql_type_override")
    " Check the runtimepath to see if the file exists
    if globpath(&runtimepath, 'indent/'.b:sql_type_override.'.vim') != ''
        let filename = b:sql_type_override
    endif
elseif exists("g:sql_type_default")
    if globpath(&runtimepath, 'indent/'.g:sql_type_default.'.vim') != ''
        let filename = g:sql_type_default
    endif
endif

" Source the appropriate file
exec 'runtime indent/'.filename.'.vim'


" vim:sw=4:
