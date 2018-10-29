" Vim filetype plugin file (GUI menu, folding and completion)
" Language:     Debian Changelog
" Maintainer:   Debian Vim Maintainers
" Former Maintainers:   Michael Piefel <piefel@informatik.hu-berlin.de>
"                       Stefano Zacchiroli <zack@debian.org>
" Last Change:  2018-01-28
" License:      Vim License
" URL:          https://salsa.debian.org/vim-team/vim-debian/blob/master/ftplugin/debchangelog.vim

" Bug completion requires apt-listbugs installed for Debian packages or
" python-launchpadlib installed for Ubuntu packages

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin=1

" {{{1 Local settings (do on every load)
if exists('g:debchangelog_fold_enable')
  setlocal foldmethod=expr
  setlocal foldexpr=DebGetChangelogFold(v:lnum)
  setlocal foldtext=DebChangelogFoldText()
endif

" Debian changelogs are not supposed to have any other text width,
" so the user cannot override this setting
setlocal tw=78
setlocal comments=f:* 

" Clean unloading
let b:undo_ftplugin = 'setlocal tw< comments< foldmethod< foldexpr< foldtext<'
" }}}1

if exists('g:did_changelog_ftplugin')
  finish
endif

" Don't load another plugin (this is global)
let g:did_changelog_ftplugin = 1

" {{{1 GUI menu

" Helper functions returning various data.
" Returns full name, either from $DEBFULLNAME or debianfullname.
" TODO Is there a way to determine name from anywhere else?
function <SID>FullName()
    if exists('$DEBFULLNAME')
	return $DEBFULLNAME
    elseif exists('g:debianfullname')
	return g:debianfullname
    else
	return 'Your Name'
    endif
endfunction

" Returns email address, from $DEBEMAIL, $EMAIL or debianemail.
function <SID>Email()
    if exists('$DEBEMAIL')
	return $DEBEMAIL
    elseif exists('$EMAIL')
	return $EMAIL
    elseif exists('g:debianemail')
	return g:debianemail
    else
	return 'your@email.address'
    endif
endfunction

" Returns date in RFC822 format.
function <SID>Date()
    let savelang = v:lc_time
    execute 'language time C'
    let dateandtime = strftime('%a, %d %b %Y %X %z')
    execute 'language time ' . savelang
    return dateandtime
endfunction

function <SID>WarnIfNotUnfinalised()
    if match(getline('.'), ' -- [[:alpha:]][[:alnum:].]')!=-1
	echohl WarningMsg
	echo 'The entry has not been unfinalised before editing.'
	echohl None
	return 1
    endif
    return 0
endfunction

function <SID>Finalised()
    let savelinenum = line('.')
    1
    call search('^ -- ')
    if match(getline('.'), ' -- [[:alpha:]][[:alnum:].]')!=-1
	let returnvalue = 1
    else
	let returnvalue = 0
    endif
    execute savelinenum
    return returnvalue
endfunction

" These functions implement the menus
function NewVersion()
    " The new entry is unfinalised and shall be changed
    amenu disable Changelog.New\ Version
    amenu enable Changelog.Add\ Entry
    amenu enable Changelog.Close\ Bug
    amenu enable Changelog.Set\ Distribution
    amenu enable Changelog.Set\ Urgency
    amenu disable Changelog.Unfinalise
    amenu enable Changelog.Finalise
    call append(0, substitute(getline(1), '-\([[:digit:]]\+\))', '-$$\1)', ''))
    call append(1, '')
    call append(2, '')
    call append(3, ' -- ')
    call append(4, '')
    call Urgency('low')
    normal! 1G0
    call search(')')
    normal! h
    normal! 
    call setline(1, substitute(getline(1), '-\$\$', '-', ''))
    if exists('g:debchangelog_fold_enable')
        foldopen
    endif
    call AddEntry()
endfunction

function AddEntry()
    1
    call search('^ -- ')
    .-2
    call append('.', '  * ')
    .+3
    let warn=<SID>WarnIfNotUnfinalised()
    .-2
    if warn
	echohl MoreMsg
	call input('Hit ENTER')
	echohl None
    endif
    startinsert!
endfunction

function CloseBug()
    1
    call search('^ -- ')
    let warn=<SID>WarnIfNotUnfinalised()
    .-2
    call append('.', '  *  (closes: #' . input('Bug number to close: ') . ')')
    normal! j^ll
    startinsert
