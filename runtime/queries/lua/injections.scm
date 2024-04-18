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

((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    (string
      content: _ @injection.content)))
  (#set! injection.language "vim")
  (#any-of? @_vimcmd_identifier
    "vim.cmd" "vim.api.nvim_command" "vim.api.nvim_command" "vim.api.nvim_exec2"))

((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments
    (string
      content: _ @injection.content) .))
  (#set! injection.language "query")
  (#any-of? @_vimcmd_identifier "vim.treesitter.query.set" "vim.treesitter.query.parse"))

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
  (#set! injection.language "lua"))

; exec_lua [[ ... ]] in functionaltests
((function_call
  name: (identifier) @_function
  arguments: (arguments
    (string
      content: (string_content) @injection.content)))
  (#eq? @_function "exec_lua")
  (#set! injection.language "lua"))

; vim.api.nvim_create_autocmd("FileType", { command = "injected here" })
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
  ; limit so only 2-argument functions gets matched before pred handle
  (#eq? @_vimcmd_identifier "vim.api.nvim_create_autocmd")
  (#eq? @_command "command")
  (#set! injection.language "vim"))

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
  (#set! injection.language "vim"))

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
  ; Limiting predicate handling to only functions with 4 arguments
  (#eq? @_user_cmd "vim.api.nvim_buf_create_user_command")
  (#set! injection.language "vim"))

; rhs highlighting for vim.keymap.set/vim.api.nvim_set_keymap/vim.api.nvim_buf_set_keymap
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
; highlight string as query if starts with `;; query`
(string
  content: _ @injection.content
  (#lua-match? @injection.content "^%s*;+%s?query")
  (#set! injection.language "query"))
