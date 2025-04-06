" Vim syntax file
" Language:             man.conf(5) - man configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword manconfTodo         contained TODO FIXME XXX NOTE

syn region  manconfComment      display oneline start='^#' end='$'
                                \ contains=manconfTodo,@Spell

if !has("win32") && $OSTYPE =~   'bsd'
  syn match   manconfBegin      display '^'
                                \ nextgroup=manconfKeyword,manconfSection,
                                \ manconfComment skipwhite

  syn keyword manconfKeyword    contained _build _crunch
                                \ nextgroup=manconfExtCmd skipwhite

  syn keyword manconfKeyword    contained _suffix
                                \ nextgroup=manconfExt skipwhite

  syn keyword manconfKeyword    contained _crunch

  syn keyword manconfKeyword    contained _subdir _version _whatdb
                                \ nextgroup=manconfPaths skipwhite

  syn match   manconfExtCmd     contained display '\.\S\+'
                                \ nextgroup=manconfPaths skipwhite

  syn match   manconfSection    contained '[^#_ \t]\S*'
                                \ nextgroup=manconfPaths skipwhite

  syn keyword manconfSection    contained _default
                                \ nextgroup=manconfPaths skipwhite

  syn match   manconfPaths      contained display '\S\+'
                                \ nextgroup=manconfPaths skipwhite

  syn match   manconfExt        contained display '\.\S\+'

  hi def link manconfExtCmd     Type
  hi def link manconfSection    Identifier
  hi def link manconfPaths      String
else
  syn match   manconfBegin      display '^'
                                \ nextgroup=manconfBoolean,manconfKeyword,
                                \ manconfDecompress,manconfComment skipwhite

  syn keyword manconfBoolean    contained FSSTND FHS NOAUTOPATH NOCACHE

  syn keyword manconfKeyword    contained MANBIN
                                \ nextgroup=manconfPath skipwhite

  syn keyword manconfKeyword    contained MANPATH MANPATH_MAP
                                \ nextgroup=manconfFirstPath skipwhite

  syn keyword manconfKeyword    contained APROPOS WHATIS TROFF NROFF JNROFF EQN
                                \ NEQN JNEQN TBL COL REFER PIC VGRIND GRAP
                                \ PAGER BROWSER HTMLPAGER CMP CAT COMPRESS
                                \ DECOMPRESS MANDEFOPTIONS
                                \ nextgroup=manconfCommand skipwhite

  syn keyword manconfKeyword    contained COMPRESS_EXT
                                \ nextgroup=manconfExt skipwhite

  syn keyword manconfKeyword    contained MANSECT
                                \ nextgroup=manconfManSect skipwhite

  syn match   manconfPath       contained display '\S\+'

  syn match   manconfFirstPath  contained display '\S\+'
                                \ nextgroup=manconfSecondPath skipwhite

  syn match   manconfSecondPath contained display '\S\+'

  syn match   manconfCommand    contained display '\%(/[^/ \t]\+\)\+'
                                \ nextgroup=manconfCommandOpt skipwhite

  syn match   manconfCommandOpt contained display '\S\+'
                                \ nextgroup=manconfCommandOpt skipwhite

  syn match   manconfExt        contained display '\.\S\+'

  syn match   manconfManSect    contained '[^:]\+' nextgroup=manconfManSectSep

  syn match   manconfManSectSep contained ':' nextgroup=manconfManSect

  syn match   manconfDecompress contained '\.\S\+'
                                \ nextgroup=manconfCommand skipwhite

  hi def link manconfBoolean    Boolean
  hi def link manconfPath       String
  hi def link manconfFirstPath  manconfPath
  hi def link manconfSecondPath manconfPath
  hi def link manconfCommand    String
  hi def link manconfCommandOpt Special
  hi def link manconfManSect    Identifier
  hi def link manconfManSectSep Delimiter
  hi def link manconfDecompress Type
endif

hi def link manconfTodo         Todo
hi def link manconfComment      Comment
hi def link manconfKeyword      Keyword
hi def link manconfExt          Type

let b:current_syntax = "manconf"

let &cpo = s:cpo_save
unlet s:cpo_save
