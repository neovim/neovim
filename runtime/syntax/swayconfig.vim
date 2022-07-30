" Vim syntax file
" Language: sway window manager config
" Original Author: James Eapen <james.eapen@vai.org>
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 0.11.0
" Last Change: 2022 Jun 07

" References:
" http://i3wm.org/docs/userguide.html#configuring
" https://github.com/swaywm/sway/blob/b69d637f7a34e239e48a4267ae94a5e7087b5834/sway/sway.5.scd
" http://vimdoc.sourceforge.net/htmldoc/syntax.html
"
"
" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

runtime! syntax/i3config.vim

scriptencoding utf-8

" Error
"syn match swayConfigError /.*/

" Group mode/bar
syn keyword swayConfigBlockKeyword set input contained
syn region swayConfigBlock start=+.*s\?{$+ end=+^}$+ contains=i3ConfigBlockKeyword,swayConfigBlockKeyword,i3ConfigString,i3ConfigBind,i3ConfigComment,i3ConfigFont,i3ConfigFocusWrappingType,i3ConfigColor,i3ConfigVariable transparent keepend extend

" binding
syn keyword swayConfigBindKeyword bindswitch bindgesture contained
syn match swayConfigBind /^\s*\(bindswitch\)\s\+.*$/ contains=i3ConfigVariable,i3ConfigBindKeyword,swayConfigBindKeyword,i3ConfigVariableAndModifier,i3ConfigNumber,i3ConfigUnit,i3ConfigUnitOr,i3ConfigBindArgument,i3ConfigModifier,i3ConfigAction,i3ConfigString,i3ConfigGapStyleKeyword,i3ConfigBorderStyleKeyword

" bindgestures
syn keyword swayConfigBindGestureCommand swipe pinch hold contained
syn keyword swayConfigBindGestureDirection up down left right next prev contained
syn keyword swayConfigBindGesturePinchDirection inward outward clockwise counterclockwise contained
syn match swayConfigBindGestureHold /^\s*\(bindgesture\)\s\+hold\(:[1-5]\)\?\s\+.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,i3ConfigWorkspaceKeyword,i3ConfigAction
syn match swayConfigBindGestureSwipe /^\s*\(bindgesture\)\s\+swipe\(:[1-5]\)\?:\(up\|down\|left\|right\)\s\+.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,i3ConfigWorkspaceKeyword,i3ConfigAction
syn match swayConfigBindGesturePinch /^\s*\(bindgesture\)\s\+\(pinch\):.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,swayConfigBindGesturePinchDirection,i3ConfigWorkspaceKeyword,i3ConfigAction

" floating
syn keyword swayConfigFloatingKeyword floating contained
syn match swayConfigFloating /^\s*floating\s\+\(enable\|disable\|toggle\)\s*$/ contains=swayConfigFloatingKeyword

syn clear i3ConfigFloatingModifier
syn keyword swayConfigFloatingModifier floating_modifier contained
syn match swayConfigFloatingMouseAction /^\s\?.*floating_modifier\s.*\(normal\|inverted\)$/ contains=swayConfigFloatingModifier,i3ConfigVariable

" Gaps
syn clear i3ConfigSmartBorderKeyword
syn clear i3ConfigSmartBorder
syn keyword swayConfigSmartBorderKeyword on no_gaps off contained
syn match swayConfigSmartBorder /^\s*smart_borders\s\+\(on\|no_gaps\|off\)\s\?$/ contains=swayConfigSmartBorderKeyword

" Changing colors
syn keyword swayConfigClientColorKeyword focused_tab_title contained
syn match swayConfigClientColor /^\s*client.\w\+\s\+.*$/ contains=i3ConfigClientColorKeyword,i3ConfigColor,i3ConfigVariable,i3ConfigClientColorKeyword,swayConfigClientColorKeyword

" set display outputs
syn match swayConfigOutput /^\s*output\s\+.*$/ contains=i3ConfigOutput

" set display focus 
syn keyword swayConfigFocusKeyword focus contained
syn keyword swayConfigFocusType output contained
syn match swayConfigFocus /^\s*focus\soutput\s.*$/ contains=swayConfigFocusKeyword,swayConfigFocusType

" xwayland 
syn keyword swayConfigXwaylandKeyword xwayland contained
syn match swayConfigXwaylandModifier /^\s*xwayland\s\+\(enable\|disable\|force\)\s\?$/ contains=swayConfigXwaylandKeyword

"hi def link swayConfigError                         Error
hi def link i3ConfigFloating                        Error
hi def link swayConfigFloating                      Type
hi def link swayConfigFloatingMouseAction           Type
hi def link swayConfigFocusKeyword                  Type
hi def link swayConfigSmartBorderKeyword            Type
hi def link swayConfigBindGestureCommand            Identifier
hi def link swayConfigBindGestureDirection          Constant
hi def link swayConfigBindGesturePinchDirection     Constant
hi def link swayConfigBindKeyword                   Identifier
hi def link swayConfigBlockKeyword                  Identifier
hi def link swayConfigClientColorKeyword            Identifier
hi def link swayConfigFloatingKeyword               Identifier
hi def link swayConfigFloatingModifier              Identifier
hi def link swayConfigFocusType                     Identifier
hi def link swayConfigSmartBorder                   Identifier
hi def link swayConfigXwaylandKeyword               Identifier
hi def link swayConfigXwaylandModifier              Type
hi def link swayConfigBindGesture                   PreProc

let b:current_syntax = "swayconfig"
