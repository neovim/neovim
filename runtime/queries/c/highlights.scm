(identifier) @variable

[
  "const"
  "default"
  "enum"
  "extern"
  "inline"
  "return"
  "sizeof"
  "static"
  "struct"
  "typedef"
  "union"
  "volatile"
  "goto"
] @keyword

[
  "while"
  "for"
  "do"
  "continue"
  "break"
] @repeat

[
 "if"
 "else"
 "case"
 "switch"
] @conditional

"#define" @constant.macro
[
  "#if"
  "#ifdef"
  "#ifndef"
  "#else"
  "#elif"
  "#endif"
  (preproc_directive)
] @keyword

"#include" @include

[
  "="

  "-"
  "*"
  "/"
  "+"
  "%"

  "~"
  "|"
  "&"
  "^"
  "<<"
  ">>"

  "->"

  "<"
  "<="
  ">="
  ">"
  "=="
  "!="

  "!"
  "&&"
  "||"

  "-="
  "+="
  "*="
  "/="
  "%="
  "|="
  "&="
  "^="
  "--"
  "++"
] @operator

[
 (true)
 (false)
] @boolean

[ "." ";" ":" "," ] @punctuation.delimiter

(conditional_expression [ "?" ":" ] @conditional)


[ "(" ")" "[" "]" "{" "}"] @punctuation.bracket

(string_literal) @string
(system_lib_string) @string

(null) @constant.builtin
(number_literal) @number
(char_literal) @number

(call_expression
  function: (identifier) @function)
(call_expression
  function: (field_expression
    field: (field_identifier) @function))
(function_declarator
  declarator: (identifier) @function)
(preproc_function_def
  name: (identifier) @function.macro)
[
 (preproc_arg)
 (preproc_defined)
]  @function.macro
; TODO (preproc_arg)  @embedded

(field_identifier) @property
(statement_identifier) @label

[
(type_identifier)
(primitive_type)
(sized_type_specifier)
(type_descriptor)
 ] @type

(declaration type: [(identifier) (type_identifier)] @type)
(cast_expression type: [(identifier) (type_identifier)] @type)
(sizeof_expression value: (parenthesized_expression (identifier) @type))

((identifier) @constant
 (#match? @constant "^[A-Z][A-Z0-9_]+$"))

(comment) @comment

;; Parameters
(parameter_declaration
  declarator: (identifier) @parameter)

(parameter_declaration
  declarator: (pointer_declarator) @parameter)

(preproc_params
  (identifier)) @parameter

(ERROR) @error
