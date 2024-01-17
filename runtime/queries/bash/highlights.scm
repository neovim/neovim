[
  "("
  ")"
  "{"
  "}"
  "["
  "]"
  "[["
  "]]"
  "(("
  "))"
] @punctuation.bracket

[
  ";"
  ";;"
  ";&"
  ";;&"
  "&"
] @punctuation.delimiter

[
  ">"
  ">>"
  "<"
  "<<"
  "&&"
  "|"
  "|&"
  "||"
  "="
  "+="
  "=~"
  "=="
  "!="
  "&>"
  "&>>"
  "<&"
  ">&"
  ">|"
  "<&-"
  ">&-"
  "<<-"
  "<<<"
  ".."
] @operator

; Do *not* spell check strings since they typically have some sort of
; interpolation in them, or, are typically used for things like filenames, URLs,
; flags and file content.
[
  (string)
  (raw_string)
  (ansi_c_string)
  (heredoc_body)
] @string

[
  (heredoc_start)
  (heredoc_end)
] @label

(variable_assignment
  (word) @string)

(command
  argument: "$" @string) ; bare dollar

[
  "if"
  "then"
  "else"
  "elif"
  "fi"
  "case"
  "in"
  "esac"
] @keyword.conditional

[
  "for"
  "do"
  "done"
  "select"
  "until"
  "while"
] @keyword.repeat

[
  "declare"
  "typeset"
  "export"
  "readonly"
  "local"
  "unset"
  "unsetenv"
] @keyword

"function" @keyword.function

(special_variable_name) @constant

; trap -l
((word) @constant.builtin
  (#match? @constant.builtin "^SIG(HUP|INT|QUIT|ILL|TRAP|ABRT|BUS|FPE|KILL|USR[12]|SEGV|PIPE|ALRM|TERM|STKFLT|CHLD|CONT|STOP|TSTP|TT(IN|OU)|URG|XCPU|XFSZ|VTALRM|PROF|WINCH|IO|PWR|SYS|RTMIN([+]([1-9]|1[0-5]))?|RTMAX(-([1-9]|1[0-4]))?)$"))

((word) @boolean
  (#any-of? @boolean "true" "false"))

(comment) @comment @spell

(test_operator) @operator

(command_substitution
  "$(" @punctuation.bracket)

(process_substitution
  "<(" @punctuation.bracket)

(arithmetic_expansion
  [
    "$(("
    "(("
  ] @punctuation.special
  "))" @punctuation.special)

(arithmetic_expansion
  "," @punctuation.delimiter)

(ternary_expression
  [
    "?"
    ":"
  ] @keyword.conditional.ternary)

(binary_expression
  operator: _ @operator)

(unary_expression
  operator: _ @operator)

(postfix_expression
  operator: _ @operator)

(function_definition
  name: (word) @function)

(command_name
  (word) @function.call)

((command_name
  (word) @function.builtin)
  ; format-ignore
  (#any-of? @function.builtin
    "alias" "bg" "bind" "break" "builtin" "caller" "cd"
    "command" "compgen" "complete" "compopt" "continue"
    "coproc" "dirs" "disown" "echo" "enable" "eval"
    "exec" "exit" "fc" "fg" "getopts" "hash" "help"
    "history" "jobs" "kill" "let" "logout" "mapfile"
    "popd" "printf" "pushd" "pwd" "read" "readarray"
    "return" "set" "shift" "shopt" "source" "suspend"
    "test" "time" "times" "trap" "type" "typeset"
    "ulimit" "umask" "unalias" "wait"))

(command
  argument:
    [
      (word) @variable.parameter
      (concatenation
        (word) @variable.parameter)
    ])

(number) @number

((word) @number
  (#lua-match? @number "^[0-9]+$"))

(file_redirect
  destination: (word) @variable.parameter)

(file_descriptor) @operator

(simple_expansion
  "$" @punctuation.special) @none

(expansion
  "${" @punctuation.special
  "}" @punctuation.special) @none

(expansion
  operator: _ @punctuation.special)

(expansion
  "@"
  .
  operator: _ @character.special)

((expansion
  (subscript
    index: (word) @character.special))
  (#any-of? @character.special "@" "*"))

"``" @punctuation.special

(variable_name) @variable

((variable_name) @constant
  (#lua-match? @constant "^[A-Z][A-Z_0-9]*$"))

(case_item
  value: (word) @variable.parameter)

[
  (regex)
  (extglob_pattern)
] @string.regexp

((program
  .
  (comment) @keyword.directive)
  (#lua-match? @keyword.directive "^#!/"))
