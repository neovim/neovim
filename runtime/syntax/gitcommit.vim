" Vim syntax file
" Language:	git commit file
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Filenames:	*.git/COMMIT_EDITMSG
" Last Change:	2022 Jan 05

if exists("b:current_syntax")
  finish
endif

scriptencoding utf-8

syn case match
syn sync minlines=50
syn sync linebreaks=1

if has("spell")
  syn spell toplevel
endif

syn include @gitcommitDiff syntax/diff.vim
syn region gitcommitDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@gitcommitDiff

syn match   gitcommitSummary	"^.*\%<51v." contained containedin=gitcommitFirstLine nextgroup=gitcommitOverflow contains=@Spell
syn match   gitcommitOverflow	".*" contained contains=@Spell
syn match   gitcommitBlank	"^.\+" contained contains=@Spell
syn match   gitcommitFirstLine	"\%^.*" nextgroup=gitcommitBlank,gitcommitComment skipnl

let s:scissors = 0
let s:l = search('^[#;@!$%^&|:] -\{24,\} >8 -\{24,\}$', 'cnW', '', 100)
if s:l == 0
  let s:l = line('$')
elseif getline(s:l)[0] !=# getline(s:l - 1)[0]
  let s:scissors = 1
endif
let s:comment = escape((matchstr(getline(s:l), '^[#;@!$%^&|:]\S\@!') . '#')[0], '^$.*[]~\"/')

if s:scissors
  let s:comment .= ' -\{24,\} >8 -\{24,\}$'
  exe 'syn region gitcommitComment start="^' . s:comment . '" end="\%$" contains=gitcommitDiff'
else
  exe 'syn match gitcommitComment "^' . s:comment . '.*"'
endif
exe 'syn match   gitcommitTrailers "\n\@<=\n\%([[:alnum:]-]\+\s*:.*\|(cherry picked from commit .*\)\%(\n\s.*\|\n[[:alnum:]-]\+\s*:.*\|\n(cherry picked from commit .*\)*\%(\n\n*\%(' . s:comment . '\)\|\n*\%$\)\@="'

unlet s:l s:comment s:scissors

syn match   gitcommitTrailerToken "^[[:alnum:]-]\+\s*:" contained containedin=gitcommitTrailers

syn match   gitcommitHash	"\<\x\{40,}\>" contains=@NoSpell display
syn match   gitcommitOnBranch	"\%(^. \)\@<=On branch" contained containedin=gitcommitComment nextgroup=gitcommitBranch skipwhite
syn match   gitcommitOnBranch	"\%(^. \)\@<=Your branch .\{-\} '" contained containedin=gitcommitComment nextgroup=gitcommitBranch skipwhite
syn match   gitcommitBranch	"[^ ']\+" contained
syn match   gitcommitNoBranch	"\%(^. \)\@<=Not currently on any branch." contained containedin=gitcommitComment
syn match   gitcommitHeader	"\%(^. \)\@<=\S.*[:：]\%(\n^$\)\@!$" contained containedin=gitcommitComment
syn region  gitcommitAuthor	matchgroup=gitCommitHeader start=/\%(^. \)\@<=\%(Author\|Committer\|Date\):/ end=/$/ keepend oneline contained containedin=gitcommitComment transparent
syn match   gitcommitHeader	"\%(^. \)\@<=commit\%( \x\{40,\}$\)\@=" contained containedin=gitcommitComment nextgroup=gitcommitHash skipwhite
syn match   gitcommitNoChanges	"\%(^. \)\@<=No changes$" contained containedin=gitcommitComment

syn match   gitcommitType		"\%(^.\t\)\@<=[^[:punct:][:space:]][^/:：]*[^[:punct:][:space:]][:：]\ze "he=e-1 contained containedin=gitcommitComment nextgroup=gitcommitFile skipwhite
syn match   gitcommitFile		".\{-\}\%($\| -> \)\@=" contained nextgroup=gitcommitArrow
syn match   gitcommitArrow		" -> " contained nextgroup=gitcommitFile
syn match   gitcommitUntrackedFile	"\%(^.\t\)\@<=[^:：/]*\%(/.*\)\=$" contained containedin=gitcommitComment

