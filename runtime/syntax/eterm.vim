" Vim syntax file
" Language:             eterm(1) configuration file
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2006-04-21

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword etermTodo             contained TODO FIXME XXX NOTE

syn region  etermComment          display oneline start='^#' end='$'
                                  \ contains=etermTodo,@Spell

syn match   etermMagic            display '^<Eterm-[0-9.]\+>$'

syn match   etermNumber           contained display '\<\(\d\+\|0x\x\{1,2}\)\>'

syn region  etermString           contained display oneline start=+"+
                                  \ skip=+\\"+ end=+"+

syn keyword etermBoolean          contained on off true false yes no

syn keyword etermPreProc          contained appname exec get put random version
                                  \ include preproc

syn keyword etermFunctions        contained copy exit kill nop paste save
                                  \ scroll search spawn

syn cluster etermGeneral          contains=etermComment,etermFunction,
                                  \ etermPreProc

syn keyword etermKeyMod           contained ctrl shift lock mod1 mod2 mod3 mod4
                                  \ mod5 alt meta anymod
syn keyword etermKeyMod           contained button1 button2 button3 button4
                                  \ button5

syn keyword etermColorOptions     contained video nextgroup=etermVideoOptions
                                  \ skipwhite

syn keyword etermVideoType        contained normal reverse

syn keyword etermColorOptions     contained foreground background cursor
                                  \ cursor_text pointer
                                  \ nextgroup=etermColorType skipwhite

syn keyword etermColorType        contained bd ul
syn match   etermColorType        contained display '\<\%(\d\|1[0-5]\)'

syn keyword etermColorOptions     contained color
                                  \ nextgroup=etermColorNumber skipwhite

syn keyword etermColorNumber      contained bd ul nextgroup=etermColorSpec
                                  \ skipwhite
syn match   etermColorNumber      contained display '\<\%(\d\|1[0-5]\)'
                                  \ nextgroup=etermColorSpec skipwhite

syn match   etermColorSpec        contained display '\S\+'

syn region  etermColorContext     fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+color\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermColorOptions

syn keyword etermAttrOptions      contained geometry nextgroup=etermGeometry
                                  \ skipwhite

syn match   etermGeometry         contained display '\d\+x\d++\d\++\d\+'

syn keyword etermAttrOptions      contained scrollbar_type
                                  \ nextgroup=etermScrollbarType skipwhite

syn keyword etermScrollbarType    contained motif xterm next

syn keyword etermAttrOptions      contained font nextgroup=etermFontType
                                  \ skipwhite

syn keyword etermFontType         contained bold nextgroup=etermFont skipwhite
syn match   etermFontType         contained display '[0-5]' nextgroup=etermFont
                                  \ skipwhite

syn match   etermFont             contained display '\S\+'

syn keyword etermFontType         contained default nextgroup=etermNumber
                                  \ skipwhite

syn keyword etermFontType         contained proportional nextgroup=etermBoolean
                                  \ skipwhite

syn keyword etermFontType         contained fx nextgroup=etermString skipwhite

syn keyword etermAttrOptions      contained title name iconname
                                  \ nextgroup=etermString skipwhite

syn keyword etermAttrOptions      contained scrollbar_width desktop
                                  \ nextgroup=etermNumber skipwhite

syn region  etermAttrContext      fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+attributes\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermAttrOptions

syn keyword etermIClassOptions    contained icon path nextgroup=etermString
                                  \ skipwhite
syn keyword etermIClassOptions    contained cache nextgroup=etermNumber
                                  \ skipwhite
syn keyword etermIClassOptions    contained anim nextgroup=etermNumber
                                  \ skipwhite

syn region  etermIClassContext    fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+imageclasses\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermImageContext,
                                  \ etermIClassOptions

syn keyword etermImageOptions     contained type nextgroup=etermImageType
                                  \ skipwhite

syn keyword etermImageTypes       contained background trough anchor up_arrow
                                  \ left_arrow right_arrow menu menuitem
                                  \ submenu button buttonbar down_arrow

syn keyword etermImageOptions     contained mode nextgroup=etermImageModes
                                  \ skipwhite

syn keyword etermImageModes       contained image trans viewport auto solid
                                  \ nextgroup=etermImageModesAllow skipwhite
syn keyword etermImageModesAllow  contained allow nextgroup=etermImageModesR
                                  \ skipwhite
syn keyword etermImageModesR      contained image trans viewport auto solid

syn keyword etermImageOptions     contained state nextgroup=etermImageState
                                  \ skipwhite

syn keyword etermImageState       contained normal selected clicked disabled

syn keyword etermImageOptions     contained color nextgroup=etermImageColorFG
                                  \ skipwhite

syn keyword etermImageColorFG     contained '\S\+' nextgroup=etermImageColorBG
                                  \ skipwhite

syn keyword etermImageColorBG     contained '\S\+'

syn keyword etermImageOptions     contained file nextgroup=etermString
                                  \ skipwhite

