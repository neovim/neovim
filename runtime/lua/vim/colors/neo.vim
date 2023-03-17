set background=dark

highlight clear
let g:colors_name = 'neo'

if &termguicolors || has('gui_running')
  let g:terminal_color_0 = '#303030' " black
  let g:terminal_color_1 = '#af5f5f' " red
  let g:terminal_color_2 = '#5faf5f' " green
  let g:terminal_color_3 = '#d7af5f' " yellow
  let g:terminal_color_4 = '#5f87d7' " blue
  let g:terminal_color_5 = '#875faf' " magenta
  let g:terminal_color_6 = '#008787' " cyan
  let g:terminal_color_7 = '#d9d9d9' " white
  let g:terminal_color_8 = '#808080' " gray
  let g:terminal_color_9 = '#af5f5f' " brightred
  let g:terminal_color_10 = '#5faf5f' " brightgreen
  let g:terminal_color_11 = '#d7af5f' " brightyellow
  let g:terminal_color_12 = '#5f87d7' " brightblue
  let g:terminal_color_13 = '#875faf' " brightmagenta
  let g:terminal_color_14 = '#008787' " brightcyan
  let g:terminal_color_15 = '#e5e5e5' " brightwhite
endif

" TODO: is hl-Ignore on neovim different?
" TODO: how is WinSeparator different from VertSplit?
" TODO: neovim WhiteSpace or something is added
" TODO: test termguicolors
" TODO: test GUI Spelling undercurls on actual GUI and wezterm/kitty/alacritty
" TODO: set hl-User1 to User9 for `:h 'stl' usages` with same palette

" Must be set first
highlight! Normal ctermfg=250 ctermbg=234 cterm=NONE guifg=#bcbcbc guibg=#1c1c1c gui=NONE

" Preferred groups, see `:h group-name`
highlight! Comment ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! Constant ctermfg=110 ctermbg=NONE cterm=NONE guifg=#afaf87 guibg=NONE gui=NONE
highlight! Identifier ctermfg=108 ctermbg=NONE cterm=NONE guifg=#87af87 guibg=NONE gui=NONE
highlight! Statement ctermfg=139 ctermbg=NONE cterm=NONE guifg=#af87af guibg=NONE gui=NONE
highlight! PreProc ctermfg=144 ctermbg=NONE cterm=NONE guifg=#afaf87 guibg=NONE gui=NONE
highlight! Type ctermfg=110 ctermbg=NONE cterm=NONE guifg=#87afd7 guibg=NONE gui=NONE
highlight! Special ctermfg=66 ctermbg=NONE cterm=NONE guifg=#5f8787 guibg=NONE gui=NONE
highlight! Underlined ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
highlight! Ignore ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
highlight! Error ctermfg=210 ctermbg=234 cterm=reverse guifg=#ff8787 guibg=#1c1c1c gui=reverse
highlight! Todo ctermfg=144 ctermbg=234 cterm=reverse guifg=#afaf87 guibg=#1c1c1c gui=reverse

highlight! Statusline ctermfg=234 ctermbg=247 cterm=NONE guifg=#1c1c1c guibg=#9e9e9e gui=NONE
highlight! StatuslineNC ctermfg=234 ctermbg=243 cterm=NONE guifg=#1c1c1c guibg=#767676 gui=NONE
highlight! TabLineFill ctermfg=235 ctermbg=235 cterm=NONE guifg=#262626 guibg=#262626 gui=NONE

highlight! link TabLine StatuslineNC
highlight! link TabLineSel Statusline
highlight! link VertSplit TabLineFill

highlight! MsgArea ctermfg=250 ctermbg=235 cterm=NONE guifg=#262626 guibg=#262626 gui=NONE

highlight! CursorLineNr ctermfg=150 ctermbg=234 cterm=NONE guifg=#afd787 guibg=#1c1c1c gui=NONE
highlight! LineNr ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! LineNrAbove ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! LineNrBelow ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE

highlight! Folded ctermfg=247 ctermbg=235 cterm=NONE guifg=#9e9e9e guibg=#262626
highlight! FoldColumn ctermfg=244 ctermbg=234 cterm=NONE guifg=#808080 guibg=#1c1c1c gui=NONE
highlight! SignColumn ctermfg=NONE ctermbg=234 cterm=NONE guifg=NONE guibg=#1c1c1c gui=NONE
highlight! CursorColumn ctermfg=NONE ctermbg=236 cterm=NONE guifg=NONE guibg=#303030 gui=NONE
highlight! ColorColumn ctermfg=NONE ctermbg=236 cterm=NONE guifg=NONE guibg=#303030 gui=NONE
highlight! CursorLine ctermfg=NONE ctermbg=236 cterm=NONE guifg=NONE guibg=#303030 gui=NONE

highlight! Pmenu ctermfg=250 ctermbg=235 cterm=NONE guifg=#bcbcbc guibg=#262626 gui=NONE
highlight! PmenuThumb ctermfg=250 ctermbg=250 cterm=NONE guifg=#bcbcbc guibg=#bcbcbc gui=NONE
highlight! PmenuSbar ctermfg=238 ctermbg=238 cterm=NONE guifg=#444444 guibg=#444444 gui=NONE
highlight! PmenuSel ctermfg=234 ctermbg=150 cterm=NONE guifg=#1c1c1c guibg=#afd787 gui=NONE

highlight! ErrorMsg ctermfg=210 ctermbg=234 cterm=reverse guifg=#ff8787 guibg=#1c1c1c gui=reverse
highlight! ModeMsg ctermfg=150 ctermbg=234 cterm=NONE guifg=#afd787 guibg=#1c1c1c gui=NONE
highlight! MoreMsg ctermfg=150 ctermbg=234 cterm=NONE guifg=#afd787 guibg=#1c1c1c gui=NONE
highlight! Question ctermfg=150 ctermbg=234 cterm=NONE guifg=#afd787 guibg=#1c1c1c gui=NONE
highlight! WarningMsg ctermfg=173 ctermbg=234 cterm=NONE guifg=#d7875f guibg=#1c1c1c gui=NONE
highlight! MatchParen ctermfg=66 ctermbg=234 cterm=reverse guifg=#5f8787 guibg=#1c1c1c gui=NONE
highlight! Conceal ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! Title ctermfg=144 ctermbg=NONE cterm=NONE guifg=#afaf87 guibg=NONE gui=NONE
highlight! Directory ctermfg=110 ctermbg=NONE cterm=NONE guifg=#afaf87 guibg=NONE gui=NONE
highlight! NonText ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! EndOfBuffer ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE
highlight! SpecialKey ctermfg=244 ctermbg=NONE cterm=NONE guifg=#808080 guibg=NONE gui=NONE

highlight! IncSearch ctermfg=234 ctermbg=185 cterm=NONE guifg=#1c1c1c guibg=#dfdf5f gui=NONE
highlight! CurSearch ctermfg=234 ctermbg=150 cterm=NONE guifg=#1c1c1c guibg=#afd787 gui=NONE
highlight! Search ctermfg=234 ctermbg=108 cterm=NONE guifg=#1c1c1c guibg=#87af87 gui=NONE

highlight! QuickFixLine ctermfg=234 ctermbg=110 cterm=NONE guifg=#1c1c1c guibg=#afaf87 gui=NONE
highlight! Visual ctermfg=234 ctermbg=150 cterm=NONE guifg=#1c1c1c guibg=#afd787 gui=NONE
highlight! VisualNOS ctermfg=234 ctermbg=150 cterm=NONE guifg=#1c1c1c guibg=#afd787 gui=NONE
highlight! WildMenu ctermfg=234 ctermbg=150 cterm=NONE guifg=#1c1c1c guibg=#afd787 gui=NONE

highlight! debugPC ctermfg=234 ctermbg=66 cterm=NONE guifg=#1c1c1c guibg=#5f875f gui=NONE
highlight! debugBreakpoint ctermfg=234 ctermbg=173 cterm=NONE guifg=#1c1c1c guibg=#d7875f gui=NONE

highlight! SpellBad ctermfg=210 ctermbg=234 cterm=underline guisp=#ff8787 guibg=#1c1c1c gui=undercurl
highlight! SpellCap ctermfg=66 ctermbg=234 cterm=underline guisp=#5f875f guibg=#1c1c1c gui=undercurl
highlight! SpellLocal ctermfg=108 ctermbg=234 cterm=underline guisp=#87af87 guibg=#1c1c1c gui=undercurl
highlight! SpellRare ctermfg=110 ctermbg=234 cterm=underline guisp=#87afd7 guibg=#1c1c1c gui=undercurl

highlight! DiffAdd ctermfg=234 ctermbg=108 cterm=NONE guifg=#1c1c1c guibg=#87af87 gui=NONE

" TODO: these might need tweaking orange might need tweaking
highlight! DiffDelete ctermfg=137 ctermbg=NONE cterm=NONE guifg=#af875f guibg=NONE gui=NONE
highlight! DiffText ctermfg=234 ctermbg=188 cterm=NONE guifg=#1c1c1c guibg=#dfdfdf gui=NONE
highlight! DiffChange ctermfg=234 ctermbg=145 cterm=NONE guifg=#1c1c1c guibg=#afafaf gui=NONE

highlight! link NormalFloat Pmenu
highlight! link NormalFloatNC Normal

highlight! link WinBar Statusline
highlight! link WinBarNC StatuslineNC

" vim: et ts=2 sw=2
