((html_tag) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined))

((latex_block) @injection.content
  (#set! injection.language "latex")
  (#set! injection.include-children))
