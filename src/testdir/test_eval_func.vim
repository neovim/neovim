" Vim script used in test_eval.in.  Needed for script-local function.

func! s:Testje()
  return "foo"
endfunc

let Bar = function('s:Testje')

$put ='s:Testje exists: ' . exists('s:Testje')
$put ='func s:Testje exists: ' . exists('*s:Testje')
$put ='Bar exists: ' . exists('Bar')
$put ='func Bar exists: ' . exists('*Bar')
