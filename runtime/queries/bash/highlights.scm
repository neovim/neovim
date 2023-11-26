(simple_expansion) @none
(expansion
  "${" @punctuation.special
  "}" @punctuation.special) @none
[
 "("
 ")"
 "(("
 "))"
 "{"
 "}"
 "["
 "]"
 "[["
 "]]"
 ] @punctuation.bracket

[
 ";"
 ";;"
 (heredoc_start)
 ] @punctuation.delimiter

[
 "$"
] @punctuation.special

[
 ">"
 ">>"
 "<"
 "<<"
 "&"
 "&&"
 "|"
 "||"
 "="
 "=~"
 "=="
 "!="
 ] @operator

[
 (string)
 (raw_string)
 (ansi_c_string)
 (heredoc_body)
] @string @spell

(variable_assignment (word) @string)

[
 "if"
 "then"
 "else"
 "elif"
 "fi"
 "case"
 "in"
 "esac"
 ] @conditional

[
 "for"
 "do"
 "done"
 "select"
 "until"
 "while"
 ] @repeat

[
 "declare"
 "export"
 "local"
 "readonly"
 "unset"
 ] @keyword

"function" @keyword.function

(special_variable_name) @constant

; trap -l
((word) @constant.builtin
 (#match? @constant.builtin "^SIG(HUP|INT|QUIT|ILL|TRAP|ABRT|BUS|FPE|KILL|USR[12]|SEGV|PIPE|ALRM|TERM|STKFLT|CHLD|CONT|STOP|TSTP|TT(IN|OU)|URG|XCPU|XFSZ|VTALRM|PROF|WINCH|IO|PWR|SYS|RTMIN([+]([1-9]|1[0-5]))?|RTMAX(-([1-9]|1[0-4]))?)$"))

((word) @boolean
  (#any-of? @boolean "true" "false"))

(comment) @comment @spell
(test_operator) @string

(command_substitution
  [ "$(" ")" ] @punctuation.bracket)

(process_substitution
  [ "<(" ")" ] @punctuation.bracket)


(function_definition
  name: (word) @function)

(command_name (word) @function.call)

((command_name (word) @function.builtin)
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
  argument: [
             (word) @parameter
             (concatenation (word) @parameter)
             ])

((word) @number
  (#lua-match? @number "^[0-9]+$"))

(file_redirect
  descriptor: (file_descriptor) @operator
  destination: (word) @parameter)

(expansion
  [ "${" "}" ] @punctuation.bracket)

(variable_name) @variable

((variable_name) @constant
 (#lua-match? @constant "^[A-Z][A-Z_0-9]*$"))

(case_item
  value: (word) @parameter)

(regex) @string.regex

((program . (comment) @preproc)
  (#lua-match? @preproc "^#!/"))
