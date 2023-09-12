" Vim syntax file
" Language: i3 config file
" Original Author: Mohamed Boughaba <mohamed dot bgb at gmail dot com>
" Maintainer: Quentin Hibon (github user hiqua)
" Version: 0.4.22
" Reference version (JosefLitos/i3config.vim): 4.22
" Last Change: 2023-09-09

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

" Comment
" Comments are started with a # and can only be used at the beginning of a line
syn match i3ConfigComment /^\s*#.*$/ contains=i3ConfigTodo

syn match i3ConfigOperator /[,;:]/ contained
syn match i3ConfigParen /[{}]/ contained

" Font
" A FreeType font description is composed by:
" a font family, a style, a weight, a variant, a stretch and a size.
syn keyword i3ConfigFontKeyword font contained
syn match i3ConfigFontNamespace /\w\+:/ contained contains=i3ConfigOperator
syn match i3ConfigFontContent /-\?\w\+\(-\+\|\s\+\|,\)/ contained contains=i3ConfigFontNamespace,i3ConfigFontKeyword,i3ConfigOperator
syn match i3ConfigFontSize /\s\=\d\+\(px\)\?\s\?$/ contained
syn match i3ConfigFont /^\s*font\s\+.*$/ contains=i3ConfigFontContent,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+.*\(\\\_.*\)\?$/ contains=i3ConfigFontContent,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+.*\(\\\_.*\)\?[^\\]\+$/ contains=i3ConfigFontContent,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+\(\(.*\\\_.*\)\|\(.*[^\\]\+$\)\)/ contains=i3ConfigFontContent,i3ConfigFontSize,i3ConfigFontNamespace

" Common value types
syn keyword i3ConfigBoolean yes no enabled disabled on off true false contained
syn region i3ConfigString start=/"/ skip=/\\"/ end=/"/ contained contains=i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigVariable keepend extend
syn region i3ConfigString start=/'/ end=/'/ contained contains=i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigVariable keepend extend
syn match i3ConfigColor /#\w\{3,8}/ contained
syn match i3ConfigNumber /\([a-zA-Z0-9_$]\)\@<!\d\+\([a-zA-Z0-9_$]\)\@!/ contained

" Variables
syn match i3ConfigVariable /\$[A-Z0-9a-z_:|[\]-]\+/
syn keyword i3ConfigSetKeyword set contained
syn match i3ConfigSet /^set \$.*$/ contains=i3ConfigVariable,i3ConfigSetKeyword,i3ConfigColor,i3ConfigString,i3ConfigNoStartupId,i3ConfigNumber,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShParam,i3ConfigShOper

" Include other config files
syn keyword i3ConfigIncludeKeyword include contained
syn match i3ConfigCommandSubstitutionRegion /`[^`]*`/ contained contains=i3ConfigShDelim,i3ConfigShParam,i3ConfigShOper,i3ConfigShCommand
syn match i3ConfigIncludePath /[~./a-zA-Z0-9`][^~]*$/ contained contains=i3ConfigCommandSubstitutionRegion
syn match i3ConfigInclude /^include .[^~]*$/ contains=i3ConfigIncludeKeyword,i3ConfigString,i3ConfigVariable,i3ConfigIncludePath

" Gaps
syn keyword i3ConfigGapStyleKeyword inner outer horizontal vertical top right bottom left current all set plus minus toggle up down contained
syn match i3ConfigGapStyle /^gaps \(inner\|outer\|horizontal\|vertical\|left\|top\|right\|bottom\)\(\s\+\(current\|all\)\)\?\(\s\+\(set\|plus\|minus\|toggle\)\)\?\(\s\+\(-\?\d\+\|\$.*\)\)$/ contains=i3ConfigGapStyleKeyword,i3ConfigNumber,i3ConfigVariable
syn keyword i3ConfigSmartGapKeyword on inverse_outer contained
syn match i3ConfigSmartGap /^smart_gaps \(on\|inverse_outer\)$/ contains=i3ConfigSmartGapKeyword
syn keyword i3ConfigSmartBorderKeyword on no_gaps contained
syn match i3ConfigSmartBorder /^smart_borders \(on\|no_gaps\)$/ contains=i3ConfigSmartBorderKeyword

