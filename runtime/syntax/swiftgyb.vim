" This source file is part of the Swift.org open source project
"
" Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
" Licensed under Apache License v2.0 with Runtime Library Exception
"
" See https://swift.org/LICENSE.txt for license information
" See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
"
" Vim syntax file
" Language: gyb on swift
"
" Vim maintainer: Emir SARI <bitigchi@me.com>

runtime! syntax/swift.vim
unlet b:current_syntax

syn include @Python syntax/python.vim
syn region pythonCode matchgroup=gybPythonCode start=+^ *%+ end=+$+ contains=@Python keepend
syn region pythonCode matchgroup=gybPythonCode start=+%{+ end=+}%+ contains=@Python keepend
syn match gybPythonCode /\${[^}]*}/
hi def link gybPythonCode CursorLineNr

let b:current_syntax = "swiftgyb"

