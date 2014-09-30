" Vim syntax file
" Language:     Subversion (svn) commit file
" Maintainer:   Dmitry Vasiliev <dima at hlabs dot org>
" URL:          https://github.com/hdima/vim-scripts/blob/master/syntax/svn.vim
" Last Change:  2013-11-08
" Filenames:    svn-commit*.tmp
" Version:      1.10

" Contributors:
"
" List of the contributors in alphabetical order:
"
"   A. S. Budden
"   Ingo Karkat
"   Myk Taylor
"   Stefano Zacchiroli

" For version 5.x: Clear all syntax items.
" For version 6.x: Quit when a syntax file was already loaded.
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn spell toplevel

syn match svnFirstLine  "\%^.*" nextgroup=svnRegion,svnBlank skipnl
syn match svnSummary    "^.\{0,50\}" contained containedin=svnFirstLine nextgroup=svnOverflow contains=@Spell
syn match svnOverflow   ".*" contained contains=@Spell
syn match svnBlank      "^.*" contained contains=@Spell

syn region svnRegion    end="\%$" matchgroup=svnDelimiter start="^--.*--$" contains=svnRemoved,svnRenamed,svnAdded,svnModified,svnProperty,@NoSpell
syn match svnRemoved    "^D    .*$" contained contains=@NoSpell
syn match svnRenamed    "^R[ M][ U][ +] .*$" contained contains=@NoSpell
syn match svnAdded      "^A[ M][ U][ +] .*$" contained contains=@NoSpell
syn match svnModified   "^M[ M][ U]  .*$" contained contains=@NoSpell
syn match svnProperty   "^_M[ U]  .*$" contained contains=@NoSpell

" Synchronization.
syn sync clear
syn sync match svnSync  grouphere svnRegion "^--.*--$"me=s-1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already.
" For version 5.8 and later: only when an item doesn't have highlighting yet.
if version >= 508 || !exists("did_svn_syn_inits")
  if version <= 508
    let did_svn_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink svnSummary     Keyword
  HiLink svnBlank       Error

  HiLink svnRegion      Comment
  HiLink svnDelimiter   NonText
  HiLink svnRemoved     Constant
  HiLink svnAdded       Identifier
  HiLink svnModified    Special
  HiLink svnProperty    Special
  HiLink svnRenamed     Special

  delcommand HiLink
endif

let b:current_syntax = "svn"
