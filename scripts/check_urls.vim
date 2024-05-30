" Test for URLs in help documents.
"
" Opens a new window with all found URLS followed by return code from curl
" (anything other than 0 means unreachable)
"
" Written by Christian Brabandt.

func Test_check_URLs()
"20.10.23, added by Restorer
  if has("win32")
    let s:outdev = 'nul'
  else
    let s:outdev = '/dev/null'
  endif
" Restorer: For Windows users. If "curl" or "wget" is installed on the system
" but not in %PATH%, add the full path to them to %PATH% environment variable.
  if executable('curl')
    " Note: does not follow redirects!
    let s:command1 = 'curl --silent --max-time 5 --fail --output ' ..s:outdev.. ' --head '
    let s:command2 = ""
  elseif executable('wget')
    " Note: only allow a couple of redirects
    let s:command1 = 'wget --quiet -S --spider --max-redirect=2 --timeout=5 --tries=2 -O ' ..s:outdev.. ' '
    let s:command2 = ""
  elseif has("win32") "20.10.23, added by Restorer
    if executable('powershell')
      if 2 == system('powershell -nologo -noprofile "$psversiontable.psversion.major"')
        echoerr 'To work in OS Windows requires the program "PowerShell" version 3.0 or higher'
        return
      endif
      let s:command1 = 
            \ "powershell -nologo -noprofile \"{[Net.ServicePointManager]::SecurityProtocol = 'Tls12, Tls11, Tls, Ssl3'};try{(Invoke-WebRequest -MaximumRedirection 2 -TimeoutSec 5 -Uri "
      let s:command2 = ').StatusCode}catch{exit [int]$Error[0].Exception.Status}"'
    endif
  else
    echoerr 'Only works when "curl" or "wget", or "powershell" is available'
    return
  endif

  " Do the testing.
  set report =999
  set nomore shm +=s

  let pat='\(https\?\|ftp\)://[^\t* ]\+'
  exe 'helpgrep' pat
  helpclose

  let urls = map(getqflist(), 'v:val.text')
  " do not use submatch(1)!
  let urls = map(urls, {key, val -> matchstr(val, pat)})
  " remove examples like user@host (invalid urls)
  let urls = filter(urls, 'v:val !~ "@"')
  " Remove example URLs which are invalid
  let urls = filter(urls, {key, val -> val !~ '\<\(\(my\|some\)\?host\|machine\|hostname\|file\)\>'})
  new
  put =urls
  " remove some more invalid items
  " empty lines
  "20.10.23, Restorer: '_' is a little faster, see `:h global`
  v/./d _
  " remove # anchors
  %s/#.*$//e
  " remove trailing stuff (parenthesis, dot, comma, quotes), but only for HTTP
  " links
  g/^h/s#[.),'"`/>][:.,]\?$##
  g#^[hf]t\?tp:/\(/\?\.*\)$#d _
  silent! g/ftp://,$/d _
  silent! g/=$/d _
  let a = getline(1,'$')
  let a = uniq(sort(a))
  %d _
  call setline(1, a)

  %s/.*/\=TestURL(submatch(0))/

  " highlight the failures
  /.* \([0-9]*[1-9]\|[0-9]\{2,}\)$
endfunc

func TestURL(url)
  " Relies on the return code to determine whether a page is valid
  echom printf("Testing URL: %d/%d %s", line('.'), line('$'), a:url)
  call system(s:command1 .. shellescape(a:url) .. s:command2)
  return printf("%s %d", a:url, v:shell_error)
endfunc

call Test_check_URLs()

" vim: sw=2 sts=2 et
