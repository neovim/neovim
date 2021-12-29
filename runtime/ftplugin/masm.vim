" Vim filetype plugin file
" Language:	Microsoft Macro Assembler (80x86)
" Maintainer:	Wu Yongwei <wuyongwei@gmail.com>
" Last Change:	2020-05-09 23:02:05 +0800

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl iskeyword<"

setlocal iskeyword=@,48-57,_,36,60,62,63,@-@

let &cpo = s:cpo_save
unlet s:cpo_save
