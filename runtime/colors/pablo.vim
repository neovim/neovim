" Name:         pablo
" Author:       Ron Aaron <ron@ronware.org>
" Maintainer:   Original maintainerRon Aaron <ron@ronware.org>
" Website:      https://github.com/vim/colorschemes
" License:      Same as Vim
" Last Updated: Wed 10 Jul 2024 17:37:50

" Generated by Colortemplate v2.2.3

set background=dark

" hi clear
source $VIMRUNTIME/colors/vim.lua " Nvim: revert to Vim default color scheme
let g:colors_name = 'pablo'

let s:t_Co = &t_Co

if (has('termguicolors') && &termguicolors) || has('gui_running')
  let g:terminal_ansi_colors = ['#000000', '#cd0000', '#00cd00', '#cdcd00', '#0000ee', '#cd00cd', '#00cdcd', '#e5e5e5', '#7f7f7f', '#ff0000', '#00ff00', '#ffff00', '#5c5cff', '#ff00ff', '#00ffff', '#ffffff']
  " Nvim uses g:terminal_color_{0-15} instead
  for i in range(g:terminal_ansi_colors->len())
    let g:terminal_color_{i} = g:terminal_ansi_colors[i]
  endfor
endif
hi! link Terminal Normal
hi! link StatusLineTerm StatusLine
hi! link StatusLineTermNC StatusLineNC
hi! link CurSearch Search
hi! link CursorLineFold CursorLine
hi! link CursorLineSign CursorLine
hi! link MessageWindow Pmenu
hi! link PopupNotification Todo
hi Normal guifg=#ffffff guibg=#000000 gui=NONE cterm=NONE
hi Comment guifg=#808080 guibg=NONE gui=NONE cterm=NONE
hi Constant guifg=#00ffff guibg=NONE gui=NONE cterm=NONE
hi Identifier guifg=#00c0c0 guibg=NONE gui=NONE cterm=NONE
hi Statement guifg=#c0c000 guibg=NONE gui=bold cterm=bold
hi PreProc guifg=#00ff00 guibg=NONE gui=NONE cterm=NONE
hi Type guifg=#00c000 guibg=NONE gui=NONE cterm=NONE
hi Special guifg=#0000ff guibg=NONE gui=NONE cterm=NONE
hi Underlined guifg=#80a0ff guibg=NONE gui=underline cterm=underline
hi Ignore guifg=#000000 guibg=#000000 gui=NONE cterm=NONE
hi Error guifg=#ffffff guibg=#ff0000 gui=NONE cterm=NONE
hi Todo guifg=#000000 guibg=#c0c000 gui=NONE cterm=NONE
hi Conceal guifg=#666666 guibg=NONE gui=NONE cterm=NONE
hi Cursor guifg=#000000 guibg=#ffffff gui=NONE cterm=NONE
hi lCursor guifg=#000000 guibg=#ffffff gui=NONE cterm=NONE
hi CursorIM guifg=NONE guibg=fg gui=NONE cterm=NONE
hi Title guifg=#ff00ff guibg=NONE gui=bold cterm=bold
hi Directory guifg=#00c000 guibg=NONE gui=NONE cterm=NONE
hi Search guifg=#000000 guibg=#c0c000 gui=NONE cterm=NONE
hi IncSearch guifg=#ffffff guibg=NONE gui=reverse cterm=reverse
hi NonText guifg=#0000ff guibg=NONE gui=bold cterm=bold
hi EndOfBuffer guifg=#0000ff guibg=NONE gui=bold cterm=bold
hi ErrorMsg guifg=#ffffff guibg=#cd0000 gui=NONE cterm=NONE
hi WarningMsg guifg=#ff0000 guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=#00ffff guibg=#a9a9a9 gui=NONE cterm=NONE
hi ColorColumn guifg=NONE guibg=#4d4d4d gui=NONE cterm=NONE
hi FoldColumn guifg=#7f7f7f guibg=#303030 gui=NONE cterm=NONE
hi Folded guifg=#7f7f7f guibg=#303030 gui=NONE cterm=NONE
hi CursorColumn guifg=NONE guibg=#3a3a3a gui=NONE cterm=NONE
hi CursorLine guifg=NONE guibg=#3a3a3a gui=NONE cterm=NONE
hi CursorLineNr guifg=#ffff00 guibg=#3a3a3a gui=bold cterm=bold
hi Visual guifg=#00008b guibg=#a9a9a9 gui=NONE cterm=NONE
hi VisualNOS guifg=NONE guibg=#000000 gui=bold,underline cterm=underline
hi LineNr guifg=#7f7f7f guibg=NONE gui=NONE cterm=NONE
hi! link LineNrAbove LineNr
hi! link LineNrBelow LineNr
hi MatchParen guifg=NONE guibg=#008b8b gui=NONE cterm=NONE
hi ModeMsg guifg=NONE guibg=NONE gui=bold ctermfg=NONE ctermbg=NONE cterm=bold
hi MoreMsg guifg=#5c5cff guibg=NONE gui=bold cterm=bold
hi Question guifg=#00ff00 guibg=NONE gui=bold cterm=bold
hi SpecialKey guifg=#00ffff guibg=NONE gui=NONE cterm=NONE
hi WildMenu guifg=#000000 guibg=#ffff00 gui=NONE cterm=NONE
hi QuickFixLine guifg=#000000 guibg=#00cdcd gui=NONE cterm=NONE
hi SpellBad guifg=#ff0000 guibg=NONE guisp=#ff0000 gui=undercurl cterm=underline
hi SpellCap guifg=#5c5cff guibg=NONE guisp=#5c5cff gui=undercurl cterm=underline
hi SpellLocal guifg=#ff00ff guibg=NONE guisp=#ff00ff gui=undercurl cterm=underline
hi SpellRare guifg=#ffff00 guibg=NONE guisp=#ffff00 gui=undercurl cterm=underline
hi StatusLine guifg=#ffff00 guibg=#0000ee gui=NONE cterm=NONE
hi StatusLineNC guifg=#000000 guibg=#ffffff gui=NONE cterm=NONE
hi VertSplit guifg=#000000 guibg=#ffffff gui=NONE cterm=NONE
hi TabLine guifg=#ffffff guibg=#7f7f7f gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=#000000 gui=reverse cterm=reverse
hi TabLineSel guifg=#ffffff guibg=#000000 gui=bold cterm=bold
hi ToolbarLine guifg=NONE guibg=#000000 gui=NONE cterm=NONE
hi ToolbarButton guifg=#000000 guibg=#e5e5e5 gui=bold cterm=bold
hi Pmenu guifg=fg guibg=#303030 gui=NONE cterm=NONE
hi PmenuSbar guifg=NONE guibg=NONE gui=NONE ctermfg=NONE ctermbg=NONE cterm=NONE
hi PmenuSel guifg=#000000 guibg=#e5e5e5 gui=NONE cterm=NONE
hi PmenuThumb guifg=NONE guibg=#ffffff gui=NONE cterm=NONE
hi PmenuMatch guifg=#ff00ff guibg=#303030 gui=NONE cterm=NONE
hi PmenuMatchSel guifg=#ff00ff guibg=#e5e5e5 gui=NONE cterm=NONE
hi DiffAdd guifg=#ffffff guibg=#5f875f gui=NONE cterm=NONE
hi DiffChange guifg=#ffffff guibg=#5f87af gui=NONE cterm=NONE
hi DiffText guifg=#000000 guibg=#c6c6c6 gui=NONE cterm=NONE
hi DiffDelete guifg=#ffffff guibg=#af5faf gui=NONE cterm=NONE

