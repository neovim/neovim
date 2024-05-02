--- @meta _
-- THIS FILE IS GENERATED
-- DO NOT EDIT
error('Cannot require a meta file')

--- @class vim.api.keyset.buf_attach
--- @field on_lines? function
--- @field on_bytes? function
--- @field on_changedtick? function
--- @field on_detach? function
--- @field on_reload? function
--- @field utf_sizes? boolean
--- @field preview? boolean

--- @class vim.api.keyset.buf_delete
--- @field force? boolean
--- @field unload? boolean

--- @class vim.api.keyset.clear_autocmds
--- @field buffer? integer
--- @field event? any
--- @field group? any
--- @field pattern? any

--- @class vim.api.keyset.cmd
--- @field cmd? string
--- @field range? any[]
--- @field count? integer
--- @field reg? string
--- @field bang? boolean
--- @field args? any[]
--- @field magic? table<string,any>
--- @field mods? table<string,any>
--- @field nargs? any
--- @field addr? any
--- @field nextcmd? any

--- @class vim.api.keyset.cmd_magic
--- @field file? boolean
--- @field bar? boolean

--- @class vim.api.keyset.cmd_mods
--- @field silent? boolean
--- @field emsg_silent? boolean
--- @field unsilent? boolean
--- @field filter? table<string,any>
--- @field sandbox? boolean
--- @field noautocmd? boolean
--- @field browse? boolean
--- @field confirm? boolean
--- @field hide? boolean
--- @field horizontal? boolean
--- @field keepalt? boolean
--- @field keepjumps? boolean
--- @field keepmarks? boolean
--- @field keeppatterns? boolean
--- @field lockmarks? boolean
--- @field noswapfile? boolean
--- @field tab? integer
--- @field verbose? integer
--- @field vertical? boolean
--- @field split? string

--- @class vim.api.keyset.cmd_mods_filter
--- @field pattern? string
--- @field force? boolean

--- @class vim.api.keyset.cmd_opts
--- @field output? boolean

--- @class vim.api.keyset.complete_set
--- @field info? string

--- @class vim.api.keyset.context
--- @field types? any[]

--- @class vim.api.keyset.create_augroup
--- @field clear? any

--- @class vim.api.keyset.create_autocmd
--- @field buffer? integer
--- @field callback? any
--- @field command? string
--- @field desc? string
--- @field group? any
--- @field nested? boolean
--- @field once? boolean
--- @field pattern? any

--- @class vim.api.keyset.echo_opts
--- @field verbose? boolean

--- @class vim.api.keyset.empty

--- @class vim.api.keyset.eval_statusline
--- @field winid? integer
--- @field maxwidth? integer
--- @field fillchar? string
--- @field highlights? boolean
--- @field use_winbar? boolean
--- @field use_tabline? boolean
--- @field use_statuscol_lnum? integer

--- @class vim.api.keyset.exec_autocmds
--- @field buffer? integer
--- @field group? any
--- @field modeline? boolean
--- @field pattern? any
--- @field data? any

--- @class vim.api.keyset.exec_opts
--- @field output? boolean

--- @class vim.api.keyset.get_autocmds
--- @field event? any
--- @field group? any
--- @field pattern? any
--- @field buffer? any

--- @class vim.api.keyset.get_commands
--- @field builtin? boolean

--- @class vim.api.keyset.get_extmark
--- @field details? boolean
--- @field hl_name? boolean

--- @class vim.api.keyset.get_extmarks
--- @field limit? integer
--- @field details? boolean
--- @field hl_name? boolean
--- @field overlap? boolean
--- @field type? string

--- @class vim.api.keyset.get_highlight
--- @field id? integer
--- @field name? string
--- @field link? boolean
--- @field create? boolean

--- @class vim.api.keyset.get_ns
--- @field winid? integer

--- @class vim.api.keyset.highlight
--- @field bold? boolean
--- @field standout? boolean
--- @field strikethrough? boolean
--- @field underline? boolean
--- @field undercurl? boolean
--- @field underdouble? boolean
--- @field underdotted? boolean
--- @field underdashed? boolean
--- @field italic? boolean
--- @field reverse? boolean
--- @field altfont? boolean
--- @field nocombine? boolean
--- @field default? boolean
--- @field cterm? any
--- @field foreground? any
--- @field fg? any
--- @field background? any
--- @field bg? any
--- @field ctermfg? any
--- @field ctermbg? any
--- @field special? any
--- @field sp? any
--- @field link? any
--- @field global_link? any
--- @field fallback? boolean
--- @field blend? integer
--- @field fg_indexed? boolean
--- @field bg_indexed? boolean
--- @field force? boolean
--- @field url? string

