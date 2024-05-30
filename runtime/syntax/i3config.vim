" Vim syntax file
" Language: i3 config file
" Original Author: Josef Litos (JosefLitos/i3config.vim)
" Maintainer: Quentin Hibon (github user hiqua)
" Version: 1.2.4
" Last Change: 2024-05-24

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
" String in simpler (matchable end) and more robust (includes `extend` keyword) forms
syn cluster i3ConfigStrIn contains=i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,@i3ConfigNumVar,i3ConfigExecAction
syn match i3ConfigString /\(["']\)[^\\"')\]}]*\1/ contained contains=@i3ConfigStrIn
syn region i3ConfigString start=/"[^\\"')\]}]*[\\')\]}]/ skip=/\\\@<=\("\|$\)/ end=/"\|$/ contained contains=@i3ConfigStrIn keepend extend
syn region i3ConfigString start=/'[^\\"')\]}]*[\\")\]}]/ skip=/\\\@<=$/ end=/'\|$/ contained contains=@i3ConfigStrIn keepend extend
syn match i3ConfigColor /#[0-9A-Fa-f]\{3,8}/ contained
syn match i3ConfigNumber /[0-9A-Za-z_$-]\@<!-\?\d\+\w\@!/ contained
" Grouping of common usages
syn cluster i3ConfigStrVar contains=i3ConfigString,i3ConfigVariable
syn cluster i3ConfigNumVar contains=i3ConfigNumber,i3ConfigVariable
syn cluster i3ConfigColVar contains=i3ConfigColor,i3ConfigVariable
syn cluster i3ConfigIdent contains=i3ConfigString,i3ConfigNumber,i3ConfigVariable
syn cluster i3ConfigValue contains=@i3ConfigIdent,i3ConfigBoolean

" 4.1 Include directive
syn match i3ConfigIncludeCommand /`[^`]*`/ contained contains=@i3ConfigSh
syn region i3ConfigParamLine matchgroup=i3ConfigKeyword start=/include / end=/$/ contained contains=@i3ConfigStrVar,i3ConfigIncludeCommand,i3ConfigShOper keepend

" 4.2 Comments
syn match i3ConfigComment /#.*$/ contained contains=i3ConfigTodo

" 4.3 Fonts
syn match i3ConfigFontSize / \d\+\(px\)\?$/ contained
syn match i3ConfigColonOperator /:/ contained
syn match i3ConfigFontNamespace /pango:/ contained contains=i3ConfigColonOperator
syn region i3ConfigParamLine matchgroup=i3ConfigKeyword start=/font / skip=/\\$/ end=/$/ contained contains=i3ConfigFontNamespace,i3ConfigFontSize,i3ConfigSeparator keepend containedin=i3ConfigBarBlock

" 4.4-4.5 Keyboard/Mouse bindings
syn match i3ConfigBindArgument /--\(release\|border\|whole-window\|exclude-titlebar\) / contained nextgroup=i3ConfigBindArgument,i3ConfigBindCombo
syn match i3ConfigBindModifier /+/ contained
syn keyword i3ConfigBindModkey Ctrl Shift Mod1 Mod2 Mod3 Mod4 Mod5 contained
syn match i3ConfigBindCombo /[$0-9A-Za-z_+]\+/ contained contains=i3ConfigBindModifier,i3ConfigVariable,i3ConfigBindModkey nextgroup=i3ConfigBind
syn cluster i3ConfigBinder contains=i3ConfigCriteria,@i3ConfigCommand,i3ConfigSeparator
syn region i3ConfigBind start=/\zs/ skip=/\\$/ end=/$/ contained contains=@i3ConfigBinder keepend
syn keyword i3ConfigBindKeyword bindsym bindcode contained skipwhite nextgroup=i3ConfigBindArgument,i3ConfigBindCombo

" 4.6 Binding modes
syn region i3ConfigModeBlock matchgroup=i3ConfigKeyword start=/mode\ze\( --pango_markup\)\? \([^'" {]\+\|'[^']\+'\|".\+"\)\s\+{$/ end=/^}\zs$/ contained contains=i3ConfigShParam,@i3ConfigStrVar,i3ConfigBindKeyword,i3ConfigComment,i3ConfigParen fold keepend extend

" 4.7 Floating modifier
syn match i3ConfigKeyword /floating_modifier [$A-Z][0-9A-Za-z]*$/ contained contains=i3ConfigVariable,i3ConfigBindModkey

" 4.8 Floating window size
syn keyword i3ConfigSizeSpecial x contained
syn match i3ConfigSize /-\?\d\+ x -\?\d\+/ contained contains=i3ConfigSizeSpecial,i3ConfigNumber
syn keyword i3ConfigKeyword floating_maximum_size floating_minimum_size contained skipwhite nextgroup=i3ConfigSize

" 4.9 Orientation
syn keyword i3ConfigOrientationOpts vertical horizontal auto contained
syn keyword i3ConfigKeyword default_orientation contained skipwhite nextgroup=i3ConfigOrientationOpts

" 4.10 Layout mode
syn keyword i3ConfigWorkspaceLayoutOpts default stacking tabbed contained
syn keyword i3ConfigKeyword workspace_layout contained skipwhite nextgroup=i3ConfigWorkspaceLayoutOpts

" 4.11 Title alignment
syn keyword i3ConfigTitleAlignOpts left center right contained
syn keyword i3ConfigKeyword title_align contained skipwhite nextgroup=i3ConfigTitleAlignOpts

" 4.12 Border size
syn keyword i3ConfigBorderOpts none normal pixel contained skipwhite nextgroup=@i3ConfigNumVar
syn keyword i3ConfigKeyword default_floating_border default_border contained skipwhite nextgroup=i3ConfigBorderOpts

" 4.13 Hide edge borders
syn keyword i3ConfigEdgeOpts none vertical horizontal both smart smart_no_gaps contained
syn keyword i3ConfigKeyword hide_edge_borders contained skipwhite nextgroup=i3ConfigEdgeOpts

" 4.14 Smart Borders
syn keyword i3ConfigSmartBorderOpts no_gaps contained
syn keyword i3ConfigKeyword smart_borders contained skipwhite nextgroup=i3ConfigSmartBorderOpts,i3ConfigBoolean

" 4.15 Arbitrary commands
syn keyword i3ConfigKeyword for_window contained skipwhite nextgroup=i3ConfigCriteria

" 4.16 No opening focus
syn keyword i3ConfigKeyword no_focus contained skipwhite nextgroup=i3ConfigCondition

" 4.17 Variables
syn match i3ConfigVariable /\$[0-9A-Za-z_:|[\]-]\+/
syn region i3ConfigSet start=/\$/ skip=/\\$/ end=/$/ contained contains=@i3ConfigSh,@i3ConfigValue,i3ConfigColor,i3ConfigBindModkey keepend
syn keyword i3ConfigKeyword set contained skipwhite nextgroup=i3ConfigSet

" 4.18 X resources
syn region i3ConfigParamLine matchgroup=i3ConfigKeyword start=/set_from_resource\ze \$/ end=/$/ contained contains=@i3ConfigColVar,i3ConfigDotOperator

" 4.19 Assign clients to workspaces
syn match i3ConfigAssignSpecial /→\|number/ contained
syn region i3ConfigKeyword start=/assign / end=/$/ contained contains=i3ConfigAssignSpecial,i3ConfigCondition,@i3ConfigIdent keepend

" 4.20 Executing shell commands
syn region i3ConfigShCommand matchgroup=i3ConfigShDelim start=/\$(/ end=/)/ contained contains=i3ConfigExecAction,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigString,i3ConfigNumber,i3ConfigVariable extend
syn match  i3ConfigShDelim /[[\]{}();`]\+/ contained
syn match  i3ConfigShOper /[<>&|+=~^*!.?]\+/ contained
syn match i3ConfigShParam /\<-[A-Za-z-][0-9A-Za-z_-]*\>/ contained
syn cluster i3ConfigSh contains=@i3ConfigIdent,i3ConfigShOper,i3ConfigShDelim,i3ConfigShParam,i3ConfigShCommand
syn region i3ConfigExec start=/ \ze[^{]/ skip=/\\$/ end=/$/ contained contains=i3ConfigExecAction,@i3ConfigSh keepend
syn keyword i3ConfigKeyword exec_always exec contained nextgroup=i3ConfigExec

" 4.21 Workspaces per output
syn match i3ConfigOutputIdent /[^'",; ]\+/ contained contains=@i3ConfigIdent,i3ConfigColonOperator skipwhite nextgroup=i3ConfigOutputIdent
syn region i3ConfigOutputIdent start=/['"]/ end=/\ze/ contained contains=@i3ConfigIdent skipwhite nextgroup=i3ConfigOutputIdent
syn keyword i3ConfigOutput output contained skipwhite nextgroup=i3ConfigOutputIdent
syn match i3ConfigWorkspaceIdent /[^'",; ]\+/ contained contains=@i3ConfigIdent skipwhite nextgroup=i3ConfigGaps,i3ConfigOutput
syn region i3ConfigWorkspaceIdent start=/['"]/ end=/\ze/ contained contains=@i3ConfigIdent skipwhite nextgroup=i3ConfigGaps,i3ConfigOutput
syn keyword i3ConfigKeyword workspace contained skipwhite nextgroup=i3ConfigWorkspaceIdent

" 4.22 Changing colors
syn keyword i3ConfigClientOpts focused focused_inactive focused_tab_title unfocused urgent placeholder background contained skipwhite nextgroup=i3ConfigColorSeq
syn match i3ConfigDotOperator /\./ contained nextgroup=i3ConfigClientOpts
syn keyword i3ConfigKeyword client contained nextgroup=i3ConfigDotOperator

" 4.23 Interprocess communication
syn region i3ConfigParamLine matchgroup=i3ConfigKeyword start=/ipc-socket / end=/$/ contained contains=i3ConfigNumber,i3ConfigShOper

" 4.24 Focus follows mouse
syn keyword i3ConfigFocusFollowsMouseOpts always contained
syn keyword i3ConfigKeyword focus_follows_mouse contained skipwhite nextgroup=i3ConfigBoolean,i3ConfigFocusFollowsMouseOpts

" 4.25 Mouse warping
syn keyword i3ConfigMouseWarpingOpts output container none contained
syn keyword i3ConfigKeyword mouse_warping contained skipwhite nextgroup=i3ConfigMouseWarpingOpts

" 4.26 Popups while fullscreen
syn keyword i3ConfigPopupFullscreenOpts smart ignore leave_fullscreen contained
syn keyword i3ConfigKeyword popup_during_fullscreen contained skipwhite nextgroup=i3ConfigPopupFullscreenOpts

" 4.27 Focus wrapping
syn keyword i3ConfigFocusWrappingOpts force workspace contained
syn keyword i3ConfigKeyword focus_wrapping contained skipwhite nextgroup=i3ConfigBoolean,i3ConfigFocusWrappingOpts

" 4.28 Forcing Xinerama
" 4.29 Automatic workspace back-and-forth
" 4.32 Show marks in title
syn keyword i3ConfigKeyword force_xinerama workspace_auto_back_and_forth show_marks contained skipwhite nextgroup=i3ConfigBoolean

" 4.30 Delay urgency hint
syn match i3ConfigTimeUnit / \d\+\( ms\)\?$/ contained contains=i3ConfigNumber
syn keyword i3ConfigKeyword force_display_urgency_hint contained nextgroup=i3ConfigTimeUnit

" 4.31 Focus on window activation
syn keyword i3ConfigFocusOnActivationOpts smart urgent focus none contained
syn keyword i3ConfigKeyword focus_on_window_activation contained skipwhite nextgroup=i3ConfigFocusOnActivationOpts

" 4.34 Tiling drag
syn keyword i3ConfigTilingDragOpts modifier titlebar contained skipwhite nextgroup=i3ConfigTilingDragOpts
syn keyword i3ConfigKeyword tiling_drag contained skipwhite nextgroup=i3ConfigTilingDragOpts,i3ConfigBoolean

" 4.35 Gaps (+6.24)
syn keyword i3ConfigGapsWhich inner outer horizontal vertical left right top bottom contained skipwhite nextgroup=i3ConfigGapsWhere,@i3ConfigNumVar
syn keyword i3ConfigGapsWhere current all contained skipwhite nextgroup=i3ConfigGapsOper
syn keyword i3ConfigGapsOper set plus minus toggle contained skipwhite nextgroup=@i3ConfigNumVar
syn match i3ConfigGaps /gaps/ contained contains=i3ConfigCommand skipwhite nextgroup=i3ConfigGapsWhich
syn keyword i3ConfigCommand gaps contained skipwhite nextgroup=i3ConfigGapsWhich

syn keyword i3ConfigSmartGapOpts inverse_outer toggle contained
syn keyword i3ConfigKeyword smart_gaps contained skipwhite nextgroup=i3ConfigSmartGapOpts,i3ConfigBoolean

" 5 Configuring bar
syn keyword i3ConfigBarOpts modifier contained skipwhite nextgroup=i3ConfigBindCombo,i3ConfigBarOptVals
syn keyword i3ConfigBarOpts i3bar_command status_command workspace_command contained skipwhite nextgroup=@i3ConfigSh
syn keyword i3ConfigBarOpts mode hidden_state id position output tray_output tray_padding separator_symbol workspace_buttons workspace_min_width strip_workspace_numbers strip_workspace_name binding_mode_indicator padding contained skipwhite nextgroup=i3ConfigBarOptVals,@i3ConfigValue,i3ConfigShOper
syn keyword i3ConfigBarOptVals dock hide invisible show none top bottom primary nonprimary contained
syn region i3ConfigBarBlock matchgroup=i3ConfigKeyword start=/bar\ze {$/ end=/^\s*}\zs$/ contained contains=i3ConfigBarOpts,i3ConfigComment,i3ConfigParen,i3ConfigBindKeyword,i3ConfigColorsBlock fold keepend extend

" 5.16 Color block
syn match i3ConfigColorSeq /#[0-9A-Fa-f]\{3,8}\|\$[0-9A-Za-z_:|[\]-]\+/ contained contains=@i3ConfigColVar skipwhite nextgroup=i3ConfigColorSeq
syn keyword i3ConfigColorsOpts background statusline separator contained skipwhite nextgroup=@i3ConfigColVar
syn match i3ConfigColorsOpts /focused_\(background\|statusline\|separator\)\|\(focused\|active\|inactive\|urgent\)_workspace\|binding_mode/ contained skipwhite nextgroup=i3ConfigColorSeq
syn region i3ConfigColorsBlock matchgroup=i3ConfigKeyword start=/^\s\+colors \ze{$/ end=/^\s\+}\zs$/ contained contains=i3ConfigColorsOpts,i3ConfigComment,i3ConfigParen fold keepend extend

" 6.0 Command criteria
syn keyword i3ConfigConditionProp class instance window_role window_type machine id title urgent workspace con_mark con_id floating_from tiling_from contained
syn keyword i3ConfigConditionSpecial __focused__ all floating tiling contained
syn region i3ConfigCondition matchgroup=i3ConfigShDelim start=/\[/ end=/\]/ contained contains=i3ConfigConditionProp,i3ConfigShOper,i3ConfigConditionSpecial,@i3ConfigIdent keepend extend
syn region i3ConfigCriteria start=/\[/ skip=/\\$/ end=/\(;\|$\)/ contained contains=i3ConfigCondition,@i3ConfigCommand,i3ConfigSeparator keepend transparent

" 6.1 Actions through shell
syn match i3ConfigExecActionKeyword /i3-msg/ contained
syn cluster i3ConfigExecActionVal contains=i3ConfigExecActionKeyword,i3ConfigCriteria,i3ConfigAction,i3ConfigActionKeyword,i3ConfigOption,@i3ConfigNumVar
syn region i3ConfigExecAction start=/[a-z3-]\+msg "/ skip=/ "\|\\$/ end=/"\|$/ contained contains=i3ConfigExecActionKeyword,@i3ConfigExecActionVal keepend extend
syn region i3ConfigExecAction start=/[a-z3-]\+msg '/ skip=/ '\|\\$/ end=/'\|$/ contained contains=i3ConfigExecActionKeyword,@i3ConfigExecActionVal keepend extend
syn region i3ConfigExecAction start=/[a-z3-]\+msg ['"-]\@!/ skip=/\\$/ end=/[&|;})'"]\@=\|$/ contained contains=i3ConfigExecActionKeyword,@i3ConfigExecActionVal keepend extend
" 6.1 Executing applications (4.20)
syn region i3ConfigAction matchgroup=i3ConfigCommand start=/exec / skip=/\\$/ end=/\ze[,;]\|$/ contained contains=i3ConfigExecAction,@i3ConfigSh keepend

" 6.3 Manipulating layout
syn keyword i3ConfigLayoutOpts default tabbed stacking splitv splith toggle split all contained
syn region i3ConfigAction matchgroup=i3ConfigCommand start=/layout / skip=/\\$/ end=/\ze[,;]\|$/ contained contains=i3ConfigLayoutOpts keepend transparent

" 6.4 Focusing containers
syn keyword i3ConfigFocusOpts left right up down parent child next prev sibling floating tiling mode_toggle contained
syn keyword i3ConfigOutputDir left right down up current primary nonprimary next prev contained skipwhite
syn keyword i3ConfigFocusOutput output contained skipwhite nextgroup=i3ConfigOutputIdent,i3ConfigOutputDir
syn keyword i3ConfigActionKeyword focus contained skipwhite nextgroup=i3ConfigFocusOpts,i3ConfigFocusOutput
syn keyword i3ConfigKeyword focus skipwhite contained nextgroup=i3ConfigFocusOutput

" 6.8 Focusing workspaces (4.21)
syn keyword i3ConfigWorkspaceDir prev next back_and_forth contained
syn keyword i3ConfigWorkspaceDir number contained skipwhite nextgroup=i3ConfigWorkspaceIdent
syn keyword i3ConfigActionKeyword workspace contained skipwhite nextgroup=i3ConfigWorkspaceDir,i3ConfigWorkspaceIdent

" 6.8.2 Renaming workspaces
syn region i3ConfigWorkspaceFromTo start=/workspace\( .*\)\? to/ end=/\ze[,;]\|$/ contained contains=i3ConfigMoveType,@i3ConfigWorkspaceIdent keepend transparent
syn keyword i3ConfigActionKeyword rename contained skipwhite nextgroup=i3ConfigWorkspaceFromTo

" 6.5,6.9-6.11 Moving containers
syn match i3ConfigUnit /-\?\d\+\( px\| ppt\)\?/ contained contains=i3ConfigNumber skipwhite nextgroup=i3ConfigUnit,i3ConfigResizeExtra
syn keyword i3ConfigMoveDir left right down up position contained skipwhite nextgroup=i3ConfigUnit
syn match i3ConfigMoveDir /position \(mouse\|center\)/ contained
syn keyword i3ConfigMoveDir absolute contained skipwhite nextgroup=i3ConfigMoveDir
syn keyword i3ConfigMoveDir absolute contained

syn keyword i3ConfigMoveType mark contained skipwhite nextgroup=i3ConfigOutputIdent
syn keyword i3ConfigMoveType scratchpad contained
syn keyword i3ConfigMoveType output contained skipwhite nextgroup=i3ConfigOutputIdent,i3ConfigOutputDir
syn keyword i3ConfigMoveType workspace contained skipwhite nextgroup=i3ConfigMoveType,i3ConfigWorkspaceIdent,i3ConfigWorkspaceDir
syn keyword i3ConfigMoveType window container contained skipwhite nextgroup=i3ConfigMoveType
syn keyword i3ConfigMoveTo to contained
syn match i3ConfigMoveType /to/ contained contains=i3ConfigMoveTo skipwhite nextgroup=i3ConfigMoveType
syn match i3ConfigActionKeyword /move\( --no-auto-back-and-forth\)\?/ contained contains=i3ConfigShParam skipwhite nextgroup=i3ConfigMoveType,i3ConfigMoveDir

" 6.12 Resizing containers/windows
syn keyword i3ConfigResizeExtra or height contained skipwhite nextgroup=i3ConfigUnit
syn keyword i3ConfigResizeDir up down left right width height contained skipwhite nextgroup=i3ConfigUnit
syn keyword i3ConfigResizeType grow shrink contained skipwhite nextgroup=i3ConfigResizeDir
syn keyword i3ConfigResizeType set contained skipwhite nextgroup=i3ConfigResizeDir,i3ConfigUnit
syn keyword i3ConfigActionKeyword resize contained skipwhite nextgroup=i3ConfigResizeType

" 6.14 VIM-like marks
syn match i3ConfigMarkOpt /--\(add\|replace\)\( --toggle\)\?/ contained contains=i3ConfigShParam skipwhite nextgroup=i3ConfigOutputIdent
syn keyword i3ConfigActionKeyword mark contained skipwhite nextgroup=i3ConfigMarkOpt,i3ConfigOutputIdent

" Commands usable for direct config calls - for enforcing start of line for Commands
syn match i3ConfigTopLevelDirective /^\s*/ nextgroup=i3ConfigComment,i3ConfigKeyword,i3ConfigCommand,i3ConfigBindKeyword,i3ConfigParamLine,i3ConfigModeBlock,i3ConfigBarBlock,i3ConfigError

" Commands useable in keybinds
syn keyword i3ConfigActionKeyword mode append_layout kill open fullscreen sticky split floating swap unmark title_window_icon title_format border restart reload exit scratchpad nop bar contained skipwhite nextgroup=i3ConfigOption,@i3ConfigValue
syn keyword i3ConfigOption default enable disable toggle key restore current horizontal vertical auto none normal pixel show container with id con_id padding hidden_state hide dock invisible contained skipwhite nextgroup=i3ConfigOption,@i3ConfigValue
" Commands usable at runtime (outside loading config)
syn cluster i3ConfigCommand contains=i3ConfigCommand,i3ConfigAction,i3ConfigActionKeyword,@i3ConfigValue,i3ConfigColor

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
hi def link i3ConfigComment                         Comment
hi def link i3ConfigColonOperator                   i3ConfigOperator
hi def link i3ConfigFontNamespace                   i3ConfigOption
hi def link i3ConfigFontSize                        i3ConfigNumber
hi def link i3ConfigBindArgument                    i3ConfigShParam
hi def link i3ConfigBindModifier                    i3ConfigOperator
hi def link i3ConfigBindModkey                      Special
hi def link i3ConfigBindCombo                       SpecialChar
hi def link i3ConfigBindKeyword                     i3ConfigKeyword
hi def link i3ConfigSizeSpecial                     i3ConfigOperator
hi def link i3ConfigOrientationOpts                 i3ConfigOption
hi def link i3ConfigWorkspaceLayoutOpts             i3ConfigOption
hi def link i3ConfigTitleAlignOpts                  i3ConfigOption
hi def link i3ConfigBorderOpts                      i3ConfigOption
hi def link i3ConfigEdgeOpts                        i3ConfigOption
hi def link i3ConfigSmartBorderOpts                 i3ConfigOption
hi def link i3ConfigVariable                        Variable
hi def link i3ConfigAssignSpecial                   i3ConfigOption
hi def link i3ConfigShParam                         PreProc
hi def link i3ConfigShDelim                         Delimiter
hi def link i3ConfigShOper                          Operator
hi def link i3ConfigShCommand                       Normal
hi def link i3ConfigOutputIdent                     i3ConfigParamLine
hi def link i3ConfigOutput                          i3ConfigMoveType
hi def link i3ConfigWorkspaceIdent                  i3ConfigParamLine
hi def link i3ConfigDotOperator                     i3ConfigOperator
hi def link i3ConfigClientOpts                      i3ConfigOption
hi def link i3ConfigFocusFollowsMouseOpts           i3ConfigOption
hi def link i3ConfigMouseWarpingOpts                i3ConfigOption
hi def link i3ConfigPopupFullscreenOpts             i3ConfigOption
hi def link i3ConfigFocusWrappingOpts               i3ConfigOption
hi def link i3ConfigTimeUnit                        i3ConfigNumber
hi def link i3ConfigFocusOnActivationOpts           i3ConfigOption
hi def link i3ConfigTilingDragOpts                  i3ConfigOption
hi def link i3ConfigGapsWhich                       i3ConfigOption
hi def link i3ConfigGapsWhere                       i3ConfigOption
hi def link i3ConfigGapsOper                        i3ConfigOption
hi def link i3ConfigSmartGapOpts                    i3ConfigOption
hi def link i3ConfigBarModifier                     i3ConfigKeyword
hi def link i3ConfigBarOpts                         i3ConfigKeyword
hi def link i3ConfigBarOptVals                      i3ConfigOption
hi def link i3ConfigColorsOpts                      i3ConfigOption
hi def link i3ConfigConditionProp                   i3ConfigShParam
hi def link i3ConfigConditionSpecial                Constant
hi def link i3ConfigExecActionKeyword               i3ConfigShCommand
hi def link i3ConfigExecAction                      i3ConfigString
hi def link i3ConfigLayoutOpts                      i3ConfigOption
hi def link i3ConfigFocusOpts                       i3ConfigOption
hi def link i3ConfigOutputDir                       i3ConfigOption
hi def link i3ConfigFocusOutput                     i3ConfigOutput
hi def link i3ConfigWorkspaceDir                    i3ConfigOption
hi def link i3ConfigMoveDir                         i3ConfigOption
hi def link i3ConfigMoveType                        Constant
hi def link i3ConfigMoveTo                          i3ConfigOption
hi def link i3ConfigUnit                            i3ConfigNumber
hi def link i3ConfigResizeExtra                     i3ConfigOption
hi def link i3ConfigResizeDir                       i3ConfigOption
hi def link i3ConfigResizeType                      i3ConfigOption
hi def link i3ConfigMark                            i3ConfigCommand
hi def link i3ConfigActionKeyword                   i3ConfigCommand
hi def link i3ConfigOption                          Type

let b:current_syntax = "i3config"