endfunction

function Distribution(dist)
    call setline(1, substitute(getline(1), ')  *\%(UNRELEASED\|\l\+\);', ') ' . a:dist . ';', ''))
endfunction

function Urgency(urg)
    call setline(1, substitute(getline(1), 'urgency=.*$', 'urgency=' . a:urg, ''))
endfunction

function <SID>UnfinaliseMenu()
    " This means the entry shall be changed
    amenu disable Changelog.New\ Version
    amenu enable Changelog.Add\ Entry
    amenu enable Changelog.Close\ Bug
    amenu enable Changelog.Set\ Distribution
    amenu enable Changelog.Set\ Urgency
    amenu disable Changelog.Unfinalise
    amenu enable Changelog.Finalise
endfunction

function Unfinalise()
    call <SID>UnfinaliseMenu()
    1
    call search('^ -- ')
    call setline('.', ' -- ')
endfunction

function <SID>FinaliseMenu()
    " This means the entry should not be changed anymore
    amenu enable Changelog.New\ Version
    amenu disable Changelog.Add\ Entry
    amenu disable Changelog.Close\ Bug
    amenu disable Changelog.Set\ Distribution
    amenu disable Changelog.Set\ Urgency
    amenu enable Changelog.Unfinalise
    amenu disable Changelog.Finalise
endfunction

function Finalise()
    call <SID>FinaliseMenu()
    1
    call search('^ -- ')
    call setline('.', ' -- ' . <SID>FullName() . ' <' . <SID>Email() . '>  ' . <SID>Date())
endfunction


function <SID>MakeMenu()
    amenu &Changelog.&New\ Version			:call NewVersion()<CR>
    amenu Changelog.&Add\ Entry				:call AddEntry()<CR>
    amenu Changelog.&Close\ Bug				:call CloseBug()<CR>
    menu Changelog.-sep-				<nul>

    amenu Changelog.Set\ &Distribution.&unstable	:call Distribution("unstable")<CR>
    amenu Changelog.Set\ Distribution.&frozen		:call Distribution("frozen")<CR>
    amenu Changelog.Set\ Distribution.&stable		:call Distribution("stable")<CR>
    menu Changelog.Set\ Distribution.-sep-		<nul>
    amenu Changelog.Set\ Distribution.frozen\ unstable	:call Distribution("frozen unstable")<CR>
    amenu Changelog.Set\ Distribution.stable\ unstable	:call Distribution("stable unstable")<CR>
    amenu Changelog.Set\ Distribution.stable\ frozen	:call Distribution("stable frozen")<CR>
    amenu Changelog.Set\ Distribution.stable\ frozen\ unstable	:call Distribution("stable frozen unstable")<CR>

    amenu Changelog.Set\ &Urgency.&low			:call Urgency("low")<CR>
    amenu Changelog.Set\ Urgency.&medium		:call Urgency("medium")<CR>
    amenu Changelog.Set\ Urgency.&high			:call Urgency("high")<CR>

    menu Changelog.-sep-				<nul>
    amenu Changelog.U&nfinalise				:call Unfinalise()<CR>
    amenu Changelog.&Finalise				:call Finalise()<CR>

    if <SID>Finalised()
	call <SID>FinaliseMenu()
    else
	call <SID>UnfinaliseMenu()
    endif
endfunction

augroup changelogMenu
au BufEnter * if &filetype == "debchangelog" | call <SID>MakeMenu() | endif
au BufLeave * if &filetype == "debchangelog" | silent! aunmenu Changelog | endif
augroup END

" }}}
" {{{1 folding

" look for an author name in the [zonestart zoneend] lines searching backward
function! s:getAuthor(zonestart, zoneend)
  let linepos = a:zoneend
  while linepos >= a:zonestart
    let line = getline(linepos)
    if line =~# '^ --'
      return substitute(line, '^ --\s*\([^<]\+\)\s*.*', '\1', '')
    endif
    let linepos -= 1
  endwhile
  return '[unknown]'
endfunction

" Look for a package source name searching backward from the givenline and
" returns it. Return the empty string if the package name can't be found
function! DebGetPkgSrcName(lineno)
  let lineidx = a:lineno
  let pkgname = ''
  while lineidx > 0
    let curline = getline(lineidx)
    if curline =~# '^\S'
      let pkgname = matchlist(curline, '^\(\S\+\).*$')[1]
      break
    endif
    let lineidx = lineidx - 1
  endwhile
  return pkgname
