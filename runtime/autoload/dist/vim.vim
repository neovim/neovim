" Vim runtime support library,
" runs the vim9 script version or legacy script version
" on demand (mostly for Neovim compatability)
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Nov 04


" enable the zip and gzip plugin by default, if not set
if !exists('g:zip_exec')
  let g:zip_exec = 1
endif

if !exists('g:gzip_exec')
  let g:gzip_exec = 1
endif

if !has('vim9script')
  function dist#vim#IsSafeExecutable(filetype, executable)
    let cwd = getcwd()
    if empty(exepath(a:executable))
      return v:false
    endif
    return get(g:, a:filetype .. '_exec', get(g:, 'plugin_exec', 0)) &&
          \ (fnamemodify(exepath(a:executable), ':p:h') !=# cwd
          \ || (split($PATH, has('win32') ? ';' : ':')->index(cwd) != -1 &&
          \  cwd != '.'))
  endfunction

  finish
endif

def dist#vim#IsSafeExecutable(filetype: string, executable: string): bool
  return dist#vim9#IsSafeExecutable(filetype, executable)
enddef
