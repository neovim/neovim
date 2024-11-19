; Keywords
"return" @keyword.return

[
  "goto"
  "in"
  "local"
] @keyword

(break_statement) @keyword

(do_statement
  [
    "do"
    "end"
  ] @keyword)

(while_statement
  [
    "while"
    "do"
    "end"
  ] @keyword.repeat)

(repeat_statement
  [
    "repeat"
    "until"
  ] @keyword.repeat)

(if_statement
  [
    "if"
    "elseif"
    "else"
    "then"
    "end"
  ] @keyword.conditional)

(elseif_statement
  [
    "elseif"
    "then"
    "end"
  ] @keyword.conditional)

(else_statement
  [
    "else"
    "end"
  ] @keyword.conditional)

(for_statement
  [
    "for"
    "do"
    "end"
  ] @keyword.repeat)

(function_declaration
  [
    "function"
    "end"
  ] @keyword.function)

(function_definition
  [
    "function"
    "end"
  ] @keyword.function)

; Operators
[
  "and"
  "not"
  "or"
] @keyword.operator

[
  "+"
  "-"
  "*"
  "/"
  "%"
  "^"
  "#"
  "=="
  "~="
  "<="
  ">="
  "<"
  ">"
  "="
  "&"
  "~"
  "|"
  "<<"
  ">>"
  "//"
  ".."
] @operator

; Punctuations
[
  ";"
  ":"
  "::"
  ","
  "."
] @punctuation.delimiter

; Brackets
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

; Variables
(identifier) @variable

((identifier) @constant.builtin
  (#eq? @constant.builtin "_VERSION"))

((identifier) @variable.builtin
  (#eq? @variable.builtin "self"))

((identifier) @module.builtin
  (#any-of? @module.builtin "_G" "debug" "io" "jit" "math" "os" "package" "string" "table" "utf8"))

((identifier) @keyword.coroutine
  (#eq? @keyword.coroutine "coroutine"))

(variable_list
  (attribute
    "<" @punctuation.bracket
    (identifier) @attribute
    ">" @punctuation.bracket))

; Labels
(label_statement
  (identifier) @label)

(goto_statement
  (identifier) @label)

; Constants
((identifier) @constant
  (#lua-match? @constant "^[A-Z][A-Z_0-9]*$"))

(nil) @constant.builtin

[
  (false)
  (true)
] @boolean

; Tables
(field
  name: (identifier) @property)

(dot_index_expression
  field: (identifier) @variable.member)

(table_constructor
  [
    "{"
    "}"
  ] @constructor)

; Functions
(parameters
  (identifier) @variable.parameter)

(vararg_expression) @variable.parameter.builtin

(function_declaration
  name: [
    (identifier) @function
    (dot_index_expression
      field: (identifier) @function)
  ])

(function_declaration
  name: (method_index_expression
    method: (identifier) @function.method))

(assignment_statement
  (variable_list
    .
    name: [
      (identifier) @function
      (dot_index_expression
        field: (identifier) @function)
    ])
  (expression_list
    .
    value: (function_definition)))

(table_constructor
  (field
    name: (identifier) @function
    value: (function_definition)))

(function_call
  name: [
    (identifier) @function.call
    (dot_index_expression
      field: (identifier) @function.call)
    (method_index_expression
      method: (identifier) @function.method.call)
  ])

(function_call
  (identifier) @function.builtin
  (#any-of? @function.builtin
    ; built-in functions in Lua 5.1
    "assert" "collectgarbage" "dofile" "error" "getfenv" "getmetatable" "ipairs" "load" "loadfile"
    "loadstring" "module" "next" "pairs" "pcall" "print" "rawequal" "rawget" "rawlen" "rawset"
    "require" "select" "setfenv" "setmetatable" "tonumber" "tostring" "type" "unpack" "xpcall"
    "__add" "__band" "__bnot" "__bor" "__bxor" "__call" "__concat" "__div" "__eq" "__gc" "__idiv"
    "__index" "__le" "__len" "__lt" "__metatable" "__mod" "__mul" "__name" "__newindex" "__pairs"
    "__pow" "__shl" "__shr" "__sub" "__tostring" "__unm"))

; Others
(comment) @comment @spell

((comment) @comment.documentation
  (#lua-match? @comment.documentation "^[-][-][-]"))

((comment) @comment.documentation
  (#lua-match? @comment.documentation "^[-][-](%s?)@"))

(hash_bang_line) @keyword.directive

(number) @number

(string) @string

(escape_sequence) @string.escape

; string.match("123", "%d+")
(function_call
  (dot_index_expression
    field: (identifier) @_method
    (#any-of? @_method "find" "match" "gmatch" "gsub"))
  arguments: (arguments
    .
    (_)
    .
    (string
      content: (string_content) @string.regexp)))

;("123"):match("%d+")
(function_call
  (method_index_expression
    method: (identifier) @_method
    (#any-of? @_method "find" "match" "gmatch" "gsub"))
  arguments: (arguments
    .
    (string
      content: (string_content) @string.regexp)))
