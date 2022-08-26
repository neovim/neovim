" Vim syntax file
" Language:	generic git output
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2022 Jan 05

if exists("b:current_syntax")
  finish
endif

syn case match
syn sync minlines=50

syn include @gitDiff syntax/diff.vim

syn region gitHead start=/\%^\%(tag \|tree \|object \)\@=/ end=/^$/ contains=@NoSpell
syn region gitHead start=/\%(^commit\%( \x\{4,\}\)\{1,\}\%(\s*(.*)\)\=$\)\@=/ end=/^$/ contains=@NoSpell
" git log --oneline
" minimize false positives by verifying contents of buffer
if getline(1) =~# '^\x\{7,\} ' && getline('$') =~# '^\x\{7,\} '
  syn match gitHashAbbrev /^\x\{7,\} \@=/ contains=@NoSpell
elseif getline(1) =~#     '^[|\/\\_ ]\{-\}\*[|\/\\_ ]\{-\} \x\{7,\} '
  syn match gitHashAbbrev /^[|\/\\_ ]\{-\}\*[|\/\\_ ]\{-\} \zs\x\{7,\} \@=/ contains=@NoSpell
endif
" git log --graph
syn region gitGraph start=/\%(^[|\/\\_ ]*\*[|\/\\_ ]\{-\} commit\%( \x\{4,\}\)\{1,\}\%(\s*(.*)\)\=$\)\@=/ end=/^\%([|\/\\_ ]*$\)\@=/ contains=@NoSpell
" git blame --porcelain
syn region gitHead start=/\%(^\x\{40,\} \d\+ \d\+\%( \d\+\)\=$\)\@=/ end=/^\t\@=/ contains=@NoSpell
" git ls-tree
syn match  gitMode    /^\d\{6\}\%( \%(blob\|tree\) \x\{4,\}\t\)\@=/ nextgroup=gitType skipwhite contains=@NoSpell
" git ls-files --stage
syn match  gitMode    /^\d\{6\}\%( \x\{4,\} [0-3]\t\)\@=/ nextgroup=gitHashStage skipwhite contains=@NoSpell
" .git/HEAD, .git/refs/
syn match  gitKeyword /\%^ref: \@=/ nextgroup=gitReference skipwhite contains=@NoSpell
syn match  gitHash /\%^\x\{40,}\%$/ skipwhite contains=@NoSpell
" .git/logs/
syn match  gitReflog /^\x\{40,\} \x\{40,\} .\{-\}\d\+\s-\d\{4\}\t.*/ skipwhite contains=@NoSpell,gitReflogOld

syn region gitDiff start=/^\%(diff --git \)\@=/ end=/^\%(diff --\|$\)\@=/ contains=@gitDiff fold
syn region gitDiff start=/^\%(@@ -\)\@=/ end=/^\%(diff --\%(git\|cc\|combined\) \|$\)\@=/ contains=@gitDiff

syn region gitDiffMerge start=/^\%(diff --\%(cc\|combined\) \)\@=/ end=/^\%(diff --\|$\)\@=/ contains=@gitDiff
syn region gitDiffMerge start=/^\%(@@@@* -\)\@=/ end=/^\%(diff --\|$\)\@=/ contains=@gitDiff
syn match gitDiffAdded "^ \++.*" contained containedin=gitDiffMerge
syn match gitDiffAdded "{+[^}]*+}" contained containedin=gitDiff
syn match gitDiffRemoved "^ \+-.*" contained containedin=gitDiffMerge
syn match gitDiffRemoved "\[-[^]]*-\]" contained containedin=gitDiff

syn match  gitKeyword /^commit \@=/ contained containedin=gitHead nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitKeyword /^\%(object\|tree\|parent\|encoding\|gpgsig\%(-\w\+\)\=\|previous\) \@=/ contained containedin=gitHead nextgroup=gitHash skipwhite contains=@NoSpell
syn match  gitKeyword /^Merge:/  contained containedin=gitHead nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitIdentityKeyword /^\%(author\|committer\|tagger\) \@=/ contained containedin=gitHead nextgroup=gitIdentity skipwhite contains=@NoSpell
syn match  gitIdentityHeader /^\%(Author\|Commit\|Tagger\):/ contained containedin=gitHead nextgroup=gitIdentity skipwhite contains=@NoSpell
syn match  gitDateHeader /^\%(AuthorDate\|CommitDate\|Date\):/ contained containedin=gitHead nextgroup=gitDate skipwhite contains=@NoSpell

