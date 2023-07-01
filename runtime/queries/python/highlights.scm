;; From tree-sitter-python licensed under MIT License
; Copyright (c) 2016 Max Brunsfeld

; Variables
(identifier) @variable

; Reset highlighting in f-string interpolations
(interpolation) @none

;; Identifier naming conventions
((identifier) @type
 (#lua-match? @type "^[A-Z].*[a-z]"))
((identifier) @constant
 (#lua-match? @constant "^[A-Z][A-Z_0-9]*$"))

((identifier) @constant.builtin
 (#lua-match? @constant.builtin "^__[a-zA-Z0-9_]*__$"))

((identifier) @constant.builtin
 (#any-of? @constant.builtin
           ;; https://docs.python.org/3/library/constants.html
           "NotImplemented"
           "Ellipsis"
           "quit"
           "exit"
           "copyright"
           "credits"
           "license"))

((attribute
    attribute: (identifier) @field)
 (#lua-match? @field "^[%l_].*$"))

((assignment
  left: (identifier) @type.definition
  (type (identifier) @_annotation))
 (#eq? @_annotation "TypeAlias"))

((assignment
  left: (identifier) @type.definition
  right: (call
    function: (identifier) @_func))
 (#any-of? @_func "TypeVar" "NewType"))

; Function calls

(call
  function: (identifier) @function.call)

(call
  function: (attribute
              attribute: (identifier) @method.call))

((call
   function: (identifier) @constructor)
 (#lua-match? @constructor "^%u"))

((call
  function: (attribute
              attribute: (identifier) @constructor))
 (#lua-match? @constructor "^%u"))

;; Decorators

((decorator "@" @attribute)
 (#set! "priority" 101))

(decorator
  (identifier) @attribute)
(decorator
  (attribute
    attribute: (identifier) @attribute))
(decorator
  (call (identifier) @attribute))
(decorator
  (call (attribute
          attribute: (identifier) @attribute)))

((decorator
  (identifier) @attribute.builtin)
 (#any-of? @attribute.builtin "classmethod" "property"))

;; Builtin functions

((call
  function: (identifier) @function.builtin)
 (#any-of? @function.builtin
          "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray" "bytes" "callable" "chr" "classmethod"
          "compile" "complex" "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec" "filter" "float" "format"
          "frozenset" "getattr" "globals" "hasattr" "hash" "help" "hex" "id" "input" "int" "isinstance" "issubclass"
          "iter" "len" "list" "locals" "map" "max" "memoryview" "min" "next" "object" "oct" "open" "ord" "pow"
          "print" "property" "range" "repr" "reversed" "round" "set" "setattr" "slice" "sorted" "staticmethod" "str"
          "sum" "super" "tuple" "type" "vars" "zip" "__import__"))

;; Function definitions

(function_definition
  name: (identifier) @function)

(type (identifier) @type)
(type
  (subscript
    (identifier) @type)) ; type subscript: Tuple[int]

((call
  function: (identifier) @_isinstance
  arguments: (argument_list
    (_)
    (identifier) @type))
 (#eq? @_isinstance "isinstance"))

;; Normal parameters
(parameters
  (identifier) @parameter)
;; Lambda parameters
(lambda_parameters
  (identifier) @parameter)
(lambda_parameters
  (tuple_pattern
    (identifier) @parameter))
; Default parameters
(keyword_argument
  name: (identifier) @parameter)
; Naming parameters on call-site
(default_parameter
  name: (identifier) @parameter)
(typed_parameter
  (identifier) @parameter)
(typed_default_parameter
  (identifier) @parameter)
; Variadic parameters *args, **kwargs
(parameters
  (list_splat_pattern ; *args
    (identifier) @parameter))
(parameters
  (dictionary_splat_pattern ; **kwargs
    (identifier) @parameter))


;; Literals

(none) @constant.builtin
[(true) (false)] @boolean
((identifier) @variable.builtin
 (#eq? @variable.builtin "self"))
((identifier) @variable.builtin
 (#eq? @variable.builtin "cls"))

(integer) @number
(float) @float

(comment) @comment @spell

((module . (comment) @preproc)
  (#lua-match? @preproc "^#!/"))

(string) @string
(escape_sequence) @string.escape

; doc-strings

(module . (expression_statement (string) @string.documentation @spell))

(class_definition
  body:
    (block
      . (expression_statement (string) @string.documentation @spell)))

(function_definition
  body:
    (block
      . (expression_statement (string) @string.documentation @spell)))

; Tokens

[
  "-"
  "-="
  ":="
  "!="
  "*"
  "**"
  "**="
  "*="
  "/"
  "//"
  "//="
  "/="
  "&"
  "&="
  "%"
  "%="
  "^"
  "^="
  "+"
  "+="
  "<"
  "<<"
  "<<="
  "<="
  "<>"
  "="
  "=="
  ">"
  ">="
  ">>"
  ">>="
  "@"
  "@="
  "|"
  "|="
  "~"
  "->"
] @operator

; Keywords
[
  "and"
  "in"
  "is"
  "not"
  "or"
  "is not"
  "not in"

  "del"
] @keyword.operator

[
  "def"
  "lambda"
] @keyword.function

[
  "assert"
  "class"
  "exec"
  "global"
  "nonlocal"
  "pass"
  "print"
  "with"
  "as"
] @keyword

[
  "async"
  "await"
] @keyword.coroutine

[
  "return"
  "yield"
] @keyword.return
(yield "from" @keyword.return)

(future_import_statement
  "from" @include
  "__future__" @constant.builtin)
(import_from_statement "from" @include)
"import" @include

(aliased_import "as" @include)

["if" "elif" "else" "match" "case"] @conditional

["for" "while" "break" "continue"] @repeat

[
  "try"
  "except"
  "except*"
  "raise"
  "finally"
] @exception

(raise_statement "from" @exception)

(try_statement
  (else_clause
    "else" @exception))

["(" ")" "[" "]" "{" "}"] @punctuation.bracket

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

(type_conversion) @function.macro

["," "." ":" ";" (ellipsis)] @punctuation.delimiter

;; Class definitions

(class_definition name: (identifier) @type)

(class_definition
  body: (block
          (function_definition
            name: (identifier) @method)))

(class_definition
  superclasses: (argument_list
                  (identifier) @type))

((class_definition
  body: (block
          (expression_statement
            (assignment
              left: (identifier) @field))))
 (#lua-match? @field "^%l.*$"))
((class_definition
  body: (block
          (expression_statement
            (assignment
              left: (_
                     (identifier) @field)))))
 (#lua-match? @field "^%l.*$"))

((class_definition
  (block
    (function_definition
      name: (identifier) @constructor)))
 (#any-of? @constructor "__new__" "__init__"))

((identifier) @type.builtin
 (#any-of? @type.builtin
              ;; https://docs.python.org/3/library/exceptions.html
              "BaseException" "Exception" "ArithmeticError" "BufferError" "LookupError" "AssertionError" "AttributeError"
              "EOFError" "FloatingPointError" "GeneratorExit" "ImportError" "ModuleNotFoundError" "IndexError" "KeyError"
              "KeyboardInterrupt" "MemoryError" "NameError" "NotImplementedError" "OSError" "OverflowError" "RecursionError"
              "ReferenceError" "RuntimeError" "StopIteration" "StopAsyncIteration" "SyntaxError" "IndentationError" "TabError"
              "SystemError" "SystemExit" "TypeError" "UnboundLocalError" "UnicodeError" "UnicodeEncodeError" "UnicodeDecodeError"
              "UnicodeTranslateError" "ValueError" "ZeroDivisionError" "EnvironmentError" "IOError" "WindowsError"
              "BlockingIOError" "ChildProcessError" "ConnectionError" "BrokenPipeError" "ConnectionAbortedError"
              "ConnectionRefusedError" "ConnectionResetError" "FileExistsError" "FileNotFoundError" "InterruptedError"
              "IsADirectoryError" "NotADirectoryError" "PermissionError" "ProcessLookupError" "TimeoutError" "Warning"
              "UserWarning" "DeprecationWarning" "PendingDeprecationWarning" "SyntaxWarning" "RuntimeWarning"
              "FutureWarning" "ImportWarning" "UnicodeWarning" "BytesWarning" "ResourceWarning"
              ;; https://docs.python.org/3/library/stdtypes.html
              "bool" "int" "float" "complex" "list" "tuple" "range" "str"
              "bytes" "bytearray" "memoryview" "set" "frozenset" "dict" "type" "object"))

;; Error
(ERROR) @error
