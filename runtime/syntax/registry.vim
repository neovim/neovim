" Vim syntax file
" Language:	Windows Registry export with regedit (*.reg)
" Maintainer:	Dominique Stéphan (dominique@mggen.com)
" URL: 		http://www.mggen.com/vim/syntax/registry.zip (doesn't work)
" Last change:	2014 Oct 31
"		Included patch from Alexander A. Ulitin

" clear any unwanted syntax defs
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" shut case off
syn case ignore

" Head of regedit .reg files, it's REGEDIT4 on Win9#/NT
syn match registryHead		"^REGEDIT[0-9]*\s*$\|^Windows Registry Editor Version \d*\.\d*\s*$"

" Comment
syn match  registryComment	"^;.*$"

" Registry Key constant
syn keyword registryHKEY	HKEY_LOCAL_MACHINE HKEY_CLASSES_ROOT HKEY_CURRENT_USER
syn keyword registryHKEY	HKEY_USERS HKEY_CURRENT_CONFIG HKEY_DYN_DATA
" Registry Key shortcuts
syn keyword registryHKEY	HKLM HKCR HKCU HKU HKCC HKDD

" Some values often found in the registry
" GUID (Global Unique IDentifier)
syn match   registryGUID	"{[0-9A-Fa-f]\{8}\-[0-9A-Fa-f]\{4}\-[0-9A-Fa-f]\{4}\-[0-9A-Fa-f]\{4}\-[0-9A-Fa-f]\{12}}" contains=registrySpecial

" Disk
" syn match   registryDisk	"[a-zA-Z]:\\\\"

" Special and Separator characters
syn match   registrySpecial	"\\"
syn match   registrySpecial	"\\\\"
syn match   registrySpecial	"\\\""
syn match   registrySpecial	"\."
syn match   registrySpecial	","
syn match   registrySpecial	"\/"
syn match   registrySpecial	":"
syn match   registrySpecial	"-"

" String
syn match   registryString	"\".*\"" contains=registryGUID,registrySpecial

" Path
syn region  registryPath		start="\[" end="\]" contains=registryHKEY,registryGUID,registrySpecial

" Path to remove
" like preceding path but with a "-" at begin
syn region registryRemove	start="\[\-" end="\]" contains=registryHKEY,registryGUID,registrySpecial

" Subkey
syn match  registrySubKey		"^\".*\"="
" Default value
syn match  registrySubKey		"^@="

" Numbers

" Hex or Binary
" The format can be precised between () :
" 0    REG_NONE
" 1    REG_SZ
" 2    REG_EXPAND_SZ
" 3    REG_BINARY
" 4    REG_DWORD, REG_DWORD_LITTLE_ENDIAN
" 5    REG_DWORD_BIG_ENDIAN
" 6    REG_LINK
" 7    REG_MULTI_SZ
" 8    REG_RESOURCE_LIST
" 9    REG_FULL_RESOURCE_DESCRIPTOR
" 10   REG_RESOURCE_REQUIREMENTS_LIST
" The value can take several lines, if \ ends the line
" The limit to 999 matches is arbitrary, it avoids Vim crashing on a very long
" line of hex values that ends in a comma.
"syn match registryHex		"hex\(([0-9]\{0,2})\)\=:\([0-9a-fA-F]\{2},\)\{0,999}\([0-9a-fA-F]\{2}\|\\\)$" contains=registrySpecial
syn match registryHex		"hex\(([0-9]\{0,2})\)\=:\([0-9a-fA-F]\{2},\)*\([0-9a-fA-F]\{2}\|\\\)$" contains=registrySpecial
syn match registryHex		"^\s*\([0-9a-fA-F]\{2},\)\{0,999}\([0-9a-fA-F]\{2}\|\\\)$" contains=registrySpecial
" Dword (32 bits)
syn match registryDword		"dword:[0-9a-fA-F]\{8}$" contains=registrySpecial


" The default methods for highlighting.  Can be overridden later
hi def link registryComment	Comment
hi def link registryHead		Constant
hi def link registryHKEY		Constant
hi def link registryPath		Special
hi def link registryRemove	PreProc
hi def link registryGUID		Identifier
hi def link registrySpecial	Special
hi def link registrySubKey	Type
hi def link registryString	String
hi def link registryHex		Number
hi def link registryDword		Number



let b:current_syntax = "registry"

" vim:ts=8
