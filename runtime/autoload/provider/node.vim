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

let s:NodeHandler = {
\ 'stdout_buffered': v:true,
\ 'result': ''
\ }
function! s:NodeHandler.on_exit(job_id, data, event) abort
  let bin_dir = join(get(self, 'stdout', []), '')
  let entry_point = bin_dir . self.entry_point
  let self.result = filereadable(entry_point) ? entry_point : ''
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
  let minver = [6, 0]
  if exists('g:node_host_prog')
    return [expand(g:node_host_prog, v:true), '']
  endif
  if !executable('node')
    return ['', 'node not found (or not executable)']
  endif
  if !s:is_minimum_version(v:null, minver[0], minver[1])
    return ['', printf('node version %s.%s not found', minver[0], minver[1])]
  endif

  let npm_opts = {}
  if executable('npm')
    let npm_opts = deepcopy(s:NodeHandler)
    let npm_opts.entry_point = '/neovim/bin/cli.js'
    let npm_opts.job_id = jobstart('npm --loglevel silent root -g', npm_opts)
  endif

  let yarn_opts = {}
  if executable('yarn')
    let yarn_opts = deepcopy(s:NodeHandler)
    let yarn_opts.entry_point = '/node_modules/neovim/bin/cli.js'
    " `yarn global dir` is slow (> 250ms), try the default path first
    " XXX: The following code is not portable
    " https://github.com/yarnpkg/yarn/issues/2049#issuecomment-263183768
    if has('unix')
      let yarn_default_path = $HOME . '/.config/yarn/global/' . yarn_opts.entry_point
      if filereadable(yarn_default_path)
        return [yarn_default_path, '']
      endif
    endif
    let yarn_opts.job_id = jobstart('yarn global dir', yarn_opts)
  endif

  " npm returns the directory faster, so let's check that first
  if !empty(npm_opts)
    let result = jobwait([npm_opts.job_id])
    if result[0] == 0 && npm_opts.result != ''
      return [npm_opts.result, '']
    endif
  endif

  if !empty(yarn_opts)
    let result = jobwait([yarn_opts.job_id])
    if result[0] == 0 && yarn_opts.result != ''
      return [yarn_opts.result, '']
    endif
  endif

  return ['', 'failed to detect node']
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
let [s:prog, s:_] = provider#node#Detect()
let g:loaded_node_provider = empty(s:prog) ? 1 : 2

if g:loaded_node_provider != 2
  let s:err = 'Cannot find the "neovim" node package. Try :checkhealth'
endif

call remote#host#RegisterPlugin('node-provider', 'node', [])
