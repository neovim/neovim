" Vim syntax file
" Language: i3 config file
" Original Author: Mohamed Boughaba <mohamed dot bgb at gmail dot com>
" Maintainer: Quentin Hibon (github user hiqua)
" Version: 0.4
" Last Change: 2022 Jun 05

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
syn match i3ConfigError /.*/

" Todo
syn keyword i3ConfigTodo TODO FIXME XXX contained

" Comment
" Comments are started with a # and can only be used at the beginning of a line
syn match i3ConfigComment /^\s*#.*$/ contains=i3ConfigTodo

" Font
" A FreeType font description is composed by:
" a font family, a style, a weight, a variant, a stretch and a size.
syn match i3ConfigFontSeparator /,/ contained
syn match i3ConfigFontSeparator /:/ contained
syn keyword i3ConfigFontKeyword font contained
syn match i3ConfigFontNamespace /\w\+:/ contained contains=i3ConfigFontSeparator
syn match i3ConfigFontContent /-\?\w\+\(-\+\|\s\+\|,\)/ contained contains=i3ConfigFontNamespace,i3ConfigFontSeparator,i3ConfigFontKeyword
syn match i3ConfigFontSize /\s\=\d\+\(px\)\?\s\?$/ contained
syn match i3ConfigFont /^\s*font\s\+.*$/ contains=i3ConfigFontContent,i3ConfigFontSeparator,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+.*\(\\\_.*\)\?$/ contains=i3ConfigFontContent,i3ConfigFontSeparator,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+.*\(\\\_.*\)\?[^\\]\+$/ contains=i3ConfigFontContent,i3ConfigFontSeparator,i3ConfigFontSize,i3ConfigFontNamespace
syn match i3ConfigFont /^\s*font\s\+\(\(.*\\\_.*\)\|\(.*[^\\]\+$\)\)/ contains=i3ConfigFontContent,i3ConfigFontSeparator,i3ConfigFontSize,i3ConfigFontNamespace

