" Vim syntax file
" Language:	none; used to see highlighting
" Maintainer:	Ronald Schild <rs@scutum.de>
" Last Change:	2019 Jun 06
" Version:	5.4n.1
" Additional Changes By: Lifepillar, Bram

" To see your current highlight settings, do
"    :so $VIMRUNTIME/syntax/hitest.vim

" save global options and registers
let s:hidden      = &hidden
let s:lazyredraw  = &lazyredraw
let s:more	  = &more
let s:report      = &report
let s:whichwrap   = &whichwrap
let s:shortmess   = &shortmess
let s:wrapscan    = &wrapscan
let s:register_a  = @a
let s:register_se = @/

" set global options
set hidden lazyredraw nomore report=99999 shortmess=aoOstTW wrapscan
set whichwrap&

" print current highlight settings into register a
redir @a
silent highlight
redir END

" Open a new window if the current one isn't empty
if line("$") != 1 || getline(1) != ""
  new
endif

" edit temporary file
edit Highlight\ test

" set local options
setlocal autoindent noexpandtab formatoptions=t shiftwidth=18 noswapfile tabstop=18
let &textwidth=&columns

" insert highlight settings
% delete
put a

" remove cleared groups
silent! g/ cleared$/d

" remove the colored xxx items
g/xxx /s///e

" remove color settings (not needed here)
global! /links to/ substitute /\s.*$//e

" Move split 'links to' lines to the same line
% substitute /^\(\w\+\)\n\s*\(links to.*\)/\1\t\2/e

" move linked groups to the end of file
global /links to/ move $

" move linked group names to the matching preferred groups
" TODO: this fails if the group linked to isn't defined
% substitute /^\(\w\+\)\s*\(links to\)\s*\(\w\+\)$/\3\t\2 \1/e
silent! global /links to/ normal mz3ElD0#$p'zdd

" delete empty lines
global /^ *$/ delete

" precede syntax command
% substitute /^[^ ]*/syn keyword &\t&/

" execute syntax commands
syntax clear
% yank a
@a

" remove syntax commands again
% substitute /^syn keyword //

" pretty formatting
global /^/ exe "normal Wi\<CR>\t\eAA\ex"
global /^\S/ join

" find out first syntax highlighting
let b:various = &highlight.',:Normal,:Cursor,:,'
let b:i = 1
while b:various =~ ':'.substitute(getline(b:i), '\s.*$', ',', '')
   let b:i = b:i + 1
   if b:i > line("$") | break | endif
endwhile

" insert headlines
call append(0, "Highlighting groups for various occasions")
call append(1, "-----------------------------------------")

if b:i < line("$")-1
   let b:synhead = "Syntax highlighting groups"
   if exists("hitest_filetypes")
      redir @a
      let
      redir END
      let @a = substitute(@a, 'did_\(\w\+\)_syn\w*_inits\s*#1', ', \1', 'g')
      let @a = substitute(@a, "\n\\w[^\n]*", '', 'g')
      let @a = substitute(@a, "\n", '', 'g')
      let @a = substitute(@a, '^,', '', 'g')
      if @a != ""
	 let b:synhead = b:synhead." - filetype"
	 if @a =~ ','
	    let b:synhead = b:synhead."s"
	 endif
	 let b:synhead = b:synhead.":".@a
      endif
   endif
   call append(b:i+1, "")
   call append(b:i+2, b:synhead)
   call append(b:i+3, substitute(b:synhead, '.', '-', 'g'))
endif

" remove 'hls' highlighting
nohlsearch
normal 0

" we don't want to save this temporary file
set nomodified

" the following trick avoids the "Press RETURN ..." prompt
0 append
.

" restore global options and registers
let &hidden      = s:hidden
let &lazyredraw  = s:lazyredraw
let &more	 = s:more
let &report	 = s:report
let &shortmess	 = s:shortmess
let &whichwrap   = s:whichwrap
let &wrapscan	 = s:wrapscan
let @a		 = s:register_a

" restore last search pattern
call histdel("search", -1)
let @/ = s:register_se

" remove variables
unlet s:hidden s:lazyredraw s:more s:report s:shortmess
unlet s:whichwrap s:wrapscan s:register_a s:register_se

" vim: ts=8
