" Vim syntax file
" Language:      TT2 (Perl Template Toolkit)
" Maintainer:    vim-perl <vim-perl@googlegroups.com>
" Author:        Moriki, Atsushi <4woods+vim@gmail.com>
" Homepage:      https://github.com/vim-perl/vim-perl
" Bugs/requests: https://github.com/vim-perl/vim-perl/issues
" License:       Vim License (see :help license)
" Last Change:   2018 Mar 28
"
" Installation:
"   put tt2.vim and tt2html.vim in to your syntax directory.
"
"   add below in your filetype.vim.
"       au BufNewFile,BufRead *.tt2 setf tt2
"           or
"       au BufNewFile,BufRead *.tt2
"           \ if ( getline(1) . getline(2) . getline(3) =~ '<\chtml' |
"           \           && getline(1) . getline(2) . getline(3) !~ '<[%?]' ) |
"           \   || getline(1) =~ '<!DOCTYPE HTML' |
"           \   setf tt2html |
"           \ else |
"           \   setf tt2 |
"           \ endif
"
"   define START_TAG, END_TAG
"       "ASP"
"       :let b:tt2_syn_tags = '<% %>'
"       "PHP"
"       :let b:tt2_syn_tags = '<? ?>'
"       "TT2 and HTML"
"       :let b:tt2_syn_tags = '\[% %] <!-- -->'
"
" Changes:
"           0.1.3
"               Changed fileformat from 'dos' to 'unix'
"               Deleted 'echo' that print obstructive message
"           0.1.2
"               Added block comment syntax
"               e.g. [%# COMMENT
"                        COMMENT TOO %]
"                    [%# IT'S SAFE %]  HERE IS OUTSIDE OF TT2 DIRECTIVE
"                    [% # WRONG!! %]   HERE STILL BE COMMENT
"           0.1.1
"               Release
"           0.1.0
"               Internal

if !exists("b:tt2_syn_tags")
    let b:tt2_syn_tags = '\[% %]'
    "let b:tt2_syn_tags = '\[% %] \[\* \*]'
endif

if !exists("b:tt2_syn_inc_perl")
    let b:tt2_syn_inc_perl = 1
endif

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

syn cluster tt2_top_cluster contains=tt2_perlcode,tt2_tag_region

" TT2 TAG Region
if exists("b:tt2_syn_tags")

    let s:str = b:tt2_syn_tags . ' '
    let s:str = substitute(s:str,'^ \+','','g')
    let s:str = substitute(s:str,' \+',' ','g')

    while stridx(s:str,' ') > 0

        let s:st = strpart(s:str,0,stridx(s:str,' '))
        let s:str = substitute(s:str,'[^ ]* ','',"")

        let s:ed = strpart(s:str,0,stridx(s:str,' '))
        let s:str = substitute(s:str,'[^ ]* ','',"")

        exec 'syn region  tt2_tag_region '.
                    \ 'matchgroup=tt2_tag '.
                    \ 'start=+\(' . s:st .'\)[-]\=+ '.
                    \ 'end=+[-]\=\(' . s:ed . '\)+ '.
                    \ 'contains=@tt2_statement_cluster keepend extend'

        exec 'syn region  tt2_commentblock_region '.
                    \ 'matchgroup=tt2_tag '.
                    \ 'start=+\(' . s:st .'\)[-]\=\(#\)\@=+ '.
                    \ 'end=+[-]\=\(' . s:ed . '\)+ '.
                    \ 'keepend extend'

        "Include Perl syntax when 'PERL' 'RAWPERL' block
        if b:tt2_syn_inc_perl
            syn include @Perl syntax/perl.vim
            exec 'syn region tt2_perlcode '.
                        \ 'start=+\(\(RAW\)\=PERL\s*[-]\=' . s:ed . '\(\n\)\=\)\@<=+ ' .
                        \ 'end=+' . s:st . '[-]\=\s*END+me=s-1 contains=@Perl keepend'
        endif

        "echo 'TAGS ' . s:st . ' ' . s:ed
        unlet s:st
        unlet s:ed
    endwhile

