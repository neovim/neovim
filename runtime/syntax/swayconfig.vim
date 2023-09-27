" Vim syntax file
" Language: sway config file
" Original Author: Josef Litos (JosefLitos/i3config.vim)
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 1.0.0
" Last Change: 2023-09-14

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

" i3 extensions
syn keyword i3ConfigActionKeyword opacity urgent shortcuts_inhibitor splitv splith splitt contained
syn keyword i3ConfigOption set plus minus allow deny csd v h t contained

syn keyword i3ConfigConditionProp app_id pid shell contained

syn keyword i3ConfigWorkspaceDir prev_on_output next_on_output contained

syn keyword swayConfigBindKeyword bindswitch bindgesture contained
syn match i3ConfigBindArgument /--\(locked\|to-code\|no-repeat\|input-device=[:0-9a-zA-Z_/-]\+\|no-warn\)/ contained
syn region i3ConfigBind start=/^\s*bind\(switch\|gesture\) / skip=/\\$/ end=/$/ contains=swayConfigBindKeyword,swayConfigBindswitch,swayConfigBindswitchArgument,swayConfigBindgesture,swayConfigBindgestureArgument,i3ConfigCriteria,i3ConfigAction,i3ConfigSeparator,i3ConfigActionKeyword,i3ConfigOption,i3ConfigString,i3ConfigNumber,i3ConfigVariable,i3ConfigBoolean keepend

