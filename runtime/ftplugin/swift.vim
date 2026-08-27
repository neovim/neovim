" This source file is part of the Swift.org open source project
"
" Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
" Licensed under Apache License v2.0 with Runtime Library Exception
"
" See https://swift.org/LICENSE.txt for license information
" See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
"
" Vim maintainer: 	Emir SARI <bitigchi@me.com>
" Last Change:		2021 Jan 08
"			2026 Jun 27 by Vim Project (add recommended style guard)

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
    finish
endif

let b:did_ftplugin = 1
let b:undo_ftplugin = "setlocal comments< expandtab< tabstop< shiftwidth< smartindent<"

setlocal comments=s1:/*,mb:*,ex:*/,:///,://
if get(g:, 'swift_recommended_style',
      \ get(g:, 'filetype_recommended_style', 1))
  setlocal expandtab
  setlocal sw=4 sts=4
endif
setlocal smartindent
