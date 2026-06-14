if exists('b:did_ftplugin')
    finish
endif

let b:did_ftplugin = 1
let b:undo_ftplugin = 'setlocal foldmethod< comments< commentstring< omnifunc<'
let b:undo_ftplugin .= '| delc -buffer AlignCommodity'
let b:undo_ftplugin .= '| delc -buffer GetContext'

setl foldmethod=syntax
setl comments=b:;
setl commentstring=;\ %s
compiler bean_check

" This variable customizes the behavior of the AlignCommodity command.
if !exists('g:beancount_separator_col')
    let g:beancount_separator_col = 50
endif
if !exists('g:beancount_account_completion')
    let g:beancount_account_completion = 'default'
endif
if !exists('g:beancount_detailed_first')
    let g:beancount_detailed_first = 0
endif

command! -buffer -range AlignCommodity
            \ :call beancount#align_commodity(<line1>, <line2>)

command! -buffer -range GetContext
            \ :call beancount#get_context()

" Omnifunc for account completion.
if get(g:, 'beancount_completion_enable', 0)
    setl omnifunc=beancountcomplete#complete
endif
