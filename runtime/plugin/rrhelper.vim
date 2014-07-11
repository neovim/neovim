" Vim plugin with helper function(s) for --remote-wait
" Maintainer: Flemming Madsen <fma@cci.dk>
" Last Change: 2008 May 29

" Has this already been loaded?
if exists("loaded_rrhelper") || !has("clientserver")
  finish
endif
let loaded_rrhelper = 1

" Setup answers for a --remote-wait client who will assume
" a SetupRemoteReplies() function in the command server

function SetupRemoteReplies()
  let cnt = 0
  let max = argc()

  let id = expand("<client>")
  if id == 0
    return
  endif
  while cnt < max
    " Handle same file from more clients and file being more than once
    " on the command line by encoding this stuff in the group name
    let uniqueGroup = "RemoteReply_".id."_".cnt

    " Path separators are always forward slashes for the autocommand pattern.
    " Escape special characters with a backslash.
    let f = substitute(argv(cnt), '\\', '/', "g")
    if exists('*fnameescape')
      let f = fnameescape(f)
    else
      let f = escape(f, " \t\n*?[{`$\\%#'\"|!<")
    endif
    execute "augroup ".uniqueGroup
    execute "autocmd ".uniqueGroup." BufUnload ". f ."  call DoRemoteReply('".id."', '".cnt."', '".uniqueGroup."', '". f ."')"
    let cnt = cnt + 1
  endwhile
  augroup END
endfunc

function DoRemoteReply(id, cnt, group, file)
  call server2client(a:id, a:cnt)
  execute 'autocmd! '.a:group.' BufUnload '.a:file
  execute 'augroup! '.a:group
endfunc

" vim: set sw=2 sts=2 :
