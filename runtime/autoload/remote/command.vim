function! remote#command#UpdateRemotePlugins(hosts, plugin_patterns,
      \ remote_plugins_manifest, plugins_for_host) abort
  let commands = []
  let hosts = keys(a:hosts)
  for host in hosts
    if has_key(a:plugin_patterns, host)
      try
        let commands +=
              \   ['" '.host.' plugins']
              \ + s:RegistrationCommands(host, a:hosts, a:plugin_patterns,
              \                          a:plugins_for_host)
              \ + ['', '']
      catch
        echomsg v:throwpoint
        echomsg v:exception
      endtry
    endif
  endfor
  call writefile(commands, a:remote_plugins_manifest)
  echomsg printf('remote/host: generated the manifest file in "%s"',
        \ a:remote_plugins_manifest)
endfunction


function! s:RegistrationCommands(host, hosts, plugin_patterns, plugins_for_host) abort
  " Register a temporary host clone for discovering specs
  let host_id = a:host.'-registration-clone'
  call remote#host#RegisterClone(host_id, a:host)
  let pattern = a:plugin_patterns[a:host]
  let paths = globpath(&rtp, 'rplugin/'.a:host.'/'.pattern, 0, 1)
  if empty(paths)
    return []
  endif

  for path in paths
    call remote#host#RegisterPlugin(host_id, path, [])
  endfor
  let channel = remote#host#Require(host_id)
  let lines = []
  for path in paths
    let specs = rpcrequest(channel, 'specs', path)
    if type(specs) != type([])
      " host didn't return a spec list, indicates a failure while loading a
      " plugin
      continue
    endif
    call add(lines, "call remote#host#RegisterPlugin('".a:host
          \ ."', '".path."', [")
    for spec in specs
      call add(lines, "      \\ ".string(spec).",")
    endfor
    call add(lines, "     \\ ])")
  endfor
  echomsg printf("remote/host: %s host registered plugins %s",
        \ a:host, string(map(copy(paths), "fnamemodify(v:val, ':t')")))

  " Delete the temporary host clone
  call rpcstop(a:hosts[host_id].channel)
  call remove(a:hosts, host_id)
  call remove(a:plugins_for_host, host_id)
  return lines
endfunction
