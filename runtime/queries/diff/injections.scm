(block
  (old_file
    (filename) @injection.filename)
  (new_file)
  (hunks
    (hunk
      changes: (changes
        [
          (context) @injection.content
          (addition)
          (deletion) @injection.content
        ]+)))
  (#offset! @injection.content 0 1 0 0)
  (#gsub! @injection.filename "^\"" "")
  (#gsub! @injection.filename "\"$" "")
  (#gsub! @injection.filename "\t.*$" "")
  (#gsub! @injection.filename "^[ab]/" ""))

(block
  (old_file)
  (new_file
    (filename) @injection.filename)
  (hunks
    (hunk
      changes: (changes
        [
          (context) @injection.content
          (addition) @injection.content
          (deletion)
        ]+)))
  (#offset! @injection.content 0 1 0 0)
  (#gsub! @injection.filename "^\"" "")
  (#gsub! @injection.filename "\"$" "")
  (#gsub! @injection.filename "\t.*$" "")
  (#gsub! @injection.filename "^[ab]/" ""))
