; Code highlighting in diff hunks
; additions
(block
  (new_file
    (filename) @injection.filename)
  (hunks
    (hunk
      (changes
        [
          (context) @injection.content
          (addition) @injection.content
          (deletion)
          (special)
          (change)
          (unrecognized)
        ]+)))
  (#offset! @injection.content 0 1 0 1)
  (#gsub! @injection.filename "\t.*$" "")
  (#gsub! @injection.filename "^\"(.+)\"$" "%1"))

; deletions
(block
  (old_file
    (filename) @injection.filename)
  (hunks
    (hunk
      (changes
        [
          (context) @injection.content
          (addition)
          (deletion) @injection.content
          (special)
          (change)
          (unrecognized)
        ]+)))
  (#offset! @injection.content 0 1 0 1)
  (#gsub! @injection.filename "\t.*$" "")
  (#gsub! @injection.filename "^\"(.+)\"$" "%1"))
