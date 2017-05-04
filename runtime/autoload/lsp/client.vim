let s:client_configuration = get(s:, 'client_configuration', {})

""
" Add a server option for a filetype
"
" @param ftype (string|list): A string or list of strings of filetypes to associate with this server
" @param configuration (dictionary): The command to be sent to start the server
"   name        (string):   The name of the server
"   command     (string):   The command to start the server
"   arguments   (list):     Any arguments to pass to the server
"
" @returns (bool): True if successful, else false
function! lsp#client#add(ftype, configuration) abort
  if type(a:ftype) == v:t_string
    let type_list = [a:ftype]
  elseif type(a:ftype) == v:t_list
    let type_list = a:ftype
  else
    echoerr '[LSP]: List or string required for `ftype`'
    return v:false
  endif

  if !has_key(a:configuration, 'name')
    echoerr '[LSP]: "name" is a required key'
    return v:false
  endif

  if !has_key(a:configuration, 'command')
    echoerr '[LSP]: "command" is a required key'
    return v:false
  endif

  if !has_key(a:configuration, 'arguments')
    echoerr '[LSP]: "arguments" is a required key'
    return v:false
  endif

  for key in type_list
    let s:client_configuration[key] = a:configuration
  endfor

  return v:true
endfunction

function! lsp#client#get_configuration(ftype) abort
  return get(s:client_configuration, a:ftype, {})
endfunction


""
" Get the name for a filetype
" @param ftype (string): The filetype to get the associated name
"
" @returns (string): The client's name
function! lsp#client#get_name(ftype) abort
  return get(lsp#client#get_configuration(a:ftype), 'name', '')
endfunction

""
" Get the command for a filetype
" @param ftype (string): The filetype you want to get the command for
"
" @returns (string|list): The command to use to start the server
function! lsp#client#get_command(ftype) abort
  return get(lsp#client#get_configuration(a:ftype), 'command', '')
endfunction

""
" Get the arguments for a filetype
function! lsp#client#get_arguments(ftype) abort
  return get(lsp#client#get_configuration(a:ftype), 'arguments', '')
endfunction
