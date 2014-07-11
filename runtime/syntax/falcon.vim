" Vim syntax file
" Language:     Falcon
" Maintainer:   Steven Oliver <oliver.steven@gmail.com>
" Website:      http://github.com/steveno/vim-files/blob/master/syntax/falcon.vim
" Credits:      Thanks the ruby.vim authors, I borrowed a lot!
"               Thanks to the lisp authors for the rainbow code!
" -------------------------------------------------------------------------------

" When wanted, highlight the trailing whitespace.
if exists("c_space_errors")
    if !exists("c_no_trail_space_error")
        syn match falconSpaceError "\s\+$"
    endif

    if !exists("c_no_tab_space_error")
        syn match falconSpaceError " \+\t"me=e-1
    endif
endif

" Symbols
syn match falconSymbol "\(;\|,\|\.\)"
syn match falconSymbolOther "\(#\|@\)" display

" Operators
syn match falconOperator "\(+\|-\|\*\|/\|=\|<\|>\|\*\*\|!=\|\~=\)"
syn match falconOperator "\(<=\|>=\|=>\|\.\.\|<<\|>>\|\"\)"

" Clusters
syn region falconSymbol start="[]})\"':]\@<!:\"" end="\"" skip="\\\\\|\\\"" contains=@falconStringSpecial fold
syn case match

" Keywords
syn keyword falconKeyword all allp any anyp as attributes brigade cascade catch choice class const
syn keyword falconKeyword continue def directive do list dropping enum eq eval exit export from function
syn keyword falconKeyword give global has hasnt in init innerfunc lambda launch launch len List list
syn keyword falconKeyword load notin object pass print printl provides raise return self sender static to
syn keyword falconKeyword try xamp

" Error Type Keywords
syn keyword falconKeyword CloneError CodeError Error InterruprtedError IoError MathError
syn keyword falconKeyword ParamError RangeError SyntaxError TraceStep TypeError

" Todo
syn keyword falconTodo DEBUG FIXME NOTE TODO XXX

" Conditionals
syn keyword falconConditional and case default else end if iff
syn keyword falconConditional elif or not switch select
syn match   falconConditional "end\s\if"

" Loops
syn keyword falconRepeat break for loop forfirst forlast formiddle while

" Booleans
syn keyword falconBool true false

" Constants
syn keyword falconConst PI E nil
syn match   falconConstant  "\%(\%([.@$]\@<!\.\)\@<!\<\|::\)\_s*\zs\u\w*\%(\>\|::\)\@=\%(\s*(\)\@!"

" Comments
syn match falconCommentSkip contained "^\s*\*\($\|\s\+\)"
syn region falconComment start="/\*" end="\*/" contains=@falconCommentGroup,falconSpaceError,falconTodo
syn region falconCommentL start="//" end="$" keepend contains=@falconCommentGroup,falconSpaceError,falconTodo
syn match falconSharpBang "\%^#!.*" display
syn sync ccomment falconComment

" Numbers
syn match falconNumbers transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=falconIntLiteral,falconFloatLiteral,falconHexadecimal,falconOctal
syn match falconNumbersCom contained transparent "\<[+-]\=\d\|[+-]\=\.\d" contains=falconIntLiteral,falconFloatLiteral,falconHexadecimal,falconOctal
syn match falconHexadecimal contained "\<0x\x\+\>"
syn match falconOctal contained "\<0\o\+\>"
syn match falconIntLiteral contained "[+-]\<d\+\(\d\+\)\?\>"
syn match falconFloatLiteral contained "[+-]\=\d\+\.\d*"
syn match falconFloatLiteral contained "[+-]\=\d*\.\d*"

" Includes
syn keyword falconInclude load import

" Expression Substitution and Backslash Notation
syn match falconStringEscape "\\\\\|\\[abefnrstv]\|\\\o\{1,3}\|\\x\x\{1,2}" contained display
syn match falconStringEscape "\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)" contained display
syn region falconSymbol start="[]})\"':]\@<!:\"" end="\"" skip="\\\\\|\\\"" contains=falconStringEscape fold

