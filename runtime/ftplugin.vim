" Vim support file to switch on loading plugins for file types
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2006 Apr 30

if exists("did_load_ftplugin")
  finish
endif
let did_load_ftplugin = 1

augroup filetypeplugin
  au FileType * call s:LoadFTPlugin()

  func! s:LoadFTPlugin()
    if exists("b:undo_ftplugin")
      exe b:undo_ftplugin
      unlet! b:undo_ftplugin b:did_ftplugin
    endif

    let s = expand("<amatch>")
    if s != ""
      if &cpo =~# "S" && exists("b:did_ftplugin")
	" In compatible mode options are reset to the global values, need to
	" set the local values also when a plugin was already used.
	unlet b:did_ftplugin
      endif

      " When there is a dot it is used to separate filetype names.  Thus for
      " "aaa.bbb" load "aaa" and then "bbb".
      for name in split(s, '\.')
        exe 'runtime! ftplugin/' . name . '.vim ftplugin/' . name . '_*.vim ftplugin/' . name . '/*.vim'
        " Load lua ftplugins
        exe printf('runtime! ftplugin/%s.lua ftplugin/%s_*.lua ftplugin/%s/*.lua', name, name, name)
      endfor
    endif
  endfunc
augroup END
