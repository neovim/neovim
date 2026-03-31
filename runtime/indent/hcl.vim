" Vim indent file
" Language:    HCL
" Maintainer:  Gregory Anders
" Upstream:    https://github.com/hashivim/vim-terraform
" License:     ISC
" Last Change: 2024-09-03
"
" Copyright (c) 2014-2016 Mark Cornick <mark@markcornick.com>
"
" Permission to use, copy, modify, and/or distribute this software for any purpose
" with or without fee is hereby granted, provided that the above copyright notice
" and this permission notice appear in all copies.
"
" THE SOFTWARE IS PROVIDED 'AS IS' AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
" REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
" FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
" INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
" OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
" TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
" THIS SOFTWARE.

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal autoindent shiftwidth=2 tabstop=2 softtabstop=2 expandtab
setlocal indentexpr=hcl#indentexpr(v:lnum)
setlocal indentkeys+=<:>,0=},0=)

let b:undo_indent = 'setlocal ai< sw< ts< sts< et< inde< indk<'
