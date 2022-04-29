" dockerfile.vim - Syntax highlighting for Dockerfiles
" Maintainer:   Honza Pokorny <https://honza.ca>
" Last Change:  2020 Feb 11
" License:      BSD

" https://docs.docker.com/engine/reference/builder/

if exists("b:current_syntax")
    finish
endif

syntax include @JSON syntax/json.vim
unlet b:current_syntax

syntax include @Shell syntax/sh.vim
unlet b:current_syntax

syntax case ignore
syntax match dockerfileLinePrefix /\v^\s*(ONBUILD\s+)?\ze\S/ contains=dockerfileKeyword nextgroup=dockerfileInstruction skipwhite
syntax region dockerfileFrom matchgroup=dockerfileKeyword start=/\v^\s*(FROM)\ze(\s|$)/ skip=/\v\\\_./ end=/\v((^|\s)AS(\s|$)|$)/ contains=dockerfileOption

syntax keyword dockerfileKeyword contained ADD ARG CMD COPY ENTRYPOINT ENV EXPOSE HEALTHCHECK LABEL MAINTAINER ONBUILD RUN SHELL STOPSIGNAL USER VOLUME WORKDIR
syntax match dockerfileOption contained /\v(^|\s)\zs--\S+/

syntax match dockerfileInstruction contained /\v<(\S+)>(\s+--\S+)*/             contains=dockerfileKeyword,dockerfileOption skipwhite nextgroup=dockerfileValue
syntax match dockerfileInstruction contained /\v<(ADD|COPY)>(\s+--\S+)*/        contains=dockerfileKeyword,dockerfileOption skipwhite nextgroup=dockerfileJSON
syntax match dockerfileInstruction contained /\v<(HEALTHCHECK)>(\s+--\S+)*/     contains=dockerfileKeyword,dockerfileOption skipwhite nextgroup=dockerfileInstruction
syntax match dockerfileInstruction contained /\v<(CMD|ENTRYPOINT|RUN)>/         contains=dockerfileKeyword skipwhite nextgroup=dockerfileShell
syntax match dockerfileInstruction contained /\v<(CMD|ENTRYPOINT|RUN)>\ze\s+\[/ contains=dockerfileKeyword skipwhite nextgroup=dockerfileJSON
syntax match dockerfileInstruction contained /\v<(SHELL|VOLUME)>/               contains=dockerfileKeyword skipwhite nextgroup=dockerfileJSON

syntax region dockerfileString contained start=/\v"/ skip=/\v\\./ end=/\v"/
syntax region dockerfileJSON   contained keepend start=/\v\[/ skip=/\v\\\_./ end=/\v$/ contains=@JSON
syntax region dockerfileShell  contained keepend start=/\v/ skip=/\v\\\_./ end=/\v$/ contains=@Shell
syntax region dockerfileValue  contained keepend start=/\v/ skip=/\v\\\_./ end=/\v$/ contains=dockerfileString

syntax region dockerfileComment start=/\v^\s*#/ end=/\v$/ contains=@Spell
set commentstring=#\ %s

hi def link dockerfileString String
hi def link dockerfileKeyword Keyword
hi def link dockerfileComment Comment
hi def link dockerfileOption Special

let b:current_syntax = "dockerfile"
