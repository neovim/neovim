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

  let dest = stdpath('data')
  if !empty(dest)
    if !isdirectory(dest)
      if getftype(dest) != "link"
        call mkdir(dest, 'p', 0700)
      endif
    endif
    let manifest_base = dest
  endif

  return manifest_base.'/rplugin.vim'
endfunction

" Old manifest file based on known script locations.
function! s:GetOldManifestPaths() abort
  let prefix = exists('$MYVIMRC')
        \ ? $MYVIMRC
        \ : matchstr(get(split(execute('scriptnames'), '\n'), 0, ''), '\f\+$')
  let origpath = fnamemodify(expand(prefix, 1), ':h')
        \.'/.'.fnamemodify(prefix, ':t').'-rplugin~'
  if !has('win32')
    return [origpath]
  endif
  " Windows used to use $APPLOCALDATA/nvim but stdpath('data') is
  " $XDG_DATA_DIR/nvim-data
  let pseudostdpath = exists('$LOCALAPPDATA') ? '$LOCALAPPDATA' : '~/AppData/Local'
  let pseudostdpath = fnamemodify(expand(pseudostdpath), ':p')
  return [substitute(pseudostdpath, '[/\\]\=$', '/', '') . 'nvim/rplugin.vim', origpath]
endfunction

function! s:GetManifest() abort
  let manifest = s:GetManifestPath()
  if !filereadable(manifest)
    " Check if an old manifest file exists and move it to the new location.
    for old_manifest in s:GetOldManifestPaths()
      if filereadable(old_manifest)
        call rename(old_manifest, manifest)
        break
      endif
    endfor
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

if index(v:argv, "--clean") < 0
  call s:LoadRemotePlugins()
endif
