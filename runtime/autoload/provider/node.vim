if exists('g:loaded_node_provider')
  finish
endif
let g:loaded_node_provider = 1

function! s:is_minimum_version(version, min_major, min_minor) abort
  if empty(a:version)
    let nodejs_version = get(split(system(['node', '-v']), "\n"), 0, '')
    if v:shell_error || nodejs_version[0] !=# 'v'
      return 0
    endif
  else
    let nodejs_version = a:version
  endif
  " Remove surrounding junk.  Example: 'v4.12.0' => '4.12.0'
  let nodejs_version = matchstr(nodejs_version, '\(\d\.\?\)\+')
  " [major, minor, patch]
  let v_list = split(nodejs_version, '\.')
  return len(v_list) == 3
    \ && ((str2nr(v_list[0]) > str2nr(a:min_major))
    \     || (str2nr(v_list[0]) == str2nr(a:min_major)
    \         && str2nr(v_list[1]) >= str2nr(a:min_minor)))
endfunction

function! s:find_node_client(package_manager) abort
  if !executable(a:package_manager)
    return ''
  endif
  let is_yarn = a:package_manager ==# 'yarn'
  let cmd = is_yarn ? 'yarn global dir' : 'npm root -g'
  let global_modules_dir = get(split(system(cmd), "\n"), 0, '')
  if v:shell_error || !isdirectory(global_modules_dir)
    return ''
  endif
  " `yarn global dir` returns the parent of '/node_modules'.
  let global_modules_dir = is_yarn ? global_modules_dir . '/node_modules' : global_modules_dir
  if !isdirectory(global_modules_dir)
    return ''
  endif
  let entry_point = global_modules_dir . '/neovim/bin/cli.js'
  if !filereadable(entry_point)
    return ''
  endif
  return entry_point
endfunction

" Support for --inspect-brk requires node 6.12+ or 7.6+ or 8+
" Return 1 if it is supported
" Return 0 otherwise
function! provider#node#can_inspect() abort
  if !executable('node')
    return 0
  endif
  let ver = get(split(system(['node', '-v']), "\n"), 0, '')
  if v:shell_error || ver[0] !=# 'v'
    return 0
  endif
  return (ver[1] ==# '6' && s:is_minimum_version(ver, 6, 12))
    \ || s:is_minimum_version(ver, 7, 6)
endfunction

function! provider#node#Detect() abort
  if exists('g:node_host_prog')
    return g:node_host_prog
  endif
  if !s:is_minimum_version(v:null, 6, 0)
    return ''
  endif
  let entry_point = s:find_node_client('npm')
  let entry_point = !empty(entry_point) ? entry_point : s:find_node_client('yarn')
  return entry_point
endfunction

function! provider#node#Prog() abort
  return s:prog
endfunction

function! provider#node#Require(host) abort
  if s:err != ''
    echoerr s:err
    return
  endif

  let args = ['node']

  if !empty($NVIM_NODE_HOST_DEBUG) && provider#node#can_inspect()
    call add(args, '--inspect-brk')
  endif

  call add(args, provider#node#Prog())

  return provider#Poll(args, a:host.orig_name, '$NVIM_NODE_LOG_FILE')
endfunction

function! provider#node#Call(method, args) abort
  if s:err != ''
    echoerr s:err
    return
  endif

  if !exists('s:host')
    try
      let s:host = remote#host#Require('node')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      return
    endtry
  endif
  return call('rpcrequest', insert(insert(a:args, 'node_'.a:method), s:host))
endfunction


let s:err = ''
let s:prog = provider#node#Detect()

if empty(s:prog)
  let s:err = 'Cannot find the "neovim" node package. Try :checkhealth'
endif

call remote#host#RegisterPlugin('node-provider', 'node', [])
