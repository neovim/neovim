(lua_statement
  (script
    (body) @injection.content
    (#set! injection.language "lua")))

(lua_statement
  (chunk) @injection.content
  (#set! injection.language "lua"))

(ruby_statement
  (script
    (body) @injection.content
    (#set! injection.language "ruby")))

(ruby_statement
  (chunk) @injection.content
  (#set! injection.language "ruby"))

(python_statement
  (script
    (body) @injection.content
    (#set! injection.language "python")))

(python_statement
  (chunk) @injection.content
  (#set! injection.language "python"))

((set_item
  option: (option_name) @_option
  value: (set_value) @injection.content)
  (#any-of? @_option
    "includeexpr" "inex" "printexpr" "pexpr" "formatexpr" "fex" "indentexpr" "inde" "foldtext" "fdt"
    "foldexpr" "fde" "diffexpr" "dex" "patchexpr" "pex" "charconvert" "ccv")
  (#set! injection.language "vim"))
