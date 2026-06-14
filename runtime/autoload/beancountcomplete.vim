" Vim completion script
" Language: beancount
" Maintainer: Nathan Grigg
" Latest Revision: 2021-03-06

let s:using_python3 = has('python3') || has('python3/dyn')

" Equivalent to python's startswith
" Matches based on user's ignorecase preference
function! s:startswith(string, prefix) abort
    return strpart(a:string, 0, strlen(a:prefix)) == a:prefix
endfunction

function! s:count_expression(text, expression) abort
    return len(split(a:text, a:expression, 1)) - 1
endfunction

function! s:sort_accounts_by_depth(name1, name2) abort
    let l:depth1 = s:count_expression(a:name1, ':')
    let l:depth2 = s:count_expression(a:name2, ':')
    return l:depth1 == l:depth2 ? 0 : l:depth1 > l:depth2 ? 1 : -1
endfunction

let s:directives = ['open', 'close', 'commodity', 'txn', 'balance', 'pad', 'note', 'document', 'price', 'event', 'query', 'custom']

" ------------------------------
" Completion functions
" ------------------------------
function! beancountcomplete#complete(findstart, base) abort
    if a:findstart
        let l:col = searchpos('\s', 'bn', line('.'))[1]
        if l:col == 0
            return -1
        else
            return l:col
        endif
    endif

    let l:partial_line = strpart(getline('.'), 0, getpos('.')[2]-1)
    " Match directive types
    if l:partial_line =~# '^\d\d\d\d\(-\|/\)\d\d\1\d\d $'
        return beancountcomplete#complete_basic(s:directives, a:base, '')
    endif

    " If we are using python3, now is a good time to load everything
    call beancountcomplete#load_everything()

    " Split out the first character (for cases where we don't want to match the
    " leading character: ", #, etc)
    let l:first = strpart(a:base, 0, 1)
    let l:rest = strpart(a:base, 1)

    if l:partial_line =~# '^\d\d\d\d\(-\|/\)\d\d\1\d\d event $' && l:first ==# '"'
        return beancountcomplete#complete_basic(b:beancount_events, l:rest, '"')
    endif

    let l:two_tokens = searchpos('\S\+\s', 'bn', line('.'))[1]
    let l:prev_token = strpart(getline('.'), l:two_tokens, getpos('.')[2] - l:two_tokens)
    " Match curriences if previous token is number
    if l:prev_token =~# '^\d\+\([\.,]\d\+\)*'
        call beancountcomplete#load_currencies()
        return beancountcomplete#complete_basic(b:beancount_currencies, a:base, '')
    endif

    if l:first ==# '#'
        call beancountcomplete#load_tags()
        return beancountcomplete#complete_basic(b:beancount_tags, l:rest, '#')
    elseif l:first ==# '^'
        call beancountcomplete#load_links()
        return beancountcomplete#complete_basic(b:beancount_links, l:rest, '^')
    elseif l:first ==# '"'
        call beancountcomplete#load_payees()
        return beancountcomplete#complete_basic(b:beancount_payees, l:rest, '"')
    else
        call beancountcomplete#load_accounts()
        return beancountcomplete#complete_account(a:base)
    endif
endfunction

function! beancountcomplete#get_root() abort
    if exists('b:beancount_root')
        return b:beancount_root
    endif
    return expand('%')
endfunction

function! beancountcomplete#load_everything() abort
    if s:using_python3 && !exists('b:beancount_loaded')
        let l:root = beancountcomplete#get_root()
python3 << EOF
import vim
from beancount import loader
from beancount.core import data

accounts = set()
currencies = set()
events = set()
links = set()
payees = set()
tags = set()

