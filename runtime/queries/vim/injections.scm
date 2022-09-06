(lua_statement (script (body) @lua))
(lua_statement (chunk) @lua)
; (ruby_statement (script (body) @ruby))
; (ruby_statement (chunk) @ruby)
; (python_statement (script (body) @python))
; (python_statement (chunk) @python)
;; (perl_statement (script (body) @perl))
;; (perl_statement (chunk) @perl)

; (autocmd_statement (pattern) @regex)

((set_item
   option: (option_name) @_option
   value: (set_value) @vim)
  (#any-of? @_option
    "includeexpr" "inex"
    "printexpr" "pexpr"
    "formatexpr" "fex"
    "indentexpr" "inde"
    "foldtext" "fdt"
    "foldexpr" "fde"
    "diffexpr" "dex"
    "patchexpr" "pex"
    "charconvert" "ccv"))

; (comment) @comment