--- @class vim.api.keyset.highlight_cterm
--- @field bold? boolean
--- @field standout? boolean
--- @field strikethrough? boolean
--- @field underline? boolean
--- @field undercurl? boolean
--- @field underdouble? boolean
--- @field underdotted? boolean
--- @field underdashed? boolean
--- @field italic? boolean
--- @field reverse? boolean
--- @field altfont? boolean
--- @field nocombine? boolean

--- @class vim.api.keyset.keymap
--- @field noremap? boolean
--- @field nowait? boolean
--- @field silent? boolean
--- @field script? boolean
--- @field expr? boolean
--- @field unique? boolean
--- @field callback? function
--- @field desc? string
--- @field replace_keycodes? boolean

--- @class vim.api.keyset.open_term
--- @field on_input? function
--- @field force_crlf? boolean

--- @class vim.api.keyset.option
--- @field scope? string
--- @field win? integer
--- @field buf? integer
--- @field filetype? string

--- @class vim.api.keyset.redraw
--- @field flush? boolean
--- @field cursor? boolean
--- @field valid? boolean
--- @field statuscolumn? boolean
--- @field statusline? boolean
--- @field tabline? boolean
--- @field winbar? boolean
--- @field range? any[]
--- @field win? integer
--- @field buf? integer

--- @class vim.api.keyset.runtime
--- @field is_lua? boolean
--- @field do_source? boolean

--- @class vim.api.keyset.set_decoration_provider
--- @field on_start? function
--- @field on_buf? function
--- @field on_win? function
--- @field on_line? function
--- @field on_end? function
--- @field _on_hl_def? function
--- @field _on_spell_nav? function

--- @class vim.api.keyset.set_extmark
--- @field id? integer
--- @field end_line? integer
--- @field end_row? integer
--- @field end_col? integer
--- @field hl_group? number|string
--- @field virt_text? any[]
--- @field virt_text_pos? string
--- @field virt_text_win_col? integer
--- @field virt_text_hide? boolean
--- @field virt_text_repeat_linebreak? boolean
--- @field hl_eol? boolean
--- @field hl_mode? string
--- @field invalidate? boolean
--- @field ephemeral? boolean
--- @field priority? integer
--- @field right_gravity? boolean
--- @field end_right_gravity? boolean
--- @field virt_lines? any[]
--- @field virt_lines_above? boolean
--- @field virt_lines_leftcol? boolean
--- @field strict? boolean
--- @field sign_text? string
--- @field sign_hl_group? number|string
--- @field number_hl_group? number|string
--- @field line_hl_group? number|string
--- @field cursorline_hl_group? number|string
--- @field conceal? string
--- @field spell? boolean
--- @field ui_watched? boolean
--- @field undo_restore? boolean
--- @field url? string
--- @field scoped? boolean

--- @class vim.api.keyset.user_command
--- @field addr? any
--- @field bang? boolean
--- @field bar? boolean
--- @field complete? any
--- @field count? any
--- @field desc? any
--- @field force? boolean
--- @field keepscript? boolean
--- @field nargs? any
--- @field preview? any
--- @field range? any
--- @field register? boolean

--- @class vim.api.keyset.win_config
--- @field row? number
--- @field col? number
--- @field width? integer
--- @field height? integer
--- @field anchor? string
--- @field relative? string
--- @field split? string
--- @field win? integer
--- @field bufpos? any[]
--- @field external? boolean
--- @field focusable? boolean
--- @field vertical? boolean
--- @field zindex? integer
--- @field border? any
--- @field title? any
--- @field title_pos? string
--- @field footer? any
--- @field footer_pos? string
--- @field style? string
--- @field noautocmd? boolean
--- @field fixed? boolean
--- @field hide? boolean

--- @class vim.api.keyset.win_text_height
--- @field start_row? integer
--- @field end_row? integer
--- @field start_vcol? integer
--- @field end_vcol? integer

--- @class vim.api.keyset.xdl_diff
--- @field on_hunk? function
--- @field result_type? string
--- @field algorithm? string
--- @field ctxlen? integer
--- @field interhunkctxlen? integer
--- @field linematch? any
--- @field ignore_whitespace? boolean
--- @field ignore_whitespace_change? boolean
--- @field ignore_whitespace_change_at_eol? boolean
--- @field ignore_cr_at_eol? boolean
--- @field ignore_blank_lines? boolean
--- @field indent_heuristic? boolean
