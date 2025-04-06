" Vim filetype plugin file
" Language:	Mail
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2025 Feb 20
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl modeline< tw< fo< comments< commentstring<"

" Don't use modelines in e-mail messages, avoid trojan horses and nasty
" "jokes" (e.g., setting 'textwidth' to 5).
setlocal nomodeline

" many people recommend keeping e-mail messages 72 chars wide
if &tw == 0
  setlocal tw=72
endif

" Set 'formatoptions' to break text lines and keep the comment leader ">".
setlocal fo+=tcql

" Set commentstring to quoting sign ">" so comment shortcuts can be used to
" edit quoted parts of mail
setlocal commentstring=>\ %s
" Add n:> to 'comments, in case it was removed elsewhere
setlocal comments+=n:>

" .eml files are universally formatted with DOS line-endings, per RFC5322.
" If the file was not DOS the it will be marked as changed, which is probably
" a good thing.
if expand('%:e') ==? 'eml'
  let b:undo_ftplugin ..= " fileformat=" .. &fileformat
  setlocal fileformat=dos
endif

" Add mappings, unless the user doesn't want this.
if !exists("no_plugin_maps") && !exists("no_mail_maps")
  " Quote text by inserting "> "
  if !hasmapto('<Plug>MailQuote')
    vmap <buffer> <LocalLeader>q <Plug>MailQuote
    nmap <buffer> <LocalLeader>q <Plug>MailQuote
  endif
  vnoremap <buffer> <Plug>MailQuote :s/^/> /<CR>:noh<CR>``
  nnoremap <buffer> <Plug>MailQuote :.,$s/^/> /<CR>:noh<CR>``
endif
