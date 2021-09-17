" :help vim.diagnostic

hi default DiagnosticError ctermfg=1 guifg=Red
hi default DiagnosticWarn ctermfg=3 guifg=Orange
hi default DiagnosticInfo ctermfg=4 guifg=LightBlue
hi default DiagnosticHint ctermfg=7 guifg=LightGrey

hi default DiagnosticUnderlineError cterm=underline gui=underline guisp=Red
hi default DiagnosticUnderlineWarn cterm=underline gui=underline guisp=Orange
hi default DiagnosticUnderlineInfo cterm=underline gui=underline guisp=LightBlue
hi default DiagnosticUnderlineHint cterm=underline gui=underline guisp=LightGrey

hi default link DiagnosticVirtualTextError DiagnosticError
hi default link DiagnosticVirtualTextWarn DiagnosticWarn
hi default link DiagnosticVirtualTextInfo DiagnosticInfo
hi default link DiagnosticVirtualTextHint DiagnosticHint

hi default link DiagnosticFloatingError DiagnosticError
hi default link DiagnosticFloatingWarn DiagnosticWarn
hi default link DiagnosticFloatingInfo DiagnosticInfo
hi default link DiagnosticFloatingHint DiagnosticHint

hi default link DiagnosticSignError DiagnosticError
hi default link DiagnosticSignWarn DiagnosticWarn
hi default link DiagnosticSignInfo DiagnosticInfo
hi default link DiagnosticSignHint DiagnosticHint
