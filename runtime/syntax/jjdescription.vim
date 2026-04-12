" Vim syntax file
" Language:	jj description
" Maintainer:	Gregory Anders <greg@gpanders.com>
" Last Change:	2024 May 8
" 2025 Apr 17 by Vim Project (don't require space to start comments, #17130)
" 2026 Apr 09 by Vim Project (anchor status regex to beginning of line, #19879)
" 2026 Apr 09 by Vim Project (detect renames of files, #19879)
" 2026 Apr 11 by Vim Project (configure summary length, #19905)

if exists('b:current_syntax')
  finish
endif

syn match jjAdded "^JJ:\s\+\zsA\s.*" contained
syn match jjRemoved "^JJ:\s\+\zsD\s.*" contained
syn match jjChanged "^JJ:\s\+\zsM\s.*" contained
syn match jjRenamed "^JJ:\s\+\zsR\s.*" contained

syn region jjComment start="^JJ:" end="$" contains=jjAdded,jjRemoved,jjChanged,jjRenamed

syn include @jjCommitDiff syntax/diff.vim
syn region jjCommitDiff start=/\%(^diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@jjCommitDiff

if get(g:, 'jjcommit_summary_length', get(g:, 'gitcommit_summary_length', 0)) < 0
  syn match   jjdescriptionSummary	"^.*$" contained containedin=jjcommitFirstLine nextgroup=jjcommitOverflow contains=@Spell
elseif get(g:, 'jjcommit_summary_length', get(g:, 'gitcommit_summary_length', 1)) > 0
  exe 'syn match   jjdescriptionSummary	"^.*\%<' . (get(g:, 'jjcommit_summary_length', get(:g, 'gitcommit_summary_length', 50) + 1) . 'v." contained containedin=jjcommitFirstLine nextgroup=jjcommitOverflow contains=@Spell'
endif
syn match   jjcommitOverflow	".*" contained contains=@Spell
syn match   jjcommitBlank	"^.\+" contained contains=@Spell
syn match   jjcommitFirstLine	"\%^.*" nextgroup=jjcommitBlank,jjComment skipnl

hi def link jjcommitSummary	Keyword
hi def link jjComment		Comment
hi def link jjAdded		Added
hi def link jjRemove		Removed
hi def link jjChange		Changed
hi def link jjRenamed		Changed
hi def link jjcommitBlank	Error

let b:current_syntax = 'jjdescription'
