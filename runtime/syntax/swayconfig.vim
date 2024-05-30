" Vim syntax file
" Language: sway config file
" Original Author: Josef Litos (JosefLitos/i3config.vim)
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 1.2.4
" Last Change: 2024-05-24

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

" before i3 load to give i3ConfigKeyword lower priority
syn cluster i3ConfigCommand contains=i3ConfigCommand,i3ConfigAction,i3ConfigActionKeyword,@i3ConfigValue,i3ConfigColor,i3ConfigKeyword

runtime! syntax/i3config.vim

" Sway extensions to i3
syn keyword i3ConfigActionKeyword opacity urgent shortcuts_inhibitor splitv splith splitt contained contained skipwhite nextgroup=i3ConfigOption
syn keyword i3ConfigOption set plus minus allow deny csd v h t contained contained skipwhite nextgroup=i3ConfigOption,@i3ConfigValue

syn keyword i3ConfigConditionProp app_id pid shell contained

syn keyword i3ConfigWorkspaceDir prev_on_output next_on_output contained

syn match i3ConfigBindArgument /--\(locked\|to-code\|no-repeat\|input-device=[^ '"]*\|no-warn\) / contained contains=i3ConfigShOper,@i3ConfigStrVar nextgroup=i3ConfigBindArgument,i3ConfigBindCombo
syn region i3ConfigBindArgument start=/--input-device=['"]/ end=/\s/ contained contains=@i3ConfigIdent,i3ConfigShOper,i3ConfigString nextgroup=i3ConfigBindArgument,i3ConfigBindCombo

syn region i3ConfigBindCombo matchgroup=i3ConfigParen start=/{$/ end=/^\s*}$/ contained contains=i3ConfigBindArgument,i3ConfigBindCombo,i3ConfigComment fold keepend extend
" hack for blocks with start outside parsing range
syn region swayConfigBlockOrphan start=/^\s\+\(--[a-z-]\+ \)*\([$A-Z][$0-9A-Za-z_+]\+\|[a-z]\) [a-z[]/ skip=/\\$\|$\n^\s*}$/ end=/$/ contains=i3ConfigBindArgument,i3ConfigBindCombo,i3ConfigParen keepend extend

syn region i3ConfigExec start=/ {$/ end=/^\s*}$/ contained contains=i3ConfigExecAction,@i3ConfigSh,i3ConfigComment fold keepend extend

syn keyword swayConfigFloatingModifierOpts normal inverse none contained
syn match i3ConfigKeyword /floating_modifier \(none\|[$A-Z][0-9A-Za-z]\+ \(normal\|inverse\)\)$/ contained contains=i3ConfigVariable,i3ConfigBindModkey,swayConfigFloatingModifierOpts

syn match swayConfigI3Param /--i3/ contains=i3ConfigShParam skipwhite nextgroup=i3ConfigEdgeOpts
syn keyword i3ConfigKeyword hide_edge_borders contained skipwhite nextgroup=swayConfigI3Param,i3ConfigEdgeOpts

syn keyword i3ConfigBarOpts swaybar_command contained skipwhite nextgroup=@i3ConfigSh
syn region i3ConfigBarOpts matchgroup=i3ConfigBarOpts start=/gaps/ end=/$/ contained contains=@i3ConfigNumVar
syn keyword i3ConfigBarOpts height pango_markup status_edge_padding status_padding wrap_scroll tray_bindcode tray_bindsym icon_theme contained skipwhite nextgroup=i3ConfigBarOptVals,@i3ConfigValue,i3ConfigShOper
syn keyword i3ConfigBarOptVals overlay contained

syn keyword i3ConfigExecActionKeyword swaymsg contained

" Sway-only options
" Xwayland
syn keyword swayConfigXOpt enable disable force contained
syn keyword i3ConfigKeyword xwayland contained skipwhite nextgroup=swayConfigXOpt

" Inhibit idle
syn keyword swayConfigInhibitOpts focus fullscreen open none visible contained
syn keyword i3ConfigActionKeyword inhibit_idle contained skipwhite nextgroup=swayConfigInhibitOpts

" Bindswitch
syn match swayConfigBindswitchArgument /--\(locked\|no-warn\|reload\) / contained nextgroup=swayConfigBindswitchArgument,swayConfigBindswitchType
syn keyword swayConfigBindswitchType lid tablet contained nextgroup=swayConfigBindswitchCombo
syn keyword swayConfigBindswitchState toggle contained
syn match swayConfigBindswitchCombo /:\(on\|off\|toggle\) / contained contains=i3ConfigColonOperator,swayConfigBindswitchState,i3ConfigBoolean nextgroup=i3ConfigBind
syn region swayConfigBindswitchType matchgroup=i3ConfigParen start=/{$/ end=/^\s*}$/ contained contains=swayConfigBindswitchArgument,swayConfigBindswitchType,i3ConfigComment fold keepend extend
syn keyword i3ConfigBindKeyword bindswitch contained skipwhite nextgroup=swayConfigBindswitchArgument,swayConfigBindswitchType
" hack for blocks with start outside parsing range
syn region swayConfigBlockOrphan start=/^\s\+\(lid\|tablet\):/ skip=/\\$\|$\n^\s*}$/ end=/$/ contains=swayConfigBindswitchArgument,swayConfigBindswitchType,i3ConfigParen keepend extend

" Bindgesture
syn match swayConfigBindgestureArgument /--\(exact\|input-device=[:0-9A-Za-z_/-]\+\|no-warn\) / contained nextgroup=swayConfigBindgestureArgument,swayConfigBindgestureCombo
syn keyword swayConfigBindgestureType hold swipe pinch contained
syn keyword swayConfigBindgestureDir up down left right inward outward clockwise counterclockwise contained
syn match swayConfigBindgestureCombo /\(hold\(:[1-5]\)\?\|swipe\(:[3-5]\)\?\(:up\|:down\|:left\|:right\)\?\|pinch\(:[2-5]\)\?:\(+\?\(inward\|outward\|clockwise\|counterclockwise\|up\|down\|left\|right\)\)\+\) / contained contains=i3ConfigNumber,swayConfigBindgestureType,i3ConfigColonOperator,swayConfigBindgestureDir,i3ConfigBindModifier nextgroup=swayConfigBindgestureCombo,i3ConfigBind
syn region swayConfigBindgestureCombo matchgroup=i3ConfigParen start=/{$/ end=/^\s*}$/ contained contains=swayConfigBindgestureArgument,swayConfigBindgestureCombo,i3ConfigComment fold keepend extend
syn keyword i3ConfigBindKeyword bindgesture contained skipwhite nextgroup=swayConfigBindgestureArgument,swayConfigBindgestureCombo
" hack for blocks with start outside parsing range
syn region swayConfigBlockOrphan start=/^\s\+\(--[a-z-]\+ \)*\(hold\|swipe\|pinch\):/ skip=/\\$\|$\n^\s*}$/ end=/$/ contains=swayConfigBindgestureArgument,swayConfigBindgestureCombo,i3ConfigParen keepend extend

" Tiling drag threshold
" Titlebar commands
syn keyword i3ConfigKeyword tiling_drag_threshold titlebar_border_thickness contained skipwhite nextgroup=@i3ConfigNumVar
syn match i3ConfigKeyword /titlebar_padding \(\d\+\|\$\S\+\)\( \d\+\)\?$/ contained contains=@i3ConfigNumVar

syn match swayConfigDeviceOper /[*:;!]/ contained

" Input devices
syn keyword swayConfigInputOpts xkb_variant xkb_rules xkb_switch_layout xkb_numlock xkb_file xkb_capslock xkb_model repeat_delay repeat_rate map_to_output map_to_region map_from_region tool_mode accel_profile dwt dwtp drag_lock drag click_method middle_emulation tap events calibration_matrix natural_scroll left_handed pointer_accel scroll_button scroll_factor scroll_method tap_button_map contained skipwhite nextgroup=swayConfigInputOptVals,@i3ConfigValue
syn keyword swayConfigInputOptVals absolute relative adaptive flat none button_areas clickfinger toggle two_finger edge on_button_down lrm lmr next prev pen eraser brush pencil airbrush disabled_on_external_mouse disable enable contained skipwhite nextgroup=swayConfigInputOpts,@i3ConfigValue,swayConfigDeviceOper
syn match swayConfigDeviceOper /,/ contained nextgroup=swayConfigXkbOptsPair,swayConfigXkbLayout
syn match swayConfigXkbLayout /[a-z]\+/ contained nextgroup=swayConfigDeviceOper
syn keyword swayConfigInputOpts xkb_layout contained skipwhite nextgroup=swayConfigXkbLayout
syn match swayConfigXkbOptsPairVal /[0-9a-z_-]\+/ contained contains=i3ConfigNumber skipwhite nextgroup=swayConfigDeviceOper,swayConfigInputOpts
syn match swayConfigXkbOptsPair /[a-z]\+:/ contained contains=i3ConfigColonOperator nextgroup=swayConfigXkbOptsPairVal
syn keyword swayConfigInputOpts xkb_options contained skipwhite nextgroup=swayConfigXkbOptsPair

syn region swayConfigInput start=/\s/ skip=/\\$/ end=/\ze[,;]\|$/ contained contains=swayConfigInputOpts,@i3ConfigValue keepend
syn region swayConfigInput matchgroup=i3ConfigParen start=/ {$/ end=/^\s*}$/ contained contains=swayConfigInputOpts,@i3ConfigValue,i3ConfigComment keepend extend
syn keyword swayConfigInputType touchpad pointer keyboard touch tablet_tool tablet_pad switch contained nextgroup=swayConfigInput
syn match swayConfigInputIdent /type:!\?/ contained contains=swayConfigDeviceOper nextgroup=swayConfigInputType
syn match swayConfigInputIdent /[^t '"]\S*/ contained contains=i3ConfigOutputIdent nextgroup=swayConfigInput
syn region swayConfigInputIdent start=/['"]/ end=/\ze/ contained contains=i3ConfigOutputIdent nextgroup=swayConfigInput
syn keyword i3ConfigKeyword input contained skipwhite nextgroup=swayConfigInputIdent

" Seat
syn keyword swayConfigSeatOpts cursor fallback hide_cursor keyboard_grouping shortcuts_inhibitor pointer_constraint xcursor_theme contained skipwhite nextgroup=swayConfigSeatOptVals,@i3ConfigValue
syn match swayConfigInputTypeSeq / \w\+/ contained contains=swayConfigInputType nextgroup=swayConfigInputTypeSeq,swayConfigSeatOpts
syn keyword swayConfigSeatOpts idle_inhibit idle_wake contained nextgroup=swayConfigInputTypeSeq
syn keyword swayConfigSeatOpts attach contained skipwhite nextgroup=swayConfigSeatIdent
syn match swayConfigSeatOptVals /when-typing/ contained skipwhite nextgroup=swayConfigSeatOptVals
syn keyword swayConfigSeatOptVals move set press release none smart activate deactivate toggle escape enable disable contained skipwhite nextgroup=swayConfigSeatOpts
syn region swayConfigSeat start=/\s/ skip=/\\$/ end=/\ze[,;]\|$/ contained contains=swayConfigSeatOpts,@i3ConfigValue keepend
syn region swayConfigSeat matchgroup=i3ConfigParen start=/ {$/ end=/^\s*}$/ contained contains=swayConfigSeatOpts,@i3ConfigValue,i3ConfigComment keepend extend
syn match swayConfigSeatIdent /[^ ]\+/ contained contains=i3ConfigOutputIdent skipwhite nextgroup=swayConfigSeat
syn keyword i3ConfigKeyword seat contained skipwhite nextgroup=swayConfigSeatIdent

" Output monitors
syn keyword swayConfigOutputOpts mode resolution res modeline position pos scale scale_filter subpixel transform disable enable power dpms max_render_time adaptive_sync render_bit_depth contained skipwhite nextgroup=swayConfigOutputOptVals,@i3ConfigValue,swayConfigOutputMode
syn keyword swayConfigOutputOptVals linear nearest smart rgb bgr vrgb vbgr none clockwise anticlockwise toggle contained skipwhite nextgroup=swayConfigOutputOptVals,@i3ConfigValue
syn keyword swayConfigOutputBgVals solid_color fill stretch fit center tile contained skipwhite nextgroup=@i3ConfigColVar
syn match swayConfigOutputBg /[#$]\S\+ solid_color/ contained contains=@i3ConfigColVar,swayConfigOutputBgVals
syn match swayConfigOutputBg /[^b# '"]\S*/ contained contains=i3ConfigShOper skipwhite nextgroup=swayConfigOutputBgVals
syn region swayConfigOutputBg start=/['"]/ end=/\ze/ contained contains=@i3ConfigIdent skipwhite nextgroup=swayConfigOutputBgVals
syn keyword swayConfigOutputOpts bg background contained skipwhite nextgroup=swayConfigOutputBg
syn match swayConfigOutputFPS /@[0-9.]\+Hz/ contained skipwhite nextgroup=swayConfigOutputOpts
syn match swayConfigOutputMode /\(--custom \)\?[0-9]\+x[0-9]\+/ contained contains=i3ConfigShParam skipwhite nextgroup=swayConfigOutputFPS,swayConfigOutputOpts
syn match swayConfigOutputOptVals /\(flipped-\)\?\(90\|180\|270\)\|flipped\|normal/ contained contains=i3ConfigNumber skipwhite nextgroup=swayConfigOutputOptsVals
syn region swayConfigOutput start=/\s/ skip=/\\$/ end=/\ze[,;]\|$/ contained contains=swayConfigOutputOpts,@i3ConfigValue keepend
syn region swayConfigOutput matchgroup=i3ConfigParen start=/ {$/ end=/^\s*}$/ contained contains=swayConfigOutputOpts,@i3ConfigValue,i3ConfigComment keepend extend
syn match swayConfigOutputIdent /[^ ]\+/ contained contains=i3ConfigOutputIdent skipwhite nextgroup=swayConfigOutput
syn keyword i3ConfigKeyword output contained skipwhite nextgroup=swayConfigOutputIdent

" Define the highlighting.
hi def link swayConfigFloatingModifierOpts   i3ConfigOption
hi def link swayConfigXOpt                   i3ConfigOption
hi def link swayConfigInhibitOpts            i3ConfigOption
hi def link swayConfigBindswitchArgument     i3ConfigBindArgument
hi def link swayConfigBindswitchType         i3ConfigMoveType
hi def link swayConfigBindswitchState        i3ConfigMoveDir
hi def link swayConfigBindgestureArgument    i3ConfigBindArgument
hi def link swayConfigBindgestureType        i3ConfigMoveType
hi def link swayConfigBindgestureDir         i3ConfigMoveDir
hi def link swayConfigDeviceOper             i3ConfigOperator
hi def link swayConfigInputType              i3ConfigMoveType
hi def link swayConfigInputIdent             i3ConfigMoveDir
hi def link swayConfigInputOptVals           i3ConfigShParam
hi def link swayConfigInputOpts              i3ConfigOption
hi def link swayConfigXkbOptsPairVal         i3ConfigParamLine
hi def link swayConfigXkbOptsPair            i3ConfigShParam
hi def link swayConfigXkbLayout              i3ConfigParamLine
hi def link swayConfigSeatOptVals            swayConfigInputOptVals
hi def link swayConfigSeatOpts               swayConfigInputOpts
hi def link swayConfigOutputOptVals          swayConfigInputOptVals
hi def link swayConfigOutputBgVals           swayConfigInputOptVals
hi def link swayConfigOutputOpts             swayConfigInputOpts
hi def link swayConfigOutputFPS              Constant
hi def link swayConfigOutputMode             i3ConfigNumber

let b:current_syntax = "swayconfig"
