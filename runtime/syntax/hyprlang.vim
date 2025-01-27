" Vim syntax file
" Language:     hyprlang
" Maintainer:   Luca Saccarola <github.e41mv@aleeas.com>
" Last Change:  2024 nov 15

if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "hyprlang"

syn case ignore

syn match hyprCommand '^\s*\zs\S\+\ze\s*=' contains=hyprVariable
syn match hyprValue '=\s*\zs.\+\ze$' contains=hyprNumber,hyprFloat,hyprBoolean,hyprString,hyprColor,hyprModifier,hyprVariable,hyprComment

syn match hyprVariable '\$\w\+' contained

" Category
syn region hyprCategory matchgroup=hyprCategoryD start='^\s*\k\+\s*{' end='^\s*}' contains=hyprCommand,hyprValue,hyprComment,hyprCategory,hyprCategoryD

" Variables Types
syn match   hyprNumber  '\%[-+]\<\d\+\>\%[%]' contained
syn match   hyprFloat   '\%[-+]\<\d\+\.\d\+\>\%[%]' contained
syn match   hyprString  '["\'].*["\']' contained
syn match   hyprColor   'rgb(\(\w\|\d\)\{6})' contained
syn match   hyprColor   'rgba(\(\w\|\d\)\{8})' contained
syn match   hyprColor   '0x\(\w\|\d\)\{8}' contained
syn keyword hyprBoolean true false yes no on off contained

"               Super         Shift         Alt         Ctrl        Control
syn keyword hyprModifier contained
      \ super                 supershift    superalt    superctrl   supercontrol
      \                       super_shift   super_alt   super_ctrl  super_control
      \ shift   shiftsuper                  shiftalt    shiftctrl   shiftcontrol
      \         shift_super                 shift_alt   shift_ctrl  shift_control
      \ alt     altsuper      altshift                  altctrl     altcontrol
      \         alt_super     alt_shift                 alt_ctrl    alt_control
      \ ctrl    ctrlsuper     ctrlshift     ctrlalt                 ctrlcontrol
      \         ctrl_super    ctrl_shift    ctrl_alt                ctrl_control
      \ control controlsuper  controlshift  controlalt  controlctrl
      \         control_super control_shift control_alt control_ctrl

" Comments
syn match hyprComment '#.*$'

" Link to default groups
hi def link hyprVariable  Identifier
hi def link hyprCategoryD Special
hi def link hyprComment   Comment
hi def link hyprNumber    Constant
hi def link hyprModifier  Constant
hi def link hyprFloat     hyprNumber
hi def link hyprBoolean   Boolean
hi def link hyprString    String
hi def link hyprColor     Structure
hi def link hyprCommand   Keyword

" vim: ts=8 sts=2 sw=2 et