entries, errors, options_map = loader.load_file(vim.eval('l:root'))
for index, entry in enumerate(entries):
    if isinstance(entry, data.Open):
        accounts.add(entry.account)
        if entry.currencies:
            currencies.update(entry.currencies)
    elif isinstance(entry, data.Commodity):
        currencies.add(entry.currency)
    elif isinstance(entry, data.Event):
        events.add(entry.type)
    elif isinstance(entry, data.Transaction):
        if entry.tags:
            tags.update(entry.tags)
        if entry.links:
            links.update(entry.links)
        if entry.payee:
            payees.add(entry.payee)

vim.bindeval('b:')['beancount_accounts'] = sorted(accounts)
vim.bindeval('b:')['beancount_currencies'] = sorted(currencies)
vim.bindeval('b:')['beancount_events'] = sorted(events)
vim.bindeval('b:')['beancount_links'] = sorted(links)
vim.bindeval('b:')['beancount_payees'] = sorted(payees)
vim.bindeval('b:')['beancount_tags'] = sorted(tags)
vim.bindeval('b:')['beancount_loaded'] = 1
EOF
    endif
endfunction

function! beancountcomplete#load_accounts() abort
    if !s:using_python3 && !exists('b:beancount_accounts')
        let l:root = beancountcomplete#get_root()
        let b:beancount_accounts = beancountcomplete#query_single(l:root, 'select distinct account;')
    endif
endfunction

function! beancountcomplete#load_tags() abort
    if !s:using_python3 && !exists('b:beancount_tags')
        let l:root = beancountcomplete#get_root()
        let b:beancount_tags = beancountcomplete#query_single(l:root, 'select distinct tags;')
    endif
endfunction

function! beancountcomplete#load_links() abort
    if !s:using_python3 && !exists('b:beancount_links')
        let l:root = beancountcomplete#get_root()
        let b:beancount_links = beancountcomplete#query_single(l:root, 'select distinct links;')
    endif
endfunction

function! beancountcomplete#load_currencies() abort
    if !s:using_python3 && !exists('b:beancount_currencies')
        let l:root = beancountcomplete#get_root()
        let b:beancount_currencies = beancountcomplete#query_single(l:root, 'select distinct currency;')
    endif
endfunction

function! beancountcomplete#load_payees() abort
    if !s:using_python3 && !exists('b:beancount_payees')
        let l:root = beancountcomplete#get_root()
        let b:beancount_payees = beancountcomplete#query_single(l:root, 'select distinct payee;')
    endif
endfunction

" General completion function
function! beancountcomplete#complete_basic(input, base, prefix) abort
    let l:matches = filter(copy(a:input), 's:startswith(v:val, a:base)')

    return map(l:matches, 'a:prefix . v:val')
endfunction

" Complete account name.
function! beancountcomplete#complete_account(base) abort
    if g:beancount_account_completion ==? 'chunks'
        let l:pattern = '^\V' . substitute(a:base, ':', '\\[^:]\\*:', 'g') . '\[^:]\*'
    else
        let l:pattern = '^\V\.\*' . substitute(a:base, ':', '\\.\\*:\\.\\*', 'g') . '\.\*'
    endif

    let l:matches = []
    let l:index = -1
    while 1
        let l:index = match(b:beancount_accounts, l:pattern, l:index + 1)
        if l:index == -1 | break | endif
        call add(l:matches, matchstr(b:beancount_accounts[l:index], l:pattern))
    endwhile

    if g:beancount_detailed_first
        let l:matches = reverse(sort(l:matches, 's:sort_accounts_by_depth'))
    endif

    return l:matches
endfunction

function! beancountcomplete#query_single(root_file, query) abort
    if s:using_python3
python3 << EOF
import vim
import subprocess

# We intentionally want to ignore stderr so it doesn't mess up our query processing
output = subprocess.check_output(
    ['bean-query', vim.eval('a:root_file'), vim.eval('a:query')],
    stderr=subprocess.DEVNULL,
    text=True,
).splitlines()
output = output[2:]
result_list = sorted(y for y in (x.strip() for x in output) if y)
EOF
        return py3eval('result_list')
    else
        return []
    endif
endfunction
