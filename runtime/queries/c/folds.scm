[
  (for_statement)
  (if_statement)
  (while_statement)
  (do_statement)
  (switch_statement)
  (case_statement)
  (function_definition)
  (struct_specifier)
  (enum_specifier)
  (comment)
  (preproc_if)
  (preproc_elif)
  (preproc_else)
  (preproc_ifdef)
  (preproc_function_def)
  (initializer_list)
  (gnu_asm_expression)
  (preproc_include)+
] @fold

(compound_statement
  (compound_statement) @fold)
