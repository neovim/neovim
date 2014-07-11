" Vim syntax file
" Language:         elinks(1) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-06-17

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn keyword elinksTodo      contained TODO FIXME XXX NOTE

syn region  elinksComment   display oneline start='#' end='$'
                            \ contains=elinksTodo,@Spell

syn match   elinksNumber    '\<\d\+\>'

syn region  elinksString    start=+"+ skip=+\\\\\|\\"+ end=+"+
                            \ contains=@elinksColor

syn keyword elinksKeyword   set bind

syn keyword elinksPrefix    bookmarks
syn keyword elinksOptions   file_format

syn keyword elinksPrefix    config
syn keyword elinksOptions   comments indentation saving_style i18n
                            \ saving_style_w show_template

syn keyword elinksPrefix    connection ssl client_cert
syn keyword elinksOptions   enable file cert_verify async_dns max_connections
                            \ max_connections_to_host receive_timeout retries
                            \ unrestartable_receive_timeout

syn keyword elinksPrefix    cookies
syn keyword elinksOptions   accept_policy max_age paranoid_security save resave

syn keyword elinksPrefix    document browse accesskey forms images links
syn keyword elinksPrefix    active_link colors search cache codepage colors
syn keyword elinksPrefix    format memory download dump history global html
syn keyword elinksPrefix    plain
syn keyword elinksOptions   auto_follow priority auto_submit confirm_submit
                            \ input_size show_formhist file_tags
                            \ image_link_tagging image_link_prefix
                            \ image_link_suffix show_as_links
                            \ show_any_as_links background text enable_color
                            \ bold invert underline color_dirs numbering
                            \ use_tabindex number_keys_select_link
                            \ wraparound case regex show_hit_top_bottom
                            \ wraparound show_not_found margin_width refresh
                            \ minimum_refresh_time scroll_margin scroll_step
                            \ table_move_order size size cache_redirects
                            \ ignore_cache_control assume force_assumed text
                            \ background link vlink dirs allow_dark_on_black
                            \ ensure_contrast use_document_colors directory
                            \ set_original_time overwrite notify_bell
                            \ codepage width enable max_items display_type
                            \ write_interval keep_unhistory display_frames
                            \ display_tables expand_table_columns display_subs
                            \ display_sups link_display underline_links
                            \ wrap_nbsp display_links compress_empty_lines

syn keyword elinksPrefix    mime extension handler mailcap mimetypes type
syn keyword elinksOptions   ask block program enable path ask description
                            \ prioritize enable path default_type

syn keyword elinksPrefix    protocol file cgi ftp proxy http bugs proxy
syn keyword elinksPrefix    referer https proxy rewrite dumb smart
syn keyword elinksOptions   path policy allow_special_files show_hidden_files
                            \ try_encoding_extensions host anon_passwd
                            \ use_pasv use_epsv accept_charset allow_blacklist
                            \ broken_302_redirect post_no_keepalive http10
                            \ host user passwd policy fake accept_language
                            \ accept_ui_language trace user_agent host
                            \ enable-dumb enable-smart

syn keyword elinksPrefix    terminal
syn keyword elinksOptions   type m11_hack utf_8_io restrict_852 block_cursor
                            \ colors transparency underline charset

syn keyword elinksPrefix    ui colors color mainmenu normal selected hotkey
                            \ menu marked hotkey frame dialog generic
                            \ frame scrollbar scrollbar-selected title text
                            \ checkbox checkbox-label button button-selected
                            \ field field-text meter shadow title title-bar
                            \ title-text status status-bar status-text tabs
                            \ unvisited normal loading separator searched mono
syn keyword elinksOptions   text background

syn keyword elinksPrefix    ui dialogs leds sessions tabs timer
syn keyword elinksOptions   listbox_min_height shadows underline_hotkeys enable
                            \ auto_save auto_restore auto_save_foldername
                            \ homepage show_bar wraparound confirm_close
                            \ enable duration action language show_status_bar
                            \ show_title_bar startup_goto_dialog
                            \ success_msgbox window_title

syn keyword elinksOptions   secure_file_saving

syn cluster elinksColor     contains=elinksColorBlack,elinksColorDarkRed,
                            \ elinksColorDarkGreen,elinksColorDarkYellow,
                            \ elinksColorDarkBlue,elinksColorDarkMagenta,
                            \ elinksColorDarkCyan,elinksColorGray,
                            \ elinksColorDarkGray,elinksColorRed,
                            \ elinksColorGreen,elinksColorYellow,
                            \ elinksColorBlue,elinksColorMagenta,
                            \ elinksColorCyan,elinksColorWhite

syn keyword elinksColorBlack        contained black
syn keyword elinksColorDarkRed      contained darkred sandybrown maroon crimson
                                    \ firebrick
syn keyword elinksColorDarkGreen    contained darkgreen darkolivegreen
                                    \ darkseagreen forestgreen
                                    \ mediumspringgreen seagreen
syn keyword elinksColorDarkYellow   contained brown blanchedalmond chocolate
                                    \ darkorange darkgoldenrod orange rosybrown
                                    \ saddlebrown peru olive olivedrab sienna
syn keyword elinksColorDarkBlue     contained darkblue cadetblue cornflowerblue
                                    \ darkslateblue deepskyblue midnightblue
                                    \ royalblue steelblue navy
syn keyword elinksColorDarkMagenta  contained darkmagenta mediumorchid
                                    \ mediumpurple mediumslateblue slateblue
                                    \ deeppink hotpink darkorchid orchid purple
                                    \ indigo
syn keyword elinksColorDarkCyan     contained darkcyan mediumaquamarine
                                    \ mediumturquoise darkturquoise teal
syn keyword elinksColorGray         contained silver dimgray lightslategray
                                    \ slategray lightgrey burlywood plum tan
                                    \ thistle
syn keyword elinksColorDarkGray     contained gray darkgray darkslategray
                                    \ darksalmon
syn keyword elinksColorRed          contained red indianred orangered tomato
                                    \ lightsalmon salmon coral lightcoral
syn keyword elinksColorGreen        contained green greenyellow lawngreen
                                    \ lightgreen lightseagreen limegreen
                                    \ mediumseagreen springgreen yellowgreen
                                    \ palegreen lime chartreuse
syn keyword elinksColorYellow       contained yellow beige darkkhaki
                                    \ lightgoldenrodyellow palegoldenrod gold
                                    \ goldenrod khaki lightyellow
syn keyword elinksColorBlue         contained blue aliceblue aqua aquamarine
                                    \ azure dodgerblue lightblue lightskyblue
                                    \ lightsteelblue mediumblue
syn keyword elinksColorMagenta      contained magenta darkviolet blueviolet
                                    \ lightpink mediumvioletred palevioletred
                                    \ violet pink fuchsia
syn keyword elinksColorCyan         contained cyan lightcyan powderblue skyblue
                                    \ turquoise paleturquoise
syn keyword elinksColorWhite        contained white antiquewhite floralwhite
                                    \ ghostwhite navajowhite whitesmoke linen
                                    \ lemonchiffon cornsilk lavender
                                    \ lavenderblush seashell mistyrose ivory
                                    \ papayawhip bisque gainsboro honeydew
                                    \ mintcream moccasin oldlace peachpuff snow
                                    \ wheat

hi def link elinksTodo              Todo
hi def link elinksComment           Comment
hi def link elinksNumber            Number
hi def link elinksString            String
hi def link elinksKeyword           Keyword
hi def link elinksPrefix            Identifier
hi def link elinksOptions           Identifier
hi def      elinksColorBlack        ctermfg=Black       guifg=Black
hi def      elinksColorDarkRed      ctermfg=DarkRed     guifg=DarkRed
hi def      elinksColorDarkGreen    ctermfg=DarkGreen   guifg=DarkGreen
hi def      elinksColorDarkYellow   ctermfg=DarkYellow  guifg=DarkYellow
hi def      elinksColorDarkBlue     ctermfg=DarkBlue    guifg=DarkBlue
hi def      elinksColorDarkMagenta  ctermfg=DarkMagenta guifg=DarkMagenta
hi def      elinksColorDarkCyan     ctermfg=DarkCyan    guifg=DarkCyan
hi def      elinksColorGray         ctermfg=Gray        guifg=Gray
hi def      elinksColorDarkGray     ctermfg=DarkGray    guifg=DarkGray
hi def      elinksColorRed          ctermfg=Red         guifg=Red
hi def      elinksColorGreen        ctermfg=Green       guifg=Green
hi def      elinksColorYellow       ctermfg=Yellow      guifg=Yellow
hi def      elinksColorBlue         ctermfg=Blue        guifg=Blue
hi def      elinksColorMagenta      ctermfg=Magenta     guifg=Magenta
hi def      elinksColorCyan         ctermfg=Cyan        guifg=Cyan
hi def      elinksColorWhite        ctermfg=White       guifg=White

let b:current_syntax = "elinks"

let &cpo = s:cpo_save
unlet s:cpo_save
