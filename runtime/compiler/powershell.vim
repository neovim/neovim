" Vim compiler file
" Compiler:	powershell
" URL: https://github.com/PProvost/vim-ps1
" Last Change: 2020 Mar 30

if exists("current_compiler")
  finish
endif
let current_compiler = "powershell"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

if !exists("g:ps1_makeprg_cmd")
  if executable('pwsh')
    " pwsh is the future
    let g:ps1_makeprg_cmd = 'pwsh'
  elseif executable('pwsh.exe')
    let g:ps1_makeprg_cmd = 'pwsh.exe'
  elseif executable('powershell.exe')
    let g:ps1_makeprg_cmd = 'powershell.exe'
  else
    let g:ps1_makeprg_cmd = ''
  endif
endif

if !executable(g:ps1_makeprg_cmd)
  echoerr "To use the powershell compiler, please set g:ps1_makeprg_cmd to the powershell executable!"
endif

" Show CategoryInfo, FullyQualifiedErrorId, etc?
let g:ps1_efm_show_error_categories = get(g:, 'ps1_efm_show_error_categories', 0)

" Use absolute path because powershell requires explicit relative paths
" (./file.ps1 is okay, but # expands to file.ps1)
let &l:makeprg = g:ps1_makeprg_cmd .' %:p:S'

" Parse file, line, char from callstacks:
"     Write-Ouput : The term 'Write-Ouput' is not recognized as the name of a
"     cmdlet, function, script file, or operable program. Check the spelling
"     of the name, or if a path was included, verify that the path is correct
"     and try again.
"     At C:\script.ps1:11 char:5
"     +     Write-Ouput $content
"     +     ~~~~~~~~~~~
"         + CategoryInfo          : ObjectNotFound: (Write-Ouput:String) [], CommandNotFoundException
"         + FullyQualifiedErrorId : CommandNotFoundException

" Showing error in context with underlining.
CompilerSet errorformat=%+G+%m
" Error summary.
CompilerSet errorformat+=%E%*\\S\ :\ %m
" Error location.
CompilerSet errorformat+=%CAt\ %f:%l\ char:%c
" Errors that span multiple lines (may be wrapped to width of terminal).
CompilerSet errorformat+=%C%m
" Ignore blank/whitespace-only lines.
CompilerSet errorformat+=%Z\\s%#

if g:ps1_efm_show_error_categories
  CompilerSet errorformat^=%+G\ \ \ \ +\ %.%#\\s%#:\ %m
else
  CompilerSet errorformat^=%-G\ \ \ \ +\ %.%#\\s%#:\ %m
endif


" Parse file, line, char from of parse errors:
"     At C:\script.ps1:22 char:16
"     + Stop-Process -Name "invalidprocess
"     +                    ~~~~~~~~~~~~~~~
"     The string is missing the terminator: ".
"         + CategoryInfo          : ParserError: (:) [], ParseException
"         + FullyQualifiedErrorId : TerminatorExpectedAtEndOfString
CompilerSet errorformat+=At\ %f:%l\ char:%c


let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2:
