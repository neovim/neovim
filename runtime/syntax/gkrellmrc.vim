" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: gkrellm theme files `gkrellmrc'
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2003-04-30
" URL: http://trific.ath.cx/Ftp/vim/syntax/gkrellmrc.vim

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

setlocal iskeyword=_,-,a-z,A-Z,48-57

syn case match

" Base constructs
syn match gkrellmrcComment "#.*$" contains=gkrellmrcFixme
syn keyword gkrellmrcFixme FIXME TODO XXX NOT contained
syn region gkrellmrcString start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline
syn match gkrellmrcNumber "^-\=\(\d\+\)\=\.\=\d\+"
syn match gkrellmrcNumber "\W-\=\(\d\+\)\=\.\=\d\+"lc=1
syn keyword gkrellmrcConstant none
syn match gkrellmrcRGBColor "#\(\x\{12}\|\x\{9}\|\x\{6}\|\x\{3}\)\>"

" Keywords
syn keyword gkrellmrcBuiltinExt cpu_nice_color cpu_nice_grid_color krell_depth krell_expand krell_left_margin krell_right_margin krell_x_hot krell_yoff mem_krell_buffers_depth mem_krell_buffers_expand mem_krell_buffers_x_hot mem_krell_buffers_yoff mem_krell_cache_depth mem_krell_cache_expand mem_krell_cache_x_hot mem_krell_cache_yoff sensors_bg_volt timer_bg_timer
syn keyword gkrellmrcGlobal allow_scaling author chart_width_ref theme_alternatives
syn keyword gkrellmrcSetCmd set_image_border set_integer set_string
syn keyword gkrellmrcGlobal bg_slider_meter_border bg_slider_panel_border
syn keyword gkrellmrcGlobal frame_bottom_height frame_left_width frame_right_width frame_top_height frame_left_chart_overlap frame_right_chart_overlap frame_left_panel_overlap frame_right_panel_overlap frame_left_spacer_overlap frame_right_spacer_overlap spacer_overlap_off cap_images_off
syn keyword gkrellmrcGlobal frame_bottom_border frame_left_border frame_right_border frame_top_border spacer_top_border spacer_bottom_border frame_left_chart_border frame_right_chart_border frame_left_panel_border frame_right_panel_border
syn keyword gkrellmrcGlobal chart_in_color chart_in_color_grid chart_out_color chart_out_color_grid
syn keyword gkrellmrcGlobal bg_separator_height bg_grid_mode
syn keyword gkrellmrcGlobal rx_led_x rx_led_y tx_led_x tx_led_y
syn keyword gkrellmrcGlobal decal_mail_frames decal_mail_delay
syn keyword gkrellmrcGlobal decal_alarm_frames decal_warn_frames
syn keyword gkrellmrcGlobal krell_slider_depth krell_slider_expand krell_slider_x_hot
syn keyword gkrellmrcGlobal button_panel_border button_meter_border
syn keyword gkrellmrcGlobal large_font normal_font small_font
syn keyword gkrellmrcGlobal spacer_bottom_height spacer_top_height spacer_bottom_height_chart spacer_top_height_chart spacer_bottom_height_meter spacer_top_height_meter
syn keyword gkrellmrcExpandMode left right bar-mode left-scaled right-scaled bar-mode-scaled
syn keyword gkrellmrcMeterName apm cal clock fs host mail mem swap timer sensors uptime
syn keyword gkrellmrcChartName cpu proc disk inet and net
syn match gkrellmrcSpecialClassName "\*"
syn keyword gkrellmrcStyleCmd StyleMeter StyleChart StylePanel
syn keyword gkrellmrcStyleItem textcolor alt_textcolor font alt_font transparency border label_position margin margins left_margin right_margin top_margin bottom_margin krell_depth krell_yoff krell_x_hot krell_expand krell_left_margin krell_right_margin

" Define the default highlighting

hi def link gkrellmrcComment Comment
hi def link gkrellmrcFixme Todo

hi def link gkrellmrcString gkrellmrcConstant
hi def link gkrellmrcNumber gkrellmrcConstant
hi def link gkrellmrcRGBColor gkrellmrcConstant
hi def link gkrellmrcExpandMode gkrellmrcConstant
hi def link gkrellmrcConstant Constant

hi def link gkrellmrcMeterName gkrellmrcClass
hi def link gkrellmrcChartName gkrellmrcClass
hi def link gkrellmrcSpecialClassName gkrellmrcClass
hi def link gkrellmrcClass Type

hi def link gkrellmrcGlobal gkrellmrcItem
hi def link gkrellmrcBuiltinExt gkrellmrcItem
hi def link gkrellmrcStyleItem gkrellmrcItem
hi def link gkrellmrcItem Function

hi def link gkrellmrcSetCmd Special
hi def link gkrellmrcStyleCmd Statement


let b:current_syntax = "gkrellmrc"
