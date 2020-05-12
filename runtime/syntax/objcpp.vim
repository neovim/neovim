" Vim syntax file
" Language:	    Objective C++
" Maintainer:	    Kazunobu Kuriyama <kazunobu.kuriyama@nifty.com>
" Ex-Maintainer:    Anthony Hodsdon <ahodsdon@fastmail.fm>
" Last Change:	    2007 Oct 29

" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

" Read in C++ and ObjC syntax files
runtime! syntax/cpp.vim
unlet b:current_syntax
runtime! syntax/objc.vim

syn keyword objCppNonStructure    class template namespace transparent contained
syn keyword objCppNonStatement    new delete friend using transparent contained

let b:current_syntax = "objcpp"
