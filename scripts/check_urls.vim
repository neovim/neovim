" Test for URLs in help documents.
"
" Opens a new window with all found URLS followed by return code from curl
" (anything other than 0 means unreachable)
"
" Written by Christian Brabandt.

func Test_check_URLs()
  if has("win32")
    echoerr "Doesn't work on MS-Windows"
    return
  endif
  if executable('curl')
    " Note: does not follow redirects!
    let s:command = 'curl --silent --fail --output /dev/null --head '
  elseif executable('wget')
    " Note: only allow a couple of redirects
    let s:command = 'wget --quiet -S --spider --max-redirect=2 --timeout=5 --tries=2 -O /dev/null '
  else
    echoerr 'Only works when "curl" or "wget" is available'
    return
  endif

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
  v/./d
  " remove # anchors
  %s/#.*$//e
  " remove trailing stuff (parenthesis, dot, comma, quotes), but only for HTTP
  " links
  g/^h/s#[.,)'"/>][:.]\?$##
  g#^[hf]t\?tp:/\(/\?\.*\)$#d
  silent! g/ftp://,$/d
  silent! g/=$/d
  let a = getline(1,'$')
  let a = uniq(sort(a))
  %d
  call setline(1, a)

  " Do the testing.
  set nomore
  %s/.*/\=TestURL(submatch(0))/

  " highlight the failures
  /.* \([0-9]*[1-9]\|[0-9]\{2,}\)$
endfunc

func TestURL(url)
  " Relies on the return code to determine whether a page is valid
  echom printf("Testing URL: %d/%d %s", line('.'), line('$'), a:url)
  call system(s:command . shellescape(a:url))
  return printf("%s %d", a:url, v:shell_error)
endfunc

call Test_check_URLs()
