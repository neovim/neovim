(redirected_statement
  body: (command
    argument: (string) @injection.content
  )
  redirect: (file_redirect
    destination: (word) @_dest
  )
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#lang_from_filename! injection.language @_dest)
)