endfunction

function! DebChangelogFoldText()
  if v:folddashes ==# '-'  " changelog entry fold
    return foldtext() . ' -- ' . s:getAuthor(v:foldstart, v:foldend) . ' '
  endif
  return foldtext()
endfunction

function! DebGetChangelogFold(lnum)
  let line = getline(a:lnum)
  if line =~# '^\w\+'
    return '>1' " beginning of a changelog entry
  endif
  if line =~# '^\s\+\[.*\]'
    return '>2' " beginning of an author-specific chunk
  endif
  if line =~# '^ --'
    return '1'
  endif
  return '='
endfunction

if exists('g:debchangelog_fold_enable')
  silent! foldopen!   " unfold the entry the cursor is on (usually the first one)
endif

" }}}

" {{{1 omnicompletion for Closes: #

if !exists('g:debchangelog_listbugs_severities')
  let g:debchangelog_listbugs_severities = 'critical,grave,serious,important,normal,minor,wishlist'
endif

fun! DebCompleteBugs(findstart, base)
  if a:findstart
    let line = getline('.')

    " try to detect whether this is closes: or lp:
    let g:debchangelog_complete_mode = 'debbugs'
    let try_colidx = col('.') - 1
    let colidx = -1 " default to no-completion-possible

    while try_colidx > 0 && line[try_colidx - 1] =~# '\s\|\d\|#\|,\|:'
      let try_colidx = try_colidx - 1
      if line[try_colidx] ==# '#' && colidx == -1
        " found hash, where we complete from:
        let colidx = try_colidx
      elseif line[try_colidx] ==# ':'
        if try_colidx > 1 && strpart(line, try_colidx - 2, 3) =~? '\clp:'
          let g:debchangelog_complete_mode = 'lp'
        endif
        break
      endif
    endwhile
    return colidx
  else " return matches:
    let bug_lines = []
    if g:debchangelog_complete_mode ==? 'lp'
      if ! has('python')
        echoerr 'vim must be built with Python support to use LP bug completion'
        return
      endif
      let pkgsrc = DebGetPkgSrcName(line('.'))
      python << EOF
import vim
try:
    from launchpadlib.launchpad import Launchpad
    from lazr.restfulclient.errors import HTTPError
    # login anonymously
    lp = Launchpad.login_anonymously('debchangelog.vim', 'production')
    ubuntu = lp.distributions['ubuntu']
    try:
        sp = ubuntu.getSourcePackage(name=vim.eval('pkgsrc'))
        status = ('New', 'Incomplete', 'Confirmed', 'Triaged',
                  'In Progress', 'Fix Committed')
        tasklist = sp.searchTasks(status=status, order_by='id')
        liststr = '['
        for task in tasklist:
            bug = task.bug
            liststr += "'#%d - %s'," % (bug.id, bug.title.replace('\'', '\'\''))
        liststr += ']'
        vim.command('silent let bug_lines = %s' % liststr.encode('utf-8'))
    except HTTPError:
        pass
except ImportError:
    vim.command('echoerr \'python-launchpadlib >= 1.5.4 needs to be installed to use Launchpad bug completion\'')
EOF
    else
      if ! filereadable('/usr/sbin/apt-listbugs')
        echoerr 'apt-listbugs not found, you should install it to use Closes bug completion'
        return
      endif
      let pkgsrc = DebGetPkgSrcName(line('.'))
      let listbugs_output = system('/usr/sbin/apt-listbugs -s ' . g:debchangelog_listbugs_severities . ' list ' . pkgsrc . ' | grep "^ #" 2> /dev/null')
      let bug_lines = split(listbugs_output, '\n')
    endif
    let completions = []
    for line in bug_lines
      let parts = matchlist(line, '^\s*\(#\S\+\)\s*-\s*\(.*\)$')
      " filter only those which match a:base:
      if parts[1] !~ '^' . a:base
        continue
      endif
      let completion = {}
      let completion['word'] = parts[1]
      let completion['menu'] = parts[2]
      let completion['info'] = parts[0]
      let completions += [completion]
    endfor
    return completions
  endif
endfun

setlocal omnifunc=DebCompleteBugs

" }}}

" vim: set foldmethod=marker:
