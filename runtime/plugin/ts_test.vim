let g:ts_test_path = expand("<sfile>:p:h:h")
let g:has_ts = v:false

func! TSTest()
  if g:has_ts
    return
  end
  " TODO: module!
  lua require'treesitter_rt'
  lua theparser = create_parser(vim.api.nvim_get_current_buf())
  let g:has_ts = v:true
endfunc

func! TSCursor()
  " disable matchparen
  NoMatchParen
  call TSTest()
  au CursorMoved <buffer> lua ts_cursor()
  au CursorMovedI <buffer> lua ts_cursor()
  map <buffer> <Plug>(ts-expand) <cmd>lua ts_expand_node()<cr>
endfunc

func! TSSyntax()
  " disable matchparen
  set syntax=
  call TSTest()
  lua ts_syntax()
endfunc

command! TSTest call TSTest()
command! TSCursor call TSCursor()
command! TSSyntax call TSSyntax()
