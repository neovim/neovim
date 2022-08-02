" Vim syntax file
" Language:    Windows PowerShell
" URL:         https://github.com/PProvost/vim-ps1
" Last Change: 2020 Nov 24
"
" The following settings are available for tuning syntax highlighting:
"    let ps1_nofold_blocks = 1
"    let ps1_nofold_sig = 1
"    let ps1_nofold_region = 1

if exists("b:current_syntax")
	finish
endif

" Operators contain dashes
setlocal iskeyword+=-

" PowerShell doesn't care about case
syn case ignore

" Sync-ing method
syn sync minlines=100

" Certain tokens can't appear at the top level of the document
syn cluster ps1NotTop contains=@ps1Comment,ps1CDocParam,ps1FunctionDeclaration

" Comments and special comment words
syn keyword ps1CommentTodo TODO FIXME XXX TBD HACK NOTE contained
syn match ps1CDocParam /.*/ contained
syn match ps1CommentDoc /^\s*\zs\.\w\+\>/ nextgroup=ps1CDocParam contained
syn match ps1CommentDoc /#\s*\zs\.\w\+\>/ nextgroup=ps1CDocParam contained
syn match ps1Comment /#.*/ contains=ps1CommentTodo,ps1CommentDoc,@Spell
syn region ps1Comment start="<#" end="#>" contains=ps1CommentTodo,ps1CommentDoc,@Spell

" Language keywords and elements
syn keyword ps1Conditional if else elseif switch default
syn keyword ps1Repeat while for do until break continue foreach in
syn match ps1Repeat /\<foreach\>/ nextgroup=ps1Block skipwhite
syn match ps1Keyword /\<while\>/ nextgroup=ps1Block skipwhite
syn match ps1Keyword /\<where\>/ nextgroup=ps1Block skipwhite

syn keyword ps1Exception begin process end exit inlinescript parallel sequence
syn keyword ps1Keyword try catch finally throw
syn keyword ps1Keyword return filter in trap param data dynamicparam 
syn keyword ps1Constant $true $false $null
syn match ps1Constant +\$?+
syn match ps1Constant +\$_+
syn match ps1Constant +\$\$+
syn match ps1Constant +\$^+

" Keywords reserved for future use
syn keyword ps1Keyword class define from using var

" Function declarations
syn keyword ps1Keyword function nextgroup=ps1Function skipwhite
syn keyword ps1Keyword filter nextgroup=ps1Function skipwhite
syn keyword ps1Keyword workflow nextgroup=ps1Function skipwhite
syn keyword ps1Keyword configuration nextgroup=ps1Function skipwhite
syn keyword ps1Keyword class nextgroup=ps1Function skipwhite
syn keyword ps1Keyword enum nextgroup=ps1Function skipwhite

" Function declarations and invocations
syn match ps1Cmdlet /\v(add|clear|close|copy|enter|exit|find|format|get|hide|join|lock|move|new|open|optimize|pop|push|redo|remove|rename|reset|search|select|Set|show|skip|split|step|switch|undo|unlock|watch)(-\w+)+/ contained
syn match ps1Cmdlet /\v(connect|disconnect|read|receive|send|write)(-\w+)+/ contained
syn match ps1Cmdlet /\v(backup|checkpoint|compare|compress|convert|convertfrom|convertto|dismount|edit|expand|export|group|import|initialize|limit|merge|mount|out|publish|restore|save|sync|unpublish|update)(-\w+)+/ contained
syn match ps1Cmdlet /\v(debug|measure|ping|repair|resolve|test|trace)(-\w+)+/ contained
syn match ps1Cmdlet /\v(approve|assert|build|complete|confirm|deny|deploy|disable|enable|install|invoke|register|request|restart|resume|start|stop|submit|suspend|uninstall|unregister|wait)(-\w+)+/ contained
syn match ps1Cmdlet /\v(block|grant|protect|revoke|unblock|unprotect)(-\w+)+/ contained
syn match ps1Cmdlet /\v(use)(-\w+)+/ contained

" Other functions
syn match ps1Function /\w\+\(-\w\+\)\+/ contains=ps1Cmdlet

" Type declarations
syn match ps1Type /\[[a-z_][a-z0-9_.,\[\]]\+\]/

" Variable references
syn match ps1ScopeModifier /\(global:\|local:\|private:\|script:\)/ contained
syn match ps1Variable /\$\w\+\(:\w\+\)\?/ contains=ps1ScopeModifier
syn match ps1Variable /\${\w\+\(:\?[[:alnum:]_()]\+\)\?}/ contains=ps1ScopeModifier

