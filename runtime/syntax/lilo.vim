" Vim syntax file
" Language: lilo configuration (lilo.conf)
" Maintainer: Niels Horn <niels.horn@gmail.com>
" Previous Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2010-02-03

" Setup
if version >= 600
  if exists("b:current_syntax")
    finish
  endif
else
  syntax clear
endif

if version >= 600
  command -nargs=1 SetIsk setlocal iskeyword=<args>
else
  command -nargs=1 SetIsk set iskeyword=<args>
endif
SetIsk @,48-57,.,-,_
delcommand SetIsk

syn case ignore

" Base constructs
syn match liloError "\S\+"
syn match liloComment "#.*$"
syn match liloEnviron "\$\w\+" contained
syn match liloEnviron "\${[^}]\+}" contained
syn match liloDecNumber "\d\+" contained
syn match liloHexNumber "0[xX]\x\+" contained
syn match liloDecNumberP "\d\+p\=" contained
syn match liloSpecial contained "\\\(\"\|\\\|$\)"
syn region liloString start=+"+ skip=+\\\\\|\\"+ end=+"+ contained contains=liloSpecial,liloEnviron
syn match liloLabel :[^ "]\+: contained contains=liloSpecial,liloEnviron
syn region liloPath start=+[$/]+ skip=+\\\\\|\\ \|\\$"+ end=+ \|$+ contained contains=liloSpecial,liloEnviron
syn match liloDecNumberList "\(\d\|,\)\+" contained contains=liloDecNumber
syn match liloDecNumberPList "\(\d\|[,p]\)\+" contained contains=liloDecNumberP,liloDecNumber
syn region liloAnything start=+[^[:space:]#]+ skip=+\\\\\|\\ \|\\$+ end=+ \|$+ contained contains=liloSpecial,liloEnviron,liloString

" Path
syn keyword liloOption backup bitmap boot disktab force-backup keytable map message nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn keyword liloKernelOpt initrd root nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn keyword liloImageOpt path loader table nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn keyword liloDiskOpt partition nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty

" Other
syn keyword liloOption menu-scheme raid-extra-boot serial install nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty
syn keyword liloOption bios-passes-dl nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty
syn keyword liloOption default label alias wmdefault nextgroup=liloEqLabelString,liloEqLabelStringComment,liloError skipwhite skipempty
syn keyword liloKernelOpt ramdisk nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty
syn keyword liloImageOpt password range nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty
syn keyword liloDiskOpt set type nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty

" Symbolic
syn keyword liloKernelOpt vga nextgroup=liloEqVga,liloEqVgaComment,liloError skipwhite skipempty

" Number
syn keyword liloOption delay timeout verbose nextgroup=liloEqDecNumber,liloEqDecNumberComment,liloError skipwhite skipempty
syn keyword liloDiskOpt sectors heads cylinders start nextgroup=liloEqDecNumber,liloEqDecNumberComment,liloError skipwhite skipempty

" String
syn keyword liloOption menu-title nextgroup=liloEqString,liloEqStringComment,liloError skipwhite skipempty
syn keyword liloKernelOpt append addappend nextgroup=liloEqString,liloEqStringComment,liloError skipwhite skipempty
syn keyword liloImageOpt fallback literal nextgroup=liloEqString,liloEqStringComment,liloError skipwhite skipempty

" Hex number
syn keyword liloImageOpt map-drive to boot-as nextgroup=liloEqHexNumber,liloEqHexNumberComment,liloError skipwhite skipempty
syn keyword liloDiskOpt bios normal hidden nextgroup=liloEqNumber,liloEqNumberComment,liloError skipwhite skipempty

" Number list
syn keyword liloOption bmp-colors nextgroup=liloEqNumberList,liloEqNumberListComment,liloError skipwhite skipempty

" Number list, some of the numbers followed by p
syn keyword liloOption bmp-table bmp-timer nextgroup=liloEqDecNumberPList,liloEqDecNumberPListComment,liloError skipwhite skipempty

" Flag
syn keyword liloOption compact fix-table geometric ignore-table lba32 linear mandatory nowarn prompt
syn keyword liloOption bmp-retain el-torito-bootable-CD large-memory suppress-boot-time-BIOS-data
syn keyword liloKernelOpt read-only read-write
syn keyword liloImageOpt bypass lock mandatory optional restricted single-key unsafe
syn keyword liloImageOpt master-boot wmwarn wmdisable
syn keyword liloDiskOpt change activate deactivate inaccessible reset

" Image
syn keyword liloImage image other nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn keyword liloDisk disk nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn keyword liloChRules change-rules

" Vga keywords
syn keyword liloVgaKeyword ask ext extended normal contained

" Comment followed by equal sign and ...
syn match liloEqPathComment "#.*$" contained nextgroup=liloEqPath,liloEqPathComment,liloError skipwhite skipempty
syn match liloEqVgaComment "#.*$" contained nextgroup=liloEqVga,liloEqVgaComment,liloError skipwhite skipempty
syn match liloEqNumberComment "#.*$" contained nextgroup=liloEqNumber,liloEqNumberComment,liloError skipwhite skipempty
syn match liloEqDecNumberComment "#.*$" contained nextgroup=liloEqDecNumber,liloEqDecNumberComment,liloError skipwhite skipempty
syn match liloEqHexNumberComment "#.*$" contained nextgroup=liloEqHexNumber,liloEqHexNumberComment,liloError skipwhite skipempty
syn match liloEqStringComment "#.*$" contained nextgroup=liloEqString,liloEqStringComment,liloError skipwhite skipempty
syn match liloEqLabelStringComment "#.*$" contained nextgroup=liloEqLabelString,liloEqLabelStringComment,liloError skipwhite skipempty
syn match liloEqNumberListComment "#.*$" contained nextgroup=liloEqNumberList,liloEqNumberListComment,liloError skipwhite skipempty
syn match liloEqDecNumberPListComment "#.*$" contained nextgroup=liloEqDecNumberPList,liloEqDecNumberPListComment,liloError skipwhite skipempty
syn match liloEqAnythingComment "#.*$" contained nextgroup=liloEqAnything,liloEqAnythingComment,liloError skipwhite skipempty

" Equal sign followed by ...
syn match liloEqPath "=" contained nextgroup=liloPath,liloPathComment,liloError skipwhite skipempty
syn match liloEqVga "=" contained nextgroup=liloVgaKeyword,liloHexNumber,liloDecNumber,liloVgaComment,liloError skipwhite skipempty
syn match liloEqNumber "=" contained nextgroup=liloDecNumber,liloHexNumber,liloNumberComment,liloError skipwhite skipempty
syn match liloEqDecNumber "=" contained nextgroup=liloDecNumber,liloDecNumberComment,liloError skipwhite skipempty
syn match liloEqHexNumber "=" contained nextgroup=liloHexNumber,liloHexNumberComment,liloError skipwhite skipempty
syn match liloEqString "=" contained nextgroup=liloString,liloStringComment,liloError skipwhite skipempty
syn match liloEqLabelString "=" contained nextgroup=liloString,liloLabel,liloLabelStringComment,liloError skipwhite skipempty
syn match liloEqNumberList "=" contained nextgroup=liloDecNumberList,liloDecNumberListComment,liloError skipwhite skipempty
syn match liloEqDecNumberPList "=" contained nextgroup=liloDecNumberPList,liloDecNumberPListComment,liloError skipwhite skipempty
syn match liloEqAnything "=" contained nextgroup=liloAnything,liloAnythingComment,liloError skipwhite skipempty

" Comment followed by ...
syn match liloPathComment "#.*$" contained nextgroup=liloPath,liloPathComment,liloError skipwhite skipempty
syn match liloVgaComment "#.*$" contained nextgroup=liloVgaKeyword,liloHexNumber,liloVgaComment,liloError skipwhite skipempty
syn match liloNumberComment "#.*$" contained nextgroup=liloDecNumber,liloHexNumber,liloNumberComment,liloError skipwhite skipempty
syn match liloDecNumberComment "#.*$" contained nextgroup=liloDecNumber,liloDecNumberComment,liloError skipwhite skipempty
syn match liloHexNumberComment "#.*$" contained nextgroup=liloHexNumber,liloHexNumberComment,liloError skipwhite skipempty
syn match liloStringComment "#.*$" contained nextgroup=liloString,liloStringComment,liloError skipwhite skipempty
syn match liloLabelStringComment "#.*$" contained nextgroup=liloString,liloLabel,liloLabelStringComment,liloError skipwhite skipempty
syn match liloDecNumberListComment "#.*$" contained nextgroup=liloDecNumberList,liloDecNumberListComment,liloError skipwhite skipempty
syn match liloDecNumberPListComment "#.*$" contained nextgroup=liloDecNumberPList,liloDecNumberPListComment,liloError skipwhite skipempty
syn match liloAnythingComment "#.*$" contained nextgroup=liloAnything,liloAnythingComment,liloError skipwhite skipempty

" Define the default highlighting
if version >= 508 || !exists("did_lilo_syntax_inits")
  if version < 508
    let did_lilo_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink liloEqPath             liloEquals
  HiLink liloEqWord             liloEquals
  HiLink liloEqVga              liloEquals
  HiLink liloEqDecNumber        liloEquals
  HiLink liloEqHexNumber        liloEquals
  HiLink liloEqNumber           liloEquals
  HiLink liloEqString           liloEquals
  HiLink liloEqAnything         liloEquals
  HiLink liloEquals             Special

  HiLink liloError              Error

  HiLink liloEqPathComment      liloComment
  HiLink liloEqVgaComment       liloComment
  HiLink liloEqDecNumberComment liloComment
  HiLink liloEqHexNumberComment liloComment
  HiLink liloEqStringComment    liloComment
  HiLink liloEqAnythingComment  liloComment
  HiLink liloPathComment        liloComment
  HiLink liloVgaComment         liloComment
  HiLink liloDecNumberComment   liloComment
  HiLink liloHexNumberComment   liloComment
  HiLink liloNumberComment      liloComment
  HiLink liloStringComment      liloComment
  HiLink liloAnythingComment    liloComment
  HiLink liloComment            Comment

  HiLink liloDiskOpt            liloOption
  HiLink liloKernelOpt          liloOption
  HiLink liloImageOpt           liloOption
  HiLink liloOption             Keyword

  HiLink liloDecNumber          liloNumber
  HiLink liloHexNumber          liloNumber
  HiLink liloDecNumberP         liloNumber
  HiLink liloNumber             Number
  HiLink liloString             String
  HiLink liloPath               Constant

  HiLink liloSpecial            Special
  HiLink liloLabel              Title
  HiLink liloDecNumberList      Special
  HiLink liloDecNumberPList     Special
  HiLink liloAnything           Normal
  HiLink liloEnviron            Identifier
  HiLink liloVgaKeyword         Identifier
  HiLink liloImage              Type
  HiLink liloChRules            Preproc
  HiLink liloDisk               Preproc

  delcommand HiLink
endif

let b:current_syntax = "lilo"
