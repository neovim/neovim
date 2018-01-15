

let s:last_location = -1

""
" Omni completion with LSP
function! lsp#completion#omni(findstart, base) abort
  " If we haven't started, then don't return anything useful
  if !luaeval("require('lsp.plugin').client.has_started()")
    return a:findstart ? -1 : []
  endif

  if a:findstart
    let s:last_location =  col('.')

    let line_to_cursor = strpart(getline('.'), 0, col('.') - 1)
    let [string_result, start_position, end_position] = matchstrpos(line_to_cursor, '\k\+$')
    let length = end_position - start_position

    return len(line_to_cursor) - length
  else
    let g:__lsp_location = {
          \ 'position': {
            \ 'character': col('.') + len(a:base),
            \ 'line': line('.') - 1,
          \ },
        \ }

    let results = lsp#request('textDocument/completion', g:__lsp_location)

    let g:__debug = {
          \ 'findstart': a:findstart,
          \ 'col': col('.'),
          \ 'base': a:base,
          \ 'location': g:__lsp_location,
          \ 'results': results
          \ }

    return results
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
