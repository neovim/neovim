" Vim syntax file
" Language:	TI linker command file
" Document:	https://downloads.ti.com/docs/esd/SPRUI03A/Content/SPRUI03A_HTML/linker_description.html
" Document:	https://software-dl.ti.com/ccs/esd/documents/sdto_cgt_Linker-Command-File-Primer.html
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 31

if exists("b:current_syntax")
  finish
endif

runtime! syntax/cmacro.vim

syn case ignore
syn match lnkNumber		"0x[0-9a-f]\+"
" Linker command files are ASCII files that contain one or more of the following:
" Input filenames, which specify object files, archive libraries, or other command files.
" Linker options, which can be used in the command file in the same manner that they are used on the command line
syn match   lnkOption		"^[-+][-_a-zA-Z#@]\+"
syn match   lnkOption		"^--[^ \t$=`'"|);]\+"
syn match   lnkFile		'[^ =]\+\%(\.\S\+\)\+\>'
syn match   lnkLibFile		'[^ =]\+\.lib\>'
" The MEMORY and SECTIONS linker directives. The MEMORY directive defines the target memory configuration (see Section 8.5.4). The SECTIONS directive controls how sections are built and allocated (see Section 8.5.5.)
syn keyword lnkKeyword	ADDRESS_MASK f LOAD ORIGIN START ALGORITHM FILL LOAD_END PAGE TABLE ALIGN GROUP LOAD_SIZE PALIGN TYPE ATTR HAMMING_MASK LOAD_START PARITY_MASK UNION BLOCK HIGH MEMORY RUN UNORDERED COMPRESSION INPUT_PAGE MIRRORING RUN_END VFILL COPY INPUT_RANGE NOINIT RUN_SIZE DSECT l NOLOAD RUN_START ECC LEN o SECTIONS END LENGTH ORG SIZE
syn region  lnkLibrary		start=+<+ end=+>+
syn match   lnkAttrib		'\<[RWXI]\+\>'
syn match   lnkSections      	'\<\.\k\+'
" Assignment statements, which define and assign values to global symbols
syn case match

hi def link lnkNumber		Number
hi def link lnkOption		Special
hi def link lnkKeyword		Keyword
hi def link lnkLibrary		String
hi def link lnkFile		String
hi def link lnkLibFile		Special
hi def link lnkAttrib		Type
hi def link lnkSections		Macro

let b:current_syntax = "lnk"
