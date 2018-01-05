let s:server_configuration = get(s:, 'server_configuration', {})

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
function! lsp#server#add(ftype, configuration) abort
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

  for current_filetype in type_list
    " Only add a new startup command if we haven't already
    if !has_key(s:server_configuration, current_filetype)
      augroup LanguageServerStartup
        call execute(printf('autocmd FileType %s silent call lsp#start("%s")', current_filetype, current_filetype))
      augroup END
    endif

    let s:server_configuration[current_filetype] = a:configuration
  endfor

  return v:true
endfunction

function! lsp#server#get_configuration(ftype) abort
  return get(s:server_configuration, a:ftype, {})
endfunction


""
" Get the name for a filetype
" @param ftype (string): The filetype to get the associated name
"
" @returns (string): The server's name
function! lsp#server#get_name(ftype) abort
  return get(lsp#server#get_configuration(a:ftype), 'name', '')
endfunction

""
" Get the command for a filetype
" @param ftype (string): The filetype you want to get the command for
"
" @returns (string|list): The command to use to start the server
function! lsp#server#get_command(ftype) abort
  return get(lsp#server#get_configuration(a:ftype), 'command', '')
endfunction

""
" Get the arguments for a filetype
function! lsp#server#get_arguments(ftype) abort
  return get(lsp#server#get_configuration(a:ftype), 'arguments', '')
endfunction
