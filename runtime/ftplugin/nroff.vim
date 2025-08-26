" Vim filetype plugin
" Language:	roff(7)
" Maintainer:	Aman Verma
" Homepage:	https://github.com/a-vrma/vim-nroff-ftplugin
" Document:	https://www.gnu.org/software/groff/manual/groff.html
" Previous Maintainer: Chris Spiegel <cspiegel@gmail.com>
" Last Changes:
"	2024 May 24 by Riley Bruins <ribru17@gmail.com> ('commentstring' #14843)
"	2025 Feb 12 by Wu, Zhenyu <wuzhenyu@ustc.edu> (matchit configuration #16619)
"	2025 Apr 16 by Eisuke Kawashima (cpoptions #17121)
"	2025 Apr 24 by Eisuke Kawashima (move options from syntax to ftplugin #17174)
"	2025 Jun 18 by Vim Project: update commentstring option (#17516)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal commentstring=.\\\"\ %s
setlocal comments=:.\\\",:\\\",:'\\\",:'''
setlocal sections+=Sh
setlocal define=.\s*de

if get(b:, 'preprocs_as_sections')
  setlocal sections=EQTSPS[\ G1GS
endif

let b:undo_ftplugin = 'setlocal commentstring< comments< sections& define<'

if get(b:, 'nroff_is_groff')
  " groff_ms exdented paragraphs are not in the default paragraphs list.
  setlocal paragraphs+=XP
  let b:undo_ftplugin .= ' paragraphs&'
endif

if exists('loaded_matchit')
  let b:match_words = '^\.\s*ie\>:^\.\s*el\>'
        \ . ',^\.\s*LB\>:^\.\s*LI\>:^\.\s*LE\>'
        \ . ',^\.\s*TS\>:^\.\s*TE\>'
        \ . ',^\.\s*PS\>:^\.\s*P[EF]\>'
        \ . ',^\.\s*EQ\>:^\.\s*EN\>'
        \ . ',^\.\s*[\>:^\.\s*]\>'
        \ . ',^\.\s*FS\>:^\.\s*FE\>'
  let b:undo_ftplugin .= "| unlet b:match_words"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
