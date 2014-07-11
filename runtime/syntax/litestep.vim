" Vim syntax file
" Language:         LiteStep RC file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-02-22

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword litestepTodo
      \ contained
      \ TODO FIXME XXX NOTE

syn match   litestepComment
      \ contained display contains=litestepTodo,@Spell
      \ ';.*$'

syn case ignore

syn cluster litestepBeginnings
      \ contains=
      \   litestepComment,
      \   litestepPreProc,
      \   litestepMultiCommandStart,
      \   litestepBangCommandStart,
      \   litestepGenericDirective

syn match   litestepGenericDirective
      \ contained display
      \ '\<\h\w\+\>'

syn match   litestepBeginning
      \ nextgroup=@litestepBeginnings skipwhite
      \ '^'

syn keyword litestepPreProc
      \ contained
      \ Include
      \ If
      \ ElseIf
      \ Else
      \ EndIf

syn cluster litestepMultiCommands
      \ contains=
      \   litestepMultiCommand

syn match   litestepMultiCommandStart
      \ nextgroup=@litestepMultiCommands
      \ '\*'

syn match   litestepMultiCommand
      \ contained display
      \ '\<\h\w\+\>'

syn cluster litestepVariables
      \ contains=
      \   litestepBuiltinFolderVariable,
      \   litestepBuiltinConditionalVariable,
      \   litestepBuiltinResourceVariable,
      \   litestepBuiltinGUIDFolderMappingVariable,
      \   litestepVariable

syn region litestepVariableExpansion
      \ display oneline transparent
      \ contains=
      \   @litestepVariables,
      \   litestepNumber,
      \   litestepMathOperator
      \ matchgroup=litestepVariableExpansion
      \ start='\$'
      \ end='\$'

syn match litestepNumber
      \ display
      \ '\<\d\+\>'

syn region litestepString
      \ display oneline contains=litestepVariableExpansion
      \ start=+"+ end=+"+

" TODO: unsure about this one.
syn region litestepSubValue
      \ display oneline contains=litestepVariableExpansion
      \ start=+'+ end=+'+

syn keyword litestepBoolean
      \ true
      \ false

"syn keyword litestepLine
"      \ ?

"syn match   litestepColor
"      \ display
"      \ '\<\x\+\>'

syn match   litestepRelationalOperator
      \ display
      \ '=\|<[>=]\=\|>=\='

syn keyword litestepLogicalOperator
      \ and
      \ or
      \ not

syn match   litestepMathOperator
      \ contained display
      \ '[+*/-]'

syn keyword litestepBuiltinDirective
      \ LoadModule
      \ LSNoStartup
      \ LSAutoHideModules
      \ LSNoShellWarning
      \ LSSetAsShell
      \ LSUseSystemDDE
      \ LSDisableTrayService
      \ LSImageFolder
      \ ThemeAuthor
      \ ThemeName

syn keyword litestepDeprecatedBuiltinDirective
      \ LSLogLevel
      \ LSLogFile

syn match   litestepVariable
      \ contained display
      \ '\<\h\w\+\>'

syn keyword litestepBuiltinFolderVariable
      \ contained
      \ AdminToolsDir
      \ CommonAdminToolsDir
      \ CommonDesktopDir
      \ CommonFavorites
      \ CommonPrograms
      \ CommonStartMenu
      \ CommonStartup
      \ Cookies
      \ Desktop
      \ DesktopDir
      \ DocumentsDir
      \ Favorites
      \ Fonts
      \ History
      \ Internet
      \ InternetCache
      \ LitestepDir
      \ Nethood
      \ Printhood
      \ Programs
      \ QuickLaunch
      \ Recent
      \ Sendto
      \ Startmenu
      \ Startup
      \ Templates
      \ WinDir
      \ LitestepDir

syn keyword litestepBuiltinConditionalVariable
      \ contained
      \ Win2000
      \ Win95
      \ Win98
      \ Win9X
      \ WinME
      \ WinNT
      \ WinNT4
      \ WinXP

syn keyword litestepBuiltinResourceVariable
      \ contained
      \ CompileDate
      \ ResolutionX
      \ ResolutionY
      \ UserName

syn keyword litestepBuiltinGUIDFolderMappingVariable
      \ contained
      \ AdminTools
      \ BitBucket
      \ Controls
      \ Dialup
      \ Documents
      \ Drives
      \ Network
      \ NetworkAndDialup
      \ Printers
      \ Scheduled

syn cluster litestepBangs
      \ contains=
      \   litestepBuiltinBang,
      \   litestepBang

syn match   litestepBangStart
      \ nextgroup=@litestepBangs
      \ '!'

syn match   litestepBang
      \ contained display
      \ '\<\h\w\+\>'

syn keyword litestepBuiltinBang
      \ contained
      \ About
      \ Alert
      \ CascadeWindows
      \ Confirm
      \ Execute
      \ Gather
      \ HideModules
      \ LogOff
      \ MinimizeWindows
      \ None
      \ Quit
      \ Recycle
      \ Refresh
      \ Reload
      \ ReloadModule
      \ RestoreWindows
      \ Run
      \ ShowModules
      \ Shutdown
      \ Switchuser
      \ TileWindowsH
      \ TileWindowsV
      \ ToggleModules
      \ UnloadModule

hi def link litestepTodo                              Todo
hi def link litestepComment                           Comment
hi def link litestepDirective                         Keyword
hi def link litestepGenericDirective                  litestepDirective
hi def link litestepPreProc                           PreProc
hi def link litestepMultiCommandStart                 litestepPreProc
hi def link litestepMultiCommand                      litestepDirective
hi def link litestepDelimiter                         Delimiter
hi def link litestepVariableExpansion                 litestepDelimiter
hi def link litestepNumber                            Number
hi def link litestepString                            String
hi def link litestepSubValue                          litestepString
hi def link litestepBoolean                           Boolean
"hi def link litestepLine 
"hi def link litestepColor                             Type
hi def link litestepOperator                          Operator
hi def link litestepRelationalOperator                litestepOperator
hi def link litestepLogicalOperator                   litestepOperator
hi def link litestepMathOperator                      litestepOperator
hi def link litestepBuiltinDirective                  litestepDirective
hi def link litestepDeprecatedBuiltinDirective        Error
hi def link litestepVariable                          Identifier
hi def link litestepBuiltinFolderVariable             Identifier
hi def link litestepBuiltinConditionalVariable        Identifier
hi def link litestepBuiltinResourceVariable           Identifier
hi def link litestepBuiltinGUIDFolderMappingVariable  Identifier
hi def link litestepBangStart                         litestepPreProc
hi def link litestepBang                              litestepDirective
hi def link litestepBuiltinBang                       litestepBang

let b:current_syntax = "litestep"

let &cpo = s:cpo_save
unlet s:cpo_save
