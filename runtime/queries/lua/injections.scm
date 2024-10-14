; Refine injections for `cdef` calls (no changes needed in this section)
((function_call
  name: [
    (identifier) @_cdef_identifier
    (_
      _
      (identifier) @_cdef_identifier)
  ]
  arguments: (arguments
    (string
      content: _ @injection.content)))
  (#set! injection.language "c")
  (#eq? @_cdef_identifier "cdef"))

; Injection for `vim.cmd` and related commands (added `#set! injection.combined` to ensure proper boundaries)
((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    (string
      content: _ @injection.content)))
  (#set! injection.language "vim")
  (#set! injection.combined) ; Prevent language leakage beyond the function call
  (#any-of? @_vimcmd_identifier
    "vim.cmd" "vim.api.nvim_command" "vim.api.nvim_exec2"))

; Injection for Tree-sitter query functions (e.g., `vim.treesitter.query.set`) 
; Added combined to properly handle multi-line strings.
((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    (string
      content: _ @injection.content) .))
  (#set! injection.language "query")
  (#set! injection.combined) ; Ensures query injection is isolated
  (#any-of? @_vimcmd_identifier "vim.treesitter.query.set" "vim.treesitter.query.parse"))

; Injection for `vim.rpcrequest` and `vim.rpcnotify` with Lua code inside
((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    .
    (_)
    .
    (string
      content: _ @_method)
    .
    (string
      content: _ @injection.content)))
  (#any-of? @_vimcmd_identifier "vim.rpcrequest" "vim.rpcnotify")
  (#eq? @_method "nvim_exec_lua")
  (#set! injection.language "lua")
  (#set! injection.combined))

; Handle Lua injection in `exec_lua` function calls
((function_call
  name: (identifier) @_function
  arguments: (arguments
    (string
      content: (string_content) @injection.content)))
  (#eq? @_function "exec_lua")
  (#set! injection.language "lua")
  (#set! injection.combined))

; Handle `vim.api.nvim_create_autocmd` command injection
(function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    .
    (_)
    .
    (table_constructor
      (field
        name: (identifier) @_command
        value: (string
          content: (_) @injection.content))) .)
  (#eq? @_vimcmd_identifier "vim.api.nvim_create_autocmd")
  (#eq? @_command "command")
  (#set! injection.language "vim")
  (#set! injection.combined)) ; Combine injections for multi-line handling

; Handle `vim.api.nvim_create_user_command` injection
(function_call
  name: (_) @_user_cmd
  arguments: (arguments
    .
    (_)
    .
    (string
      content: (_) @injection.content)
    .
    (_) .)
  (#eq? @_user_cmd "vim.api.nvim_create_user_command")
  (#set! injection.language "vim")
  (#set! injection.combined))

; Handle `vim.api.nvim_buf_create_user_command` injection (with 4 arguments)
(function_call
  name: (_) @_user_cmd
  arguments: (arguments
    .
    (_)
    .
    (_)
    .
    (string
      content: (_) @injection.content)
    .
    (_) .)
  (#eq? @_user_cmd "vim.api.nvim_buf_create_user_command")
  (#set! injection.language "vim")
  (#set! injection.combined))

; Handle comments for `vim.api.nvim_set_keymap` and `vim.keymap.set`
; (This section is commented out but can be enabled if needed.)
;
; (function_call
;   name: (_) @_map
;   arguments:
;     (arguments
;       . (_)
;       . (_)
;       .
;       (string
;         content: (_) @injection.content))
;   (#any-of? @_map "vim.api.nvim_set_keymap" "vim.keymap.set")
;   (#set! injection.language "vim"))
;
; (function_call
;   name: (_) @_map
;   arguments:
;     (arguments
;       . (_)
;       . (_)
;       . (_)
;       .
;       (string
;         content: (_) @injection.content)
;       . (_) .)
;   (#eq? @_map "vim.api.nvim_buf_set_keymap")
;   (#set! injection.language "vim"))

; Handle special `query` injection based on comment style
(string
  content: _ @injection.content
  (#lua-match? @injection.content "^%s*;+%s?query")
  (#set! injection.language "query"))
