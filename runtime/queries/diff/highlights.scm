(comment) @comment @spell

[
  (addition)
  (new_file)
] @diff.plus

[
  (deletion)
  (old_file)
] @diff.minus

(change) @diff.delta

(commit) @constant

(location) @attribute

(command
  "diff" @function
  (argument) @variable.parameter)

(filename) @string.special.path

(special) @string.special

"\\" @punctuation.special

(mode) @number

([
  ".."
  "+"
  "++"
  "+++"
  "++++"
  ">"
  "-"
  "--"
  "---"
  "----"
  "<"
  "!"
] @punctuation.special
  (#set! priority 95))

[
  (binary_change)
  (similarity)
  (dissimilarity)
  (file_change)
] @label

(index
  "index" @keyword)

(similarity
  (score) @number
  "%" @number)

(dissimilarity
  (score) @number
  "%" @number)

(binary_patch
  [
    "GIT"
    "binary"
    "patch"
  ] @label)

(binary_hunk
  [
    "literal"
    "delta"
  ] @keyword
  (size) @number)

forward: (binary_hunk
  (payload) @diff.plus)

reverse: (binary_hunk
  (payload) @diff.minus)
