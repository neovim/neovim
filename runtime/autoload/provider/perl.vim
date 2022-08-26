if exists('s:loaded_perl_provider')
  finish
endif

let s:loaded_perl_provider = 1

function! provider#perl#Detect() abort
  " use g:perl_host_prog if set or check if perl is on the path
  let prog = exepath(get(g:, 'perl_host_prog', 'perl'))
  if empty(prog)
    return ['', '']
  endif

  " if perl is available, make sure we have 5.22+
  call system([prog, '-e', 'use v5.22'])
  if v:shell_error
    return ['', 'Perl version is too old, 5.22+ required']
  endif

  " if perl is available, make sure the required module is available
  call system([prog, '-W', '-MNeovim::Ext', '-e', ''])
  if v:shell_error
    return ['', '"Neovim::Ext" cpan module is not installed']
  endif

  return [prog, '']
endfunction

function! provider#perl#Prog() abort
  return s:prog
endfunction

function! provider#perl#Require(host) abort
  if s:err != ''
    echoerr s:err
    return
  endif

  let prog = provider#perl#Prog()
  let args = [s:prog, '-e', 'use Neovim::Ext; start_host();']

  " Collect registered perl plugins into args
  let perl_plugins = remote#host#PluginsForHost(a:host.name)
  for plugin in perl_plugins
    call add(args, plugin.path)
  endfor

  return provider#Poll(args, a:host.orig_name, '$NVIM_PERL_LOG_FILE')
endfunction

function! provider#perl#Call(method, args) abort
  if s:err != ''
    echoerr s:err
    return
  endif

  if !exists('s:host')
    try
      let s:host = remote#host#Require('legacy-perl-provider')
    catch
      let s:err = v:exception
      echohl WarningMsg
      echomsg v:exception
      echohl None
      return
    endtry
  endif
  return call('rpcrequest', insert(insert(a:args, 'perl_'.a:method), s:host))
endfunction

let [s:prog, s:err] = provider#perl#Detect()
let g:loaded_perl_provider = empty(s:prog) ? 1 : 2

if g:loaded_perl_provider != 2
  let s:err = 'Cannot find perl or the required perl module'
endif


" The perl provider plugin will run in a separate instance of the perl
" host.
call remote#host#RegisterClone('legacy-perl-provider', 'perl')
call remote#host#RegisterPlugin('legacy-perl-provider', 'ScriptHost.pm', [])