syn region  gitcommitUntracked	start=/^\z(.\) Untracked files:$/ end=/^\z1\=$\|^\z1\@!/ contains=gitcommitHeader containedin=gitcommitComment containedin=gitcommitComment contained transparent fold
syn region  gitcommitDiscarded	start=/^\z(.\) Change\%(s not staged for commit\|d but not updated\):$/ end=/^\z1\=$\|^\z1\@!/ contains=gitcommitHeader,gitcommitDiscardedType containedin=gitcommitComment containedin=gitcommitComment contained transparent fold
syn region  gitcommitSelected	start=/^\z(.\) Changes to be committed:$/ end=/^\z1$\|^\z1\@!/ contains=gitcommitHeader,gitcommitSelectedType containedin=gitcommitComment containedin=gitcommitComment contained transparent fold
syn region  gitcommitUnmerged	start=/^\z(.\) Unmerged paths:$/ end=/^\z1\=$\|^\z1\@!/ contains=gitcommitHeader,gitcommitUnmergedType containedin=gitcommitComment containedin=gitcommitComment contained transparent fold

syn match   gitcommitUntrackedFile	"\%(^.\t\)\@<=.*" contained containedin=gitcommitUntracked

syn match   gitcommitDiscardedType	"\%(^.\t\)\@<=[^[:punct:][:space:]][^/:：]*[^[:punct:][:space:]][:：]\ze "he=e-1 contained nextgroup=gitcommitDiscardedFile skipwhite
syn match   gitcommitSelectedType	"\%(^.\t\)\@<=[^[:punct:][:space:]][^/:：]*[^[:punct:][:space:]][:：]\ze "he=e-1 contained nextgroup=gitcommitSelectedFile skipwhite
syn match   gitcommitUnmergedType	"\%(^.\t\)\@<=[^[:punct:][:space:]][^/:：]*[^[:punct:][:space:]][:：]\ze "he=e-1 contained nextgroup=gitcommitUnmergedFile skipwhite
syn match   gitcommitDiscardedFile	"\S.\{-\}\%($\| -> \)\@=" contained nextgroup=gitcommitDiscardedArrow
syn match   gitcommitSelectedFile	"\S.\{-\}\%($\| -> \)\@=" contained nextgroup=gitcommitSelectedArrow
syn match   gitcommitUnmergedFile	"\S.\{-\}\%($\| -> \)\@=" contained nextgroup=gitcommitUnmergedArrow
syn match   gitcommitDiscardedArrow	" -> " contained nextgroup=gitcommitDiscardedFile
syn match   gitcommitSelectedArrow	" -> " contained nextgroup=gitcommitSelectedFile
syn match   gitcommitUnmergedArrow	" -> " contained nextgroup=gitcommitUnmergedFile

hi def link gitcommitSummary		Keyword
hi def link gitcommitTrailerToken	Label
hi def link gitcommitComment		Comment
hi def link gitcommitHash		Identifier
hi def link gitcommitOnBranch		Comment
hi def link gitcommitBranch		Special
hi def link gitcommitNoBranch		gitCommitBranch
hi def link gitcommitDiscardedType	gitcommitType
hi def link gitcommitSelectedType	gitcommitType
hi def link gitcommitUnmergedType	gitcommitType
hi def link gitcommitType		Type
hi def link gitcommitNoChanges		gitcommitHeader
hi def link gitcommitHeader		PreProc
hi def link gitcommitUntrackedFile	gitcommitFile
hi def link gitcommitDiscardedFile	gitcommitFile
hi def link gitcommitSelectedFile	gitcommitFile
hi def link gitcommitUnmergedFile	gitcommitFile
hi def link gitcommitFile		Constant
hi def link gitcommitDiscardedArrow	gitcommitArrow
hi def link gitcommitSelectedArrow	gitcommitArrow
hi def link gitcommitUnmergedArrow	gitcommitArrow
hi def link gitcommitArrow		gitcommitComment
"hi def link gitcommitOverflow		Error
hi def link gitcommitBlank		Error

let b:current_syntax = "gitcommit"
