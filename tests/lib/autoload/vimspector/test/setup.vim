function! vimspector#test#setup#SetUpWithMappings( mappings )
  if exists ( 'g:loaded_vimpector' )
    unlet g:loaded_vimpector
  endif

  if a:mappings != v:none
    let g:vimspector_enable_mappings = a:mappings
  endif

  source vimrc

  " This is a bit of a hack
  runtime! plugin/**/*.vim
endfunction

function! vimspector#test#setup#ClearDown()
  if exists( '*vimspector#internal#state#Reset' )
    call vimspector#internal#state#Reset()
  endif
endfunction