syn match swayConfigBindBlockHeader /^\s*bind\(sym\|code\) .*{$/ contained contains=i3ConfigBindKeyword,i3ConfigBindArgument,i3ConfigParen
syn match swayConfigBindBlockCombo /^\s\+\(--[a-z-]\+ \)*[$a-zA-Z0-9_+]\+ [a-z[]\@=/ contained contains=i3ConfigBindArgument,i3ConfigBindCombo
syn region i3ConfigBind start=/^\s*bind\(sym\|code\) .*{$/ end=/^\s*}$/ contains=swayConfigBindBlockHeader,swayConfigBindBlockCombo,i3ConfigCriteria,i3ConfigAction,i3ConfigSeparator,i3ConfigActionKeyword,i3ConfigOption,i3ConfigString,i3ConfigNumber,i3ConfigVariable,i3ConfigBoolean,i3ConfigComment,i3ConfigParen fold keepend extend
" fix for extra long bindsym blocks that would be parsed incorrectly when scrolling up
syn region i3ConfigBlockOrphan start=/^\s\+\S/ skip=/^\s\|^$/ end=/^}\?/ contains=swayConfigBindBlockCombo,i3ConfigCriteria,i3ConfigAction,i3ConfigSeparator,i3ConfigActionKeyword,i3ConfigOption,i3ConfigString,i3ConfigNumber,i3ConfigVariable,i3ConfigBoolean,i3ConfigComment,i3ConfigParen keepend extend

syn keyword i3ConfigClientOpts focused_tab_title contained

syn region swayConfigExecBlock start=/exec\(_always\)\? {/ end=/^}$/ contains=i3ConfigExecKeyword,i3ConfigExecAlwaysKeyword,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigString,i3ConfigVariable,i3ConfigComment fold keepend extend

syn keyword swayConfigFloatingModifierOpts normal inverse contained
syn match i3ConfigKeyword /^floating_modifier [$a-zA-Z0-9+]\+ \(normal\|inverse\)$/ contains=i3ConfigVariable,i3ConfigBindModkey,swayConfigFloatingModifierOpts

syn match i3ConfigKeyword /^hide_edge_borders --i3 \w*$/ contains=i3ConfigEdgeKeyword,i3ConfigShParam

syn keyword i3ConfigBarOpts swaybar_command gaps height pango_markup status_edge_padding status_padding wrap_scroll tray_bindcode tray_bindsym icon_theme contained
syn keyword i3ConfigBarOptVals overlay contained

syn keyword i3ConfigExecActionKeyword swaymsg contained

" Sway-only options
" Xwayland
syn keyword swayConfigXOpt enable disable force contained
syn match i3ConfigKeyword /^xwayland \w*$/ contains=swayConfigXOpt

" Inhibit idle
syn keyword swayConfigInhibitKeyword inhibit_idle contained
syn keyword swayConfigInhibitOpts focus fullscreen open none visible contained
syn match i3ConfigAction /inhibit_idle \w*/ contained contains=swayConfigInhibitKeyword,swayConfigInhibitOpts

" Bindswitch
syn match swayConfigBindswitchArgument /--\(locked\|no-warn\|reload\)/ contained
syn keyword swayConfigBindswitchType lid tablet contained
syn keyword swayConfigBindswitchState toggle contained
syn match swayConfigBindswitch /\(lid\|tablet\):\(on\|off\|toggle\) / contained contains=swayConfigBindswitchType,i3ConfigColonOperator,swayConfigBindswitchState,i3ConfigBoolean
syn region i3ConfigBind start=/^\s*bindswitch\s\+.*{$/ end=/^\s*}$/ contains=swayConfigBindKeyword,swayConfigBindswitch,swayConfigBindswitchArgument,i3ConfigNumber,i3ConfigVariable,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,i3ConfigSeparator,i3ConfigString,i3ConfigCriteria,swayConfigOutputCommand,i3ConfigBoolean,i3ConfigComment,i3ConfigParen fold keepend extend

" Bindgesture
syn match swayConfigBindgestureArgument /--\(exact\|input-device=[:0-9a-zA-Z_/-]\+\|no-warn\)/ contained
syn keyword swayConfigBindgestureType hold swipe pinch contained
syn keyword swayConfigBindgestureDir up down left right inward outward clockwise counterclockwise contained
syn match swayConfigBindgesture /\(hold\(:[1-5]\)\?\|swipe\(:[3-5]\)\?\(:up\|:down\|:left\|:right\)\?\|pinch\(:[2-5]\)\?:\(+\?\(inward\|outward\|clockwise\|counterclockwise\|up\|down\|left\|right\)\)\+\) / contained contains=i3ConfigNumber,swayConfigBindgestureType,i3ConfigColonOperator,swayConfigBindgestureDir,i3ConfigBindModifier
syn region i3ConfigBind start=/^\s*bindgesture\s\+.*{$/ end=/^\s*}$/ contains=swayConfigBindKeyword,swayConfigBindgesture,swayConfigBindgestureArgument,i3ConfigCriteria,i3ConfigAction,i3ConfigSeparator,i3ConfigActionKeyword,i3ConfigOption,i3ConfigString,i3ConfigNumber,i3ConfigVariable,i3ConfigBoolean,i3ConfigParen fold keepend extend

" Tiling drag threshold
syn match i3ConfigKeyword /^tiling_drag_threshold \d\+$/ contains=i3ConfigNumber

" Titlebar commands
syn match i3ConfigKeyword /^titlebar_border_thickness \(\d\+\|\$\S\+\)$/ contains=i3ConfigNumber,i3ConfigVariable
syn match i3ConfigKeyword /^titlebar_padding \(\d\+\|\$\S\+\)\( \d\+\)\?$/ contains=i3ConfigNumber,i3ConfigVariable

syn match swayConfigDeviceOps /[*,:;]/ contained

" Input devices
syn keyword swayConfigInputKeyword input contained
syn keyword swayConfigInputType touchpad pointer keyboard touch tablet_tool tablet_pad switch contained
syn match swayConfigInputTypePair /\<type:\w\+\>/ contained contains=i3ConfigColonOperator,swayConfigInputType
syn region swayConfigInputStart start=/^input / end=/\s/ contained contains=swayConfigInputKeyword,swayConfigInputTypePair,i3ConfigString keepend extend
syn keyword swayConfigInputOpts xkb_layout xkb_variant xkb_rules xkb_switch_layout xkb_numlock xkb_file xkb_capslock xkb_model repeat_delay repeat_rate map_to_output map_to_region map_from_region tool_mode accel_profile dwt dwtp drag_lock drag click_method middle_emulation tap events calibration_matrix natural_scroll left_handed pointer_accel scroll_button scroll_factor scroll_method tap_button_map contained
syn keyword swayConfigInputOptVals absolute relative adaptive flat none button_areas clickfinger toggle two_finger edge on_button_down lrm lmr next prev pen eraser brush pencil airbrush disabled_on_external_mouse disable contained
syn match swayConfigXkbOptsPairVal /:[0-9a-z_-]\+/ contained contains=i3ConfigColonOperator
syn match swayConfigXkbOptsPair /[a-z]\+:[0-9a-z_-]\+/ contained contains=swayConfigXkbOptsPairVal
syn match swayConfigInputXkbOpts /xkb_options \([a-z]\+:[0-9a-z_-]\+,\?\)\+/ contained contains=swayConfigXkbOptsPair,swayConfigDeviceOps
syn region i3ConfigAction start=/input/ skip=/\\$/ end=/\([,;]\|$\)/ contained contains=swayConfigInputStart,swayConfigInputXkbOpts,swayConfigInputOpts,swayConfigInputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigBoolean,swayConfigDeviceOps keepend transparent
syn region i3ConfigInput start=/^input/ skip=/\\$/ end=/$/ contains=swayConfigInputStart,swayConfigInputXkbOpts,swayConfigInputOpts,swayConfigInputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigBoolean,swayConfigDeviceOps keepend
syn region i3ConfigInput start=/^input .* {/ end=/}$/ contains=swayConfigInputStart,swayConfigInputXkbOpts,swayConfigInputOpts,swayConfigInputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigBoolean,swayConfigDeviceOps,i3ConfigParen keepend extend

" Seat
syn keyword swayConfigSeatKeyword seat contained
syn keyword swayConfigSeatOpts attach cursor fallback hide_cursor idle_inhibit idle_wake keyboard_grouping shortcuts_inhibitor pointer_constraint xcursor_theme contained
syn match swayConfigSeatOptVals /when-typing/ contained
syn keyword swayConfigSeatOptVals move set press release none smart activate deactivate toggle escape enable disable contained
syn region i3ConfigAction start=/seat/ skip=/\\$/ end=/\([,;]\|$\)/ contained contains=swayConfigSeatKeyword,i3ConfigString,i3ConfigNumber,i3ConfigBoolean,swayConfigSeatOptVals,swayConfigSeatOpts,swayConfigDeviceOps,swayConfigInputType keepend transparent
syn region swayConfigSeat start=/seat/ skip=/\\$/ end=/$/ contains=swayConfigSeatKeyword,i3ConfigString,i3ConfigNumber,i3ConfigBoolean,swayConfigSeatOptVals,swayConfigSeatOpts,swayConfigDeviceOps,swayConfigInputType keepend
syn region swayConfigSeat start=/seat .* {$/ end=/}$/ contains=swayConfigSeatKeyword,i3ConfigString,i3ConfigNumber,i3ConfigBoolean,swayConfigSeatOptVals,swayConfigSeatOpts,swayConfigDeviceOps,i3ConfigParen,swayConfigInputType keepend extend

" Output monitors
syn keyword swayConfigOutputKeyword output contained
syn keyword swayConfigOutputOpts mode resolution res modeline position pos scale scale_filter subpixel background bg transform disable enable power dpms max_render_time adaptive_sync render_bit_depth contained
syn keyword swayConfigOutputOptVals linear nearest smart rgb bgr vrgb vbgr none normal flipped fill stretch fit center tile solid_color clockwise anticlockwise toggle contained
syn match swayConfigOutputOptVals /--custom\|flipped-\(90\|180\|270\)/ contained
syn match swayConfigOutputFPS /@[0-9.]\+Hz/ contained
syn match swayConfigOutputMode / [0-9]\+x[0-9]\+\(@[0-9.]\+Hz\)\?/ contained contains=swayConfigOutputFPS
syn region i3ConfigAction start=/output/ skip=/\\$/ end=/\([,;]\|$\)/ contained contains=swayConfigOutputKeyword,swayConfigOutputMode,swayConfigOutputOpts,swayConfigOutputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigString,i3ConfigColor,i3ConfigBoolean,swayConfigDeviceOps keepend transparent
syn region swayConfigOutput start=/^output/ skip=/\\$/ end=/$/  contains=swayConfigOutputKeyword,swayConfigOutputMode,swayConfigOutputOpts,swayConfigOutputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigString,i3ConfigColor,i3ConfigBoolean,swayConfigDeviceOps keepend
syn region swayConfigOutput start=/^output .* {$/ end=/}$/  contains=swayConfigOutputKeyword,swayConfigOutputMode,swayConfigOutputOpts,swayConfigOutputOptVals,i3ConfigVariable,i3ConfigNumber,i3ConfigString,i3ConfigColor,i3ConfigBoolean,swayConfigDeviceOps,i3ConfigParen keepend extend

" Define the highlighting.
hi def link swayConfigFloatingModifierOpts   i3ConfigOption
hi def link swayConfigBindKeyword            i3ConfigBindKeyword
hi def link swayConfigXOpt                   i3ConfigOption
hi def link swayConfigInhibitKeyword         i3ConfigCommand
hi def link swayConfigInhibitOpts            i3ConfigOption
hi def link swayConfigBindswitchArgument     i3ConfigBindArgument
hi def link swayConfigBindswitchType         i3ConfigMoveType
hi def link swayConfigBindswitchState        i3ConfigMoveDir
hi def link swayConfigBindgestureArgument    i3ConfigBindArgument
hi def link swayConfigBindgestureType        i3ConfigMoveType
hi def link swayConfigBindgestureDir         i3ConfigMoveDir
hi def link swayConfigDeviceOps              i3ConfigOperator
hi def link swayConfigInputKeyword           i3ConfigCommand
hi def link swayConfigInputType              i3ConfigMoveType
hi def link swayConfigInputTypePair          i3ConfigMoveDir
hi def link swayConfigInputOptVals           i3ConfigShParam
hi def link swayConfigInputOpts              i3ConfigOption
hi def link swayConfigXkbOptsPairVal         i3ConfigString
hi def link swayConfigXkbOptsPair            i3ConfigShParam
hi def link swayConfigInputXkbOpts           i3ConfigOption
hi def link swayConfigSeatKeyword            i3ConfigCommand
hi def link swayConfigSeatOptVals            swayConfigInputOptVals
hi def link swayConfigSeatOpts               swayConfigInputOpts
hi def link swayConfigOutputKeyword          i3ConfigCommand
hi def link swayConfigOutputOptVals          swayConfigInputOptVals
hi def link swayConfigOutputOpts             swayConfigInputOpts
hi def link swayConfigOutputFPS              Constant
hi def link swayConfigOutputMode             i3ConfigNumber

let b:current_syntax = "swayconfig"