if s:t_Co >= 256
  hi! link Terminal Normal
  hi! link StatusLineTerm StatusLine
  hi! link StatusLineTermNC StatusLineNC
  hi! link CurSearch Search
  hi! link CursorLineFold CursorLine
  hi! link CursorLineSign CursorLine
  hi! link MessageWindow Pmenu
  hi! link PopupNotification Todo
  hi Normal ctermfg=231 ctermbg=16 cterm=NONE
  hi Comment ctermfg=244 ctermbg=NONE cterm=NONE
  hi Constant ctermfg=51 ctermbg=NONE cterm=NONE
  hi Identifier ctermfg=37 ctermbg=NONE cterm=NONE
  hi Statement ctermfg=142 ctermbg=NONE cterm=bold
  hi PreProc ctermfg=46 ctermbg=NONE cterm=NONE
  hi Type ctermfg=34 ctermbg=NONE cterm=NONE
  hi Special ctermfg=21 ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=111 ctermbg=NONE cterm=underline
  hi Ignore ctermfg=16 ctermbg=16 cterm=NONE
  hi Error ctermfg=231 ctermbg=196 cterm=NONE
  hi Todo ctermfg=16 ctermbg=142 cterm=NONE
  hi Conceal ctermfg=241 ctermbg=NONE cterm=NONE
  hi Cursor ctermfg=16 ctermbg=231 cterm=NONE
  hi lCursor ctermfg=16 ctermbg=231 cterm=NONE
  hi CursorIM ctermfg=NONE ctermbg=fg cterm=NONE
  hi Title ctermfg=225 ctermbg=NONE cterm=bold
  hi Directory ctermfg=34 ctermbg=NONE cterm=NONE
  hi Search ctermfg=16 ctermbg=142 cterm=NONE
  hi IncSearch ctermfg=231 ctermbg=NONE cterm=reverse
  hi NonText ctermfg=63 ctermbg=NONE cterm=bold
  hi EndOfBuffer ctermfg=63 ctermbg=NONE cterm=bold
  hi ErrorMsg ctermfg=231 ctermbg=160 cterm=NONE
  hi WarningMsg ctermfg=196 ctermbg=NONE cterm=NONE
  hi SignColumn ctermfg=51 ctermbg=248 cterm=NONE
  hi ColorColumn ctermfg=NONE ctermbg=239 cterm=NONE
  hi FoldColumn ctermfg=102 ctermbg=236 cterm=NONE
  hi Folded ctermfg=102 ctermbg=236 cterm=NONE
  hi CursorColumn ctermfg=NONE ctermbg=237 cterm=NONE
  hi CursorLine ctermfg=NONE ctermbg=237 cterm=NONE
  hi CursorLineNr ctermfg=226 ctermbg=237 cterm=bold
  hi Visual ctermfg=20 ctermbg=248 cterm=NONE
  hi VisualNOS ctermfg=NONE ctermbg=16 cterm=underline
  hi LineNr ctermfg=102 ctermbg=NONE cterm=NONE
  hi! link LineNrAbove LineNr
  hi! link LineNrBelow LineNr
  hi MatchParen ctermfg=NONE ctermbg=44 cterm=NONE
  hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
  hi MoreMsg ctermfg=63 ctermbg=NONE cterm=bold
  hi Question ctermfg=121 ctermbg=NONE cterm=bold
  hi SpecialKey ctermfg=81 ctermbg=NONE cterm=NONE
  hi WildMenu ctermfg=16 ctermbg=226 cterm=NONE
  hi QuickFixLine ctermfg=16 ctermbg=44 cterm=NONE
  hi SpellBad ctermfg=196 ctermbg=NONE cterm=underline
  hi SpellCap ctermfg=63 ctermbg=NONE cterm=underline
  hi SpellLocal ctermfg=201 ctermbg=NONE cterm=underline
  hi SpellRare ctermfg=226 ctermbg=NONE cterm=underline
  hi StatusLine ctermfg=226 ctermbg=20 cterm=NONE
  hi StatusLineNC ctermfg=16 ctermbg=231 cterm=NONE
  hi VertSplit ctermfg=16 ctermbg=231 cterm=NONE
  hi TabLine ctermfg=231 ctermbg=102 cterm=NONE
  hi TabLineFill ctermfg=NONE ctermbg=16 cterm=reverse
  hi TabLineSel ctermfg=231 ctermbg=16 cterm=bold
  hi ToolbarLine ctermfg=NONE ctermbg=16 cterm=NONE
  hi ToolbarButton ctermfg=16 ctermbg=254 cterm=bold
  hi Pmenu ctermfg=fg ctermbg=236 cterm=NONE
  hi PmenuSbar ctermfg=NONE ctermbg=NONE cterm=NONE
  hi PmenuSel ctermfg=16 ctermbg=254 cterm=NONE
  hi PmenuThumb ctermfg=NONE ctermbg=231 cterm=NONE
  hi PmenuMatch ctermfg=201 ctermbg=236 cterm=NONE
  hi PmenuMatchSel ctermfg=201 ctermbg=254 cterm=NONE
  hi DiffAdd ctermfg=231 ctermbg=65 cterm=NONE
  hi DiffChange ctermfg=231 ctermbg=67 cterm=NONE
  hi DiffText ctermfg=16 ctermbg=251 cterm=NONE
  hi DiffDelete ctermfg=231 ctermbg=133 cterm=NONE
  unlet s:t_Co
  finish
