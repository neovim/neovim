let s:hosts = {}
let s:plugin_patterns = {}
let s:remote_plugins_manifest = fnamemodify(expand($MYVIMRC, 1), ':h')
      \.'/.'.fnamemodify($MYVIMRC, ':t').'-rplugin~'


" Register a host by associating it with a factory(funcref)
function! remote#host#Register(name, pattern, factory) abort
  let s:hosts[a:name] = {'factory': a:factory, 'channel': 0, 'initialized': 0}
  let s:plugin_patterns[a:name] = a:pattern
  if type(a:factory) == type(1) && a:factory
    " Passed a channel directly
    let s:hosts[a:name].channel = a:factory
  endif
endfunction


" Register a clone to an existing host. The new host will use the same factory
" as `source`, but it will run as a different process. This can be used by
" plugins that should run isolated from other plugins created for the same host
" type
function! remote#host#RegisterClone(name, orig_name) abort
  if !has_key(s:hosts, a:orig_name)
    throw 'No host named "'.a:orig_name.'" is registered'
  endif
  let Factory = s:hosts[a:orig_name].factory
  let s:hosts[a:name] = {
        \ 'factory': Factory,
        \ 'channel': 0,
        \ 'initialized': 0,
        \ 'orig_name': a:orig_name
        \ }
endfunction


" Get a host channel, bootstrapping it if necessary
function! remote#host#Require(name) abort
  if !has_key(s:hosts, a:name)
    throw 'No host named "'.a:name.'" is registered'
  endif
  let host = s:hosts[a:name]
  if !host.channel && !host.initialized
    let host_info = {
          \ 'name': a:name,
          \ 'orig_name': get(host, 'orig_name', a:name)
          \ }
    let host.channel = call(host.factory, [host_info])
    let host.initialized = 1
  endif
  return host.channel
endfunction


function! remote#host#IsRunning(name) abort
  if !has_key(s:hosts, a:name)
    throw 'No host named "'.a:name.'" is registered'
  endif
  return s:hosts[a:name].channel != 0
endfunction


" Example of registering a Python plugin with two commands (one async), one
" autocmd (async) and one function (sync):
"
" let s:plugin_path = expand('<sfile>:p:h').'/nvim_plugin.py'
" call remote#host#RegisterPlugin('python', s:plugin_path, [
"   \ {'type': 'command', 'name': 'PyCmd', 'sync': 1, 'opts': {}},
"   \ {'type': 'command', 'name': 'PyAsyncCmd', 'sync': 0, 'opts': {'eval': 'cursor()'}},
"   \ {'type': 'autocmd', 'name': 'BufEnter', 'sync': 0, 'opts': {'eval': 'expand("<afile>")'}},
"   \ {'type': 'function', 'name': 'PyFunc', 'sync': 1, 'opts': {}}
"   \ ])
"
" The third item in a declaration is a boolean: non zero means the command,
" autocommand or function will be executed synchronously with rpcrequest.
function! remote#host#RegisterPlugin(host, path, specs) abort
  let plugins = remote#host#PluginsForHost(a:host)

  for plugin in plugins
    if plugin.path == a:path
      throw 'Plugin "'.a:path.'" is already registered'
    endif
  endfor

  if has_key(s:hosts, a:host) && remote#host#IsRunning(a:host)
    " For now we won't allow registration of plugins when the host is already
    " running.
    throw 'Host "'.a:host.'" is already running'
  endif

  for spec in a:specs
    let type = spec.type
    let name = spec.name
    let sync = spec.sync
    let opts = spec.opts
    let rpc_method = a:path
    if type == 'command'
      let rpc_method .= ':command:'.name
      call remote#define#CommandOnHost(a:host, rpc_method, sync, name, opts)
    elseif type == 'autocmd'
      " Since multiple handlers can be attached to the same autocmd event by a
      " single plugin, we need a way to uniquely identify the rpc method to
      " call.  The solution is to append the autocmd pattern to the method
      " name(This still has a limit: one handler per event/pattern combo, but
      " there's no need to allow plugins define multiple handlers in that case)
      let rpc_method .= ':autocmd:'.name.':'.get(opts, 'pattern', '*')
      call remote#define#AutocmdOnHost(a:host, rpc_method, sync, name, opts)
    elseif type == 'function'
      let rpc_method .= ':function:'.name
      call remote#define#FunctionOnHost(a:host, rpc_method, sync, name, opts)
    else
      echoerr 'Invalid declaration type: '.type
    endif
  endfor

  call add(plugins, {'path': a:path, 'specs': a:specs})
endfunction


function! remote#host#LoadRemotePlugins() abort
  if filereadable(s:remote_plugins_manifest)
    exe 'source '.s:remote_plugins_manifest
  endif
endfunction


command! UpdateRemotePlugins call remote#command#UpdateRemotePlugins(
      \ s:hosts, s:plugin_patterns, s:remote_plugins_manifest,
      \ s:plugins_for_host)


let s:plugins_for_host = {}
function! remote#host#PluginsForHost(host) abort
  if !has_key(s:plugins_for_host, a:host)
    let s:plugins_for_host[a:host] = []
  end
  return s:plugins_for_host[a:host]
endfunction


" Registration of standard hosts

" Python/Python3
call remote#host#Register('python', '*.py',
      \ function('provider#pythonx#Require'))
call remote#host#Register('python3', '*.py',
      \ function('provider#pythonx#Require'))
