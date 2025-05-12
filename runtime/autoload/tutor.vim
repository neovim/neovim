" vim: fdm=marker et ts=4 sw=4

" Setup: {{{1
function! tutor#SetupVim()
    if !exists('g:did_load_ftplugin') || g:did_load_ftplugin != 1
        filetype plugin on
    endif
    if has('syntax')
        if !exists('g:syntax_on') || g:syntax_on == 0
            syntax on
        endif
    endif
endfunction

" Loads metadata file, if available
function! tutor#LoadMetadata()
    let b:tutor_metadata = json_decode(join(readfile(expand('%').'.json'), "\n"))
endfunction

" Mappings: {{{1

function! tutor#SetNormalMappings()
    nnoremap <silent> <buffer> <CR> :call tutor#FollowLink(0)<cr>
    nnoremap <silent> <buffer> <2-LeftMouse> :call tutor#MouseDoubleClick()<cr>
    nnoremap <buffer> >> :call tutor#InjectCommand()<cr>
endfunction

function! tutor#MouseDoubleClick()
    if foldclosed(line('.')) > -1
        normal! zo
    else
        if match(getline('.'), '^#\{1,} ') > -1 && foldlevel(line('.')) > 0
            silent normal! zc
        else
            call tutor#FollowLink(0)
        endif
    endif
endfunction

function! tutor#InjectCommand()
    let l:cmd = substitute(getline('.'),  '^\s*', '', '')
    exe l:cmd
    redraw | echohl WarningMsg | echon  "tutor: ran" | echohl None | echon " " | echohl Statement | echon l:cmd
endfunction

