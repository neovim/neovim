--- @meta
-- THIS FILE IS GENERATED
-- DO NOT EDIT
error('Cannot require a meta file')

--- @class vim.api.keyset.clear_autocmds
--- @field buffer any
--- @field event any
--- @field group any
--- @field pattern any

--- @class vim.api.keyset.cmd
--- @field cmd any
--- @field range any
--- @field count any
--- @field reg any
--- @field bang any
--- @field args any
--- @field magic any
--- @field mods any
--- @field nargs any
--- @field addr any
--- @field nextcmd any

--- @class vim.api.keyset.cmd_magic
--- @field file any
--- @field bar any

--- @class vim.api.keyset.cmd_mods
--- @field silent any
--- @field emsg_silent any
--- @field unsilent any
--- @field filter any
--- @field sandbox any
--- @field noautocmd any
--- @field browse any
--- @field confirm any
--- @field hide any
--- @field horizontal any
--- @field keepalt any
--- @field keepjumps any
--- @field keepmarks any
--- @field keeppatterns any
--- @field lockmarks any
--- @field noswapfile any
--- @field tab any
--- @field verbose any
--- @field vertical any
--- @field split any

--- @class vim.api.keyset.cmd_mods_filter
--- @field pattern any
--- @field force any

--- @class vim.api.keyset.cmd_opts
--- @field output any

--- @class vim.api.keyset.context
--- @field types any

--- @class vim.api.keyset.create_augroup
--- @field clear any

--- @class vim.api.keyset.create_autocmd
--- @field buffer any
--- @field callback any
--- @field command any
--- @field desc any
--- @field group any
--- @field nested any
--- @field once any
--- @field pattern any

--- @class vim.api.keyset.echo_opts
--- @field verbose any

--- @class vim.api.keyset.eval_statusline
--- @field winid any
--- @field maxwidth any
--- @field fillchar any
--- @field highlights any
--- @field use_winbar any
--- @field use_tabline any
--- @field use_statuscol_lnum any

--- @class vim.api.keyset.exec_autocmds
--- @field buffer any
--- @field group any
--- @field modeline any
--- @field pattern any
--- @field data any

--- @class vim.api.keyset.exec_opts
--- @field output any

--- @class vim.api.keyset.float_config
--- @field row any
--- @field col any
--- @field width any
--- @field height any
--- @field anchor any
--- @field relative any
--- @field win any
--- @field bufpos any
--- @field external any
--- @field focusable any
--- @field zindex any
--- @field border any
--- @field title any
--- @field title_pos any
--- @field style any
--- @field noautocmd any

--- @class vim.api.keyset.get_autocmds
--- @field event any
--- @field group any
--- @field pattern any
--- @field buffer any

--- @class vim.api.keyset.get_commands
--- @field builtin any

--- @class vim.api.keyset.get_highlight
--- @field id any
--- @field name any
--- @field link any

--- @class vim.api.keyset.highlight
--- @field bold any
--- @field standout any
--- @field strikethrough any
--- @field underline any
--- @field undercurl any
--- @field underdouble any
--- @field underdotted any
--- @field underdashed any
--- @field italic any
--- @field reverse any
--- @field altfont any
--- @field nocombine any
--- @field default_ any
--- @field cterm any
--- @field foreground any
--- @field fg any
--- @field background any
--- @field bg any
--- @field ctermfg any
--- @field ctermbg any
--- @field special any
--- @field sp any
--- @field link any
--- @field global_link any
--- @field fallback any
--- @field blend any
--- @field fg_indexed any
--- @field bg_indexed any

--- @class vim.api.keyset.highlight_cterm
--- @field bold any
--- @field standout any
--- @field strikethrough any
--- @field underline any
--- @field undercurl any
--- @field underdouble any
--- @field underdotted any
--- @field underdashed any
--- @field italic any
--- @field reverse any
--- @field altfont any
--- @field nocombine any

--- @class vim.api.keyset.keymap
--- @field noremap any
--- @field nowait any
--- @field silent any
--- @field script any
--- @field expr any
--- @field unique any
--- @field callback any
--- @field desc any
--- @field replace_keycodes any

--- @class vim.api.keyset.option
--- @field scope any
--- @field win any
--- @field buf any
--- @field filetype any

--- @class vim.api.keyset.runtime
--- @field is_lua any
--- @field do_source any

--- @class vim.api.keyset.set_decoration_provider
--- @field on_start any
--- @field on_buf any
--- @field on_win any
--- @field on_line any
--- @field on_end any
--- @field _on_hl_def any
--- @field _on_spell_nav any

--- @class vim.api.keyset.set_extmark
--- @field id any
--- @field end_line any
--- @field end_row any
--- @field end_col any
--- @field hl_group any
--- @field virt_text any
--- @field virt_text_pos any
--- @field virt_text_win_col any
--- @field virt_text_hide any
--- @field hl_eol any
--- @field hl_mode any
--- @field ephemeral any
--- @field priority any
--- @field right_gravity any
--- @field end_right_gravity any
--- @field virt_lines any
--- @field virt_lines_above any
--- @field virt_lines_leftcol any
--- @field strict any
--- @field sign_text any
--- @field sign_hl_group any
--- @field number_hl_group any
--- @field line_hl_group any
--- @field cursorline_hl_group any
--- @field conceal any
--- @field spell any
--- @field ui_watched any

--- @class vim.api.keyset.user_command
--- @field addr any
--- @field bang any
--- @field bar any
--- @field complete any
--- @field count any
--- @field desc any
--- @field force any
--- @field keepscript any
--- @field nargs any
--- @field preview any
--- @field range any
--- @field register_ any

--- @class vim.api.keyset.win_text_height
--- @field start_row any
--- @field end_row any
--- @field start_vcol any
--- @field end_vcol any
