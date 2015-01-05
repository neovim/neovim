" dockerfile.vim - Syntax highlighting for Dockerfiles
" Maintainer:   Honza Pokorny <http://honza.ca>
" Version:      0.5
" Last Change:  2014 Aug 29
" License:      BSD


if exists("b:current_syntax")
    finish
endif

let b:current_syntax = "dockerfile"

syntax case ignore

syntax match dockerfileKeyword /\v^\s*(ONBUILD\s+)?(ADD|CMD|ENTRYPOINT|ENV|EXPOSE|FROM|MAINTAINER|RUN|USER|VOLUME|WORKDIR|COPY)\s/

syntax region dockerfileString start=/\v"/ skip=/\v\\./ end=/\v"/

syntax match dockerfileComment "\v^\s*#.*$"

hi def link dockerfileString String
hi def link dockerfileKeyword Keyword
hi def link dockerfileComment Comment