" Commands useable in keybinds
syn keyword i3ConfigAction move exit restart reload layout append_layout workspace focus kill open fullscreen sticky split floating mark unmark resize rename scratchpad swap mode bar gaps border nop contained
syn keyword i3ConfigOption enable disable toggle mode_toggle key shrink grow height width restore container to left right up down position absolute relative window splitv splith tabbed stacked default on off inner outer current all set plus minus top bottom horizontal vertical auto none normal pixel prev next back_and_forth child parent show contained
syn match i3ConfigUnit /\sp\(pt\|x\)/ contained
syn match i3ConfigUnitOr /\sor/ contained

" Keyboard bindings
syn keyword i3ConfigBindKeyword bindsym bindcode contained
syn match i3ConfigBindArgument /--\(release\|border\|whole-window\|exclude-titlebar\)/ contained
syn match i3ConfigBindModifier /+/ contained
syn match i3ConfigBindModkey /Ctrl\|Shift\|Mod[1-5]/ contained
syn match i3ConfigBindCombo /[$a-zA-Z0-9_+]\+ / contained contains=i3ConfigBindModifier,i3ConfigVariable,i3ConfigBindModkey
syn match i3ConfigBindComboLine /bind\(sym\|code\)\( --[a-z-]\+\)* [$a-zA-Z0-9_+]\+ / contained contains=i3ConfigBindKeyword,i3ConfigBindArgument,i3ConfigBindCombo
syn match i3ConfigBind /^\s*bind\(sym\|code\)\s\+.*[^{]$/ contains=i3ConfigBindComboLine,i3ConfigNumber,i3ConfigVariable,i3ConfigAction,i3ConfigOption,i3ConfigGapStyleKeyword,i3ConfigOperator,i3ConfigString,i3ConfigUnit,i3ConfigUnitOr,i3ConfigConditional,i3ConfigBoolean,i3ConfigExec

" Floating modifier
syn keyword i3ConfigFloatingModifierKeyword floating_modifier contained
syn match i3ConfigFloatingModifier /^floating_modifier [$a-zA-Z0-9+]\+$/ contains=i3ConfigVariable,i3ConfigBindModkey,i3ConfigFloatingModifierKeyword

" Floating window size limitation
syn keyword i3ConfigSizeSpecial x contained
syn match i3ConfigSize / -\?\d\+ x -\?\d\+/ contained contains=i3ConfigSizeSpecial,i3ConfigNumber
syn keyword i3ConfigFloatingSizeKeyword floating_minimum_size floating_maximum_size contained
syn match i3ConfigFloatingSize /^floating_\(maximum\|minimum\)_size -\?\d\+ x -\?\d\+/ contains=i3ConfigFloatingSizeKeyword,i3ConfigSize

" Orientation
syn keyword i3ConfigOrientationKeyword vertical horizontal auto contained
syn match i3ConfigOrientation /^default_orientation \(vertical\|horizontal\|auto\)$/ contains=i3ConfigOrientationKeyword

" Layout
syn keyword i3ConfigLayoutKeyword default stacking tabbed contained
syn match i3ConfigLayout /^workspace_layout \(default\|stacking\|tabbed\)$/ contains=i3ConfigLayoutKeyword

" Border style
syn keyword i3ConfigBorderStyleKeyword none normal pixel contained
syn match i3ConfigBorderStyle /^\(new_window\|new_float\|default_border\|default_floating_border\)\s\+\(none\|\(normal\|pixel\)\(\s\+\d\+\)\?\(\s\+\$\w\+\(\(-\w\+\)\+\)\?\(\s\|+\)\?\)\?\)$/ contains=i3ConfigBorderStyleKeyword,i3ConfigNumber,i3ConfigVariable

" Hide borders and edges
syn keyword i3ConfigEdgeKeyword none vertical horizontal both smart smart_no_gaps contained
syn match i3ConfigEdge /^hide_edge_borders\s\+\(none\|vertical\|horizontal\|both\|smart\|smart_no_gaps\)\s\?$/ contains=i3ConfigEdgeKeyword


" Arbitrary commands for specific windows (for_window)
syn keyword i3ConfigCommandKeyword for_window contained
syn match i3ConfigConditionalText /\w\+\(-\w\+\)*/ contained
syn match i3ConfigEqualsOperator /=/ contained
syn region i3ConfigConditional start=/\[/ end=/\]/ contained contains=i3ConfigString,i3ConfigEqualsOperator,i3ConfigConditionalText
syn match i3ConfigArbitraryCommand /^for_window\s\+.*$/ contains=i3ConfigConditional,i3ConfigCommandKeyword,i3ConfigAction,i3ConfigOption,i3ConfigSize,i3ConfigNumber,i3ConfigString,i3ConfigOperator,i3ConfigBoolean,i3ConfigVariable

" Disable focus open opening
syn keyword i3ConfigNoFocusKeyword no_focus contained
syn match i3ConfigDisableFocus /^no_focus\s\+.*$/ contains=i3ConfigConditional,i3ConfigNoFocusKeyword

" Move client to specific workspace automatically
syn keyword i3ConfigAssignKeyword assign contained
syn match i3ConfigAssignSpecial /→/ contained
syn match i3ConfigAssign /^assign\s\+.*$/ contains=i3ConfigAssignKeyword,i3ConfigAssignSpecial,i3ConfigConditional,i3ConfigVariable,i3ConfigString,i3ConfigNumber

" X resources
syn keyword i3ConfigResourceKeyword set_from_resource contained
syn match i3ConfigResource /^set_from_resource\s\+.*$/ contains=i3ConfigResourceKeyword,i3ConfigConditional,i3ConfigColor,i3ConfigVariable,i3ConfigString,i3ConfigNumber

" Executing shell commands
syn keyword i3ConfigExecKeyword exec contained
syn keyword i3ConfigExecAlwaysKeyword exec_always contained
syn match i3ConfigShCmdDelim /\$/ contained
syn region i3ConfigShCommand start=/\$(/ end=/)/ contained contains=i3ConfigShCmdDelim,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigString,i3ConfigNumber,i3ConfigVariable keepend extend
syn match  i3ConfigShDelim /[[\]{}();`]\+/ contained
syn match  i3ConfigShOper /[<>&|+=~^*!.?]\+/ contained
syn match i3ConfigShParam /\<-[a-zA-Z0-9_-]\+\>/ contained containedin=i3ConfigVar
syn region i3ConfigExec start=/exec\(_always\)\?\( --no-startup-id\)\? [^{]/ skip=/\\$/ end=/\([,;]\|$\)/ contains=i3ConfigExecKeyword,i3ConfigExecAlwaysKeyword,i3ConfigShCommand,i3ConfigShDelim,i3ConfigShOper,i3ConfigShParam,i3ConfigNumber,i3ConfigString,i3ConfigVariable,i3ConfigOperator keepend extend

" Automatically putting workspaces on specific screens
syn keyword i3ConfigWorkspaceKeyword workspace contained
syn keyword i3ConfigOutput output contained
syn match i3ConfigWorkspace /^\s*workspace\s\+.*$/ contains=i3ConfigWorkspaceKeyword,i3ConfigNumber,i3ConfigString,i3ConfigOutput,i3ConfigVariable,i3ConfigBoolean

" Changing colors
syn keyword i3ConfigClientColorKeyword client focused focused_inactive unfocused urgent placeholder background contained
syn match i3ConfigClientColor /^\s*client.\w\+\s\+.*$/ contains=i3ConfigClientColorKeyword,i3ConfigColor,i3ConfigVariable

syn keyword i3ConfigTitleAlignKeyword left center right contained
syn match i3ConfigTitleAlign /^title_align .*$/ contains=i3ConfigTitleAlignKeyword

" Interprocess communication
syn match i3ConfigInterprocessKeyword /ipc-socket/ contained
syn match i3ConfigInterprocess /^ipc-socket .*$/ contains=i3ConfigInterprocessKeyword

" Mouse warping
syn keyword i3ConfigMouseWarpingKeyword mouse_warping contained
syn keyword i3ConfigMouseWarpingType output container none contained
syn match i3ConfigMouseWarping /^mouse_warping \(output\|container\|none\)$/ contains=i3ConfigMouseWarpingKeyword,i3ConfigMouseWarpingType

" Focus follows mouse
syn keyword i3ConfigFocusFollowsMouseKeyword focus_follows_mouse contained
syn keyword i3ConfigFocusFollowsMouseType always contained
syn match i3ConfigFocusFollowsMouse /^focus_follows_mouse \(yes\|no\|always\)$/ contains=i3ConfigFocusFollowsMouseKeyword,i3ConfigBoolean,i3ConfigFocusFollowsMouseType

" Focus wrapping
syn keyword i3ConfigFocusWrappingKeyword force_focus_wrapping focus_wrapping contained
syn keyword i3ConfigFocusWrappingType force workspace contained
syn match i3ConfigFocusWrapping /^focus_wrapping \(yes\|no\|force\|workspace\)$/ contains=i3ConfigBoolean,i3ConfigFocusWrappingKeyword,i3ConfigFocusWrappingType

" Popups during fullscreen mode
syn keyword i3ConfigPopupOnFullscreenKeyword popup_during_fullscreen contained
syn keyword i3ConfigPopupOnFullscreenType smart ignore leave_fullscreen contained
syn match i3ConfigPopupOnFullscreen /^popup_during_fullscreen \w\+$/ contains=i3ConfigPopupOnFullscreenKeyword,i3ConfigPopupOnFullscreenType

" Forcing Xinerama
syn keyword i3ConfigForceXineramaKeyword force_xinerama contained
syn match i3ConfigForceXinerama /^force_xinerama \(yes\|no\)$/ contains=i3ConfigBoolean,i3ConfigForceXineramaKeyword

" Automatic back-and-forth when switching to the current workspace
syn keyword i3ConfigAutomaticSwitchKeyword workspace_auto_back_and_forth contained
syn match i3ConfigAutomaticSwitch /^workspace_auto_back_and_forth \(yes\|no\)$/ contains=i3ConfigBoolean,i3ConfigAutomaticSwitchKeyword

" Delay urgency hint
syn keyword i3ConfigTimeUnit ms contained
syn keyword i3ConfigDelayUrgencyKeyword force_display_urgency_hint contained
syn match i3ConfigDelayUrgency /^force_display_urgency_hint \d\+ ms$/ contains=i3ConfigBoolean,i3ConfigDelayUrgencyKeyword,i3ConfigNumber,i3ConfigTimeUnit

" Focus on window activation
syn keyword i3ConfigFocusOnActivationKeyword focus_on_window_activation contained
syn keyword i3ConfigFocusOnActivationType smart urgent focus none contained
syn match i3ConfigFocusOnActivation /^focus_on_window_activation \(smart\|urgent\|focus\|none\)$/  contains=i3ConfigFocusOnActivationKeyword,i3ConfigFocusOnActivationType

" Show window marks in their window title
syn keyword i3ConfigShowMarksKeyword show_marks contained
syn match i3ConfigShowMarks /^show_marks \(yes\|no\)$/ contains=i3ConfigBoolean,i3ConfigShowMarksKeyword

" Mode block
syn match i3ConfigModeKeyword /^mode/ contained
syn region i3ConfigModeBlock start=/^mode\( --pango_markup\)\? \([^'" {]\+\|'[^']\+'\|".\+"\)\s\+{$/ end=/^\s*}$/ contains=i3ConfigModeKeyword,i3ConfigString,i3ConfigBind,i3ConfigComment,i3ConfigNumber,i3ConfigParen,i3ConfigVariable fold keepend extend

" Color block
syn keyword i3ConfigColorsKeyword colors contained
syn match i3ConfigColorsCategory /\(focused_\)\?\(background\|statusline\|separator\)\|\(focused\|active\|inactive\|urgent\)_workspace\|binding_mode/ contained
syn region i3ConfigColorsBlock start=/^\s\+colors {$/ end=/^\s\+}$/ contained contains=i3ConfigColorsKeyword,i3ConfigColorsCategory,i3ConfigColor,i3ConfigVariable,i3ConfigComment,i3ConfigParen fold keepend extend

" Bar block
syn keyword i3ConfigBarBlockKeyword bar i3bar_command status_command mode hidden_state id position output tray_output tray_padding font separator_symbol workspace_buttons workspace_min_width strip_workspace_numbers strip_workspace_name binding_mode_indicator padding contained
syn keyword i3ConfigBarModifierKeyword modifier contained
syn match i3ConfigBarModifierLine /^\s\+modifier [^ ]\+$/ contained contains=i3ConfigBarModifierKeyword,i3ConfigBindModifier,i3ConfigVariable,i3ConfigBindModkey
syn region i3ConfigBarBlock start=/^bar {$/ end=/^}$/ contains=i3ConfigBarBlockKeyword,i3ConfigBarModifierLine,i3ConfigBind,i3ConfigString,i3ConfigComment,i3ConfigFont,i3ConfigBoolean,i3ConfigNumber,i3ConfigOperator,i3ConfigParen,i3ConfigColor,i3ConfigVariable,i3ConfigColorsBlock fold keepend extend

" Define the highlighting.
hi def link i3ConfigKeyword                         Keyword
hi def link i3ConfigCommand                         Statement
hi def link i3ConfigError                           Error
hi def link i3ConfigTodo                            Todo
hi def link i3ConfigComment                         Comment
hi def link i3ConfigOperator                        Operator
hi def link i3ConfigParen                           Delimiter
hi def link i3ConfigFontKeyword                     i3ConfigKeyword
hi def link i3ConfigFontNamespace                   i3ConfigOption
hi def link i3ConfigFontContent                     String
hi def link i3ConfigFontSize                        Number
hi def link i3ConfigString                          String
hi def link i3ConfigNumber                          Number
hi def link i3ConfigBoolean                         Boolean
hi def link i3ConfigColor                           Constant
hi def link i3ConfigVariable                        Variable
hi def link i3ConfigSetKeyword                      i3ConfigKeyword
hi def link i3ConfigIncludeKeyword                  i3ConfigKeyword
hi def link i3ConfigCommandSubstitutionDelimiter    Delimiter
hi def link i3ConfigIncludePath                     String
hi def link i3ConfigGapStyleKeyword                 i3ConfigOption
hi def link i3ConfigGapStyle                        i3ConfigCommand
hi def link i3ConfigSmartGapKeyword                 i3ConfigOption
hi def link i3ConfigSmartGap                        i3ConfigKeyword
hi def link i3ConfigSmartBorderKeyword              i3ConfigOption
hi def link i3ConfigSmartBorder                     i3ConfigKeyword
hi def link i3ConfigAction                          i3ConfigCommand
hi def link i3ConfigOption                          Type
hi def link i3ConfigUnit                            i3ConfigNumber
hi def link i3ConfigUnitOr                          i3ConfigOperator
hi def link i3ConfigBindKeyword                     i3ConfigKeyword
hi def link i3ConfigBindModkey                      Special
hi def link i3ConfigBindCombo                       SpecialChar
hi def link i3ConfigBindModifier                    i3ConfigOperator
hi def link i3ConfigBindArgument                    i3ConfigShParam
hi def link i3ConfigFloatingModifierKeyword         i3ConfigKeyword
hi def link i3ConfigSizeSpecial                     i3ConfigOperator
hi def link i3ConfigFloatingSizeKeyword             i3ConfigKeyword
hi def link i3ConfigOrientationKeyword              i3ConfigOption
hi def link i3ConfigOrientation                     i3ConfigKeyword
hi def link i3ConfigLayoutKeyword                   i3ConfigOption
hi def link i3ConfigLayout                          i3ConfigKeyword
hi def link i3ConfigBorderStyleKeyword              i3ConfigOption
hi def link i3ConfigBorderStyle                     i3ConfigKeyword
hi def link i3ConfigEdgeKeyword                     i3ConfigOption
hi def link i3ConfigEdge                            i3ConfigKeyword
hi def link i3ConfigCommandKeyword                  i3ConfigKeyword
hi def link i3ConfigEqualsOperator                  i3ConfigOperator
hi def link i3ConfigConditionalText                 Conditional
hi def link i3ConfigConditional                     Delimiter
hi def link i3ConfigNoFocusKeyword                  i3ConfigKeyword
hi def link i3ConfigAssignKeyword                   i3ConfigKeyword
hi def link i3ConfigAssignSpecial                   i3ConfigOption
hi def link i3ConfigResourceKeyword                 i3ConfigKeyword
hi def link i3ConfigShParam                         PreProc
hi def link i3ConfigShDelim                         Delimiter
hi def link i3ConfigShOper                          Operator
hi def link i3ConfigShCmdDelim                      i3ConfigShDelim
hi def link i3ConfigShCommand                       Normal
hi def link i3ConfigExecKeyword                     i3ConfigCommand
hi def link i3ConfigExecAlwaysKeyword               i3ConfigKeyword
hi def link i3ConfigWorkspaceKeyword                i3ConfigCommand
hi def link i3ConfigOutput                          i3ConfigOption
hi def link i3ConfigClientColorKeyword              i3ConfigKeyword
hi def link i3ConfigClientColor                     Operator
hi def link i3ConfigTitleAlignKeyword               i3ConfigOption
hi def link i3ConfigTitleAlign                      i3ConfigKeyword
hi def link i3ConfigInterprocessKeyword             i3ConfigKeyword
hi def link i3ConfigMouseWarpingKeyword             i3ConfigKeyword
hi def link i3ConfigMouseWarpingType                i3ConfigOption
hi def link i3ConfigFocusFollowsMouseKeyword        i3ConfigKeyword
hi def link i3ConfigFocusFollowsMouseType           i3ConfigOption
hi def link i3ConfigFocusWrappingKeyword            i3ConfigKeyword
hi def link i3ConfigFocusWrappingType               i3ConfigOption
hi def link i3ConfigPopupOnFullscreenKeyword        i3ConfigKeyword
hi def link i3ConfigPopupOnFullscreenType           i3ConfigOption
hi def link i3ConfigForceXineramaKeyword            i3ConfigKeyword
hi def link i3ConfigAutomaticSwitchKeyword          i3ConfigKeyword
hi def link i3ConfigTimeUnit                        i3ConfigNumber
hi def link i3ConfigDelayUrgencyKeyword             i3ConfigKeyword
hi def link i3ConfigFocusOnActivationKeyword        i3ConfigKeyword
hi def link i3ConfigFocusOnActivationType           i3ConfigOption
hi def link i3ConfigShowMarksKeyword                i3ConfigKeyword
hi def link i3ConfigModeKeyword                     i3ConfigKeyword
hi def link i3ConfigColorsKeyword                   i3ConfigKeyword
hi def link i3ConfigColorsCategory                  Type
hi def link i3ConfigBarModifierKeyword              i3ConfigKeyword
hi def link i3ConfigBarBlockKeyword                 i3ConfigKeyword

let b:current_syntax = "i3config"