else

    syn region  tt2_tag_region
                \ matchgroup=tt2_tag
                \ start=+\(\[%\)[-]\=+
                \ end=+[-]\=%\]+
                \ contains=@tt2_statement_cluster keepend extend

    syn region  tt2_commentblock_region
                \ matchgroup=tt2_tag
                \ start=+\(\[%\)[-]\=#+
                \ end=+[-]\=%\]+
                \ keepend extend

    "Include Perl syntax when 'PERL' 'RAWPERL' block
    if b:tt2_syn_inc_perl
        syn include @Perl syntax/perl.vim
        syn region tt2_perlcode
                    \ start=+\(\(RAW\)\=PERL\s*[-]\=%]\(\n\)\=\)\@<=+
                    \ end=+\[%[-]\=\s*END+me=s-1
                    \ contains=@Perl keepend
    endif
endif

" Directive
syn keyword tt2_directive contained
            \ GET CALL SET DEFAULT DEBUG
            \ LAST NEXT BREAK STOP BLOCK
            \ IF IN UNLESS ELSIF FOR FOREACH WHILE SWITCH CASE
            \ USE PLUGIN MACRO META
            \ TRY FINAL RETURN LAST
            \ CLEAR TO STEP AND OR NOT MOD DIV
            \ ELSE PERL RAWPERL END
syn match   tt2_directive +|+ contained
syn keyword tt2_directive contained nextgroup=tt2_string_q,tt2_string_qq,tt2_blockname skipwhite skipempty
            \ INSERT INCLUDE PROCESS WRAPPER FILTER
            \ THROW CATCH
syn keyword tt2_directive contained nextgroup=tt2_def_tag skipwhite skipempty
            \ TAGS

syn match   tt2_def_tag "\S\+\s\+\S\+\|\<\w\+\>" contained

syn match   tt2_variable  +\I\w*+                           contained
syn match   tt2_operator  "[+*/%:?-]"                       contained
syn match   tt2_operator  "\<\(mod\|div\|or\|and\|not\)\>"  contained
syn match   tt2_operator  "[!=<>]=\=\|&&\|||"               contained
syn match   tt2_operator  "\(\s\)\@<=_\(\s\)\@="            contained
syn match   tt2_operator  "=>\|,"                           contained
syn match   tt2_deref     "\([[:alnum:]_)\]}]\s*\)\@<=\."   contained
syn match   tt2_comment   +#.*$+                            contained
syn match   tt2_func      +\<\I\w*\(\s*(\)\@=+              contained nextgroup=tt2_bracket_r skipempty skipwhite
"
syn region  tt2_bracket_r  start=+(+ end=+)+                contained contains=@tt2_statement_cluster keepend extend
syn region  tt2_bracket_b start=+\[+ end=+]+                contained contains=@tt2_statement_cluster keepend extend
syn region  tt2_bracket_b start=+{+  end=+}+                contained contains=@tt2_statement_cluster keepend extend

syn region  tt2_string_qq start=+"+ end=+"+ skip=+\\"+      contained contains=tt2_ivariable keepend extend
syn region  tt2_string_q  start=+'+ end=+'+ skip=+\\'+      contained keepend extend

syn match   tt2_ivariable  +\$\I\w*\>\(\.\I\w*\>\)*+        contained
syn match   tt2_ivariable  +\${\I\w*\>\(\.\I\w*\>\)*}+      contained

syn match   tt2_number    "\d\+"        contained
syn match   tt2_number    "\d\+\.\d\+"  contained
syn match   tt2_number    "0x\x\+"      contained
syn match   tt2_number    "0\o\+"       contained

syn match   tt2_blockname "\f\+"                       contained                        nextgroup=tt2_blockname_joint skipwhite skipempty
syn match   tt2_blockname "$\w\+"                      contained contains=tt2_ivariable nextgroup=tt2_blockname_joint skipwhite skipempty
syn region  tt2_blockname start=+"+ end=+"+ skip=+\\"+ contained contains=tt2_ivariable nextgroup=tt2_blockname_joint keepend skipwhite skipempty
syn region  tt2_blockname start=+'+ end=+'+ skip=+\\'+ contained                        nextgroup=tt2_blockname_joint keepend skipwhite skipempty
syn match   tt2_blockname_joint "+"                    contained                        nextgroup=tt2_blockname skipwhite skipempty

syn cluster tt2_statement_cluster contains=tt2_directive,tt2_variable,tt2_operator,tt2_string_q,tt2_string_qq,tt2_deref,tt2_comment,tt2_func,tt2_bracket_b,tt2_bracket_r,tt2_number

" Synchronizing
syn sync minlines=50

hi def link tt2_tag         Type
hi def link tt2_tag_region  Type
hi def link tt2_commentblock_region Comment
hi def link tt2_directive   Statement
hi def link tt2_variable    Identifier
hi def link tt2_ivariable   Identifier
hi def link tt2_operator    Statement
hi def link tt2_string_qq   String
hi def link tt2_string_q    String
hi def link tt2_blockname   String
hi def link tt2_comment     Comment
hi def link tt2_func        Function
hi def link tt2_number      Number

if exists("b:tt2_syn_tags")
    unlet b:tt2_syn_tags
endif

let b:current_syntax = "tt2"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:ts=4:sw=4