" Operators
syn keyword ps1Operator -eq -ne -ge -gt -lt -le -like -notlike -match -notmatch -replace -split -contains -notcontains
syn keyword ps1Operator -ieq -ine -ige -igt -ile -ilt -ilike -inotlike -imatch -inotmatch -ireplace -isplit -icontains -inotcontains
syn keyword ps1Operator -ceq -cne -cge -cgt -clt -cle -clike -cnotlike -cmatch -cnotmatch -creplace -csplit -ccontains -cnotcontains
syn keyword ps1Operator -in -notin
syn keyword ps1Operator -is -isnot -as -join
syn keyword ps1Operator -and -or -not -xor -band -bor -bnot -bxor
syn keyword ps1Operator -f
syn match ps1Operator /!/
syn match ps1Operator /=/
syn match ps1Operator /+=/
syn match ps1Operator /-=/
syn match ps1Operator /\*=/
syn match ps1Operator /\/=/
syn match ps1Operator /%=/
syn match ps1Operator /+/
syn match ps1Operator /-\(\s\|\d\|\.\|\$\|(\)\@=/
syn match ps1Operator /\*/
syn match ps1Operator /\//
syn match ps1Operator /|/
syn match ps1Operator /%/
syn match ps1Operator /&/
syn match ps1Operator /::/
syn match ps1Operator /,/
syn match ps1Operator /\(^\|\s\)\@<=\. \@=/

" Regular Strings
" These aren't precisely correct and could use some work
syn region ps1String start=/"/ skip=/`"/ end=/"/ contains=@ps1StringSpecial,@Spell
syn region ps1String start=/'/ skip=/''/ end=/'/

" Here-Strings
syn region ps1String start=/@"$/ end=/^"@/ contains=@ps1StringSpecial,@Spell
syn region ps1String start=/@'$/ end=/^'@/

" Interpolation
syn match ps1Escape /`./
syn region ps1Interpolation matchgroup=ps1InterpolationDelimiter start="$(" end=")" contained contains=ALLBUT,@ps1NotTop
syn region ps1NestedParentheses start="(" skip="\\\\\|\\)" matchgroup=ps1Interpolation end=")" transparent contained
syn cluster ps1StringSpecial contains=ps1Escape,ps1Interpolation,ps1Variable,ps1Boolean,ps1Constant,ps1BuiltIn,@Spell

" Numbers
syn match   ps1Number		"\(\<\|-\)\@<=\(0[xX]\x\+\|\d\+\)\([KMGTP][B]\)\=\(\>\|-\)\@="
syn match   ps1Number		"\(\(\<\|-\)\@<=\d\+\.\d*\|\.\d\+\)\([eE][-+]\=\d\+\)\=[dD]\="
syn match   ps1Number		"\<\d\+[eE][-+]\=\d\+[dD]\=\>"
syn match   ps1Number		"\<\d\+\([eE][-+]\=\d\+\)\=[dD]\>"

" Constants
syn match ps1Boolean "$\%(true\|false\)\>"
syn match ps1Constant /\$null\>/
syn match ps1BuiltIn "$^\|$?\|$_\|$\$"
syn match ps1BuiltIn "$\%(args\|error\|foreach\|home\|input\)\>"
syn match ps1BuiltIn "$\%(match\(es\)\?\|myinvocation\|host\|lastexitcode\)\>"
syn match ps1BuiltIn "$\%(ofs\|shellid\|stacktrace\)\>"

" Named Switch
syn match ps1Label /\s-\w\+/

" Folding blocks
if !exists('g:ps1_nofold_blocks')
	syn region ps1Block start=/{/ end=/}/ transparent fold
endif

if !exists('g:ps1_nofold_region')
	syn region ps1Region start=/#region/ end=/#endregion/ transparent fold keepend extend
endif

if !exists('g:ps1_nofold_sig')
	syn region ps1Signature start=/# SIG # Begin signature block/ end=/# SIG # End signature block/ transparent fold
endif

" Setup default color highlighting
hi def link ps1Number Number
hi def link ps1Block Block
hi def link ps1Region Region
hi def link ps1Exception Exception
hi def link ps1Constant Constant
hi def link ps1String String
hi def link ps1Escape SpecialChar
hi def link ps1InterpolationDelimiter Delimiter
hi def link ps1Conditional Conditional
hi def link ps1Cmdlet Function
hi def link ps1Function Identifier
hi def link ps1Variable Identifier
hi def link ps1Boolean Boolean
hi def link ps1Constant Constant
hi def link ps1BuiltIn StorageClass
hi def link ps1Type Type
hi def link ps1ScopeModifier StorageClass
hi def link ps1Comment Comment
hi def link ps1CommentTodo Todo
hi def link ps1CommentDoc Tag
hi def link ps1CDocParam Identifier
hi def link ps1Operator Operator
hi def link ps1Repeat Repeat
hi def link ps1RepeatAndCmdlet Repeat
hi def link ps1Keyword Keyword
hi def link ps1KeywordAndCmdlet Keyword
hi def link ps1Label Label

let b:current_syntax = "ps1"
