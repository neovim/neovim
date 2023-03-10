(string) @string
(escape_sequence) @string.escape
(capture (identifier) @type)
(anonymous_node (identifier) @string)
(predicate name: (identifier) @function)
(named_node name: (identifier) @variable)
(field_definition name: (identifier) @property)
(negated_field "!" @operator (identifier) @property)
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
["@" "#"] @punctuation.special
"_" @constant

((parameters (identifier) @number)
 (#match? @number "^[-+]?[0-9]+(.[0-9]+)?$"))

((program . (comment) @include)
 (#match? @include "^;\ +inherits\ *:"))

((program . (comment) @preproc)
 (#match? @preproc "^; +extends"))
