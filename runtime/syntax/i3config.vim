" Vim syntax file
" Language: i3 config file
" Original Author: Josef Litos (JosefLitos/i3config.vim)
" Maintainer: Quentin Hibon (github user hiqua)
" Version: 1.0.2
" Last Change: 2023-12-28

" References:
" http://i3wm.org/docs/userguide.html#configuring
" http://vimdoc.sourceforge.net/htmldoc/syntax.html
"
"
" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

scriptencoding utf-8

" Error
syn match i3ConfigError /.\+/

" Todo
syn keyword i3ConfigTodo TODO FIXME XXX contained

" Helper type definitions
syn match i3ConfigSeparator /[,;\\]/ contained
syn match i3ConfigParen /[{}]/ contained
syn keyword i3ConfigBoolean yes no enabled disabled on off true false contained
syn region i3ConfigString start=/\W\@<="/ skip=/\\\("\|$\)/ end=/"\|$/ contained contains=i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigVariable,i3ConfigExecAction keepend extend
syn region i3ConfigString start=/\W\@<='/ skip=/\\$/ end=/'\|$/ contained contains=i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigVariable,i3ConfigExecAction keepend extend
syn match i3ConfigColor /#[0-9A-Fa-f]\{3,8}/ contained
syn match i3ConfigNumber /[0-9A-Za-z_$-]\@<!-\?\d\+\w\@!/ contained

