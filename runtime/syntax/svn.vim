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

" quit when a syntax file was already loaded.
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet.
command -nargs=+ HiLink hi def link <args>

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

let b:current_syntax = "svn"