" Normal String and Shell Command Output
syn region falconString matchgroup=falconStringDelimiter start="\"" end="\"" skip="\\\\\|\\\"" contains=falconStringEscape fold
syn region falconString matchgroup=falconStringDelimiter start="'" end="'" skip="\\\\\|\\'" fold
syn region falconString matchgroup=falconStringDelimiter start="`" end="`" skip="\\\\\|\\`" contains=falconStringEscape fold

" Generalized Single Quoted String, Symbol and Array of Strings
syn region falconString matchgroup=falconStringDelimiter start="%[qw]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)"  end="\z1" skip="\\\\\|\\\z1" fold
syn region falconString matchgroup=falconStringDelimiter start="%[qw]{" end="}" skip="\\\\\|\\}" fold contains=falconDelimEscape
syn region falconString matchgroup=falconStringDelimiter start="%[qw]<" end=">" skip="\\\\\|\\>" fold contains=falconDelimEscape
syn region falconString matchgroup=falconStringDelimiter start="%[qw]\[" end="\]" skip="\\\\\|\\\]" fold contains=falconDelimEscape
syn region falconString matchgroup=falconStringDelimiter start="%[qw](" end=")" skip="\\\\\|\\)" fold contains=falconDelimEscape
syn region falconSymbol matchgroup=falconSymbolDelimiter start="%[s]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" fold
syn region falconSymbol matchgroup=falconSymbolDelimiter start="%[s]{" end="}" skip="\\\\\|\\}" fold contains=falconDelimEscape
syn region falconSymbol matchgroup=falconSymbolDelimiter start="%[s]<" end=">" skip="\\\\\|\\>" fold contains=falconDelimEscape
syn region falconSymbol matchgroup=falconSymbolDelimiter start="%[s]\[" end="\]" skip="\\\\\|\\\]" fold contains=falconDelimEscape
syn region falconSymbol matchgroup=falconSymbolDelimiter start="%[s](" end=")" skip="\\\\\|\\)" fold contains=falconDelimEscape

" Generalized Double Quoted String and Array of Strings and Shell Command Output
syn region falconString matchgroup=falconStringDelimiter start="%\z([~`!@#$%^&*_\-+|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" contains=falconStringEscape fold
syn region falconString matchgroup=falconStringDelimiter start="%[QWx]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" contains=falconStringEscape fold
syn region falconString matchgroup=falconStringDelimiter start="%[QWx]\={" end="}" skip="\\\\\|\\}" contains=falconStringEscape,falconDelimEscape fold
syn region falconString matchgroup=falconStringDelimiter start="%[QWx]\=<" end=">" skip="\\\\\|\\>" contains=falconStringEscape,falconDelimEscape fold
syn region falconString matchgroup=falconStringDelimiter start="%[QWx]\=\[" end="\]" skip="\\\\\|\\\]" contains=falconStringEscape,falconDelimEscape fold
syn region falconString matchgroup=falconStringDelimiter start="%[QWx]\=(" end=")" skip="\\\\\|\\)" contains=falconStringEscape,falconDelimEscape fold

syn region falconString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<\z(\h\w*\)\ze+hs=s+2 matchgroup=falconStringDelimiter end=+^\z1$+ contains=falconStringEscape fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<"\z([^"]*\)"\ze+hs=s+2  matchgroup=falconStringDelimiter end=+^\z1$+ contains=falconStringEscape fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<'\z([^']*\)'\ze+hs=s+2  matchgroup=falconStringDelimiter end=+^\z1$+ fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<`\z([^`]*\)`\ze+hs=s+2  matchgroup=falconStringDelimiter end=+^\z1$+ contains=falconStringEscape fold keepend

