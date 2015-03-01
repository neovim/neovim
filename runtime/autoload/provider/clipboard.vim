" The clipboard provider uses shell commands to communicate with the clipboard.
" The provider function will only be registered if a supported command is
" available.
let s:copy = {}
let s:paste = {}

" When caching is enabled, store the jobid of the xclip/xsel process keeping
" ownership of the selection, so we know how long the cache is valid.
let s:selection = { 'owner': 0, 'data': [] }

function! s:selection.on_exit(jobid, data, event)
  " At this point this nvim instance might already have launched
  " a new provider instance. Don't drop ownership in this case.
  if self.owner == a:jobid
    let self.owner = 0
  endif
endfunction

let s:selections = { '*': s:selection, '+': copy(s:selection)}

function! s:try_cmd(cmd, ...)
  let argv = split(a:cmd, " ")
  let out = a:0 ? systemlist(argv, a:1, 1) : systemlist(argv, [''], 1)
  if v:shell_error
    echohl WarningMsg
    echo "clipboard: error: ".(len(out) ? out[0] : '')
    echohl None
    return 0
  endif
  return out
endfunction

let s:cache_enabled = 1
let s:use_vimenc = 0
if executable('xsel-vim')
  let s:use_vimenc = 1
  let s:copy['+'] = 'xsel-vim --vimenc --nodetach -i -b'
  let s:paste['+'] = 'xsel-vim --vimenc -o -b'
  let s:copy['*'] = 'xsel-vim --vimenc --nodetach -i -p'
  let s:paste['*'] = 'xsel-vim --vimenc -o -p'
elseif executable('pbcopy')
  let s:copy['+'] = 'pbcopy'
  let s:paste['+'] = 'pbpaste'
  let s:copy['*'] = s:copy['+']
  let s:paste['*'] = s:paste['+']
  let s:cache_enabled = 0
elseif executable('xclip')
  let s:copy['+'] = 'xclip -quiet -i -selection clipboard'
  let s:paste['+'] = 'xclip -o -selection clipboard'
  let s:copy['*'] = 'xclip -quiet -i -selection primary'
  let s:paste['*'] = 'xclip -o -selection primary'
elseif executable('xsel')
  let s:copy['+'] = 'xsel --nodetach -i -b'
  let s:paste['+'] = 'xsel -o -b'
  let s:copy['*'] = 'xsel --nodetach -i -p'
  let s:paste['*'] = 'xsel -o -p'
else
  echom 'clipboard: No clipboard tool available. See :help nvim-clipboard'
  finish
endif

let s:clipboard = {}

" \n is really null
let s:vimenc_to_type = {
    \ "\n" : "v",
    \ "\x01" : "V",
    \ "\x02" : "b",
    \ }

let s:type_to_vimenc = {
    \ "v" : "\n",
    \ "V" : "\x01",
    \ "b" : "\x02",
    \ }

function! s:clipboard.get(reg)
  if s:selections[a:reg].owner > 0
    return s:selections[a:reg].data
  end
  let type = ''
  let result = s:try_cmd(s:paste[a:reg])
  if type(result) == type(0)
    " error
    return result
  end
  if s:use_vimenc && len(result) > 0 && len(result[0]) > 0
    if result[0][0] == "v"
      "vimenc format
      let vimenc_motion = result[0][1]
      let nullind = match(result[0], "\n", 2)
      " FIXME: actually handle encoding...
      let encoding = result[0][2:nullind]
      " "result[0]" is sometimes "locked" so can't this:
      "let result[0] = result[0][nullind+1:]
      let result = [result[0][nullind+1:]] + result[1:]
      " in case vim invents a fourth selection type in the meanwhile
      " just ignore it
      let type = get(s:vimenc_to_type, vimenc_motion, '')
    else
      "text format
      let result = [result[0][1:]] + result[1:]
    end
  end
  return [result, type]
endfunction

function! s:clipboard.set(lines, regtype, reg)
  let contents = copy(a:lines)
  if s:use_vimenc
    let regsym = s:type_to_vimenc[a:regtype]
    " TODO: add &encoding instead? (or even better: convert to utf-8)
    " or pluseven better: &encoding always utf-8 ...
    let contents[0] = regsym."utf-8\n".contents[0]
  end
  if s:cache_enabled == 0
    call s:try_cmd(s:copy[a:reg], contents)
    return 0
  end

  let selection = s:selections[a:reg]
  if selection.owner > 0
    " The previous provider instance should exit when the new one takes
    " ownership, but kill it to be sure we don't fill up the job table.
    call jobstop(selection.owner)
  end
  let selection.data = [a:lines, a:regtype]
  let argv = split(s:copy[a:reg], " ")
  let jobid = jobstart(argv, selection)
  if jobid <= 0
    echohl WarningMsg
    echo "clipboard: error when invoking provider"
    echohl None
    return 0
  endif
  call jobsend(jobid, contents)
  call jobclose(jobid, 'stdin')
  let selection.owner = jobid
endfunction

function! provider#clipboard#Call(method, args)
  return call(s:clipboard[a:method],a:args,s:clipboard)
endfunction
