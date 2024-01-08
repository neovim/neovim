" tarPlugin.vim -- a Vim plugin for browsing tarfiles
" Original was copyright (c) 2002, Michael C. Toren <mct@toren.net>
" Modified by Charles E. Campbell
" Distributed under the GNU General Public License.
"
" Updates are available from <http://michael.toren.net/code/>.  If you
" find this script useful, or have suggestions for improvements, please
" let me know.
" Also look there for further comments and documentation.
"
" This part only sets the autocommands.  The functions are in autoload/tar.vim.
" ---------------------------------------------------------------------
"  Load Once: {{{1
if &cp || exists("g:loaded_tarPlugin")
 finish
endif
let g:loaded_tarPlugin = "v32"
let s:keepcpo          = &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Public Interface: {{{1
augroup tar
  au!
  au BufReadCmd   tarfile::*	call tar#Read(expand("<amatch>"), 1)
  au FileReadCmd  tarfile::*	call tar#Read(expand("<amatch>"), 0)
  au BufWriteCmd  tarfile::*	call tar#Write(expand("<amatch>"))
  au FileWriteCmd tarfile::*	call tar#Write(expand("<amatch>"))

  if has("unix")
   au BufReadCmd   tarfile::*/*	call tar#Read(expand("<amatch>"), 1)
   au FileReadCmd  tarfile::*/*	call tar#Read(expand("<amatch>"), 0)
   au BufWriteCmd  tarfile::*/*	call tar#Write(expand("<amatch>"))
   au FileWriteCmd tarfile::*/*	call tar#Write(expand("<amatch>"))
  endif

  au BufReadCmd   *.tar.gz		call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar			call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.lrp			call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar.bz2		call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar.Z		call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tbz			call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tgz			call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar.lzma	call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar.xz		call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.txz			call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tar.zst		call tar#Browse(expand("<amatch>"))
  au BufReadCmd   *.tzst			call tar#Browse(expand("<amatch>"))
augroup END

" ---------------------------------------------------------------------
" Restoration And Modelines: {{{1
" vim: fdm=marker
let &cpo= s:keepcpo
unlet s:keepcpo
