" Vim syntax file
" Language: sway window manager config
" Original Author: Josef Litos
" Maintainer: James Eapen <james.eapen@vai.org>
" Version: 0.2.2
" Reference version (JosefLitos/i3config.vim): 1.8.1
" Last Change: 2023-09-08

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

" Add sway-specific options to i3config constructs
syn match i3ConfigSet /^\s*set \$\w\+ .*$/ contains=i3ConfigVariable,i3ConfigSetKeyword,i3ConfigColor,i3ConfigString,i3ConfigNoStartupId,i3ConfigNumber,swayConfigOutputCommand,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShParam,i3ConfigShOper

syn match i3ConfigBind /^\s*bind\(sym\|code\|switch\|gesture\)\s\+.*[^{]$/ contains=i3ConfigBindComboLine,swayConfigBindswitchLine,swayConfigBindgestureLine,i3ConfigNumber,i3ConfigVariable,i3ConfigAction,i3ConfigOption,i3ConfigGapStyleKeyword,i3ConfigOperator,i3ConfigString,i3ConfigUnit,i3ConfigUnitOr,i3ConfigConditional,swayConfigOutputCommand,i3ConfigBoolean,i3ConfigExec
syn region i3ConfigBlock start=/^\(mode \S\+\|bar\|\s\+colors\)\+\s\+{$/ end=/^\s*}$/ contains=i3ConfigBlockKeyword,i3ConfigString,i3ConfigBind,swayConfigBindComboBlock,swayConfigBindswitchBlock,swayConfigBindgestureBlock,i3ConfigComment,i3ConfigFont,i3ConfigBoolean,i3ConfigNumber,i3ConfigOperator,i3ConfigModifier,i3ConfigParen,i3ConfigColor,i3ConfigVariable,i3ConfigBlock fold keepend extend

" Sway options
" sway bindswitch and bindgesture
syn region swayConfigBindComboBlock start=/^\s*bind\(sym\|code\)\s\+.*{$/ end=/^\s*}$/ contains=i3ConfigBindKeyword,i3ConfigBindCombo,i3ConfigBindArgument,i3ConfigNumber,i3ConfigVariable,i3ConfigModifier,i3ConfigAction,i3ConfigOption,i3ConfigGapStyleKeyword,i3ConfigOperator,i3ConfigString,i3ConfigUnit,i3ConfigUnitOr,i3ConfigConditional,swayConfigOutputCommand,i3ConfigBoolean,i3ConfigExec,i3ConfigComment,i3ConfigParen fold keepend extend
syn match swayConfigBindswitchArgument /--\(locked\|no-warn\|reload\)/ contained
syn keyword swayConfigBindswitchType lid tablet contained
syn keyword swayConfigBindswitchAction on off toggle contained
syn match swayConfigBindswitch /\(lid\|tablet\):\(on\|off\|toggle\) / contained contains=swayConfigSwitchType,i3ConfigOperator,swayConfigBindswitchAction
syn match swayConfigBindswitchLine /bindswitch\( --\(locked\|no-warn\|reload\)\)* \(lid\|tablet\):\(on\|off\|toggle\) / contained contains=i3ConfigBindKeyword,swayConfigBindswitchArgument,swayConfigBindswitchType,swayConfigBindswitchAction,i3ConfigOperator
syn region swayConfigBindswitchBlock start=/^\s*bindswitch\s\+.*{$/ end=/^\s*}$/ contains=i3ConfigBindKeyword,swayConfigBindswitch,swayConfigBindswitchArgument,i3ConfigNumber,i3ConfigVariable,i3ConfigModifier,i3ConfigAction,i3ConfigOption,i3ConfigGapStyleKeyword,i3ConfigOperator,i3ConfigString,i3ConfigUnit,i3ConfigUnitOr,i3ConfigConditional,swayConfigOutputCommand,i3ConfigBoolean,i3ConfigExec,i3ConfigComment,i3ConfigParen fold keepend extend

syn keyword swayConfigBindgestureType hold swipe pinch contained
syn keyword swayConfigBindgestureDir up down left right inward outward clockwise counterclockwise contained
syn match swayConfigBindgestureArgument /--\(exact\|input-device=[:0-9a-zA-Z_/-]\+\|no-warn\)/ contained
syn match swayConfigBindgesture /\(hold\(:[1-5]\)\?\|swipe\(:[3-5]\)\?\(:up\|:down\|:left\|:right\)\?\|pinch\(:[2-5]\)\?:\(+\?\(inward\|outward\|clockwise\|counterclockwise\|up\|down\|left\|right\)\)\+\) / contained contains=i3ConfigNumber,swayConfigBindgestureType,i3ConfigOperator,swayConfigBindgestureDir,i3ConfigBindModifier
syn match swayConfigBindgestureLine /bindgesture\( --\(exact\|input-device=".*"\|no-warn\)\)* \(hold\(:[1-5]\)\?\|swipe\(:[3-5]\)\?\(:up\|:down\|:left\|:right\)\?\|pinch\(:[2-5]\)\?:\(+\?\(inward\|outward\|clockwise\|counterclockwise\|up\|down\|left\|right\)\)\+\) / contained contains=i3ConfigBindKeyword,swayConfigBindgestureArgument,i3ConfigNumber,swayConfigBindgestureType,i3ConfigOperator,swayConfigBindgestureDir,i3ConfigBindModifier
syn region swayConfigBindgestureBlock start=/^\s*bindgesture\s\+.*{$/ end=/^\s*}$/ contains=i3ConfigBindKeyword,swayConfigBindgesture,swayConfigBindgestureArgument,i3ConfigNumber,i3ConfigVariable,i3ConfigModifier,i3ConfigAction,i3ConfigOption,i3ConfigGapStyleKeyword,i3ConfigOperator,i3ConfigString,i3ConfigUnit,i3ConfigUnitOr,i3ConfigConditional,swayConfigOutputCommand,i3ConfigBoolean,i3ConfigExec,i3ConfigComment,i3ConfigParen fold keepend extend

syn region swayConfigExecBlock start=/exec\(_always\)\? {/ end=/^}$/ contains=i3ConfigExecKeyword,i3ConfigExecAlwaysKeyword,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigString,i3ConfigVariable,i3ConfigComment fold keepend extend

syn keyword swayConfigBlockKeyword input output seat contained

" sway display outputs
syn keyword swayConfigOutputOpts mode pos position adaptive_sync scale res resolution power max_render_time transform scale_filter subpixel bg background enable disable toggle contained
syn keyword swayConfigOutputOptVals toggle normal flipped contained
syn keyword swayConfigOutputBgOpts fill stretch fit center tile contained
syn match swayConfigOutputBg / \(background\|bg\) .* \(fill\|fit\|center\|stretch\|tile\)/ contained contains=swayConfigOutputOpts,swayConfigOutputBgOpts,swayConfigBlockKeyword,i3ConfigString
syn match swayConfigOutputFPS /@[0-9.]\+Hz/ contained
syn match swayConfigOutputMode / [0-9]\+x[0-9]\+\(@[0-9.]\+Hz\)\?/ contained contains=swayConfigOutputFPS,i3ConfigNumber
syn match swayConfigOutputCommand /output .*/ contains=swayConfigBlockKeyword,swayConfigOutputKeyword,swayConfigOutputMode,swayConfigOutputOpts,i3ConfigVariable,i3ConfigNumber,i3ConfigString,swayConfigOutputBg,i3ConfigBoolean

" sway input devices
syn keyword swayConfigInputOpts xkb_layout xkb_variant xkb_rules xkb_switch_layout xkb_numlock xkb_file xkb_capslock xkb_model repeat_delay repeat_rate map_to_output map_to_region map_from_region tool_mode accel_profile dwt dwtp drag_lock drag click_method middle_emulation tap events calibration_matrix natural_scroll left_handed pointer_accel scroll_button scroll_factor scroll_method tap_button_map contained
syn keyword swayConfigInputOptVals absolute relative adaptive flat none button_areas clickfinger toggle two_finger edge on_button_down lrm lmr contained
syn keyword swayConfigInputXkbOptsKeyword xkb_options contained
syn match swayConfigInputXkbOptsVals /:[0-9a-z_-]\+/ contained contains=i3ConfigOperator
syn match swayConfigInputXkbOptsOpts /[a-z]\+:[0-9a-z_-]\+/ contained contains=swayConfigInputXkbOptsVals
syn match swayConfigInputXkbOpts /xkb_options \([a-z]\+:[0-9a-z_-]\+,\?\)\+/ contained contains=i3ConfigOperator,swayConfigInputXkbOptsKeyword,swayConfigInputXkbOptsOpts
syn match swayConfigInputCommand /^input\s\+".*".*/ contains=swayConfigBlockKeyword,swayConfigInputXkbOptsOpts,i3ConfigNumber,i3ConfigString,swayConfigInputOpts,swayConfigInputOptVals,i3ConfigBoolean,swayConfigInputXkbOpts,i3ConfigOperator,i3ConfigBoolean

" set display focus
syn keyword swayConfigFocusKeyword focus contained
syn match swayConfigFocus /^focus output .*$/ contains=swayConfigFocusKeyword,swayConfigBlockKeyword

" enable/disable xwayland
syn keyword swayConfigXOpt enable disable force contained
syn match swayConfigXwayland /^xwayland \(enable\|disable\|force\)/ contains=swayConfigXOpt

" sway seat
syn keyword swayConfigSeatOpts attach cursor fallback hide_cursor idle_inhibit idle_wake keyboard_grouping shortcuts_inhibitor pointer_constraint xcursor_theme contained
syn keyword swayConfigSeatOptVals move set press release none smart activate deactivate toggle escape enable disable contained
syn match swayConfigSeat /^seat .*/ contains=swayConfigBlockKeyword,i3ConfigString,i3ConfigNumber,i3ConfigBoolean,swayConfigSeatOptVals,swayConfigSeatOpts

syn region swayConfigBlock start=/^\(input\|output\|seat\).*\s{$/ end=/^}$/ contains=swayConfigInputXkbOptsOpts,swayConfigBlockKeyword,i3ConfigParen,i3ConfigVariable,i3ConfigString,i3ConfigNumber,swayConfigOutputKeyword,swayConfigOutputMode,swayConfigOutputOpts,i3ConfigColor,swayConfigOutputBg,swayConfigInputOpts,swayConfigInputOptVals,i3ConfigBoolean,swayConfigInputXkbOpts,i3ConfigOperator,i3ConfigBoolean,swayConfigSeatOptVals,swayConfigSeatOpts,i3ConfigComment fold keepend extend

" Define the highlighting.
hi def link swayConfigFocusKeyword                  i3ConfigAction
hi def link swayConfigOutputOpts                    i3ConfigOption
hi def link swayConfigOutputBgOpts                  i3ConfigOption
hi def link swayConfigOutputOptVals                 i3ConfigOption
hi def link swayConfigOutputFPS                     Constant
hi def link swayConfigInputOptVals                  i3ConfigOption
hi def link swayConfigInputOpts                     i3ConfigKeyword
hi def link swayConfigInputXkbOptsVals              i3ConfigString
hi def link swayConfigInputXkbOptsOpts              i3ConfigOption
hi def link swayConfigInputXkbOptsKeyword           i3ConfigKeyword
hi def link swayConfigSeatOpts                      i3ConfigKeyword
hi def link swayConfigSeatOptVals                   i3ConfigOption
hi def link swayConfigBlockKeyword                  i3ConfigAction
hi def link swayConfigXOpt                          i3ConfigOption
hi def link swayConfigXwayland                      i3ConfigKeyword
hi def link swayConfigBindswitchType                Type
hi def link swayConfigBindswitchAction              Keyword
hi def link swayConfigBindswitchArgument            i3ConfigBindArgument
hi def link swayConfigBindgestureType               Type
hi def link swayConfigBindgestureDir                Keyword
hi def link swayConfigBindgestureArgument           i3ConfigBindArgument

let b:current_syntax = "swayconfig"
