((preproc_def
 (preproc_arg) @injection.content)
 (#lua-match? @injection.content "\n")
 (#set! injection.language "c"))

(preproc_function_def
 (preproc_arg) @injection.content
 (#set! injection.language "c"))

(preproc_call
 (preproc_arg) @injection.content
 (#set! injection.language "c"))

; ((comment) @injection.content
;  (#set! injection.language "comment"))

; TODO: add when asm is added
; (gnu_asm_expression assembly_code: (string_literal) @injection.content
; (#set! injection.language "asm"))
; (gnu_asm_expression assembly_code: (concatenated_string (string_literal) @injection.content)
; (#set! injection.language "asm"))
