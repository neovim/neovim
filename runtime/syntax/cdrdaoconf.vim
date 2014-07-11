" Vim syntax file
" Language:         cdrdao(1) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-09-02

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword cdrdaoconfTodo
      \ TODO FIXME XXX NOTE

syn match   cdrdaoconfBegin
      \ display
      \ nextgroup=@cdrdaoconfKeyword,cdrdaoconfComment
      \ '^'

syn cluster cdrdaoconfKeyword
      \ contains=cdrdaoconfIntegerKeyword,
      \          cdrdaoconfDriverKeyword,
      \          cdrdaoconfDeviceKeyword,
      \          cdrdaoconfPathKeyword

syn keyword cdrdaoconfIntegerKeyword
      \ contained
      \ nextgroup=cdrdaoconfIntegerDelimiter
      \ write_speed
      \ write_buffers
      \ user_capacity
      \ full_burn
      \ read_speed
      \ cddb_timeout

syn keyword cdrdaoconfIntegerKeyword
      \ contained
      \ nextgroup=cdrdaoconfParanoiaModeDelimiter
      \ read_paranoia_mode

syn keyword cdrdaoconfDriverKeyword
      \ contained
      \ nextgroup=cdrdaoconfDriverDelimiter
      \ write_driver
      \ read_driver

syn keyword cdrdaoconfDeviceKeyword
      \ contained
      \ nextgroup=cdrdaoconfDeviceDelimiter
      \ write_device
      \ read_device

syn keyword cdrdaoconfPathKeyword
      \ contained
      \ nextgroup=cdrdaoconfPathDelimiter
      \ cddb_directory
      \ tmp_file_dir

syn match   cdrdaoconfIntegerDelimiter
      \ contained
      \ nextgroup=cdrdaoconfInteger
      \ skipwhite
      \ ':'

syn match   cdrdaoconfParanoiaModeDelimiter
      \ contained
      \ nextgroup=cdrdaoconfParanoiaMode
      \ skipwhite
      \ ':'

syn match   cdrdaoconfDriverDelimiter
      \ contained
      \ nextgroup=cdrdaoconfDriver
      \ skipwhite
      \ ':'

syn match   cdrdaoconfDeviceDelimiter
      \ contained
      \ nextgroup=cdrdaoconfDevice
      \ skipwhite
      \ ':'

syn match   cdrdaoconfPathDelimiter
      \ contained
      \ nextgroup=cdrdaoconfPath
      \ skipwhite
      \ ':'

syn match   cdrdaoconfInteger
      \ contained
      \ '\<\d\+\>'

syn match   cdrdaoParanoiaMode
      \ contained
      \ '[0123]'

syn match   cdrdaoconfDriver
      \ contained
      \ '\<\(cdd2600\|generic-mmc\%(-raw\)\=\|plextor\%(-scan\)\|ricoh-mp6200\|sony-cdu9\%(20\|48\)\|taiyo-yuden\|teac-cdr55\|toshiba\|yamaha-cdr10x\)\>'

syn region  cdrdaoconfDevice
      \ contained
      \ matchgroup=cdrdaoconfDevice
      \ start=+"+
      \ end=+"+

syn region  cdrdaoconfPath
      \ contained
      \ matchgroup=cdrdaoconfPath
      \ start=+"+
      \ end=+"+

syn match   cdrdaoconfComment
      \ contains=cdrdaoconfTodo,@Spell
      \ '^.*#.*$'

hi def link cdrdaoconfTodo              Todo
hi def link cdrdaoconfComment           Comment
hi def link cdrdaoconfKeyword           Keyword
hi def link cdrdaoconfIntegerKeyword    cdrdaoconfKeyword
hi def link cdrdaoconfDriverKeyword     cdrdaoconfKeyword
hi def link cdrdaoconfDeviceKeyword     cdrdaoconfKeyword
hi def link cdrdaoconfPathKeyword       cdrdaoconfKeyword
hi def link cdrdaoconfDelimiter         Delimiter
hi def link cdrdaoconfIntegerDelimiter  cdrdaoconfDelimiter
hi def link cdrdaoconfDriverDelimiter   cdrdaoconfDelimiter
hi def link cdrdaoconfDeviceDelimiter   cdrdaoconfDelimiter
hi def link cdrdaoconfPathDelimiter     cdrdaoconfDelimiter
hi def link cdrdaoconfInteger           Number
hi def link cdrdaoconfParanoiaMode      Number
hi def link cdrdaoconfDriver            Identifier
hi def link cdrdaoconfDevice            cdrdaoconfPath
hi def link cdrdaoconfPath              String

let b:current_syntax = "cdrdaoconf"

let &cpo = s:cpo_save
unlet s:cpo_save
