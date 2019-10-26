
cquery = [[
"break" @keyword
"case" @keyword
"continue" @keyword
"do" @keyword
"else" @keyword
"for" @keyword
"if" @keyword
"return" @keyword
"sizeof" @keyword
"switch" @keyword
"while" @keyword

"const" @keyword.storagecls
"static" @keyword.storagecls
"struct" @keyword.storagecls
"inline" @keyword.storagecls
"enum" @keyword.storagecls
"extern" @keyword.storagecls
"typedef" @keyword.storagecls
"union" @keyword.storagecls

"#define" @keyword.preproc
"#else" @keyword.preproc
"#endif" @keyword.preproc
"#if" @keyword.preproc
"#ifdef" @keyword.preproc
"#ifndef" @keyword.preproc
"#include" @keyword.preproc
(preproc_directive) @keyword.preproc

(string_literal) @string
(system_lib_string) @string

(number_literal) @number
(char_literal) @string

(field_identifier) @property

(type_identifier) @type.user
(primitive_type) @type
(sized_type_specifier) @type

((function_definition (storage_class_specifier) @funcclass declarator: (function_declarator (identifier) @function.static))  (eq? @funcclass "static"))

((binary_expression left: (identifier) @dup.left right: (identifier) @dup.right) @dup (eq? @dup.left @dup.right))

(comment) @comment

(call_expression
  function: (identifier) @function)
(function_declarator
  declarator: (identifier) @function)
(preproc_function_def
  name: (identifier) @function)
]]

c_highlight_bufs = c_highlight_bufs or {}

for _, highlighter in pairs(c_highlight_bufs) do
  highlighter:set_query(cquery)
end

local TSHighlighter = require'vim.ts_highlight'

function chl_check_buf()
  local bufnr = vim.api.nvim_get_current_buf()
  if c_highlight_bufs[bufnr] == nil then
    c_highlight_bufs[bufnr] = TSHighlighter.new(cquery)
  end
end

vim.api.nvim_command([[augroup TSCHL]])
vim.api.nvim_command([[au! FileType c lua chl_check_buf() ]])
vim.api.nvim_command([[augroup END ]])

if vim.api.nvim_buf_get_option(0,"ft") == "c" then
  chl_check_buf()
end
