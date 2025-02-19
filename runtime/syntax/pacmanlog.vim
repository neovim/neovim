" Vim syntax file
" Language: pacman.log
" Maintainer: Ronan Pigott <ronan@rjp.ie>
" Last Change: 2023 Dec 04

if exists("b:current_syntax")
  finish
endif

syn sync maxlines=1
syn region pacmanlogMsg start='\S' end='$' keepend contains=pacmanlogTransaction,pacmanlogALPMMsg
syn region pacmanlogTag start='\['hs=s+1 end='\]'he=e-1 keepend nextgroup=pacmanlogMsg
syn region pacmanlogTime start='^\['hs=s+1 end='\]'he=e-1 keepend nextgroup=pacmanlogTag

syn match pacmanlogPackageName '\v[a-z0-9@_+.-]+' contained skipwhite nextgroup=pacmanlogPackageVersion
syn match pacmanlogPackageVersion '(.*)' contained

syn match pacmanlogTransaction 'transaction \v(started|completed)$' contained
syn match pacmanlogInstalled   '\v(re)?installed' contained nextgroup=pacmanlogPackageName
syn match pacmanlogUpgraded    'upgraded'         contained nextgroup=pacmanlogPackageName
syn match pacmanlogDowngraded  'downgraded'       contained nextgroup=pacmanlogPackageName
syn match pacmanlogRemoved     'removed'          contained nextgroup=pacmanlogPackageName
syn match pacmanlogWarning     'warning:.*$'      contained

syn region pacmanlogALPMMsg start='\v(\[ALPM\] )@<=(transaction|(re)?installed|upgraded|downgraded|removed|warning)>' end='$' contained
	\ contains=pacmanlogTransaction,pacmanlogInstalled,pacmanlogUpgraded,pacmanlogDowngraded,pacmanlogRemoved,pacmanlogWarning,pacmanlogPackageName,pacmanlogPackgeVersion

hi def link pacmanlogTime String
hi def link pacmanlogTag  Type

hi def link pacmanlogTransaction Special
hi def link pacmanlogInstalled   Identifier
hi def link pacmanlogRemoved     Repeat
hi def link pacmanlogUpgraded    pacmanlogInstalled
hi def link pacmanlogDowngraded  pacmanlogRemoved
hi def link pacmanlogWarning     WarningMsg

hi def link pacmanlogPackageName    Normal
hi def link pacmanlogPackageVersion Comment

let b:current_syntax = "pacmanlog"
