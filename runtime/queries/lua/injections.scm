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
  (#any-of? @_vimcmd_identifier "vim.cmd" "vim.api.nvim_command" "vim.api.nvim_exec" "vim.api.nvim_cmd"))

((function_call
  name: (_) @_vimcmd_identifier
  arguments: (arguments (string content: _ @injection.content) .))
  (#set! injection.language "query")
  (#eq? @_vimcmd_identifier "vim.treesitter.query.set_query"))

; ;; highlight string as query if starts with `;; query`
; ((string ("string_content") @injection.content)
;  (#set! injection.language "query")
;  (#lua-match? @injection.content "^%s*;+%s?query"))

; ((comment) @injection.content
;  (#set! injection.language "comment"))