syn region falconString start=+\%(\%(class\s*\|\%([]}).]\|::\)\)\_s*\|\w\)\@<!<<-\z(\h\w*\)\ze+hs=s+3 matchgroup=falconStringDelimiter end=+^\s*\zs\z1$+ contains=falconStringEscape fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]}).]\|::\)\)\_s*\|\w\)\@<!<<-"\z([^"]*\)"\ze+hs=s+3  matchgroup=falconStringDelimiter end=+^\s*\zs\z1$+ contains=falconStringEscape fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]}).]\|::\)\)\_s*\|\w\)\@<!<<-'\z([^']*\)'\ze+hs=s+3  matchgroup=falconStringDelimiter end=+^\s*\zs\z1$+ fold keepend
syn region falconString start=+\%(\%(class\s*\|\%([]}).]\|::\)\)\_s*\|\w\)\@<!<<-`\z([^`]*\)`\ze+hs=s+3  matchgroup=falconStringDelimiter end=+^\s*\zs\z1$+ contains=falconStringEscape fold keepend

" Falcon rainbox to highlight parens in varying colors
if exists("g:falcon_rainbow") && g:falcon_rainbow != 0
    syn region falconParen0           matchgroup=hlLevel0 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen1
    syn region falconParen1 contained matchgroup=hlLevel1 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen2
    syn region falconParen2 contained matchgroup=hlLevel2 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen3
    syn region falconParen3 contained matchgroup=hlLevel3 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen4
    syn region falconParen4 contained matchgroup=hlLevel4 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen5
    syn region falconParen5 contained matchgroup=hlLevel5 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen6
    syn region falconParen6 contained matchgroup=hlLevel6 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen7
    syn region falconParen7 contained matchgroup=hlLevel7 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen8
    syn region falconParen8 contained matchgroup=hlLevel8 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen9
    syn region falconParen9 contained matchgroup=hlLevel9 start="`\=(" end=")" skip="|.\{-}|" contains=@falconListCluster,falconParen0
endif

" Setup the colors for the rainbox
if exists("g:falcon_rainbow") && g:falcon_rainbow != 0
    if &bg == "dark"
        hi def hlLevel0 ctermfg=red         guifg=red1
        hi def hlLevel1 ctermfg=yellow      guifg=orange1
        hi def hlLevel2 ctermfg=green       guifg=yellow1
        hi def hlLevel3 ctermfg=cyan        guifg=greenyellow
        hi def hlLevel4 ctermfg=magenta     guifg=green1
        hi def hlLevel5 ctermfg=red         guifg=springgreen1
        hi def hlLevel6 ctermfg=yellow      guifg=cyan1
        hi def hlLevel7 ctermfg=green       guifg=slateblue1
        hi def hlLevel8 ctermfg=cyan        guifg=magenta1
        hi def hlLevel9 ctermfg=magenta     guifg=purple1
    else
        hi def hlLevel0 ctermfg=red         guifg=red3
        hi def hlLevel1 ctermfg=darkyellow  guifg=orangered3
        hi def hlLevel2 ctermfg=darkgreen   guifg=orange2
        hi def hlLevel3 ctermfg=blue        guifg=yellow3
        hi def hlLevel4 ctermfg=darkmagenta guifg=olivedrab4
        hi def hlLevel5 ctermfg=red         guifg=green4
        hi def hlLevel6 ctermfg=darkyellow  guifg=paleturquoise3
        hi def hlLevel7 ctermfg=darkgreen   guifg=deepskyblue4
        hi def hlLevel8 ctermfg=blue        guifg=darkslateblue
        hi def hlLevel9 ctermfg=darkmagenta guifg=darkviolet
    endif
endif

" Syntax Synchronizing
syn sync minlines=10 maxlines=100

" Define the default highlighting
if !exists("did_falcon_syn_inits")
    command -nargs=+ HiLink hi def link <args>

    HiLink falconKeyword          Keyword
    HiLink falconCommentString    String
    HiLink falconTodo             Todo
    HiLink falconConditional      Keyword
    HiLink falconRepeat           Repeat
    HiLink falconcommentSkip      Comment
    HiLink falconComment          Comment
    HiLink falconCommentL         Comment
    HiLink falconConst            Constant
    HiLink falconConstants        Constant
    HiLink falconOperator         Operator
    HiLink falconSymbol           Normal
    HiLink falconSpaceError       Error
    HiLink falconHexadecimal      Number
    HiLink falconOctal            Number
    HiLink falconIntLiteral       Number
    HiLink falconFloatLiteral     Float
    HiLink falconStringEscape     Special
    HiLink falconStringDelimiter  Delimiter
    HiLink falconString           String
    HiLink falconBool             Constant
    HiLink falconSharpBang        PreProc
    HiLink falconInclude          Include
    HiLink falconSymbol           Constant
    HiLink falconSymbolOther      Delimiter
    delcommand HiLink
endif

let b:current_syntax = "falcon"

" vim: set sw=4 sts=4 et tw=80 :

