(string) @string

(escape_sequence) @string.escape

(capture
  (identifier) @type)

(anonymous_node
  (identifier) @string)

(predicate
  name: (identifier) @function.call)

(named_node
  name: (identifier) @variable)

(field_definition
  name: (identifier) @property)

(negated_field
  "!" @operator
  (identifier) @property)

(comment) @comment @spell

(quantifier) @operator

(predicate_type) @punctuation.special

"." @operator

[
  "["
  "]"
  "("
  ")"
] @punctuation.bracket

":" @punctuation.delimiter

[
  "@"
  "#"
] @punctuation.special

"_" @constant

((parameters
  (identifier) @number)
  (#match? @number "^[-+]?[0-9]+(.[0-9]+)?$"))

((program
  .
  (comment)*
  .
  (comment) @keyword.import)
  (#lua-match? @keyword.import "^;+ *inherits *:"))

((program
  .
  (comment)*
  .
  (comment) @keyword.directive)
  (#lua-match? @keyword.directive "^;+ *extends *$"))

((comment) @keyword.directive
  (#lua-match? @keyword.directive "^;+%s*format%-ignore%s*$"))

((predicate
  name: (identifier) @_name
  parameters:
    (parameters
      (string
        "\"" @string
        "\"" @string) @string.regexp))
  (#any-of? @_name "match" "not-match" "vim-match" "not-vim-match" "lua-match" "not-lua-match"))

((predicate
  name: (identifier) @_name
  parameters:
    (parameters
      (string
        "\"" @string
        "\"" @string) @string.regexp
      .
      (string) .))
  (#any-of? @_name "gsub" "not-gsub"))
