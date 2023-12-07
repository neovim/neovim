; Lower priority to prefer @parameter when identifier appears in parameter_declaration.
((identifier) @variable (#set! "priority" 95))
(preproc_def (preproc_arg) @variable)

[
  "default"
  "enum"
  "struct"
  "typedef"
  "union"
  "goto"
  "asm"
  "__asm__"
] @keyword

[
  "sizeof"
  "offsetof"
] @keyword.operator

"return" @keyword.return

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

[
  "#if"
  "#ifdef"
  "#ifndef"
  "#else"
  "#elif"
  "#endif"
  "#elifdef"
  "#elifndef"
  (preproc_directive)
] @preproc

"#define" @define

"#include" @include

[ ";" ":" "," "::" ] @punctuation.delimiter

"..." @punctuation.special

[ "(" ")" "[" "]" "{" "}"] @punctuation.bracket

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
  "."

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
  ">>="
  "<<="
  "--"
  "++"
] @operator

;; Make sure the comma operator is given a highlight group after the comma
;; punctuator so the operator is highlighted properly.
(comma_expression [ "," ] @operator)

[
  (true)
  (false)
] @boolean

(conditional_expression [ "?" ":" ] @conditional.ternary)

(string_literal) @string
(system_lib_string) @string
(escape_sequence) @string.escape

(null) @constant.builtin
(number_literal) @number
(char_literal) @character

((preproc_arg) @function.macro (#set! "priority" 90))
(preproc_defined) @function.macro

(statement_identifier) @label

[
 (type_identifier)
 (type_descriptor)
] @type

(storage_class_specifier) @storageclass

[
  (type_qualifier) 
  (gnu_asm_qualifier)
] @type.qualifier

(linkage_specification
  "extern" @storageclass)

(type_definition
  declarator: (type_identifier) @type.definition)

(primitive_type) @type.builtin

(sized_type_specifier _ @type.builtin type: _?)

((identifier) @constant
 (#lua-match? @constant "^[A-Z][A-Z0-9_]+$"))
(preproc_def (preproc_arg) @constant
  (#lua-match? @constant "^[A-Z][A-Z0-9_]+$"))
(enumerator
  name: (identifier) @constant)
(case_statement
  value: (identifier) @constant)

((identifier) @constant.builtin
    (#any-of? @constant.builtin "stderr" "stdin" "stdout"))
(preproc_def (preproc_arg) @constant.builtin
  (#any-of? @constant.builtin "stderr" "stdin" "stdout"))

;; Preproc def / undef
(preproc_def
  name: (_) @constant)
(preproc_call
  directive: (preproc_directive) @_u
  argument: (_) @constant
  (#eq? @_u "#undef"))

(call_expression
  function: (identifier) @function.call)
(call_expression
  function: (field_expression
    field: (field_identifier) @function.call))
(function_declarator
  declarator: (identifier) @function)
(function_declarator
  declarator: (parenthesized_declarator
                (pointer_declarator
                  declarator: (field_identifier) @function)))
(preproc_function_def
  name: (identifier) @function.macro)

(comment) @comment @spell

((comment) @comment.documentation
  (#lua-match? @comment.documentation "^/[*][*][^*].*[*]/$"))

;; Parameters
(parameter_declaration
  declarator: (identifier) @parameter)

(parameter_declaration
  declarator: (array_declarator) @parameter)

(parameter_declaration
  declarator: (pointer_declarator) @parameter)

(preproc_params (identifier) @parameter)

[
  "__attribute__"
  "__declspec"
  "__based"
  "__cdecl"
  "__clrcall"
  "__stdcall"
  "__fastcall"
  "__thiscall"
  "__vectorcall"
  (ms_pointer_modifier)
  (attribute_declaration)
] @attribute

(ERROR) @error
