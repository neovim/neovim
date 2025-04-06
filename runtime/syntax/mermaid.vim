" Vim syntax file
" Language:     Mermaid
" Maintainer:   Craig MacEahern <https://github.com/craigmac/vim-mermaid>
" Filenames:    *.mmd
" Last Change:  2023 Dec 26

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax iskeyword @,48-57,192-255,$,_,-,:
syntax keyword mermaidKeyword
	\ _blank
	\ _self
	\ _parent
	\ _top
	\ ::icon
	\ accDescr
	\ accTitle
	\ actor
	\ activate
	\ alt
	\ and
	\ as
	\ autonumber
	\ branch
	\ break
	\ callback
	\ checkout
	\ class
	\ classDef
	\ classDiagram
	\ click
	\ commit
	\ commitgitGraph
	\ critical
	\ dataFormat
	\ dateFormat
	\ deactivate
	\ direction
	\ element
	\ else
	\ end
	\ erDiagram
	\ flowchart
	\ gantt
	\ gitGraph
	\ graph
	\ journey
	\ link
	\ LR
	\ TD
	\ TB
	\ RL
	\ loop
	\ merge
	\ mindmap root
	\ Note
	\ Note right of
	\ Note left of
	\ Note over
	\ note
	\ note right of
	\ note left of
	\ note over
	\ opt
	\ option
	\ par
	\ participant
	\ pie
	\ rect
	\ requirement
	\ rgb
	\ section
	\ sequenceDiagram
	\ state
	\ stateDiagram
	\ stateDiagram-v2
	\ style
	\ subgraph
	\ title
highlight link mermaidKeyword Keyword

syntax match mermaidStatement "|"
syntax match mermaidStatement "\~\~\~"
syntax match mermaidStatement "--"
syntax match mermaidStatement "\%(<|\|[<*o]\)\?\%(--\|\.\.\)\%(|>\|[>*o]\)\?"
syntax match mermaidStatement "-\{2,4}[>ox-]"
syntax match mermaidStatement "\.-[>ox]"
syntax match mermaidStatement "-\."
syntax match mermaidStatement "-\.\{1,3}-"
syntax match mermaidStatement "=="
syntax match mermaidStatement "=\{2,4}[>ox=]"
syntax match mermaidStatement "&"
syntax match mermaidStatement "--\?[>x)]>\?[+-]\?"
syntax match mermaidStatement "x--x"
syntax match mermaidStatement "o--o\?"
syntax match mermaidStatement "<-->\?"
syntax match mermaidStatement ":::"
syntax match mermaidStatement "||--o{"
highlight link mermaidStatement Statement

" FIXME: This unexpectedly matches flow chart node `id1(text)` or others.
"syntax match mermaidIdentifier "[\+-]\?\w\+(.*)[\$\*]\?"
"highlight link mermaidIdentifier Identifier

syntax match mermaidType "[\+-\#\~]\?\c\%(const\s\+\|\*\s*\)*\%(unsigned\s\+\)\?\%(int\|u\?int\%(8\|16\|32\|64\)_t\|char\|long\|long\s\+long\)\>\%(\s\+const\|\s*[\*&]\)*"
syntax match mermaidType "[\+-\#\~]\?\c\%(const\s\+\|\*\s*\)*\%(double\|float\|String\|bool\)\>\%(\s\+const\|\s*[\*&]\)*"
syntax match mermaidType "[\+-\#\~]\?\cBigDecimal\>"
syntax match mermaidType "[\+-\#\~]\?\cList\~.\+\~"
syntax match mermaidType "<<\w\+>>"
highlight link mermaidType Type

syntax match mermaidComment "%%.*$"
highlight link mermaidComment Comment

syntax region mermaidDirective start="%%{" end="\}%%"
highlight link mermaidDirective PreProc

syntax region mermaidString start=/"/ skip=/\\"/ end=/"/
highlight link mermaidString String

let b:current_syntax = "mermaid"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2:
