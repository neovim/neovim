" Name:         industry
" Description:  "industry" stands for 'industrial' color scheme.
" Author:       Original author Shian Lee.
" Maintainer:   Original maintainer Shian Lee.
" Website:      https://github.com/vim/colorschemes
" License:      Same as Vim
" Last Updated: 2022-07-26 15:50:05

" Generated by Colortemplate v2.2.0

set background=dark

hi clear
let g:colors_name = 'industry'

let s:t_Co = exists('&t_Co') && !empty(&t_Co) && &t_Co >= 0 ? &t_Co : -1

if (has('termguicolors') && &termguicolors) || has('gui_running')
  let g:terminal_ansi_colors = ['#303030', '#870000', '#5fd75f', '#afaf00', '#87afff', '#af00af', '#00afaf', '#6c6c6c', '#444444', '#ff0000', '#00ff00', '#ffff00', '#005fff', '#ff00ff', '#00ffff', '#ffffff']
endif
hi Normal guifg=#dadada guibg=#000000 gui=NONE cterm=NONE
hi EndOfBuffer guifg=#444444 guibg=#000000 gui=NONE cterm=NONE
hi StatusLine guifg=#000000 guibg=#dadada gui=bold cterm=bold
hi StatusLineNC guifg=#000000 guibg=#6c6c6c gui=NONE cterm=NONE
hi StatusLineTerm guifg=#000000 guibg=#00ff00 gui=bold cterm=bold
hi StatusLineTermNC guifg=#000000 guibg=#5fd75f gui=NONE cterm=NONE
hi VertSplit guifg=#000000 guibg=#6c6c6c gui=NONE cterm=NONE
hi Pmenu guifg=#dadada guibg=#444444 gui=NONE cterm=NONE
hi PmenuSel guifg=#000000 guibg=#ffff00 gui=NONE cterm=NONE
hi PmenuSbar guifg=NONE guibg=#000000 gui=NONE cterm=NONE
hi PmenuThumb guifg=NONE guibg=#6c6c6c gui=NONE cterm=NONE
hi TabLine guifg=#dadada guibg=#444444 gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=#6c6c6c gui=NONE cterm=NONE
hi TabLineSel guifg=#ffffff guibg=#000000 gui=bold cterm=bold
hi ToolbarButton guifg=#dadada guibg=#6c6c6c gui=bold cterm=bold
hi ToolbarLine guifg=NONE guibg=#303030 gui=NONE cterm=NONE
hi NonText guifg=#00afaf guibg=NONE gui=NONE cterm=NONE
hi SpecialKey guifg=#00afaf guibg=NONE gui=NONE cterm=NONE
hi Folded guifg=#00afaf guibg=#303030 gui=NONE cterm=NONE
hi Visual guifg=#dadada guibg=#6c6c6c gui=NONE cterm=NONE
hi CursorLine guifg=NONE guibg=#6c6c6c gui=NONE cterm=NONE
hi CursorColumn guifg=NONE guibg=#6c6c6c gui=NONE cterm=NONE
hi CursorLineNr guifg=#ffff00 guibg=NONE gui=bold cterm=bold
hi ColorColumn guifg=NONE guibg=#444444 gui=NONE cterm=NONE
hi QuickFixLine guifg=#000000 guibg=#ff00ff gui=NONE cterm=NONE
hi VisualNOS guifg=#dadada guibg=#6c6c6c gui=NONE cterm=NONE
hi LineNr guifg=#ffff00 guibg=NONE gui=NONE cterm=NONE
hi FoldColumn guifg=#00afaf guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=#00afaf guibg=NONE gui=NONE cterm=NONE
hi Underlined guifg=#87afff guibg=NONE gui=underline cterm=underline
hi Error guifg=#ffffff guibg=#ff0000 gui=NONE cterm=NONE
hi ErrorMsg guifg=#ffffff guibg=#ff0000 gui=NONE cterm=NONE
hi ModeMsg guifg=#ffffff guibg=NONE gui=bold cterm=bold
hi WarningMsg guifg=#870000 guibg=NONE gui=bold cterm=bold
hi MoreMsg guifg=#5fd75f guibg=NONE gui=bold cterm=bold
hi Question guifg=#00ff00 guibg=NONE gui=bold cterm=bold
hi Todo guifg=#005fff guibg=#ffff00 gui=NONE cterm=NONE
hi MatchParen guifg=#303030 guibg=#afaf00 gui=NONE cterm=NONE
hi Search guifg=#000000 guibg=#ffff00 gui=NONE cterm=NONE
hi IncSearch guifg=#000000 guibg=#00ff00 gui=NONE cterm=NONE
hi WildMenu guifg=#000000 guibg=#ffff00 gui=NONE cterm=NONE
hi Cursor guifg=#000000 guibg=#dadada gui=NONE cterm=NONE
hi lCursor guifg=#000000 guibg=#ff0000 gui=NONE cterm=NONE
hi SpellBad guifg=#ff0000 guibg=NONE guisp=#ff0000 gui=undercurl cterm=underline
hi SpellCap guifg=#005fff guibg=NONE guisp=#005fff gui=undercurl cterm=underline
hi SpellLocal guifg=#ff00ff guibg=NONE guisp=#ff00ff gui=undercurl cterm=underline
hi SpellRare guifg=#00ff00 guibg=NONE guisp=#00ff00 gui=undercurl cterm=underline
hi Comment guifg=#00afaf guibg=NONE gui=NONE cterm=NONE
hi Identifier guifg=#ff00ff guibg=NONE gui=NONE cterm=NONE
hi Function guifg=#00ff00 guibg=NONE gui=NONE cterm=NONE
hi Statement guifg=#ffffff guibg=NONE gui=bold cterm=bold
hi Constant guifg=#00ffff guibg=NONE gui=NONE cterm=NONE
hi PreProc guifg=#ffff00 guibg=NONE gui=NONE cterm=NONE
hi Type guifg=#00ff00 guibg=NONE gui=bold cterm=bold
hi Special guifg=#ff0000 guibg=NONE gui=NONE cterm=NONE
hi Delimiter guifg=#ffff00 guibg=NONE gui=NONE cterm=NONE
hi Directory guifg=#00ffff guibg=NONE gui=NONE cterm=NONE
hi Conceal guifg=#6c6c6c guibg=NONE gui=NONE cterm=NONE
hi Ignore guifg=NONE guibg=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE
hi Title guifg=#ff00ff guibg=NONE gui=bold cterm=bold
hi! link Terminal Normal
hi! link LineNrAbove LineNr
hi! link LineNrBelow LineNr
hi! link CurSearch Search
hi! link CursorLineFold CursorLine
hi! link CursorLineSign CursorLine
hi DiffAdd guifg=#ffffff guibg=#5f875f gui=NONE cterm=NONE
hi DiffChange guifg=#ffffff guibg=#5f87af gui=NONE cterm=NONE
hi DiffText guifg=#000000 guibg=#c6c6c6 gui=NONE cterm=NONE
hi DiffDelete guifg=#ffffff guibg=#af5faf gui=NONE cterm=NONE

if s:t_Co >= 256
  hi Normal ctermfg=253 ctermbg=16 cterm=NONE
  hi EndOfBuffer ctermfg=238 ctermbg=16 cterm=NONE
  hi StatusLine ctermfg=16 ctermbg=253 cterm=bold
  hi StatusLineNC ctermfg=16 ctermbg=242 cterm=NONE
  hi StatusLineTerm ctermfg=16 ctermbg=46 cterm=bold
  hi StatusLineTermNC ctermfg=16 ctermbg=77 cterm=NONE
  hi VertSplit ctermfg=16 ctermbg=242 cterm=NONE
  hi Pmenu ctermfg=253 ctermbg=238 cterm=NONE
  hi PmenuSel ctermfg=16 ctermbg=226 cterm=NONE
  hi PmenuSbar ctermfg=NONE ctermbg=16 cterm=NONE
  hi PmenuThumb ctermfg=NONE ctermbg=242 cterm=NONE
  hi TabLine ctermfg=253 ctermbg=238 cterm=NONE
  hi TabLineFill ctermfg=NONE ctermbg=242 cterm=NONE
  hi TabLineSel ctermfg=231 ctermbg=16 cterm=bold
  hi ToolbarButton ctermfg=253 ctermbg=242 cterm=bold
  hi ToolbarLine ctermfg=NONE ctermbg=236 cterm=NONE
  hi NonText ctermfg=37 ctermbg=NONE cterm=NONE
  hi SpecialKey ctermfg=37 ctermbg=NONE cterm=NONE
  hi Folded ctermfg=37 ctermbg=236 cterm=NONE
  hi Visual ctermfg=253 ctermbg=242 cterm=NONE
  hi CursorLine ctermfg=NONE ctermbg=242 cterm=NONE
  hi CursorColumn ctermfg=NONE ctermbg=242 cterm=NONE
  hi CursorLineNr ctermfg=226 ctermbg=NONE cterm=bold
  hi ColorColumn ctermfg=NONE ctermbg=238 cterm=NONE
  hi QuickFixLine ctermfg=16 ctermbg=201 cterm=NONE
  hi VisualNOS ctermfg=253 ctermbg=242 cterm=NONE
  hi LineNr ctermfg=226 ctermbg=NONE cterm=NONE
  hi FoldColumn ctermfg=37 ctermbg=NONE cterm=NONE
  hi SignColumn ctermfg=37 ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=111 ctermbg=NONE cterm=underline
  hi Error ctermfg=231 ctermbg=196 cterm=NONE
  hi ErrorMsg ctermfg=231 ctermbg=196 cterm=NONE
  hi ModeMsg ctermfg=231 ctermbg=NONE cterm=bold
  hi WarningMsg ctermfg=88 ctermbg=NONE cterm=bold
  hi MoreMsg ctermfg=77 ctermbg=NONE cterm=bold
  hi Question ctermfg=46 ctermbg=NONE cterm=bold
  hi Todo ctermfg=27 ctermbg=226 cterm=NONE
  hi MatchParen ctermfg=236 ctermbg=142 cterm=NONE
  hi Search ctermfg=16 ctermbg=226 cterm=NONE
  hi IncSearch ctermfg=16 ctermbg=46 cterm=NONE
  hi WildMenu ctermfg=16 ctermbg=226 cterm=NONE
  hi Cursor ctermfg=16 ctermbg=253 cterm=NONE
  hi lCursor ctermfg=16 ctermbg=196 cterm=NONE
  hi SpellBad ctermfg=196 ctermbg=NONE cterm=underline
  hi SpellCap ctermfg=27 ctermbg=NONE cterm=underline
  hi SpellLocal ctermfg=201 ctermbg=NONE cterm=underline
  hi SpellRare ctermfg=46 ctermbg=NONE cterm=underline
  hi Comment ctermfg=37 ctermbg=NONE cterm=NONE
  hi Identifier ctermfg=201 ctermbg=NONE cterm=NONE
  hi Function ctermfg=46 ctermbg=NONE cterm=NONE
  hi Statement ctermfg=231 ctermbg=NONE cterm=bold
  hi Constant ctermfg=51 ctermbg=NONE cterm=NONE
  hi PreProc ctermfg=226 ctermbg=NONE cterm=NONE
  hi Type ctermfg=46 ctermbg=NONE cterm=bold
  hi Special ctermfg=196 ctermbg=NONE cterm=NONE
  hi Delimiter ctermfg=226 ctermbg=NONE cterm=NONE
  hi Directory ctermfg=51 ctermbg=NONE cterm=NONE
  hi Conceal ctermfg=242 ctermbg=NONE cterm=NONE
  hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
  hi Title ctermfg=201 ctermbg=NONE cterm=bold
  hi! link Terminal Normal
  hi! link LineNrAbove LineNr
  hi! link LineNrBelow LineNr
  hi! link CurSearch Search
  hi! link CursorLineFold CursorLine
  hi! link CursorLineSign CursorLine
  hi DiffAdd ctermfg=231 ctermbg=65 cterm=NONE
  hi DiffChange ctermfg=231 ctermbg=67 cterm=NONE
  hi DiffText ctermfg=16 ctermbg=251 cterm=NONE
  hi DiffDelete ctermfg=231 ctermbg=133 cterm=NONE
  unlet s:t_Co
  finish
endif

if s:t_Co >= 16
  hi Normal ctermfg=white ctermbg=black cterm=NONE
  hi EndOfBuffer ctermfg=darkgrey ctermbg=black cterm=NONE
  hi StatusLine ctermfg=black ctermbg=white cterm=bold
  hi StatusLineNC ctermfg=black ctermbg=grey cterm=NONE
  hi StatusLineTerm ctermfg=black ctermbg=green cterm=bold
  hi StatusLineTermNC ctermfg=black ctermbg=darkgreen cterm=NONE
  hi VertSplit ctermfg=black ctermbg=grey cterm=NONE
  hi Pmenu ctermfg=white ctermbg=darkgrey cterm=NONE
  hi PmenuSel ctermfg=black ctermbg=yellow cterm=NONE
  hi PmenuSbar ctermfg=NONE ctermbg=black cterm=NONE
  hi PmenuThumb ctermfg=NONE ctermbg=grey cterm=NONE
  hi TabLine ctermfg=white ctermbg=darkgrey cterm=NONE
  hi TabLineFill ctermfg=NONE ctermbg=grey cterm=NONE
  hi TabLineSel ctermfg=white ctermbg=black cterm=bold
  hi ToolbarButton ctermfg=white ctermbg=darkgrey cterm=NONE
  hi ToolbarLine ctermfg=NONE ctermbg=black cterm=NONE
  hi NonText ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi SpecialKey ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Folded ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Visual ctermfg=black ctermbg=grey cterm=NONE
  hi CursorLine ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorLineNr ctermfg=yellow ctermbg=NONE cterm=underline
  hi ColorColumn ctermfg=white ctermbg=darkgrey cterm=NONE
  hi QuickFixLine ctermfg=black ctermbg=magenta cterm=NONE
  hi VisualNOS ctermfg=white ctermbg=grey cterm=NONE
  hi LineNr ctermfg=yellow ctermbg=NONE cterm=NONE
  hi FoldColumn ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi SignColumn ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=darkblue ctermbg=NONE cterm=underline
  hi Error ctermfg=white ctermbg=red cterm=NONE
  hi ErrorMsg ctermfg=white ctermbg=red cterm=NONE
  hi ModeMsg ctermfg=white ctermbg=NONE cterm=bold
  hi WarningMsg ctermfg=darkred ctermbg=NONE cterm=bold
  hi MoreMsg ctermfg=darkgreen ctermbg=NONE cterm=bold
  hi Question ctermfg=green ctermbg=NONE cterm=bold
  hi Todo ctermfg=blue ctermbg=yellow cterm=NONE
  hi MatchParen ctermfg=black ctermbg=darkyellow cterm=NONE
  hi Search ctermfg=black ctermbg=yellow cterm=NONE
  hi IncSearch ctermfg=black ctermbg=green cterm=NONE
  hi WildMenu ctermfg=black ctermbg=yellow cterm=NONE
  hi Cursor ctermfg=black ctermbg=white cterm=NONE
  hi lCursor ctermfg=black ctermbg=red cterm=NONE
  hi SpellBad ctermfg=red ctermbg=NONE cterm=underline
  hi SpellCap ctermfg=blue ctermbg=NONE cterm=underline
  hi SpellLocal ctermfg=magenta ctermbg=NONE cterm=underline
  hi SpellRare ctermfg=green ctermbg=NONE cterm=underline
  hi Comment ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Identifier ctermfg=magenta ctermbg=NONE cterm=NONE
  hi Function ctermfg=green ctermbg=NONE cterm=NONE
  hi Statement ctermfg=white ctermbg=NONE cterm=bold
  hi Constant ctermfg=cyan ctermbg=NONE cterm=NONE
  hi PreProc ctermfg=yellow ctermbg=NONE cterm=NONE
  hi Type ctermfg=green ctermbg=NONE cterm=bold
  hi Special ctermfg=red ctermbg=NONE cterm=NONE
  hi Delimiter ctermfg=yellow ctermbg=NONE cterm=NONE
  hi Directory ctermfg=cyan ctermbg=NONE cterm=NONE
  hi Conceal ctermfg=grey ctermbg=NONE cterm=NONE
  hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
  hi Title ctermfg=magenta ctermbg=NONE cterm=bold
  hi! link Terminal Normal
  hi! link LineNrAbove LineNr
  hi! link LineNrBelow LineNr
  hi! link CurSearch Search
  hi! link CursorLineFold CursorLine
  hi! link CursorLineSign CursorLine
  hi DiffAdd ctermfg=white ctermbg=darkgreen cterm=NONE
  hi DiffChange ctermfg=white ctermbg=blue cterm=NONE
  hi DiffText ctermfg=black ctermbg=grey cterm=NONE
  hi DiffDelete ctermfg=white ctermbg=magenta cterm=NONE
  unlet s:t_Co
  finish
endif

if s:t_Co >= 8
  hi Normal ctermfg=grey ctermbg=black cterm=NONE
  hi EndOfBuffer ctermfg=grey ctermbg=black cterm=bold
  hi StatusLine ctermfg=grey ctermbg=black cterm=bold,reverse
  hi StatusLineNC ctermfg=grey ctermbg=black cterm=reverse
  hi StatusLineTerm ctermfg=darkgreen ctermbg=black cterm=bold,reverse
  hi StatusLineTermNC ctermfg=darkgreen ctermbg=black cterm=reverse
  hi VertSplit ctermfg=grey ctermbg=black cterm=reverse
  hi Pmenu ctermfg=black ctermbg=grey cterm=NONE
  hi PmenuSel ctermfg=black ctermbg=darkyellow cterm=NONE
  hi PmenuSbar ctermfg=NONE ctermbg=black cterm=NONE
  hi PmenuThumb ctermfg=black ctermbg=darkyellow cterm=NONE
  hi TabLine ctermfg=black ctermbg=grey cterm=NONE
  hi TabLineFill ctermfg=NONE ctermbg=grey cterm=NONE
  hi TabLineSel ctermfg=grey ctermbg=black cterm=NONE
  hi ToolbarButton ctermfg=grey ctermbg=black cterm=bold,reverse
  hi ToolbarLine ctermfg=NONE ctermbg=black cterm=NONE
  hi NonText ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi SpecialKey ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Folded ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Visual ctermfg=NONE ctermbg=NONE cterm=reverse
  hi CursorLine ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorLineNr ctermfg=darkyellow ctermbg=NONE cterm=bold
  hi ColorColumn ctermfg=black ctermbg=darkyellow cterm=NONE
  hi QuickFixLine ctermfg=black ctermbg=darkmagenta cterm=NONE
  hi VisualNOS ctermfg=black ctermbg=grey cterm=NONE
  hi LineNr ctermfg=darkyellow ctermbg=NONE cterm=NONE
  hi FoldColumn ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi SignColumn ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
  hi Error ctermfg=grey ctermbg=darkred cterm=NONE
  hi ErrorMsg ctermfg=grey ctermbg=darkred cterm=NONE
  hi ModeMsg ctermfg=grey ctermbg=NONE cterm=NONE
  hi WarningMsg ctermfg=darkred ctermbg=NONE cterm=NONE
  hi MoreMsg ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Question ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Todo ctermfg=darkblue ctermbg=darkyellow cterm=NONE
  hi MatchParen ctermfg=black ctermbg=darkyellow cterm=NONE
  hi Search ctermfg=black ctermbg=darkyellow cterm=NONE
  hi IncSearch ctermfg=black ctermbg=darkgreen cterm=NONE
  hi WildMenu ctermfg=black ctermbg=darkyellow cterm=NONE
  hi SpellBad ctermfg=darkred ctermbg=darkyellow cterm=reverse
  hi SpellCap ctermfg=darkblue ctermbg=darkyellow cterm=reverse
  hi SpellLocal ctermfg=darkmagenta ctermbg=darkyellow cterm=reverse
  hi SpellRare ctermfg=darkgreen ctermbg=NONE cterm=reverse
  hi Comment ctermfg=darkcyan ctermbg=NONE cterm=bold
  hi Identifier ctermfg=magenta ctermbg=NONE cterm=NONE
  hi Function ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Statement ctermfg=grey ctermbg=NONE cterm=bold
  hi Constant ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi PreProc ctermfg=darkyellow ctermbg=NONE cterm=NONE
  hi Type ctermfg=darkgreen ctermbg=NONE cterm=bold
  hi Special ctermfg=darkred ctermbg=NONE cterm=NONE
  hi Delimiter ctermfg=darkyellow ctermbg=NONE cterm=NONE
  hi Directory ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Conceal ctermfg=grey ctermbg=NONE cterm=NONE
  hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
  hi Title ctermfg=darkmagenta ctermbg=NONE cterm=bold
  hi DiffAdd ctermfg=white ctermbg=darkgreen cterm=NONE
  hi DiffChange ctermfg=white ctermbg=darkblue cterm=NONE
  hi DiffText ctermfg=black ctermbg=grey cterm=NONE
  hi DiffDelete ctermfg=white ctermbg=darkmagenta cterm=NONE
  unlet s:t_Co
  finish
endif

if s:t_Co >= 0
  hi Normal term=NONE
  hi ColorColumn term=reverse
  hi Conceal term=NONE
  hi Cursor term=reverse
  hi CursorColumn term=NONE
  hi CursorLine term=underline
  hi CursorLineNr term=bold
  hi DiffAdd term=reverse
  hi DiffChange term=NONE
  hi DiffDelete term=reverse
  hi DiffText term=reverse
  hi Directory term=NONE
  hi EndOfBuffer term=NONE
  hi ErrorMsg term=bold,reverse
  hi FoldColumn term=NONE
  hi Folded term=NONE
  hi IncSearch term=bold,reverse,underline
  hi LineNr term=NONE
  hi MatchParen term=bold,underline
  hi ModeMsg term=bold
  hi MoreMsg term=NONE
  hi NonText term=NONE
  hi Pmenu term=reverse
  hi PmenuSbar term=reverse
  hi PmenuSel term=bold
  hi PmenuThumb term=NONE
  hi Question term=standout
  hi Search term=reverse
  hi SignColumn term=reverse
  hi SpecialKey term=bold
  hi SpellBad term=underline
  hi SpellCap term=underline
  hi SpellLocal term=underline
  hi SpellRare term=underline
  hi StatusLine term=bold,reverse
  hi StatusLineNC term=bold,underline
  hi TabLine term=bold,underline
  hi TabLineFill term=NONE
  hi Terminal term=NONE
  hi TabLineSel term=bold,reverse
  hi Title term=NONE
  hi VertSplit term=NONE
  hi Visual term=reverse
  hi VisualNOS term=NONE
  hi WarningMsg term=standout
  hi WildMenu term=bold
  hi CursorIM term=NONE
  hi ToolbarLine term=reverse
  hi ToolbarButton term=bold,reverse
  hi CurSearch term=reverse
  hi CursorLineFold term=underline
  hi CursorLineSign term=underline
  hi Comment term=bold
  hi Constant term=NONE
  hi Error term=bold,reverse
  hi Identifier term=NONE
  hi Ignore term=NONE
  hi PreProc term=NONE
  hi Special term=NONE
  hi Statement term=NONE
  hi Todo term=bold,reverse
  hi Type term=NONE
  hi Underlined term=underline
  unlet s:t_Co
  finish
