" Vim syntax file
" Language:	    Objective C++
" Maintainer:	    Kazunobu Kuriyama <kazunobu.kuriyama@nifty.com>
" Ex-Maintainer:    Anthony Hodsdon <ahodsdon@fastmail.fm>
" Last Change:	    2007 Oct 29

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif

" Read in C++ and ObjC syntax files
if version < 600
   so <sfile>:p:h/cpp.vim
   so <sfile>:p:h/objc.vim
else
   runtime! syntax/cpp.vim
   unlet b:current_syntax
   runtime! syntax/objc.vim
endif

syn keyword objCppNonStructure    class template namespace transparent contained
syn keyword objCppNonStatement    new delete friend using transparent contained

let b:current_syntax = "objcpp"