syn keyword etermImageOptions     contained geom nextgroup=etermImageGeom
                                  \ skipwhite

syn match   etermImageGeom        contained display
                                  \ '\s\+\%(\d\+x\d\++\d\++\d\+\)\=:\%(\%(tie\|scale\|hscale\|vscale\|propscale\)d\=\)\='

syn keyword etermImageOptions     contained cmod colormod
                                  \ nextgroup=etermImageCmod skipwhite

syn keyword etermImageCmod        contained image red green blue
                                  \ nextgroup=etermImageBrightness skipwhite

syn match   etermImageBrightness  contained display '\<\(\d\+\|0x\x\{1,2}\)\>'
                                  \ nextgroup=etermImageContrast skipwhite

syn match   etermImageContrast    contained display '\<\(\d\+\|0x\x\{1,2}\)\>'
                                  \ nextgroup=etermImageGamma skipwhite

syn match   etermImageGamma       contained display '\<\(\d\+\|0x\x\{1,2}\)\>'
                                  \ nextgroup=etermImageGamma skipwhite

syn region  etermImageOptions     contained display oneline
                                  \ matchgroup=etermImageOptions
                                  \ start='border\|bevel\%(\s\+\%(up\|down\)\)\|padding'
                                  \ end='$' contains=etermNumber

syn region  etermImageContext     contained fold transparent
                                  \ matchgroup=etermContext
                                  \ start='^\s*begin\s\+image\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermImageOptions

syn keyword etermMenuItemOptions  contained action
                                  \ nextgroup=etermMenuItemAction skipwhite

syn keyword etermMenuItemAction   contained string echo submenu script
                                  \ nextgroup=etermString skipwhite

syn keyword etermMenuItemAction   contained separator

syn keyword etermMenuItemOptions  contained text rtext nextgroup=etermString
                                  \ skipwhite

syn region  etermMenuItemContext  contained fold transparent
                                  \ matchgroup=etermContext
                                  \ start='^\s*begin\s\+menuitem\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermMenuItemOptions

syn keyword etermMenuOptions      contained title nextgroup=etermString
                                  \ skipwhite

syn keyword etermMenuOptions      contained font_name nextgroup=etermFont
                                  \ skipwhite

syn match   etermMenuOptions      contained display '\<sep\>\|-'

syn region  etermMenuContext      fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+menu\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermMenuOptions,
                                  \ etermMenuItemContext

syn keyword etermBind             contained bind nextgroup=etermBindMods
                                  \ skipwhite

syn keyword etermBindMods         contained ctrl shift lock mod1 mod2 mod3 mod4
                                  \ mod5 alt meta anymod
                                  \ nextgroup=etermBindMods skipwhite

syn keyword etermBindTo           contained to nextgroup=etermBindType
                                  \ skipwhite

syn keyword etermBindType         contained string echo menu script
                                  \ nextgroup=etermBindParam skipwhite

syn match   etermBindParam        contained display '\S\+'

syn region  etermActionsContext   fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+actions\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermActionsOptions

syn keyword etermButtonOptions    contained font nextgroup=etermFont skipwhite
syn keyword etermButtonOptions    contained visible nextgroup=etermBoolean
                                  \ skipwhite
syn keyword etermButtonOptions    contained dock nextgroup=etermDockOption
                                  \ skipwhite

syn keyword etermDockOption       contained top bottom no

syn keyword etermButton           contained button nextgroup=etermButtonText
                                  \ skipwhite

syn region  etermButtonText       contained display oneline start=+"+
                                  \ skip=+\\"+ end=+"+
                                  \ nextgroup=etermButtonIcon skipwhite

syn keyword etermButtonIcon       contained icon nextgroup=etermButtonIconFile
                                  \ skipwhite

syn keyword etermButtonIconFile   contained '\S\+' nextgroup=etermButtonAction
                                  \ skipwhite

syn keyword etermButtonAction     contained action nextgroup=etermBindType
                                  \ skipwhite

syn region  etermButtonContext    fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+button_bar\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermButtonOptions

syn keyword etermMultiOptions     contained encoding nextgroup=etermEncoding
                                  \ skipwhite

syn keyword etermEncoding         eucj sjis euckr big5 gb
syn match   etermEncoding         display 'iso-10646'

syn keyword etermMultiOptions     contained font nextgroup=etermFontType
                                  \ skipwhite

syn region  etermMultiContext     fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+multichar\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermMultiOptions

syn keyword etermXimOptions       contained input_method
                                  \ nextgroup=etermInputMethod skipwhite

syn match   etermInputMethod      contained display '\S+'

syn keyword etermXimOptions       contained preedit_type
                                  \ nextgroup=etermPreeditType skipwhite

syn keyword etermPreeditType      contained OverTheSpot OffTheSpot Root

syn region  etermXimContext       fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+xim\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermXimOptions

syn keyword etermTogOptions       contained map_alert visual_bell login_shell
                                  \ scrollbar utmp_logging meta8 iconic
                                  \ no_input home_on_output home_on_input
                                  \ scrollbar_floating scrollbar_right
                                  \ scrollbar_popup borderless double_buffer
                                  \ no_cursor pause xterm_select select_line
                                  \ select_trailing_spaces report_as_keysyms
                                  \ itrans immotile_trans buttonbar
                                  \ resize_gravity nextgroup=etermBoolean
                                  \ skipwhite

syn region  etermTogContext       fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+toggles\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermTogOptions

syn keyword etermKeyboardOptions  contained smallfont_key bigfont_key keysym
                                  \ nextgroup=etermKeysym skipwhite

syn keyword etermKeysym           contained '\S\+' nextgroup=etermString
                                  \ skipwhite

syn keyword etermKeyboardOptions  contained meta_mod alt_mod numlock_mod
                                  \ nextgroup=etermNumber skipwhite

syn keyword etermKeyboardOptions  contained greek app_keypad app_cursor
                                  \ nextgroup=etermBoolean skipwhite

syn region  etermKeyboardContext  fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+keyboard\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermKeyboardOptions

syn keyword etermMiscOptions      contained print_pipe cut_chars finished_title
                                  \ finished_text term_name exec
                                  \ nextgroup=etermString skipwhite

syn keyword etermMiscOptions      contained save_lines min_anchor_size
                                  \ border_width line_space

syn region  etermMiscContext      fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+misc\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermMiscOptions

syn keyword etermEScreenOptions   contained url nextgroup=etermURL skipwhite

syn match   etermURL              contained display
                                  \ '\<\%(screen\|twin\)://\%([^@:/]\+\%(@[^:/]\+\%(:[^/]\+\)\=\)\=\)\=/\S\+'

syn keyword etermEScreenOptions   contained firewall

syn keyword etermEScreenOptions   contained delay nextgroup=etermNumber
                                  \ skipwhite

syn keyword etermEScreenOptions   contained bbar_font nextgroup=etermFont
                                  \ skipwhite

syn keyword etermEScreenOptions   contained bbar_dock nextgroup=etermDockOption
                                  \ skipwhite

syn region  etermEScreenContext   fold transparent matchgroup=etermContext
                                  \ start='^\s*begin\s\+escreen\>'
                                  \ end='^\s*end\>'
                                  \ contains=@etermGeneral,etermEScreenOptions

if exists("eterm_minlines")
  let b:eterm_minlines = eterm_minlines
else
  let b:eterm_minlines = 50
endif
exec "syn sync minlines=" . b:eterm_minlines

hi def link etermTodo             Todo
hi def link etermComment          Comment
hi def link etermMagic            PreProc
hi def link etermNumber           Number
hi def link etermString           String
hi def link etermBoolean          Boolean
hi def link etermPreProc          PreProc
hi def link etermFunctions        Function
hi def link etermKeyMod           Constant
hi def link etermOption           Keyword
hi def link etermColorOptions     etermOption
hi def link etermColor            String
hi def link etermVideoType        Type
hi def link etermColorType        Type
hi def link etermColorNumber      Number
hi def link etermColorSpec        etermColor
hi def link etermContext          Keyword
hi def link etermAttrOptions      etermOption
hi def link etermGeometry         String
hi def link etermScrollbarType    Type
hi def link etermFontType         Type
hi def link etermIClassOptions    etermOption
hi def link etermImageOptions     etermOption
hi def link etermImageTypes       Type
hi def link etermImageModes       Type
hi def link etermImageModesAllow  Keyword
hi def link etermImageModesR      Type
hi def link etermImageState       Keyword
hi def link etermImageColorFG     etermColor
hi def link etermImageColorBG     etermColor
hi def link etermImageGeom        String
hi def link etermImageCmod        etermOption
hi def link etermImageBrightness  Number
hi def link etermImageContrast    Number
hi def link etermImageGamma       Number
hi def link etermMenuItemOptions  etermOption
hi def link etermMenuItemAction   Keyword
hi def link etermMenuOptions      etermOption
hi def link etermBind             Keyword
hi def link etermBindMods         Identifier
hi def link etermBindTo           Keyword
hi def link etermBindType         Type
hi def link etermBindParam        String
hi def link etermButtonOptions    etermOption
hi def link etermDockOption       etermOption
hi def link etermButtonText       String
hi def link etermButtonIcon       String
hi def link etermButtonIconFile   String
hi def link etermButtonAction     Keyword
hi def link etermMultiOptions     etermOption
hi def link etermEncoding         Identifier
hi def link etermXimOptions       etermOption
hi def link etermInputMethod      Identifier
hi def link etermPreeditType      Type
hi def link etermTogOptions       etermOption
hi def link etermKeyboardOptions  etermOption
hi def link etermKeysym           Constant
hi def link etermMiscOptions      etermOption
hi def link etermEScreenOptions   etermOption
hi def link etermURL              Identifier

let b:current_syntax = "eterm"

let &cpo = s:cpo_save
unlet s:cpo_save
