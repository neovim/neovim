" Vim syntax file
" Language: sway window manager config
" Original Author: James Eapen <james.eapen@vai.org>
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 0.2.1
" Reference version (jamespeapen/swayconfig.vim): 0.12.1
" Last Change: 2023 Mar 20

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

" binding
syn keyword swayConfigBindKeyword bindswitch bindgesture contained
syn match swayConfigBind /^\s*\(bindswitch\)\s\+.*$/ contains=i3ConfigVariable,i3ConfigBindKeyword,swayConfigBindKeyword,i3ConfigVariableAndModifier,i3ConfigNumber,i3ConfigUnit,i3ConfigUnitOr,i3ConfigBindArgument,i3ConfigModifier,i3ConfigAction,i3ConfigString,i3ConfigGapStyleKeyword,i3ConfigBorderStyleKeyword

" bindgestures
syn keyword swayConfigBindGestureCommand swipe pinch hold contained
syn keyword swayConfigBindGestureDirection up down left right next prev contained
syn keyword swayConfigBindGesturePinchDirection inward outward clockwise counterclockwise contained
syn match swayConfigBindGestureHold /^\s*\(bindgesture\)\s\+hold\(:[1-5]\)\?\s\+.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,i3ConfigWorkspaceKeyword,i3ConfigAction
syn match swayConfigBindGestureSwipe /^\s*\(bindgesture\)\s\+swipe\(:[3-5]\)\?:\(up\|down\|left\|right\)\s\+.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,i3ConfigWorkspaceKeyword,i3ConfigAction
syn match swayConfigBindGesturePinch /^\s*\(bindgesture\)\s\+pinch\(:[2-5]\)\?:\(up\|down\|left\|right\|inward\|outward\|clockwise\|counterclockwise\)\(+\(up\|down\|left\|right\|inward\|outward\|clockwise\|counterclockwise\)\)\?.*$/ contains=swayConfigBindKeyword,swayConfigBindGestureCommand,swayConfigBindGestureDirection,swayConfigBindGesturePinchDirection,i3ConfigWorkspaceKeyword,i3ConfigAction

" floating
syn keyword swayConfigFloatingKeyword floating contained
syn match swayConfigFloating /^\s*floating\s\+\(enable\|disable\|toggle\)\s*$/ contains=swayConfigFloatingKeyword

syn clear i3ConfigFloatingModifier
syn keyword swayConfigFloatingModifier floating_modifier contained
syn match swayConfigFloatingMouseAction /^\s\?.*floating_modifier\s\S\+\s\?\(normal\|inverted\|none\)\?$/ contains=swayConfigFloatingModifier,i3ConfigVariable

" Gaps
syn clear i3ConfigSmartBorderKeyword
syn clear i3ConfigSmartBorder
syn keyword swayConfigSmartBorderKeyword on no_gaps off contained
syn match swayConfigSmartBorder /^\s*smart_borders\s\+\(on\|no_gaps\|off\)\s\?$/ contains=swayConfigSmartBorderKeyword

" Changing colors
syn keyword swayConfigClientColorKeyword focused_tab_title contained
syn match swayConfigClientColor /^\s*client.\w\+\s\+.*$/ contains=i3ConfigClientColorKeyword,i3ConfigColor,i3ConfigVariable,i3ConfigClientColorKeyword,swayConfigClientColorKeyword

" Input config
syn keyword swayConfigInputKeyword input contained
syn match swayConfigInput /^\s*input\s\+.*$/ contains=swayConfigInputKeyword

" Seat config
syn keyword swayConfigSeatKeyword seat contained
syn match swayConfigSeat /^\s*seat\s\+.*$/ contains=swayConfigSeatKeyword

" set display outputs
syn match swayConfigOutput /^\s*output\s\+.*$/ contains=i3ConfigOutput

" set display focus 
syn keyword swayConfigFocusKeyword focus contained
syn keyword swayConfigFocusType output contained
syn match swayConfigFocus /^\s*focus\soutput\s.*$/ contains=swayConfigFocusKeyword,swayConfigFocusType

" mouse warping
syn keyword swayConfigMouseWarpingType container contained
syn match swayConfigMouseWarping /^\s*mouse_warping\s\+\(output\|container\|none\)\s\?$/ contains=i3ConfigMouseWarpingKeyword,i3ConfigMouseWarpingType,swayConfigMouseWarpingType

" focus follows mouse
syn clear i3ConfigFocusFollowsMouseType
syn clear i3ConfigFocusFollowsMouse

syn keyword swayConfigFocusFollowsMouseType yes no always contained
syn match swayConfigFocusFollowsMouse /^\s*focus_follows_mouse\s\+\(yes\|no\|always\)\s\?$/ contains=i3ConfigFocusFollowsMouseKeyword,swayConfigFocusFollowsMouseType


" xwayland 
syn keyword swayConfigXwaylandKeyword xwayland contained
syn match swayConfigXwaylandModifier /^\s*xwayland\s\+\(enable\|disable\|force\)\s\?$/ contains=swayConfigXwaylandKeyword

" Group mode/bar
syn clear i3ConfigBlock
syn region swayConfigBlock start=+.*s\?{$+ end=+^}$+ contains=i3ConfigBlockKeyword,i3ConfigString,i3ConfigBind,i3ConfigInitializeKeyword,i3ConfigComment,i3ConfigFont,i3ConfigFocusWrappingType,i3ConfigColor,i3ConfigVariable,swayConfigInputKeyword,swayConfigSeatKeyword,i3ConfigOutput transparent keepend extend

"hi def link swayConfigError                         Error
hi def link i3ConfigFloating                        Error
hi def link swayConfigFloating                      Type
hi def link swayConfigFloatingMouseAction           Type
hi def link swayConfigFocusKeyword                  Type
hi def link swayConfigSmartBorderKeyword            Type
hi def link swayConfigInputKeyword                  Type
hi def link swayConfigSeatKeyword                   Type
hi def link swayConfigMouseWarpingType              Type
hi def link swayConfigFocusFollowsMouseType         Type
hi def link swayConfigBindGestureCommand            Identifier
hi def link swayConfigBindGestureDirection          Constant
hi def link swayConfigBindGesturePinchDirection     Constant
hi def link swayConfigBindKeyword                   Identifier
hi def link swayConfigClientColorKeyword            Identifier
hi def link swayConfigFloatingKeyword               Identifier
hi def link swayConfigFloatingModifier              Identifier
hi def link swayConfigFocusType                     Identifier
hi def link swayConfigSmartBorder                   Identifier
hi def link swayConfigXwaylandKeyword               Identifier
hi def link swayConfigXwaylandModifier              Type
hi def link swayConfigBindGesture                   PreProc

let b:current_syntax = "swayconfig"
