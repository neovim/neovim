" Vim syntax file
" Language:	Vivado mss file
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Oct 22
" Document:	https://docs.amd.com/r/2020.2-English/ug1400-vitis-embedded/Microprocessor-Software-Specification-MSS
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>

if exists("b:current_syntax")
  finish
endif

syn case ignore
syn match	mssComment	"#.*$" contains=@Spell
syn keyword	mssKeyword	BEGIN END PARAMETER
syn keyword	mssType		OS PROCESSOR DRIVER LIBRARY
syn keyword	mssConstant	VERSION PROC_INSTANCE HW_INSTANCE OS_NAME OS_VER DRIVER_NAME DRIVER_VER LIBRARY_NAME LIBRARY_VER STDIN STDOUT XMDSTUB_PERIPHERAL ARCHIVER COMPILER COMPILER_FLAGS EXTRA_COMPILER_FLAGS

hi def link mssComment		Comment
hi def link mssKeyword		Keyword
hi def link mssType		Type
hi def link mssConstant		Constant

let b:current_syntax = "mss"
