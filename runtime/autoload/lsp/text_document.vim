function! lsp#text_document#hover() abort
  call luaeval("vim.lsp.request_async('textDocument/hover', vim.lsp.structures.TextDocumentPositionParams())")
endfunction

" Completion with LSP
function! lsp#text_document#completion_complete() abort
  call luaeval("vim.lsp.request_async('textDocument/completion', vim.lsp.structures.CompletionParams())")
  return ''
endfunction

function! lsp#text_document#signature_help() abort
  call luaeval("vim.lsp.request_async('textDocument/signatureHelp', vim.lsp.structures.SignatureHelpParams())")
  return ''
endfunction

let s:last_location = -1

" Omni completion with LSP
function! lsp#text_document#completion_omni(findstart, base) abort
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
    let results = luaeval("vim.lsp.request('textDocument/completion',"
          \ ."vim.lsp.structures.CompletionParams({col = _A })",  col('.') + len(a:base))

    if !(results is v:null)
      call filter(results, {_, match -> match['word'] =~ '^' . a:base})
    endif

    return results
  else
    throw "LSP/omnifunc bad a:findstart" a:findstart
  endif

endfunction
