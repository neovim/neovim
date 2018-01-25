if exists('g:loaded_remote_plugins')
  finish
endif
let g:loaded_remote_plugins = '/path/to/manifest'

" Get the path to the rplugin manifest file.
function! s:GetManifestPath() abort
  let manifest_base = ''

  if exists('$NVIM_RPLUGIN_MANIFEST')
    return fnamemodify($NVIM_RPLUGIN_MANIFEST, ':p')
  endif

  let dest = has('win32') ? '$LOCALAPPDATA' : '$XDG_DATA_HOME'
  if !exists(dest)
    let dest = has('win32') ? '~/AppData/Local' : '~/.local/share'
  endif

  let dest = fnamemodify(expand(dest), ':p')
  if !empty(dest)
    let dest .= ('/' ==# dest[-1:] ? '' : '/') . 'nvim'
    if !isdirectory(dest)
      call mkdir(dest, 'p', 0700)
    endif
    let manifest_base = dest
  endif

  return manifest_base.'/rplugin.vim'
endfunction

" Old manifest file based on known script locations.
function! s:GetOldManifestPath() abort
  let prefix = exists('$MYVIMRC')
        \ ? $MYVIMRC
        \ : matchstr(get(split(execute('scriptnames'), '\n'), 0, ''), '\f\+$')
  return fnamemodify(expand(prefix, 1), ':h')
        \.'/.'.fnamemodify(prefix, ':t').'-rplugin~'
endfunction

function! s:GetManifest() abort
  let manifest = s:GetManifestPath()
  if !filereadable(manifest)
    " Check if an old manifest file exists and move it to the new location.
    let old_manifest = s:GetOldManifestPath()
    if filereadable(old_manifest)
      call rename(old_manifest, manifest)
    endif
  endif
  return manifest
endfunction

function! s:LoadRemotePlugins() abort
  let g:loaded_remote_plugins = s:GetManifest()
  if filereadable(g:loaded_remote_plugins)
    execute 'source' fnameescape(g:loaded_remote_plugins)
  endif
endfunction

command! -bar UpdateRemotePlugins call remote#host#UpdateRemotePlugins()

call s:LoadRemotePlugins()