function! tutor#FollowLink(force)
    let l:stack_s = join(map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")'), '')
    if l:stack_s =~# 'tutorLink'
        let l:link_start = searchpairpos('\[', '', ')', 'nbcW')
        let l:link_end = searchpairpos('\[', '', ')', 'ncW')
        if l:link_start[0] == l:link_end[0]
            let l:linkData = getline(l:link_start[0])[l:link_start[1]-1:l:link_end[1]-1]
        else
            return
        endif
        let l:target = matchstr(l:linkData, '(\@<=.*)\@=')
        if a:force != 1 && match(l:target, '\*.\+\*') > -1
            call cursor(l:link_start[0], l:link_end[1])
            call search(l:target, '')
            normal! ^
        elseif a:force != 1 && match(l:target, '^@tutor:') > -1
            let l:tutor = matchstr(l:target, '@tutor:\zs.*')
            exe "Tutor ".l:tutor
        else
            exe "help ".l:target
        endif
    endif
endfunction

" Folding And Info: {{{1

function! tutor#TutorFolds()
    if getline(v:lnum) =~# '^#\{1,6}'
        return ">". len(matchstr(getline(v:lnum), '^#\{1,6}'))
    else
        return "="
    endif
endfunction

" Marks: {{{1

function! tutor#ApplyMarks()
    hi! link tutorExpect Special
    if exists('b:tutor_metadata') && has_key(b:tutor_metadata, 'expect')
        let b:tutor_sign_id = 1
        for expct in keys(b:tutor_metadata['expect'])
            let lnum = eval(expct)
            call matchaddpos('tutorExpect', [lnum])
            call tutor#CheckLine(lnum)
        endfor
    endif
endfunction

function! tutor#ApplyMarksOnChanged()
    if exists('b:tutor_metadata') && has_key(b:tutor_metadata, 'expect')
        let lnum = line('.')
        if index(keys(b:tutor_metadata['expect']), string(lnum)) > -1
            call tutor#CheckLine(lnum)
        endif
    endif
endfunction

function! tutor#CheckLine(line)
    if exists('b:tutor_metadata') && has_key(b:tutor_metadata, 'expect')
        let bufn = bufnr('%')
        let ctext = getline(a:line)
        let signs = sign_getplaced(bufn, {'lnum': a:line})[0].signs
        if !empty(signs)
            call sign_unplace('', {'id': signs[0].id})
        endif
        if b:tutor_metadata['expect'][string(a:line)] == -1 || ctext ==# b:tutor_metadata['expect'][string(a:line)]
            exe "sign place ".b:tutor_sign_id." line=".a:line." name=tutorok buffer=".bufn
        else
            exe "sign place ".b:tutor_sign_id." line=".a:line." name=tutorbad buffer=".bufn
        endif
        let b:tutor_sign_id+=1
    endif
endfunction

" Tutor Cmd: {{{1

function! s:Locale()
    " Make sure l:lang exists before returning.
    let l:lang = 'en_US'
    if exists('v:lang') && v:lang =~ '\a\a'
        let l:lang = v:lang
    elseif $LC_ALL =~ '\a\a'
        let l:lang = $LC_ALL
    elseif $LC_MESSAGES =~ '\a\a' || $LC_MESSAGES ==# "C"
      " LC_MESSAGES=C can be used to explicitly ask for English messages while
      " keeping LANG non-English; don't set l:lang then.
      if $LC_MESSAGES =~ '\a\a'
        let l:lang = $LC_MESSAGES
      endif
    elseif $LANG =~ '\a\a'
        let l:lang = $LANG
    endif
    return split(l:lang, '_')
endfunction

function! s:GlobPath(lp, pat)
    if version >= 704 && has('patch279')
        return globpath(a:lp, a:pat, 1, 1)
    else
        return split(globpath(a:lp, a:pat, 1), '\n')
    endif
endfunction

function! s:Sort(a, b)
    let mod_a = fnamemodify(a:a, ':t')
    let mod_b = fnamemodify(a:b, ':t')
    if mod_a == mod_b
        let retval =  0
    elseif mod_a > mod_b
        if match(mod_a, '^vim-') > -1 && match(mod_b, '^vim-') == -1
            let retval = -1
        else
            let retval = 1
        endif
    else
        if match(mod_b, '^vim-') > -1 && match(mod_a, '^vim-') == -1
            let retval = 1
        else
            let retval = -1
        endif
    endif
    return retval
endfunction

function! s:GlobTutorials(name)
    " search for tutorials:
    " 1. non-localized
    let l:tutors = s:GlobPath(&rtp, 'tutor/'.a:name.'.tutor')
    " 2. localized for current locale
    let l:locale_tutors = s:GlobPath(&rtp, 'tutor/'.s:Locale()[0].'/'.a:name.'.tutor')
    " 3. fallback to 'en'
    if len(l:locale_tutors) == 0
        let l:locale_tutors = s:GlobPath(&rtp, 'tutor/en/'.a:name.'.tutor')
    endif
    call extend(l:tutors, l:locale_tutors)
    return uniq(sort(l:tutors, 's:Sort'), 's:Sort')
endfunction

function! tutor#TutorCmd(tutor_name)
    if match(a:tutor_name, '[[:space:]]') > 0
        echom "Only one argument accepted (check spaces)"
        return
    endif

    if a:tutor_name == ''
        let l:tutor_name = 'vim-01-beginner.tutor'
    else
        let l:tutor_name = a:tutor_name
    endif

    if match(l:tutor_name, '\.tutor$') > 0
        let l:tutor_name = fnamemodify(l:tutor_name, ':r')
    endif

    let l:tutors = s:GlobTutorials(l:tutor_name)

    if len(l:tutors) == 0
        echom "No tutorial with that name found"
        return
    endif

    if len(l:tutors) == 1
        let l:to_open = l:tutors[0]
    else
        let l:idx = 0
        let l:candidates = ['Several tutorials with that name found. Select one:']
        for candidate in map(copy(l:tutors),
                    \'fnamemodify(v:val, ":h:h:t")."/".s:Locale()[0]."/".fnamemodify(v:val, ":t")')
            let l:idx += 1
            call add(l:candidates, l:idx.'. '.candidate)
        endfor
        let l:tutor_to_open = inputlist(l:candidates)
        let l:to_open = l:tutors[l:tutor_to_open-1]
    endif

    call tutor#SetupVim()
    exe "edit ".l:to_open
    call tutor#EnableInteractive(v:true)
    call tutor#ApplyTransform()
endfunction

function! tutor#TutorCmdComplete(lead,line,pos)
    let l:tutors = s:GlobTutorials('*')
    let l:names = uniq(sort(map(l:tutors, 'fnamemodify(v:val, ":t:r")'), 's:Sort'))
    return join(l:names, "\n")
endfunction

" Enables/disables interactive mode.
function! tutor#EnableInteractive(enable)
    let enable = a:enable
    if enable
        setlocal buftype=nofile
        setlocal concealcursor+=inv
        setlocal conceallevel=2
        call tutor#ApplyMarks()
        augroup tutor_interactive
            autocmd! TextChanged,TextChangedI <buffer> call tutor#ApplyMarksOnChanged()
        augroup END
    else
        setlocal buftype<
        setlocal concealcursor<
        setlocal conceallevel<
        if exists('#tutor_interactive')
            autocmd! tutor_interactive * <buffer>
        endif
    endif
endfunction

function! tutor#ApplyTransform()
    if has('win32')
        sil! %s/{unix:(\(.\{-}\)),win:(\(.\{-}\))}/\2/g
    else
        sil! %s/{unix:(\(.\{-}\)),win:(\(.\{-}\))}/\1/g
    endif
    normal! gg0
endfunction
