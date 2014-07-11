" Vim syntax file
" Language:         host.conf(5) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-06-25

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword hostconfTodo
      \ contained
      \ TODO
      \ FIXME
      \ XXX
      \ NOTE

syn match   hostconfComment
      \ display
      \ contained
      \ '\s*#.*'
      \ contains=hostconfTodo,
      \          @Spell

syn match   hostconfBegin
      \ display
      \ '^'
      \ nextgroup=hostconfComment,hostconfKeyword
      \ skipwhite

syn keyword hostconfKeyword
      \ contained
      \ order
      \ nextgroup=hostconfLookupOrder
      \ skipwhite

let s:orders = ['bind', 'hosts', 'nis']

function s:permute_suffixes(list)
  if empty(a:list)
    return []
  elseif len(a:list) == 1
    return a:list[0]
  else
    let i = 0
    let n = len(a:list)
    let sub_permutations = []
    while i < n
      let list_copy = copy(a:list)
      let removed = list_copy[i]
      call remove(list_copy, i)
      call add(sub_permutations, [removed, s:permute_suffixes(list_copy)])
      let i += 1
    endwhile
    return sub_permutations
  endif
endfunction

function s:generate_suffix_groups(list_of_order_of_orders, context, trailing_context)
  for order_of_orders in a:list_of_order_of_orders
    let order = order_of_orders[0]
    let trailing_context = a:trailing_context . toupper(order[0]) . order[1:]
    let nextgroup = 'hostconfLookupOrder' . trailing_context
    let nextgroup_delimiter = nextgroup . 'Delimiter'
    let group = 'hostconfLookupOrder' . a:context
    execute 'syn keyword' group 'contained' order 'nextgroup=' . nextgroup_delimiter 'skipwhite'
    execute 'syn match' nextgroup_delimiter 'contained display "," nextgroup=' . nextgroup 'skipwhite'
    if a:context != ""
      execute 'hi def link' group 'hostconfLookupOrder'
    endif
    execute 'hi def link' nextgroup_delimiter 'hostconfLookupOrderDelimiter'
    let context = trailing_context
    if type(order_of_orders[1]) == type([])
      call s:generate_suffix_groups(order_of_orders[1], context, trailing_context)
    else
      execute 'syn keyword hostconfLookupOrder' . context 'contained' order_of_orders[-1]
      execute 'hi def link hostconfLookupOrder' . context 'hostconfLookupOrder'
    endif
  endfor
endfunction

call s:generate_suffix_groups(s:permute_suffixes(s:orders), "", "")

delfunction s:generate_suffix_groups
delfunction s:permute_suffixes

syn keyword hostconfKeyword
      \ contained
      \ trim
      \ nextgroup=hostconfDomain
      \ skipwhite

syn match   hostconfDomain
      \ contained
      \ '\.[^:;,[:space:]]\+'
      \ nextgroup=hostconfDomainDelimiter
      \ skipwhite

syn match   hostconfDomainDelimiter
      \ contained
      \ display
      \ '[:;,]'
      \ nextgroup=hostconfDomain
      \ skipwhite

syn keyword hostconfKeyword
      \ contained
      \ multi
      \ nospoof
      \ spoofalert
      \ reorder
      \ nextgroup=hostconfBoolean
      \ skipwhite

syn keyword hostconfBoolean
      \ contained
      \ on
      \ off

syn keyword hostconfKeyword
      \ contained
      \ spoof
      \ nextgroup=hostconfSpoofValue
      \ skipwhite

syn keyword hostconfSpoofValue
      \ contained
      \ off
      \ nowarn
      \ warn

hi def link hostconfTodo                  Todo
hi def link hostconfComment               Comment
hi def link hostconfKeyword               Keyword
hi def link hostconfLookupOrder           Identifier
hi def link hostconfLookupOrderDelimiter  Delimiter
hi def link hostconfDomain                String
hi def link hostconfDomainDelimiter       Delimiter
hi def link hostconfBoolean               Boolean
hi def link hostconfSpoofValue            hostconfBoolean

let b:current_syntax = "hostconf"

let &cpo = s:cpo_save
unlet s:cpo_save