endif

if s:t_Co >= 16
  hi Normal ctermfg=white ctermbg=black cterm=NONE
  hi Comment ctermfg=darkgrey ctermbg=NONE cterm=NONE
  hi Constant ctermfg=cyan ctermbg=NONE cterm=NONE
  hi Identifier ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Statement ctermfg=darkyellow ctermbg=NONE cterm=bold
  hi PreProc ctermfg=green ctermbg=NONE cterm=NONE
  hi Type ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Special ctermfg=blue ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=darkgreen ctermbg=NONE cterm=underline
  hi Ignore ctermfg=black ctermbg=black cterm=NONE
  hi Error ctermfg=white ctermbg=red cterm=NONE
  hi Todo ctermfg=black ctermbg=darkyellow cterm=NONE
  hi Conceal ctermfg=darkgrey ctermbg=NONE cterm=NONE
  hi Cursor ctermfg=black ctermbg=white cterm=NONE
  hi lCursor ctermfg=black ctermbg=white cterm=NONE
  hi CursorIM ctermfg=NONE ctermbg=fg cterm=NONE
  hi Title ctermfg=magenta ctermbg=NONE cterm=bold
  hi Directory ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Search ctermfg=black ctermbg=darkyellow cterm=NONE
  hi IncSearch ctermfg=white ctermbg=NONE cterm=reverse
  hi NonText ctermfg=blue ctermbg=NONE cterm=bold
  hi EndOfBuffer ctermfg=blue ctermbg=NONE cterm=bold
  hi ErrorMsg ctermfg=white ctermbg=darkred cterm=NONE
  hi WarningMsg ctermfg=red ctermbg=NONE cterm=NONE
  hi SignColumn ctermfg=cyan ctermbg=black cterm=NONE
  hi ColorColumn ctermfg=white ctermbg=darkgrey cterm=NONE
  hi FoldColumn ctermfg=NONE ctermbg=NONE cterm=NONE
  hi Folded ctermfg=blue ctermbg=NONE cterm=NONE
  hi CursorColumn ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorLine ctermfg=NONE ctermbg=NONE cterm=underline
  hi CursorLineNr ctermfg=yellow ctermbg=NONE cterm=underline
  hi Visual ctermfg=darkblue ctermbg=grey cterm=NONE
  hi VisualNOS ctermfg=NONE ctermbg=black cterm=underline
  hi LineNr ctermfg=darkgrey ctermbg=NONE cterm=NONE
  hi! link LineNrAbove LineNr
  hi! link LineNrBelow LineNr
  hi MatchParen ctermfg=NONE ctermbg=darkcyan cterm=NONE
  hi ModeMsg ctermfg=NONE ctermbg=NONE cterm=bold
  hi MoreMsg ctermfg=blue ctermbg=NONE cterm=bold
  hi Question ctermfg=green ctermbg=NONE cterm=bold
  hi SpecialKey ctermfg=cyan ctermbg=NONE cterm=NONE
  hi WildMenu ctermfg=black ctermbg=yellow cterm=NONE
  hi QuickFixLine ctermfg=black ctermbg=darkcyan cterm=NONE
  hi SpellBad ctermfg=red ctermbg=NONE cterm=underline
  hi SpellCap ctermfg=blue ctermbg=NONE cterm=underline
  hi SpellLocal ctermfg=magenta ctermbg=NONE cterm=underline
  hi SpellRare ctermfg=yellow ctermbg=NONE cterm=underline
  hi StatusLine ctermfg=yellow ctermbg=darkblue cterm=NONE
  hi StatusLineNC ctermfg=black ctermbg=white cterm=NONE
  hi VertSplit ctermfg=black ctermbg=white cterm=NONE
  hi TabLine ctermfg=white ctermbg=darkgrey cterm=NONE
  hi TabLineFill ctermfg=NONE ctermbg=black cterm=reverse
  hi TabLineSel ctermfg=white ctermbg=black cterm=bold
  hi ToolbarLine ctermfg=NONE ctermbg=black cterm=NONE
  hi ToolbarButton ctermfg=black ctermbg=grey cterm=bold
  hi Pmenu ctermfg=fg ctermbg=darkgrey cterm=NONE
  hi PmenuSbar ctermfg=NONE ctermbg=NONE cterm=NONE
  hi PmenuSel ctermfg=black ctermbg=grey cterm=NONE
  hi PmenuThumb ctermfg=NONE ctermbg=white cterm=NONE
  hi PmenuMatch ctermfg=magenta ctermbg=darkgrey cterm=NONE
  hi PmenuMatchSel ctermfg=magenta ctermbg=grey cterm=NONE
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
  hi StatusLine ctermfg=darkblue ctermbg=grey cterm=reverse
  hi StatusLineNC ctermfg=grey ctermbg=black cterm=reverse
  hi StatusLineTerm ctermfg=darkblue ctermbg=grey cterm=reverse
  hi StatusLineTermNC ctermfg=grey ctermbg=black cterm=reverse
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
  hi Todo ctermfg=black ctermbg=darkyellow cterm=NONE
  hi MatchParen ctermfg=black ctermbg=darkcyan cterm=NONE
  hi Search ctermfg=black ctermbg=darkyellow cterm=NONE
  hi IncSearch ctermfg=black ctermbg=darkgreen cterm=NONE
  hi WildMenu ctermfg=black ctermbg=darkyellow cterm=NONE
  hi SpellBad ctermfg=darkred ctermbg=darkyellow cterm=reverse
  hi SpellCap ctermfg=darkblue ctermbg=darkyellow cterm=reverse
  hi SpellLocal ctermfg=darkmagenta ctermbg=darkyellow cterm=reverse
  hi SpellRare ctermfg=darkgreen ctermbg=NONE cterm=reverse
  hi Comment ctermfg=grey ctermbg=NONE cterm=bold
  hi Constant ctermfg=darkcyan ctermbg=NONE cterm=bold
  hi Identifier ctermfg=darkcyan ctermbg=NONE cterm=NONE
  hi Statement ctermfg=darkyellow ctermbg=NONE cterm=bold
  hi PreProc ctermfg=darkgreen ctermbg=NONE cterm=NONE
  hi Type ctermfg=darkgreen ctermbg=NONE cterm=bold
  hi Special ctermfg=darkblue ctermbg=NONE cterm=NONE
  hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline
  hi Ignore ctermfg=NONE ctermbg=NONE cterm=NONE
  hi Error ctermfg=grey ctermbg=darkred cterm=NONE
  hi Todo ctermfg=black ctermbg=darkyellow cterm=NONE
  hi Directory ctermfg=darkgreen ctermbg=NONE cterm=bold
  hi Conceal ctermfg=grey ctermbg=NONE cterm=NONE
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
" Color: color00        #000000     16             black
" Color: color08        #7f7f7f     102            darkgrey
" Color: color01        #cd0000     160            darkred
" Color: color09        #ff0000     196            red
" Color: color02        #00cd00     40             darkgreen
" Color: color10        #00ff00     46             green
" Color: color03        #cdcd00     184            darkyellow
" Color: color11        #ffff00     226            yellow
" Color: color04        #0000ee     20             darkblue
" Color: color12        #5c5cff     63             blue
" Color: color05        #cd00cd     164            darkmagenta
" Color: color13        #ff00ff     201            magenta
" Color: color06        #00cdcd     44             darkcyan
" Color: color14        #00ffff     51             cyan
" Color: color07        #e5e5e5     254            grey
" Color: color15        #ffffff     231            white
" Term colors: color00 color01 color02 color03 color04 color05 color06 color07
" Term colors: color08 color09 color10 color11 color12 color13 color14 color15
" Color: rgbGrey30      #4d4d4d     239            darkgrey
" Color: rgbGrey40      #666666     241            darkgrey
" Color: rgbDarkGrey    #a9a9a9     248            grey
" Color: rgbDarkBlue    #00008b     20             darkblue
" Color: rgbDarkMagenta #8b008b     164            darkmagenta
" Color: rgbBlue        #0000ff     63             blue
" Color: rgbDarkCyan    #008b8b     44             darkcyan
" Color: rgbSeaGreen    #2e8b57     121            darkgreen
" Color: rgbGrey        #bebebe     248            grey
" Color: Question       #00ff00     121            green
" Color: SignColumn     #a9a9a9     248            black
" Color: SpecialKey     #00ffff     81             cyan
" Color: StatusLineTerm #90ee90     121            darkgreen
" Color: Title          #ff00ff     225            magenta
" Color: WarningMsg     #ff0000     196            red
" Color: ToolbarLine    #7f7f7f     242            darkgrey
" Color: ToolbarButton  #d3d3d3     254            grey
" Color: Underlined     #80a0ff     111            darkgreen
" Color: Comment        #808080     244            darkgrey
" Color: Constant       #00ffff     51             cyan
" Color: Special        #0000ff     21             blue
" Color: Identifier     #00c0c0     37             darkcyan
" Color: Search         #c0c000     142            darkyellow
" Color: Statement      #c0c000     142            darkyellow
" Color: Todo           #c0c000     142            darkyellow
" Color: PreProc        #00ff00     46             green
" Color: Type           #00c000     34             darkgreen
" Color: Directory      #00c000     34             darkgreen
" Color: Pmenu          #303030     236            darkgrey
" Color: Folded         #303030     236            darkgrey
" Color: Cursorline     #3a3a3a     237            darkgrey
" Color: bgDiffA     #5F875F        65             darkgreen
" Color: bgDiffC     #5F87AF        67             blue
" Color: bgDiffD     #AF5FAF        133            magenta
" Color: bgDiffT     #C6C6C6        251            grey
" Color: fgDiffW     #FFFFFF        231            white
" Color: fgDiffB     #000000        16             black
" Color: bgDiffC8    #5F87AF        67             darkblue
" Color: bgDiffD8    #AF5FAF        133            darkmagenta
" vim: et ts=8 sw=2 sts=2
