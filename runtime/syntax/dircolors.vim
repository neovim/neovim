" Vim syntax file
" Language:        dircolors(1) input file
" Maintainer:      Jan Larres <jan@majutsushi.net>
" Previous Maintainer: Nikolai Weibull <now@bitwi.se>
" Latest Revision: 2013-08-17

if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

syntax keyword dircolorsTodo    FIXME TODO XXX NOTE contained

syntax region  dircolorsComment start='#' end='$' contains=dircolorsTodo,@Spell

syntax keyword dircolorsKeyword TERM LEFT LEFTCODE RIGHT RIGHTCODE END ENDCODE

syntax keyword dircolorsKeyword NORMAL NORM FILE RESET DIR LNK LINK SYMLINK
                              \ MULTIHARDLINK FIFO SOCK DOOR BLK CHR ORPHAN
                              \ MISSING PIPE BLOCK CHR EXEC SETUID SETGID
                              \ CAPABILITY STICKY_OTHER_WRITABLE
                              \ OTHER_WRITABLE STICKY

" Slackware only, ignored by GNU dircolors.
syntax keyword dircolorsKeyword COLOR OPTIONS EIGHTBIT

syntax match dircolorsExtension '^\s*\zs[.*]\S\+'

syntax match dircolorsEscape '\\[abefnrtv?_\\^#]'
syntax match dircolorsEscape '\\[0-9]\{3}'
syntax match dircolorsEscape '\\x[0-9a-f]\{3}'

if !has('gui_running') && &t_Co == ''
    syntax match dircolorsNumber '\<\d\+\>'
    highlight default link dircolorsNumber Number
endif

highlight default link dircolorsTodo      Todo
highlight default link dircolorsComment   Comment
highlight default link dircolorsKeyword   Keyword
highlight default link dircolorsExtension Identifier
highlight default link dircolorsEscape    Special

function! s:set_guicolors() abort
    let s:termguicolors = {}

    let s:termguicolors[0]  = "Black"
    let s:termguicolors[1]  = "DarkRed"
    let s:termguicolors[2]  = "DarkGreen"
    let s:termguicolors[3]  = "DarkYellow"
    let s:termguicolors[4]  = "DarkBlue"
    let s:termguicolors[5]  = "DarkMagenta"
    let s:termguicolors[6]  = "DarkCyan"
    let s:termguicolors[7]  = "Gray"
    let s:termguicolors[8]  = "DarkGray"
    let s:termguicolors[9]  = "Red"
    let s:termguicolors[10] = "Green"
    let s:termguicolors[11] = "Yellow"
    let s:termguicolors[12] = "Blue"
    let s:termguicolors[13] = "Magenta"
    let s:termguicolors[14] = "Cyan"
    let s:termguicolors[15] = "White"

    let xterm_palette = ["00", "5f", "87", "af", "d7", "ff"]

    let cur_col = 16

    for r in xterm_palette
        for g in xterm_palette
            for b in xterm_palette
                let s:termguicolors[cur_col] = '#' . r . g . b
                let cur_col += 1
            endfor
        endfor
    endfor

    for i in range(24)
        let g = i * 0xa + 8
        let s:termguicolors[i + 232] = '#' . g . g . g
    endfor
endfunction

function! s:get_hi_str(color, place) abort
    if a:color >= 0 && a:color <= 255
        if has('gui_running')
            return ' gui' . a:place . '=' . s:termguicolors[a:color]
        elseif a:color <= 7 || &t_Co == 256 || &t_Co == 88
            return ' cterm' . a:place . '=' . a:color
        endif
    endif
    return ''
endfunction

function! s:get_256color(colors) abort
    if len(a:colors) >= 2 " May be fewer while editing
        let [_five, color] = remove(a:colors, 0, 1)
        if _five != '5' || color == ''
            return -1
        else
            return str2nr(color)
        endif
    else
        return -1
    endif
endfunction

function! s:preview_color(linenr) abort
    let line = getline(a:linenr)
    let defline = matchlist(line, '^\v([A-Z_]+|[*.]\S+)\s+([0-9;]+)')
    if empty(defline)
        return
    endif

    let colordef = defline[2]

    let colors = split(colordef, ';')

    let hi_str = ''
    let hi_attrs = []
    while len(colors) > 0
        let item = str2nr(remove(colors, 0))
        if item == 1
            call add(hi_attrs, 'bold')
        elseif item == 3
            call add(hi_attrs, 'italic')
        elseif item == 4
            call add(hi_attrs, 'underline')
        elseif item == 7
            call add(hi_attrs, 'inverse')
        elseif item >= 30 && item <= 37
            " ANSI SGR foreground color
            let hi_str .= s:get_hi_str(item - 30, 'fg')
        elseif item >= 40 && item <= 47
            " ANSI SGR background color
            let hi_str .= s:get_hi_str(item - 40, 'bg')
        elseif item == 38
            " Foreground for terminals with 88/256 color support
            let color = s:get_256color(colors)
            if color == -1
                break
            endif
            let hi_str .= s:get_hi_str(color, 'fg')
        elseif item == 48
            " Background for terminals with 88/256 color support
            let color = s:get_256color(colors)
            if color == -1
                break
            endif
            let hi_str .= s:get_hi_str(color, 'bg')
        endif
    endwhile

    if hi_str == '' && empty(hi_attrs)
        return
    endif

    " Check whether we have already defined this color
    redir => s:currentmatch
    silent! execute 'syntax list'
    redir END

    if s:currentmatch !~# '\/\\_s\\zs' . colordef . '\\ze\\_s\/'
        " Append the buffer number to avoid problems with other dircolors
        " buffers interfering
        let bufnr = bufnr('%')
        execute 'syntax match dircolorsColor' . b:dc_next_index . '_' . bufnr .
              \ ' "\_s\zs' . colordef . '\ze\_s"'
        let hi_attrs_str = ''
        if !empty(hi_attrs)
            if has('gui_running')
                let hi_attrs_str = ' gui=' . join(hi_attrs, ',')
            else
                let hi_attrs_str = ' cterm=' . join(hi_attrs, ',')
            endif
        endif
        execute 'highlight default dircolorsColor' . b:dc_next_index . '_' .
              \ bufnr . hi_str . hi_attrs_str
        let b:dc_next_index += 1
    endif
endfunction

" Avoid accumulating too many definitions while editing
function! s:reset_colors() abort
    if b:dc_next_index > 0
        let bufnr = bufnr('%')
        for i in range(b:dc_next_index)
            execute 'syntax clear dircolorsColor' . i . '_' . bufnr
            execute 'highlight clear dircolorsColor' . i . '_' . bufnr
        endfor
        let b:dc_next_index = 0
    endif

    for linenr in range(1, line('$'))
        call s:preview_color(linenr)
    endfor
endfunction

let b:dc_next_index = 0

if has('gui_running')
    call s:set_guicolors()
endif

if has('gui_running') || &t_Co != ''
    call s:reset_colors()

    autocmd CursorMoved,CursorMovedI <buffer> call s:preview_color('.')
    autocmd CursorHold,CursorHoldI   <buffer> call s:reset_colors()
endif

let b:current_syntax = "dircolors"

let &cpo = s:cpo_save
unlet s:cpo_save
