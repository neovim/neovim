

let s:last_location = -1

""
" Omni completion with LSP
function! lsp#completion#omni(findstart, base) abort
  " If we haven't started, then don't return anything useful
  if !luaeval("require('lsp.plugin').client.has_started()")
    return a:findstart ? -1 : []
  endif

  if a:findstart == 1
    let s:last_location =  col('.')

    let line_to_cursor = strpart(getline('.'), 0, col('.') - 1)
    let [string_result, start_position, end_position] = matchstrpos(line_to_cursor, '\k\+$')
    let length = end_position - start_position

    return len(line_to_cursor) - length
  elseif a:findstart == 0
    let params = luaeval("require('lsp.structures').CompletionParams("
                         \ . "{ position = { character = _A }})",
                         \  col('.') + len(a:base))
    let results = lsp#request('textDocument/completion', params)

    call filter(results, {_, match -> match['word'] =~ '^' . a:base})
    return results
  else
    throw "LSP/omnifunc bad a:findstart" a:findstart
  endif

endfunction

""
" 
function! lsp#completion#complete() abort
  let line_to_cursor = strpart(getline('.'), 0, col('.') - 1)
  let [string_result, start_position, end_position] = matchstrpos(line_to_cursor, '\k\+$')

  let results = lsp#request('textDocument/completion')
  call complete(col('.') - (end_position - start_position), results)

  return ''
endfunction
