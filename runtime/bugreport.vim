:" Use this script to create the file "bugreport.txt", which contains
:" information about the environment of a possible bug in Vim.
:"
:" Maintainer:	Bram Moolenaar <Bram@vim.org>
:" Last change:	2005 Jun 12
:"
:" To use inside Vim:
:"	:so $VIMRUNTIME/bugreport.vim
:" Or, from the command line:
:"	vim -s $VIMRUNTIME/bugreport.vim
:"
:" The "if 1" lines are to avoid error messages when expression evaluation is
:" not compiled in.
:"
:if 1
:  let more_save = &more
:endif
:set nomore
:if has("unix")
:  !echo "uname -a" >bugreport.txt
:  !uname -a >>bugreport.txt
:endif
:redir >>bugreport.txt
:version
:if 1
:  func <SID>CheckDir(n)
:    if isdirectory(a:n)
:      echo 'directory "' . a:n . '" exists'
:    else
:      echo 'directory "' . a:n . '" does NOT exist'
:    endif
:  endfun
:  func <SID>CheckFile(n)
:    if filereadable(a:n)
:      echo '"' . a:n . '" is readable'
:    else
:      echo '"' . a:n . '" is NOT readable'
:    endif
:  endfun
:  echo "--- Directories and Files ---"
:  echo '$VIM = "' . $VIM . '"'
:  call <SID>CheckDir($VIM)
:  echo '$VIMRUNTIME = "' . $VIMRUNTIME . '"'
:  call <SID>CheckDir($VIMRUNTIME)
:  call <SID>CheckFile(&helpfile)
:  call <SID>CheckFile(fnamemodify(&helpfile, ":h") . "/tags")
:  call <SID>CheckFile($VIMRUNTIME . "/menu.vim")
:  call <SID>CheckFile($VIMRUNTIME . "/filetype.vim")
:  call <SID>CheckFile($VIMRUNTIME . "/syntax/synload.vim")
:  delfun <SID>CheckDir
:  delfun <SID>CheckFile
:  echo "--- Scripts sourced ---"
:  scriptnames
:endif
:set all
:if has("autocmd")
:  au
:endif
:if 1
:  echo "--- Normal/Visual mode mappings ---"
:endif
:map
:if 1
:  echo "--- Insert/Command-line mode mappings ---"
:endif
:map!
:if 1
:  echo "--- Abbreviations ---"
:endif
:ab
:if 1
:  echo "--- Highlighting ---"
:endif
:highlight
:if 1
:  echo "--- Variables ---"
:endif
:if 1
:  let
:endif
:redir END
:set more&
:if 1
:  let &more = more_save
:  unlet more_save
:endif
:e bugreport.txt