" variables
syn match i3ConfigString /\(['"]\)\(.\{-}\)\1/ contained
syn match i3ConfigColor /#\w\{6}/ contained
syn match i3ConfigVariableModifier /+/ contained
syn match i3ConfigVariableAndModifier /+\w\+/ contained contains=i3ConfigVariableModifier
syn match i3ConfigVariable /\$\w\+\(\(-\w\+\)\+\)\?\(\s\|+\)\?/ contains=i3ConfigVariableModifier,i3ConfigVariableAndModifier
syn keyword i3ConfigInitializeKeyword set contained
syn match i3ConfigInitialize /^\s*set\s\+.*$/ contains=i3ConfigVariable,i3ConfigInitializeKeyword,i3ConfigColor,i3ConfigString

" Include
syn keyword i3ConfigIncludeKeyword include contained
syn match i3ConfigInclude /^\s*include\s\+.*$/ contains=i3ConfigIncludeKeyword,i3ConfigString,i3ConfigVariable

" Gaps
syn keyword i3ConfigGapStyleKeyword inner outer horizontal vertical top right bottom left current all set plus minus toggle up down contained
syn match i3ConfigGapStyle /^\s*\(gaps\)\s\+\(inner\|outer\|horizontal\|vertical\|left\|top\|right\|bottom\)\(\s\+\(current\|all\)\)\?\(\s\+\(set\|plus\|minus\|toggle\)\)\?\(\s\+\(-\?\d\+\|\$.*\)\)$/ contains=i3ConfigGapStyleKeyword,i3ConfigNumber,i3ConfigVariable
syn keyword i3ConfigSmartGapKeyword on inverse_outer off contained
syn match i3ConfigSmartGap /^\s*smart_gaps\s\+\(on\|inverse_outer\|off\)\s\?$/ contains=i3ConfigSmartGapKeyword
syn keyword i3ConfigSmartBorderKeyword on no_gaps contained
syn match i3ConfigSmartBorder /^\s*smart_borders\s\+\(on\|no_gaps\)\s\?$/ contains=i3ConfigSmartBorderKeyword

" Keyboard bindings
syn keyword i3ConfigAction toggle fullscreen restart key import kill shrink grow contained
syn keyword i3ConfigAction focus move grow height width split layout resize restore reload mute unmute exit mode workspace container to contained
syn match i3ConfigModifier /\w\++\w\+\(\(+\w\+\)\+\)\?/ contained contains=i3ConfigVariableModifier
syn match i3ConfigNumber /\s\d\+/ contained
syn match i3ConfigUnit /\sp\(pt\|x\)/ contained
syn match i3ConfigUnitOr /\sor/ contained
syn keyword i3ConfigBindKeyword bindsym bindcode exec gaps border contained
syn match i3ConfigBindArgument /--\w\+\(\(-\w\+\)\+\)\?\s/ contained
syn match i3ConfigBind /^\s*\(bindsym\|bindcode\)\s\+.*$/ contains=i3ConfigVariable,i3ConfigBindKeyword,i3ConfigVariableAndModifier,i3ConfigNumber,i3ConfigUnit,i3ConfigUnitOr,i3ConfigBindArgument,i3ConfigModifier,i3ConfigAction,i3ConfigString,i3ConfigGapStyleKeyword,i3ConfigBorderStyleKeyword

" Floating
syn keyword i3ConfigSizeSpecial x contained
syn match i3ConfigNegativeSize /-/ contained
syn match i3ConfigSize /-\?\d\+\s\?x\s\?-\?\d\+/ contained contains=i3ConfigSizeSpecial,i3ConfigNumber,i3ConfigNegativeSize
syn match i3ConfigFloatingModifier /^\s*floating_modifier\s\+\$\w\+\d\?/ contains=i3ConfigVariable
syn match i3ConfigFloating /^\s*floating_\(maximum\|minimum\)_size\s\+-\?\d\+\s\?x\s\?-\?\d\+/ contains=i3ConfigSize

" Orientation
syn keyword i3ConfigOrientationKeyword vertical horizontal auto contained
syn match i3ConfigOrientation /^\s*default_orientation\s\+\(vertical\|horizontal\|auto\)\s\?$/ contains=i3ConfigOrientationKeyword

" Layout
syn keyword i3ConfigLayoutKeyword default stacking tabbed contained
syn match i3ConfigLayout /^\s*workspace_layout\s\+\(default\|stacking\|tabbed\)\s\?$/ contains=i3ConfigLayoutKeyword

" Border style
syn keyword i3ConfigBorderStyleKeyword none normal pixel contained
syn match i3ConfigBorderStyle /^\s*\(new_window\|new_float\|default_border\|default_floating_border\)\s\+\(none\|\(normal\|pixel\)\(\s\+\d\+\)\?\(\s\+\$\w\+\(\(-\w\+\)\+\)\?\(\s\|+\)\?\)\?\)\s\?$/ contains=i3ConfigBorderStyleKeyword,i3ConfigNumber,i3ConfigVariable

" Hide borders and edges
syn keyword i3ConfigEdgeKeyword none vertical horizontal both smart smart_no_gaps contained
syn match i3ConfigEdge /^\s*hide_edge_borders\s\+\(none\|vertical\|horizontal\|both\|smart\|smart_no_gaps\)\s\?$/ contains=i3ConfigEdgeKeyword

" Arbitrary commands for specific windows (for_window)
syn keyword i3ConfigCommandKeyword for_window contained
syn region i3ConfigWindowStringSpecial start=+"+  skip=+\\"+  end=+"+ contained contains=i3ConfigString
syn region i3ConfigWindowCommandSpecial start="\[" end="\]" contained contains=i3ConfigWindowStringSpacial,i3ConfigString
syn match i3ConfigArbitraryCommand /^\s*for_window\s\+.*$/ contains=i3ConfigWindowCommandSpecial,i3ConfigCommandKeyword,i3ConfigBorderStyleKeyword,i3ConfigLayoutKeyword,i3ConfigOrientationKeyword,Size,i3ConfigNumber

" Disable focus open opening
syn keyword i3ConfigNoFocusKeyword no_focus contained
syn match i3ConfigDisableFocus /^\s*no_focus\s\+.*$/ contains=i3ConfigWindowCommandSpecial,i3ConfigNoFocusKeyword

" Move client to specific workspace automatically
syn keyword i3ConfigAssignKeyword assign contained
syn match i3ConfigAssignSpecial /→/ contained
syn match i3ConfigAssign /^\s*assign\s\+.*$/ contains=i3ConfigAssignKeyword,i3ConfigWindowCommandSpecial,i3ConfigAssignSpecial

" X resources
syn keyword i3ConfigResourceKeyword set_from_resource contained
syn match i3ConfigResource /^\s*set_from_resource\s\+.*$/ contains=i3ConfigResourceKeyword,i3ConfigWindowCommandSpecial,i3ConfigColor,i3ConfigVariable

" Auto start applications
syn keyword i3ConfigExecKeyword exec exec_always contained
syn match i3ConfigNoStartupId /--no-startup-id/ contained " We are not using i3ConfigBindArgument as only no-startup-id is supported here
syn match i3ConfigExec /^\s*exec\(_always\)\?\s\+.*$/ contains=i3ConfigExecKeyword,i3ConfigNoStartupId,i3ConfigString

" Automatically putting workspaces on specific screens
syn keyword i3ConfigWorkspaceKeyword workspace contained
syn keyword i3ConfigOutput output contained
syn match i3ConfigWorkspace /^\s*workspace\s\+.*$/ contains=i3ConfigWorkspaceKeyword,i3ConfigNumber,i3ConfigString,i3ConfigOutput

" Changing colors
syn keyword i3ConfigClientColorKeyword client focused focused_inactive unfocused urgent placeholder background contained
syn match i3ConfigClientColor /^\s*client.\w\+\s\+.*$/ contains=i3ConfigClientColorKeyword,i3ConfigColor,i3ConfigVariable

syn keyword i3ConfigTitleAlignKeyword left center right contained
syn match i3ConfigTitleAlign /^\s*title_align\s\+.*$/ contains=i3ConfigTitleAlignKeyword

" Interprocess communication
syn match i3ConfigInterprocessKeyword /ipc-socket/ contained
syn match i3ConfigInterprocess /^\s*ipc-socket\s\+.*$/ contains=i3ConfigInterprocessKeyword

" Mouse warping
syn keyword i3ConfigMouseWarpingKeyword mouse_warping contained
syn keyword i3ConfigMouseWarpingType output none contained
syn match i3ConfigMouseWarping /^\s*mouse_warping\s\+\(output\|none\)\s\?$/ contains=i3ConfigMouseWarpingKeyword,i3ConfigMouseWarpingType

" Focus follows mouse
syn keyword i3ConfigFocusFollowsMouseKeyword focus_follows_mouse contained
syn keyword i3ConfigFocusFollowsMouseType yes no contained
syn match i3ConfigFocusFollowsMouse /^\s*focus_follows_mouse\s\+\(yes\|no\)\s\?$/ contains=i3ConfigFocusFollowsMouseKeyword,i3ConfigFocusFollowsMouseType

" Popups during fullscreen mode
syn keyword i3ConfigPopupOnFullscreenKeyword popup_during_fullscreen contained
syn keyword i3ConfigPopuponFullscreenType smart ignore leave_fullscreen contained
syn match i3ConfigPopupOnFullscreen /^\s*popup_during_fullscreen\s\+\w\+\s\?$/ contains=i3ConfigPopupOnFullscreenKeyword,i3ConfigPopupOnFullscreenType

" Focus wrapping
syn keyword i3ConfigFocusWrappingKeyword force_focus_wrapping focus_wrapping contained
syn keyword i3ConfigFocusWrappingType yes no contained
syn match i3ConfigFocusWrapping /^\s*\(force_\)\?focus_wrapping\s\+\(yes\|no\)\s\?$/ contains=i3ConfigFocusWrappingType,i3ConfigFocusWrappingKeyword

" Forcing Xinerama
syn keyword i3ConfigForceXineramaKeyword force_xinerama contained
syn match i3ConfigForceXinerama /^\s*force_xinerama\s\+\(yes\|no\)\s\?$/ contains=i3ConfigFocusWrappingType,i3ConfigForceXineramaKeyword

" Automatic back-and-forth when switching to the current workspace
syn keyword i3ConfigAutomaticSwitchKeyword workspace_auto_back_and_forth contained
syn match i3ConfigAutomaticSwitch /^\s*workspace_auto_back_and_forth\s\+\(yes\|no\)\s\?$/ contains=i3ConfigFocusWrappingType,i3ConfigAutomaticSwitchKeyword

" Delay urgency hint
syn keyword i3ConfigTimeUnit ms contained
syn keyword i3ConfigDelayUrgencyKeyword force_display_urgency_hint contained
syn match i3ConfigDelayUrgency /^\s*force_display_urgency_hint\s\+\d\+\s\+ms\s\?$/ contains=i3ConfigFocusWrappingType,i3ConfigDelayUrgencyKeyword,i3ConfigNumber,i3ConfigTimeUnit

" Focus on window activation
syn keyword i3ConfigFocusOnActivationKeyword focus_on_window_activation contained
syn keyword i3ConfigFocusOnActivationType smart urgent focus none contained
syn match i3ConfigFocusOnActivation /^\s*focus_on_window_activation\s\+\(smart\|urgent\|focus\|none\)\s\?$/  contains=i3ConfigFocusOnActivationKeyword,i3ConfigFocusOnActivationType

" Automatic back-and-forth when switching to the current workspace
syn keyword i3ConfigDrawingMarksKeyword show_marks contained
syn match i3ConfigDrawingMarks /^\s*show_marks\s\+\(yes\|no\)\s\?$/ contains=i3ConfigFocusWrappingType,i3ConfigDrawingMarksKeyword

" Group mode/bar
syn keyword i3ConfigBlockKeyword mode bar colors i3bar_command status_command position exec mode hidden_state modifier id position output background statusline tray_output tray_padding separator separator_symbol workspace_min_width workspace_buttons strip_workspace_numbers binding_mode_indicator focused_workspace active_workspace inactive_workspace urgent_workspace binding_mode contained
syn region i3ConfigBlock start=+^\s*[^#]*s\?{$+ end=+^\s*[^#]*}$+ contains=i3ConfigBlockKeyword,i3ConfigString,i3ConfigBind,i3ConfigComment,i3ConfigFont,i3ConfigFocusWrappingType,i3ConfigColor,i3ConfigVariable transparent keepend extend

" Line continuation
syn region i3ConfigLineCont start=/^.*\\$/ end=/^.*$/ contains=i3ConfigBlockKeyword,i3ConfigString,i3ConfigBind,i3ConfigComment,i3ConfigFont,i3ConfigFocusWrappingType,i3ConfigColor,i3ConfigVariable transparent keepend extend

" Define the highlighting.
hi def link i3ConfigError                           Error
hi def link i3ConfigTodo                            Todo
hi def link i3ConfigComment                         Comment
hi def link i3ConfigFontContent                     Type
hi def link i3ConfigFocusOnActivationType           Type
hi def link i3ConfigPopupOnFullscreenType           Type
hi def link i3ConfigOrientationKeyword              Type
hi def link i3ConfigMouseWarpingType                Type
hi def link i3ConfigFocusFollowsMouseType           Type
hi def link i3ConfigGapStyleKeyword                 Type
hi def link i3ConfigTitleAlignKeyword               Type
hi def link i3ConfigSmartGapKeyword                 Type
hi def link i3ConfigSmartBorderKeyword              Type
hi def link i3ConfigLayoutKeyword                   Type
hi def link i3ConfigBorderStyleKeyword              Type
hi def link i3ConfigEdgeKeyword                     Type
hi def link i3ConfigAction                          Type
hi def link i3ConfigCommand                         Type
hi def link i3ConfigOutput                          Type
hi def link i3ConfigWindowCommandSpecial            Type
hi def link i3ConfigFocusWrappingType               Type
hi def link i3ConfigUnitOr                          Type
hi def link i3ConfigFontSize                        Constant
hi def link i3ConfigColor                           Constant
hi def link i3ConfigNumber                          Constant
hi def link i3ConfigUnit                            Constant
hi def link i3ConfigVariableAndModifier             Constant
hi def link i3ConfigTimeUnit                        Constant
hi def link i3ConfigModifier                        Constant
hi def link i3ConfigString                          Constant
hi def link i3ConfigNegativeSize                    Constant
hi def link i3ConfigInclude                         Constant
hi def link i3ConfigFontSeparator                   Special
hi def link i3ConfigVariableModifier                Special
hi def link i3ConfigSizeSpecial                     Special
hi def link i3ConfigWindowSpecial                   Special
hi def link i3ConfigAssignSpecial                   Special
hi def link i3ConfigFontNamespace                   PreProc
hi def link i3ConfigBindArgument                    PreProc
hi def link i3ConfigNoStartupId                     PreProc
hi def link i3ConfigIncludeKeyword                  Identifier
hi def link i3ConfigFontKeyword                     Identifier
hi def link i3ConfigBindKeyword                     Identifier
hi def link i3ConfigOrientation                     Identifier
hi def link i3ConfigGapStyle                        Identifier
hi def link i3ConfigTitleAlign                      Identifier
hi def link i3ConfigSmartGap                        Identifier
hi def link i3ConfigSmartBorder                     Identifier
hi def link i3ConfigLayout                          Identifier
hi def link i3ConfigBorderStyle                     Identifier
hi def link i3ConfigEdge                            Identifier
hi def link i3ConfigFloating                        Identifier
hi def link i3ConfigFloatingModifier                Identifier
hi def link i3ConfigCommandKeyword                  Identifier
hi def link i3ConfigNoFocusKeyword                  Identifier
hi def link i3ConfigInitializeKeyword               Identifier
hi def link i3ConfigAssignKeyword                   Identifier
hi def link i3ConfigResourceKeyword                 Identifier
hi def link i3ConfigExecKeyword                     Identifier
hi def link i3ConfigWorkspaceKeyword                Identifier
hi def link i3ConfigClientColorKeyword              Identifier
hi def link i3ConfigInterprocessKeyword             Identifier
hi def link i3ConfigMouseWarpingKeyword             Identifier
hi def link i3ConfigFocusFollowsMouseKeyword        Identifier
hi def link i3ConfigPopupOnFullscreenKeyword        Identifier
hi def link i3ConfigFocusWrappingKeyword            Identifier
hi def link i3ConfigForceXineramaKeyword            Identifier
hi def link i3ConfigAutomaticSwitchKeyword          Identifier
hi def link i3ConfigDelayUrgencyKeyword             Identifier
hi def link i3ConfigFocusOnActivationKeyword        Identifier
hi def link i3ConfigDrawingMarksKeyword             Identifier
hi def link i3ConfigBlockKeyword                    Identifier
hi def link i3ConfigVariable                        Statement
hi def link i3ConfigArbitraryCommand                Type

let b:current_syntax = "i3config"