" 4.1 Include directive
syn keyword i3ConfigIncludeKeyword include contained
syn match i3ConfigIncludeCommand /`[^`]*`/ contained contains=i3ConfigShDelim,i3ConfigShParam,i3ConfigShOper,i3ConfigShCommand,i3ConfigString
syn match i3ConfigParamLine /^include .*$/ contains=i3ConfigIncludeKeyword,i3ConfigString,i3ConfigVariable,i3ConfigIncludeCommand,i3ConfigShOper

" 4.2 Comments
syn match i3ConfigComment /^\s*#.*$/ contains=i3ConfigTodo

" 4.3 Fonts
syn keyword i3ConfigFontKeyword font contained
syn match i3ConfigColonOperator /:/ contained
syn match i3ConfigFontNamespace /\w\+:/ contained contains=i3ConfigColonOperator
syn match i3ConfigFontSize / \d\+\(px\)\?\s\?$/ contained
syn region i3ConfigFont start=/^\s*font / skip=/\\$/ end=/$/ contains=i3ConfigFontKeyword,i3ConfigFontNamespace,i3ConfigFontSize,i3ConfigSeparator keepend

" 4.4-4.5 Keyboard/Mouse bindings
syn keyword i3ConfigBindKeyword bindsym bindcode contained
syn match i3ConfigBindArgument /--\(release\|border\|whole-window\|exclude-titlebar\)/ contained
syn match i3ConfigBindModifier /+/ contained
syn keyword i3ConfigBindModkey Ctrl Shift Mod1 Mod2 Mod3 Mod4 Mod5 contained
syn match i3ConfigBindCombo /[$0-9A-Za-z_+]\+ / contained contains=i3ConfigBindModifier,i3ConfigVariable,i3ConfigBindModkey
syn match i3ConfigBindComboLine /bind\(sym\|code\)\( --[a-z-]\+\)* [$0-9A-Za-z_+]\+ / contained contains=i3ConfigBindKeyword,i3ConfigBindArgument,i3ConfigBindCombo
syn region i3ConfigBind start=/^\s*bind\(sym\|code\) / skip=/\\$/ end=/$/ contains=i3ConfigBindComboLine,i3ConfigCriteria,i3ConfigAction,i3ConfigSeparator,i3ConfigActionKeyword,i3ConfigOption,i3ConfigString,i3ConfigNumber,i3ConfigVariable,i3ConfigBoolean keepend

" 4.6 Binding modes
syn region i3ConfigKeyword start=/^mode\( --pango_markup\)\? \([^'" {]\+\|'[^']\+'\|".\+"\)\s\+{$/ end=/^\s*}$/ contains=i3ConfigShParam,i3ConfigString,i3ConfigBind,i3ConfigComment,i3ConfigNumber,i3ConfigParen,i3ConfigVariable fold keepend extend

" 4.7 Floating modifier
syn match i3ConfigKeyword /^floating_modifier [$0-9A-Za-z]*$/ contains=i3ConfigVariable,i3ConfigBindModkey

" 4.8 Floating window size
syn keyword i3ConfigSizeSpecial x contained
syn match i3ConfigSize / -\?\d\+ x -\?\d\+/ contained contains=i3ConfigSizeSpecial,i3ConfigNumber
syn match i3ConfigKeyword /^floating_\(maximum\|minimum\)_size .*$/ contains=i3ConfigSize

" 4.9 Orientation
syn keyword i3ConfigOrientationOpts vertical horizontal auto contained
syn match i3ConfigKeyword /^default_orientation \w*$/ contains=i3ConfigOrientationOpts

" 4.10 Layout mode
syn keyword i3ConfigWorkspaceLayoutOpts default stacking tabbed contained
syn match i3ConfigKeyword /^workspace_layout \w*$/ contains=i3ConfigWorkspaceLayoutOpts

" 4.11 Title alignment
syn keyword i3ConfigTitleAlignOpts left center right contained
syn match i3ConfigKeyword /^title_align .*$/ contains=i3ConfigTitleAlignOpts

" 4.12 Border style
syn keyword i3ConfigBorderOpts none normal pixel contained
syn match i3ConfigKeyword /^default\(_floating\)\?_border .*$/ contains=i3ConfigBorderOpts,i3ConfigNumber,i3ConfigVariable

" 4.13 Hide edge borders
syn keyword i3ConfigEdgeOpts none vertical horizontal both smart smart_no_gaps contained
syn match i3ConfigKeyword /^hide_edge_borders \w*$/ contains=i3ConfigEdgeOpts

" 4.14 Smart Borders
syn keyword i3ConfigSmartBorderOpts no_gaps contained
syn match i3ConfigKeyword /^smart_borders \(on\|off\|no_gaps\)$/ contains=i3ConfigSmartBorderOpts,i3ConfigBoolean

" 4.15 Arbitrary commands
syn region i3ConfigKeyword start=/^for_window / end=/$/ contains=i3ConfigForWindowKeyword,i3ConfigCriteria keepend

" 4.16 No opening focus
syn match i3ConfigKeyword /^no_focus .*$/ contains=i3ConfigCondition

" 4.17 Variables
syn match i3ConfigVariable /\$[0-9A-Za-z_:|[\]-]\+/
syn keyword i3ConfigSetKeyword set contained
syn region i3ConfigSet start=/^set\s\+\$/ skip=/\\$/ end=/$/ contains=i3ConfigSetKeyword,i3ConfigVariable,i3ConfigColor,i3ConfigString,i3ConfigNumber,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShParam,i3ConfigShOper,i3ConfigBindModkey keepend

" 4.18 X resources
syn keyword i3ConfigResourceKeyword set_from_resource contained
syn match i3ConfigParamLine /^set_from_resource\s\+.*$/ contains=i3ConfigResourceKeyword,i3ConfigCondition,i3ConfigColor,i3ConfigVariable,i3ConfigString,i3ConfigNumber

" 4.19 Assign clients to workspaces
syn keyword i3ConfigAssignKeyword assign contained
syn match i3ConfigAssignSpecial /→\|number/ contained
syn match i3ConfigAssign /^assign .*$/ contains=i3ConfigAssignKeyword,i3ConfigAssignSpecial,i3ConfigCondition,i3ConfigVariable,i3ConfigString,i3ConfigNumber

" 4.20 Executing shell commands
syn keyword i3ConfigExecKeyword exec contained
syn keyword i3ConfigExecAlwaysKeyword exec_always contained
syn match i3ConfigShCmdDelim /\$(/ contained
syn region i3ConfigShCommand start=/\$(/ end=/)/ contained contains=i3ConfigShCmdDelim,i3ConfigExecAction,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigString,i3ConfigNumber,i3ConfigVariable keepend extend
syn match  i3ConfigShDelim /[[\]{}();`]\+/ contained
syn match  i3ConfigShOper /[<>&|+=~^*!.?]\+/ contained
syn match i3ConfigShParam /\<-[0-9A-Za-z_-]\+\>/ contained containedin=i3ConfigVar
syn region i3ConfigExec start=/^\s*exec\(_always\)\?\( --no-startup-id\)\? [^{]/ skip=/\\$/ end=/$/ contains=i3ConfigExecKeyword,i3ConfigExecAlwaysKeyword,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigString,i3ConfigVariable,i3ConfigExecAction keepend

" 4.21 Workspaces per output
syn keyword i3ConfigWorkspaceKeyword workspace contained
syn keyword i3ConfigWorkspaceOutput output contained
syn keyword i3ConfigWorkspaceDir prev next back_and_forth number contained
syn region i3ConfigWorkspaceLine start=/^workspace / skip=/\\$/ end=/$/ contains=i3ConfigWorkspaceKeyword,i3ConfigNumber,i3ConfigString,i3ConfigGaps,i3ConfigWorkspaceOutput,i3ConfigVariable,i3ConfigBoolean,i3ConfigSeparator keepend

" 4.22 Changing colors
syn match i3ConfigDotOperator /\./ contained
syn keyword i3ConfigClientOpts focused focused_inactive unfocused urgent placeholder background contained
syn match i3ConfigKeyword /^client\..*$/ contains=i3ConfigDotOperator,i3ConfigClientOpts,i3ConfigColor,i3ConfigVariable

" 4.23 Interprocess communication
syn match i3ConfigIpcKeyword /ipc-socket/ contained
syn match i3ConfigParamLine /^ipc-socket .*$/ contains=i3ConfigIpcKeyword

" 4.24 Focus follows mouse
syn match i3ConfigKeyword /^focus_follows_mouse \(yes\|no\)$/ contains=i3ConfigBoolean

" 4.25 Mouse warping
syn keyword i3ConfigMouseWarpingOpts output container none contained
syn match i3ConfigKeyword /^mouse_warping \w*$/ contains=i3ConfigMouseWarpingOpts

" 4.26 Popups while fullscreen
syn keyword i3ConfigPopupFullscreenOpts smart ignore leave_fullscreen contained
syn match i3ConfigKeyword /^popup_during_fullscreen \w*$/ contains=i3ConfigPopupFullscreenOpts

" 4.27 Focus wrapping
syn keyword i3ConfigFocusWrappingOpts force workspace contained
syn match i3ConfigKeyword /^focus_wrapping \(yes\|no\|force\|workspace\)$/ contains=i3ConfigBoolean,i3ConfigFocusWrappingOpts

" 4.28 Forcing Xinerama
syn match i3ConfigKeyword /^force_xinerama \(yes\|no\)$/ contains=i3ConfigBoolean

" 4.29 Automatic workspace back-and-forth
syn match i3ConfigKeyword /^workspace_auto_back_and_forth \(yes\|no\)$/ contains=i3ConfigBoolean

" 4.30 Delay urgency hint
syn keyword i3ConfigTimeUnit ms contained
syn match i3ConfigKeyword /^force_display_urgency_hint \d\+\( ms\)\?$/ contains=i3ConfigNumber,i3ConfigTimeUnit

" 4.31 Focus on window activation
syn keyword i3ConfigFocusOnActivationOpts smart urgent focus none contained
syn match i3ConfigKeyword /^focus_on_window_activation \w*$/  contains=i3ConfigFocusOnActivationOpts

" 4.32 Show marks in title
syn match i3ConfigShowMarks /^show_marks \(yes\|no\)$/ contains=i3ConfigBoolean

" 4.34 Tiling drag
syn keyword i3ConfigTilingDragOpts modifier titlebar contained
syn match i3ConfigKeyword /^tiling_drag\( off\|\( modifier\| titlebar\)\{1,2\}\)$/ contains=i3ConfigTilingDragOpts,i3ConfigBoolean

" 4.35 Gaps
syn keyword i3ConfigGapsOpts inner outer horizontal vertical left right top bottom current all set plus minus toggle contained
syn region i3ConfigGaps start=/gaps/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigGapsOpts,i3ConfigNumber,i3ConfigVariable,i3ConfigSeparator keepend
syn match i3ConfigGapsLine /^gaps .*$/ contains=i3ConfigGaps
syn keyword i3ConfigSmartGapOpts inverse_outer contained
syn match i3ConfigKeyword /^smart_gaps \(on\|off\|inverse_outer\)$/ contains=i3ConfigSmartGapOpts,i3ConfigBoolean

" 5 Configuring bar
syn match i3ConfigBarModifier /^\s\+modifier \S\+$/ contained contains=i3ConfigBindModifier,i3ConfigVariable,i3ConfigBindModkey,i3ConfigBarOptVals
syn keyword i3ConfigBarOpts bar i3bar_command status_command workspace_command mode hidden_state id position output tray_output tray_padding separator_symbol workspace_buttons workspace_min_width strip_workspace_numbers strip_workspace_name binding_mode_indicator padding contained
syn keyword i3ConfigBarOptVals dock hide invisible show none top bottom primary nonprimary contained
syn region i3ConfigBarBlock start=/^bar {$/ end=/^}$/ contains=i3ConfigBarOpts,i3ConfigBarOptVals,i3ConfigBarModifier,i3ConfigBind,i3ConfigString,i3ConfigComment,i3ConfigFont,i3ConfigBoolean,i3ConfigNumber,i3ConfigParen,i3ConfigColor,i3ConfigVariable,i3ConfigColorsBlock,i3ConfigShOper,i3ConfigShCommand fold keepend extend

" 5.16 Color block
syn keyword i3ConfigColorsKeyword colors contained
syn match i3ConfigColorsOpts /\(focused_\)\?\(background\|statusline\|separator\)\|\(focused\|active\|inactive\|urgent\)_workspace\|binding_mode/ contained
syn region i3ConfigColorsBlock start=/^\s\+colors {$/ end=/^\s\+}$/ contained contains=i3ConfigColorsKeyword,i3ConfigColorsOpts,i3ConfigColor,i3ConfigVariable,i3ConfigComment,i3ConfigParen fold keepend extend

" 6.0 Command criteria
syn keyword i3ConfigConditionProp class instance window_role window_type machine id title urgent workspace con_mark con_id floating_from tiling_from contained
syn keyword i3ConfigConditionSpecial __focused__ all floating tiling contained
syn region i3ConfigCondition start=/\[/ end=/\]/ contained contains=i3ConfigShDelim,i3ConfigConditionProp,i3ConfigShOper,i3ConfigConditionSpecial,i3ConfigNumber,i3ConfigString keepend extend
syn region i3ConfigCriteria start=/\[/ skip=/\\$/ end=/\(;\|$\)/ contained contains=i3ConfigCondition,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,i3ConfigBoolean,i3ConfigNumber,i3ConfigVariable,i3ConfigSeparator keepend transparent

" 6.1 Actions through shell
syn match i3ConfigExecActionKeyword /i3-msg/ contained
syn region i3ConfigExecAction start=/[a-z3-]\+msg "/ skip=/ "\|\\$/ end=/"\|$/ contained contains=i3ConfigExecActionKeyword,i3ConfigShCommand,i3ConfigNumber,i3ConfigShOper,i3ConfigCriteria,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,i3ConfigVariable keepend extend
syn region i3ConfigExecAction start=/[a-z3-]\+msg '/ skip=/ '\|\\$/ end=/'\|$/ contained contains=i3ConfigExecActionKeyword,i3ConfigShCommand,i3ConfigNumber,i3ConfigShOper,i3ConfigCriteria,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,i3ConfigVariable keepend extend
syn region i3ConfigExecAction start=/[a-z3-]\+msg ['"-]\@!/ skip=/\\$/ end=/[&|;})'"]\@=\|$/ contained contains=i3ConfigExecActionKeyword,i3ConfigShCommand,i3ConfigNumber,i3ConfigShOper,i3ConfigCriteria,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,i3ConfigVariable keepend extend
" 6.1 Executing applications (4.20)
syn region i3ConfigAction start=/exec/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigExecKeyword,i3ConfigExecAction,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigString,i3ConfigVariable,i3ConfigSeparator keepend

" 6.3 Manipulating layout
syn keyword i3ConfigLayoutKeyword layout contained
syn keyword i3ConfigLayoutOpts default tabbed stacking splitv splith toggle split all contained
syn region i3ConfigAction start=/layout/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigLayoutKeyword,i3ConfigLayoutOpts,i3ConfigSeparator keepend transparent

" 6.4 Focusing containers
syn keyword i3ConfigFocusKeyword focus contained
syn keyword i3ConfigFocusOpts left right up down workspace parent child next prev sibling floating tiling mode_toggle contained
syn keyword i3ConfigFocusOutputOpts left right down up current primary nonprimary next prev contained
syn region i3ConfigFocusOutput start=/ output / skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigWorkspaceOutput,i3ConfigFocusOutputOpts,i3ConfigString,i3ConfigNumber,i3ConfigSeparator keepend
syn match i3ConfigFocusOutputLine /^focus output .*$/ contains=i3ConfigFocusKeyword,i3ConfigFocusOutput
syn region i3ConfigAction start=/focus/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigFocusKeyword,i3ConfigFocusOpts,i3ConfigFocusOutput,i3ConfigString,i3ConfigSeparator keepend transparent

" 6.8 Focusing workspaces (4.21)
syn region i3ConfigAction start=/workspace / skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigWorkspaceKeyword,i3ConfigWorkspaceDir,i3ConfigNumber,i3ConfigString,i3ConfigGaps,i3ConfigWorkspaceOutput,i3ConfigVariable,i3ConfigBoolean,i3ConfigSeparator keepend transparent

" 6.8.2 Renaming workspaces
syn keyword i3ConfigRenameKeyword rename contained
syn region i3ConfigAction start=/rename workspace/ end=/[,;]\|$/ contained contains=i3ConfigRenameKeyword,i3ConfigMoveDir,i3ConfigMoveType,i3ConfigNumber,i3ConfigVariable,i3ConfigString keepend transparent

" 6.5,6.9-6.11 Moving containers
syn keyword i3ConfigMoveKeyword move contained
syn keyword i3ConfigMoveDir left right down up position absolute center to current contained
syn keyword i3ConfigMoveType window container workspace output mark mouse scratchpad contained
syn match i3ConfigUnit / px\| ppt/ contained
syn region i3ConfigAction start=/move/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigMoveKeyword,i3ConfigMoveDir,i3ConfigMoveType,i3ConfigWorkspaceDir,i3ConfigUnit,i3ConfigNumber,i3ConfigVariable,i3ConfigString,i3ConfigSeparator,i3ConfigShParam keepend transparent

" 6.12 Resizing containers/windows
syn keyword i3ConfigResizeKeyword resize contained
syn keyword i3ConfigResizeOpts grow shrink up down left right set width height or contained
syn region i3ConfigAction start=/resize/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigResizeKeyword,i3ConfigResizeOpts,i3ConfigNumber,i3ConfigUnit,i3ConfigSeparator keepend transparent

" 6.14 VIM-like marks
syn match i3ConfigMark /mark\( --\(add\|replace\)\( --toggle\)\?\)\?/ contained contains=i3ConfigShParam
syn region i3ConfigAction start=/\<mark/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigMark,i3ConfigNumber,i3ConfigString,i3ConfigSeparator keepend transparent

" 6.24 Changing gaps (4.35)
syn region i3ConfigAction start=/gaps/ skip=/\\$/ end=/[,;]\|$/ contained contains=i3ConfigGaps keepend transparent

" Commands useable in keybinds
syn keyword i3ConfigActionKeyword mode append_layout kill open fullscreen sticky split floating swap unmark show_marks title_window_icon title_format border restart reload exit scratchpad nop bar contained
syn keyword i3ConfigOption default enable disable toggle key restore current horizontal vertical auto none normal pixel show container with id con_id padding hidden_state hide dock invisible contained

" Define the highlighting.
hi def link i3ConfigError                           Error
hi def link i3ConfigTodo                            Todo
hi def link i3ConfigKeyword                         Keyword
hi def link i3ConfigCommand                         Statement
hi def link i3ConfigParamLine                       i3ConfigString
hi def link i3ConfigOperator                        Operator
hi def link i3ConfigSeparator                       i3ConfigOperator
hi def link i3ConfigParen                           Delimiter
hi def link i3ConfigBoolean                         Boolean
hi def link i3ConfigString                          String
hi def link i3ConfigColor                           Constant
hi def link i3ConfigNumber                          Number
hi def link i3ConfigIncludeKeyword                  i3ConfigKeyword
hi def link i3ConfigComment                         Comment
hi def link i3ConfigFontKeyword                     i3ConfigKeyword
hi def link i3ConfigColonOperator                   i3ConfigOperator
hi def link i3ConfigFontNamespace                   i3ConfigOption
hi def link i3ConfigFontSize                        i3ConfigNumber
hi def link i3ConfigFont                            i3ConfigString
hi def link i3ConfigBindKeyword                     i3ConfigKeyword
hi def link i3ConfigBindArgument                    i3ConfigShParam
hi def link i3ConfigBindModifier                    i3ConfigOperator
hi def link i3ConfigBindModkey                      Special
hi def link i3ConfigBindCombo                       SpecialChar
hi def link i3ConfigSizeSpecial                     i3ConfigOperator
hi def link i3ConfigOrientationOpts                 i3ConfigOption
hi def link i3ConfigWorkspaceLayoutOpts             i3ConfigOption
hi def link i3ConfigTitleAlignOpts                  i3ConfigOption
hi def link i3ConfigBorderOpts                      i3ConfigOption
hi def link i3ConfigEdgeOpts                        i3ConfigOption
hi def link i3ConfigSmartBorderOpts                 i3ConfigOption
hi def link i3ConfigVariable                        Variable
hi def link i3ConfigSetKeyword                      i3ConfigKeyword
hi def link i3ConfigResourceKeyword                 i3ConfigKeyword
hi def link i3ConfigAssignKeyword                   i3ConfigKeyword
hi def link i3ConfigAssignSpecial                   i3ConfigOption
hi def link i3ConfigExecKeyword                     i3ConfigCommand
hi def link i3ConfigExecAlwaysKeyword               i3ConfigKeyword
hi def link i3ConfigShParam                         PreProc
hi def link i3ConfigShDelim                         Delimiter
hi def link i3ConfigShOper                          Operator
hi def link i3ConfigShCmdDelim                      i3ConfigShDelim
hi def link i3ConfigShCommand                       Normal
hi def link i3ConfigWorkspaceKeyword                i3ConfigCommand
hi def link i3ConfigWorkspaceOutput                 i3ConfigMoveType
hi def link i3ConfigWorkspaceDir                    i3ConfigOption
hi def link i3ConfigDotOperator                     i3ConfigOperator
hi def link i3ConfigClientOpts                      i3ConfigOption
hi def link i3ConfigIpcKeyword                      i3ConfigKeyword
hi def link i3ConfigMouseWarpingOpts                i3ConfigOption
hi def link i3ConfigPopupFullscreenOpts             i3ConfigOption
hi def link i3ConfigFocusWrappingOpts               i3ConfigOption
hi def link i3ConfigTimeUnit                        i3ConfigNumber
hi def link i3ConfigFocusOnActivationOpts           i3ConfigOption
hi def link i3ConfigShowMarks                       i3ConfigCommand
hi def link i3ConfigTilingDragOpts                  i3ConfigOption
hi def link i3ConfigGapsOpts                        i3ConfigOption
hi def link i3ConfigGaps                            i3ConfigCommand
hi def link i3ConfigSmartGapOpts                    i3ConfigOption
hi def link i3ConfigBarModifier                     i3ConfigKeyword
hi def link i3ConfigBarOpts                         i3ConfigKeyword
hi def link i3ConfigBarOptVals                      i3ConfigOption
hi def link i3ConfigColorsKeyword                   i3ConfigKeyword
hi def link i3ConfigColorsOpts                      i3ConfigOption
hi def link i3ConfigConditionProp                   i3ConfigShParam
hi def link i3ConfigConditionSpecial                Constant
hi def link i3ConfigExecActionKeyword               i3ConfigShCommand
hi def link i3ConfigExecAction                      i3ConfigString
hi def link i3ConfigLayoutKeyword                   i3ConfigCommand
hi def link i3ConfigLayoutOpts                      i3ConfigOption
hi def link i3ConfigFocusKeyword                    i3ConfigCommand
hi def link i3ConfigFocusOpts                       i3ConfigOption
hi def link i3ConfigFocusOutputOpts                 i3ConfigOption
hi def link i3ConfigRenameKeyword                   i3ConfigCommand
hi def link i3ConfigMoveKeyword                     i3ConfigCommand
hi def link i3ConfigMoveDir                         i3ConfigOption
hi def link i3ConfigMoveType                        Constant
hi def link i3ConfigUnit                            i3ConfigNumber
hi def link i3ConfigResizeKeyword                   i3ConfigCommand
hi def link i3ConfigResizeOpts                      i3ConfigOption
hi def link i3ConfigMark                            i3ConfigCommand
hi def link i3ConfigActionKeyword                   i3ConfigCommand
hi def link i3ConfigOption                          Type

let b:current_syntax = "i3config"
