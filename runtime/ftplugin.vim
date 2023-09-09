" Vim support file to switch on loading plugins for file types
"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

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
        " Load Lua ftplugins after Vim ftplugins _per directory_
        " TODO(clason): use nvim__get_runtime when supports globs and modeline
        " XXX: "[.]" in the first pattern makes it a wildcard on Windows
        exe $'runtime! ftplugin/{name}[.]{{vim,lua}} ftplugin/{name}_*.{{vim,lua}} ftplugin/{name}/*.{{vim,lua}}'
      endfor
    endif
  endfunc
augroup END