endif

" Background: dark
" Color: foreground  #dadada        253            white
" Color: background  #000000        16             black
" Color: color00     #303030        236            black
" Color: color08     #444444        238            darkgrey
" Color: color01     #870000        88             darkred
" Color: color09     #FF0000        196            red
" Color: color02     #5FD75F        77             darkgreen
" Color: color10     #00FF00        46             green
" Color: color03     #AFAF00        142            darkyellow
" Color: color11     #FFFF00        226            yellow
" Color: color04     #87AFFF        111            darkblue
" Color: color12     #005FFF        27             blue
" Color: color05     #AF00AF        127            darkmagenta
" Color: color13     #FF00FF        201            magenta
" Color: color06     #00AFAF        37             darkcyan
" Color: color14     #00FFFF        51             cyan
" Color: color07     #6C6C6C        242            grey
" Color: color15     #FFFFFF        231            white
" Term colors: color00 color01 color02 color03 color04 color05 color06 color07
" Term colors: color08 color09 color10 color11 color12 color13 color14 color15
" Color: bgDiffA     #5F875F        65             darkgreen
" Color: bgDiffC     #5F87AF        67             blue
" Color: bgDiffD     #AF5FAF        133            magenta
" Color: bgDiffT     #C6C6C6        251            grey
" Color: fgDiffW     #FFFFFF        231            white
" Color: fgDiffB     #000000        16             black
" Color: bgDiffC8    #5F87AF        67             darkblue
" Color: bgDiffD8    #AF5FAF        133            darkmagenta
" vim: et ts=2 sw=2
