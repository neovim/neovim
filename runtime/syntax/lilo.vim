" Vim syntax file
" Language: lilo configuration (lilo.conf)
" Maintainer: Niels Horn <niels.horn@gmail.com>
" Previous Maintainer: David Necas (Yeti) <yeti@physics.muni.cz>
" Last Change: 2010-02-03

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=@,48-57,.,-,_

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

hi def link liloEqPath             liloEquals
hi def link liloEqWord             liloEquals
hi def link liloEqVga              liloEquals
hi def link liloEqDecNumber        liloEquals
hi def link liloEqHexNumber        liloEquals
hi def link liloEqNumber           liloEquals
hi def link liloEqString           liloEquals
hi def link liloEqAnything         liloEquals
hi def link liloEquals             Special

hi def link liloError              Error

hi def link liloEqPathComment      liloComment
hi def link liloEqVgaComment       liloComment
hi def link liloEqDecNumberComment liloComment
hi def link liloEqHexNumberComment liloComment
hi def link liloEqStringComment    liloComment
hi def link liloEqAnythingComment  liloComment
hi def link liloPathComment        liloComment
hi def link liloVgaComment         liloComment
hi def link liloDecNumberComment   liloComment
hi def link liloHexNumberComment   liloComment
hi def link liloNumberComment      liloComment
hi def link liloStringComment      liloComment
hi def link liloAnythingComment    liloComment
hi def link liloComment            Comment

hi def link liloDiskOpt            liloOption
hi def link liloKernelOpt          liloOption
hi def link liloImageOpt           liloOption
hi def link liloOption             Keyword

hi def link liloDecNumber          liloNumber
hi def link liloHexNumber          liloNumber
hi def link liloDecNumberP         liloNumber
hi def link liloNumber             Number
hi def link liloString             String
hi def link liloPath               Constant

hi def link liloSpecial            Special
hi def link liloLabel              Title
hi def link liloDecNumberList      Special
hi def link liloDecNumberPList     Special
hi def link liloAnything           Normal
hi def link liloEnviron            Identifier
hi def link liloVgaKeyword         Identifier
hi def link liloImage              Type
hi def link liloChRules            Preproc
hi def link liloDisk               Preproc


let b:current_syntax = "lilo"
