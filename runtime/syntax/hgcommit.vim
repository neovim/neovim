" Vim syntax file
" Language:	hg/sl (Mercurial / Sapling) commit file
" Maintainer:	Ken Takata <kentkt at csc dot jp>
"  		Max Coplan <mchcopl@gmail.com>
" Last Change:	2022-12-08
" License:	VIM License
" URL:		https://github.com/k-takata/hg-vim

if exists("b:current_syntax")
  finish
endif

syn match hgcommitComment "^\%(SL\|HG\): .*$"            contains=@NoSpell
syn match hgcommitUser    "^\%(SL\|HG\): user: \zs.*$"   contains=@NoSpell contained containedin=hgcommitComment
syn match hgcommitBranch  "^\%(SL\|HG\): branch \zs.*$"  contains=@NoSpell contained containedin=hgcommitComment
syn match hgcommitAdded   "^\%(SL\|HG\): \zsadded .*$"   contains=@NoSpell contained containedin=hgcommitComment
syn match hgcommitChanged "^\%(SL\|HG\): \zschanged .*$" contains=@NoSpell contained containedin=hgcommitComment
syn match hgcommitRemoved "^\%(SL\|HG\): \zsremoved .*$" contains=@NoSpell contained containedin=hgcommitComment

syn region hgcommitDiff start=/\%(^\(SL\|HG\): diff --\%(git\|cc\|combined\) \)\@=/ end=/^\%(diff --\|$\|@@\@!\|[^[:alnum:]\ +-]\S\@!\)\@=/ fold contains=@hgcommitDiff
syn include @hgcommitDiff syntax/shared/hgcommitDiff.vim

hi def link hgcommitComment Comment
hi def link hgcommitUser    String
hi def link hgcommitBranch  String
hi def link hgcommitAdded   Identifier
hi def link hgcommitChanged Special
hi def link hgcommitRemoved Constant

let b:current_syntax = "hgcommit"
