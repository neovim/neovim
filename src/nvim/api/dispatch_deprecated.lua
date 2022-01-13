local deprecated_aliases = {
  nvim_buf_add_highlight = 'buffer_add_highlight',
  nvim_buf_clear_highlight = 'buffer_clear_highlight',
  nvim_buf_get_lines = 'buffer_get_lines',
  nvim_buf_get_mark = 'buffer_get_mark',
  nvim_buf_get_name = 'buffer_get_name',
  nvim_buf_get_number = 'buffer_get_number',
  nvim_buf_get_option = 'buffer_get_option',
  nvim_buf_get_var = 'buffer_get_var',
  nvim_buf_is_valid = 'buffer_is_valid',
  nvim_buf_line_count = 'buffer_line_count',
  nvim_buf_set_lines = 'buffer_set_lines',
  nvim_buf_set_name = 'buffer_set_name',
  nvim_buf_set_option = 'buffer_set_option',
  nvim_call_function = 'vim_call_function',
  nvim_command = 'vim_command',
  nvim_command_output = 'vim_command_output',
  nvim_del_current_line = 'vim_del_current_line',
  nvim_err_write = 'vim_err_write',
  nvim_err_writeln = 'vim_report_error',
  nvim_eval = 'vim_eval',
  nvim_feedkeys = 'vim_feedkeys',
  nvim_get_api_info = 'vim_get_api_info',
  nvim_get_color_by_name = 'vim_name_to_color',
  nvim_get_color_map = 'vim_get_color_map',
  nvim_get_current_buf = 'vim_get_current_buffer',
  nvim_get_current_line = 'vim_get_current_line',
  nvim_get_current_tabpage = 'vim_get_current_tabpage',
  nvim_get_current_win = 'vim_get_current_window',
  nvim_get_option = 'vim_get_option',
  nvim_get_var = 'vim_get_var',
  nvim_get_vvar = 'vim_get_vvar',
  nvim_input = 'vim_input',
  nvim_list_bufs = 'vim_get_buffers',
  nvim_list_runtime_paths = 'vim_list_runtime_paths',
  nvim_list_tabpages = 'vim_get_tabpages',
  nvim_list_wins = 'vim_get_windows',
  nvim_out_write = 'vim_out_write',
  nvim_replace_termcodes = 'vim_replace_termcodes',
  nvim_set_current_buf = 'vim_set_current_buffer',
  nvim_set_current_dir = 'vim_change_directory',
  nvim_set_current_line = 'vim_set_current_line',
  nvim_set_current_tabpage = 'vim_set_current_tabpage',
  nvim_set_current_win = 'vim_set_current_window',
  nvim_set_option = 'vim_set_option',
  nvim_strwidth = 'vim_strwidth',
  nvim_subscribe = 'vim_subscribe',
  nvim_tabpage_get_var = 'tabpage_get_var',
  nvim_tabpage_get_win = 'tabpage_get_window',
  nvim_tabpage_is_valid = 'tabpage_is_valid',
  nvim_tabpage_list_wins = 'tabpage_get_windows',
  nvim_ui_detach = 'ui_detach',
  nvim_ui_try_resize = 'ui_try_resize',
  nvim_unsubscribe = 'vim_unsubscribe',
  nvim_win_get_buf = 'window_get_buffer',
  nvim_win_get_cursor = 'window_get_cursor',
  nvim_win_get_height = 'window_get_height',
  nvim_win_get_option = 'window_get_option',
  nvim_win_get_position = 'window_get_position',
  nvim_win_get_tabpage = 'window_get_tabpage',
  nvim_win_get_var = 'window_get_var',
  nvim_win_get_width = 'window_get_width',
  nvim_win_is_valid = 'window_is_valid',
  nvim_win_set_cursor = 'window_set_cursor',
  nvim_win_set_height = 'window_set_height',
  nvim_win_set_option = 'window_set_option',
  nvim_win_set_width = 'window_set_width',
}
return deprecated_aliases