syn match  gitKeyword /^[*|\/\\_ ]\+\zscommit \@=/ contained containedin=gitGraph nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitKeyword /^[|\/\\_ ]\+\zs\%(object\|tree\|parent\|encoding\|gpgsig\%(-\w\+\)\=\|previous\) \@=/ contained containedin=gitGraph nextgroup=gitHash skipwhite contains=@NoSpell
syn match  gitKeyword /^[|\/\\_ ]\+\zsMerge:/  contained containedin=gitGraph nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitIdentityKeyword /^[|\/\\_ ]\+\zs\%(author\|committer\|tagger\) \@=/ contained containedin=gitGraph nextgroup=gitIdentity skipwhite contains=@NoSpell
syn match  gitIdentityHeader /^[|\/\\_ ]\+\zs\%(Author\|Commit\|Tagger\):/ contained containedin=gitGraph nextgroup=gitIdentity skipwhite contains=@NoSpell
syn match  gitDateHeader /^[|\/\\_ ]\+\zs\%(AuthorDate\|CommitDate\|Date\):/ contained containedin=gitGraph nextgroup=gitDate skipwhite contains=@NoSpell

syn match  gitKeyword /^type \@=/ contained containedin=gitHead nextgroup=gitType skipwhite contains=@NoSpell
syn match  gitKeyword /^\%(summary\|boundary\|filename\|\%(author\|committer\)-\%(time\|tz\)\) \@=/ contained containedin=gitHead skipwhite contains=@NoSpell
syn match  gitKeyword /^tag \@=/ contained containedin=gitHead nextgroup=gitReference skipwhite contains=@NoSpell
syn match  gitIdentityKeyword /^\%(author\|committer\)-mail \@=/ contained containedin=gitHead nextgroup=gitEmail skipwhite contains=@NoSpell
syn match  gitReflogHeader /^Reflog:/ contained containedin=gitHead nextgroup=gitReflogMiddle skipwhite contains=@NoSpell
syn match  gitReflogHeader /^Reflog message:/ contained containedin=gitHead skipwhite contains=@NoSpell
syn match  gitReflogMiddle /\S\+@{\d\+} (/he=e-2 nextgroup=gitIdentity contains=@NoSpell

syn match  gitIdentity /\S.\{-\} <[^>]*>/ contained nextgroup=gitDate skipwhite contains=@NoSpell
syn region gitEmail matchgroup=gitEmailDelimiter start=/</ end=/>/ keepend oneline contained containedin=gitIdentity contains=@NoSpell
syn match  gitDate      /\<\u\l\l \u\l\l \d\=\d \d\d:\d\d:\d\d \d\d\d\d [+-]\d\d\d\d/ contained contains=@NoSpell
syn match  gitDate      /-\=\d\+ [+-]\d\d\d\d\>/               contained contains=@NoSpell
syn match  gitDate      /\<\d\+ \l\+ ago\>/                    contained contains=@NoSpell
syn match  gitType      /\<\%(tag\|commit\|tree\|blob\)\>/     contained nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitReference /\S\+\S\@!/                            contained contains=@NoSpell
syn match  gitHash      /\<\x\{40,\}\>/             contained nextgroup=gitIdentity,gitHash skipwhite contains=@NoSpell
syn match  gitReflogOld /^\x\{40,\} \@=/            contained nextgroup=gitReflogNew skipwhite contains=@NoSpell
syn match  gitReflogNew /\<\x\{40,\} \@=/           contained nextgroup=gitIdentity skipwhite contains=@NoSpell
syn match  gitHashAbbrev /\<\x\{4,\}\>/             contained nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitHashAbbrev /\<\x\{4,39\}\.\.\./he=e-3 contained nextgroup=gitHashAbbrev skipwhite contains=@NoSpell
syn match  gitHashStage /\<\x\{4,\}\>/              contained nextgroup=gitStage skipwhite contains=@NoSpell
syn match  gitStage     /\<\d\t\@=/                 contained contains=@NoSpell


syn match  gitNotesHeader /^Notes:\ze\n    /

hi def link gitDateHeader        gitIdentityHeader
hi def link gitIdentityHeader    gitIdentityKeyword
hi def link gitIdentityKeyword   Label
hi def link gitNotesHeader       gitKeyword
hi def link gitReflogHeader      gitKeyword
hi def link gitKeyword           Keyword
hi def link gitIdentity          String
hi def link gitEmailDelimiter    Delimiter
hi def link gitEmail             Special
hi def link gitDate              Number
hi def link gitMode              Number
hi def link gitHashStage         gitHash
hi def link gitHashAbbrev        gitHash
hi def link gitReflogOld         gitHash
hi def link gitReflogNew         gitHash
hi def link gitHash              Identifier
hi def link gitReflogMiddle      gitReference
hi def link gitReference         Function
hi def link gitStage             gitType
hi def link gitType              Type
hi def link gitDiffAdded         diffAdded
hi def link gitDiffRemoved       diffRemoved

let b:current_syntax = "git"
