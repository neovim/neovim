((function_call
  name: [
    (identifier) @_cdef_identifier
    (_ _ (identifier) @_cdef_identifier)
  ]
  arguments: (arguments (string content: _ @injection.content)))
  (#set! injection.language "c")
  (#eq? @_cdef_identifier "cdef"))

((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments (string content: _ @injection.content)))
  (#set! injection.language "vim")
  (#any-of? @_vimcmd_identifier "vim.cmd" "vim.api.nvim_command" "vim.api.nvim_exec2" "vim.api.nvim_cmd"))

; vim.rcprequest(123, "nvim_exec_lua", "return vim.api.nvim_buf_get_lines(0, 0, -1, false)", false)
((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments . (_) . (string content: _ @_method) . (string content: _ @injection.content)))
  (#set! injection.language "lua")
  (#any-of? @_vimcmd_identifier "vim.rpcrequest" "vim.rpcnotify")
  (#eq? @_method "nvim_exec_lua"))

((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments (string content: _ @injection.content) .))
  (#set! injection.language "query")
  (#any-of? @_vimcmd_identifier "vim.treesitter.query.set" "vim.treesitter.query.parse"))

;; highlight string as query if starts with `;; query`
(string content: _ @injection.content
 (#set! injection.language "query")
 (#lua-match? @injection.content "^%s*;+%s?query"))

; ((comment) @injection.content
;  (#set! injection.language "comment"))
