let s:last_location = -1

" Omni completion with LSP
function! lsp#completion#omni(findstart, base) abort
  " If we haven't started, then don't return anything useful
  if !luaeval("vim.lsp.client_has_started(_A)", &filetype)
    return a:findstart ? -1 : []
  endif

  if a:findstart == 1
    let s:last_location =  col('.')

    let line_to_cursor = strpart(getline('.'), 0, col('.') - 1)
    let [string_result, start_position, end_position] = matchstrpos(line_to_cursor, '\k\+$')
    let length = end_position - start_position

    return len(line_to_cursor) - length
  elseif a:findstart == 0
    let params = luaeval("vim.lsp.structures.CompletionParams("
                         \ . "{ position = { character = _A }})",
                         \  col('.') + len(a:base))
    let results = lsp#request('textDocument/completion', params)

    if !(results is v:null)
      call filter(results, {_, match -> match['word'] =~ '^' . a:base})
    endif

    return results
  else
    throw "LSP/omnifunc bad a:findstart" a:findstart
  endif

endfunction

" Completion with LSP
function! lsp#completion#complete() abort
  call lsp#request_async(
        \ 'textDocument/completion',
        \ luaeval("vim.lsp.structures.CompletionParams()")
        \ )
  return ''
endfunction
