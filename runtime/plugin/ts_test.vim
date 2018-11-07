let g:ts_test_path = expand("<sfile>:p:h:h")

func! TSTest()
  " disable matchparen
  NoMatchParen
  " TODO: module!
  lua require'treesitter_rt'
  lua theparser = create_parser(vim.api.nvim_get_current_buf())
  au CursorMoved <buffer> lua ts_cursor()
  au CursorMovedI <buffer> lua ts_cursor()
  map <buffer> <Plug>(ts-expand) <cmd>lua ts_expand_node()<cr>
endfunc
command! TSTest call TSTest()
