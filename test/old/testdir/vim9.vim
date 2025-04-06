
" Use a different file name for each run.
let s:sequence = 1

func CheckDefSuccess(lines)
  return
endfunc

func CheckDefFailure(lines, error, lnum = -3)
  return
endfunc

func CheckDefExecFailure(lines, error, lnum = -3)
  return
endfunc

func CheckScriptFailure(lines, error, lnum = -3)
  if get(a:lines, 0, '') ==# 'vim9script'
    return
  endif
  let cwd = getcwd()
  let fname = 'XScriptFailure' .. s:sequence
  let s:sequence += 1
  call writefile(a:lines, fname)
  try
    call assert_fails('so ' .. fname, a:error, a:lines, a:lnum)
  finally
    call chdir(cwd)
    call delete(fname)
  endtry
endfunc

func CheckScriptSuccess(lines)
  if get(a:lines, 0, '') ==# 'vim9script'
    return
  endif
  let cwd = getcwd()
  let fname = 'XScriptSuccess' .. s:sequence
  let s:sequence += 1
  call writefile(a:lines, fname)
  try
    exe 'so ' .. fname
  finally
    call chdir(cwd)
    call delete(fname)
  endtry
endfunc

func CheckDefAndScriptSuccess(lines)
  return
endfunc

func CheckDefAndScriptFailure(lines, error, lnum = -3)
  return
endfunc

func CheckDefExecAndScriptFailure(lines, error, lnum = -3)
  return
endfunc

" Check that "lines" inside a legacy function has no error.
func CheckLegacySuccess(lines)
  let cwd = getcwd()
  let fname = 'XlegacySuccess' .. s:sequence
  let s:sequence += 1
  call writefile(['func Func()'] + a:lines + ['endfunc'], fname)
  try
    exe 'so ' .. fname
    call Func()
  finally
    delfunc! Func
    call chdir(cwd)
    call delete(fname)
  endtry
endfunc

" Check that "lines" inside a legacy function results in the expected error
func CheckLegacyFailure(lines, error)
  let cwd = getcwd()
  let fname = 'XlegacyFails' .. s:sequence
  let s:sequence += 1
  call writefile(['func Func()'] + a:lines + ['endfunc', 'call Func()'], fname)
  try
    call assert_fails('so ' .. fname, a:error)
  finally
    delfunc! Func
    call chdir(cwd)
    call delete(fname)
  endtry
endfunc

" Execute "lines" in a legacy function, translated as in
" CheckLegacyAndVim9Success()
func CheckTransLegacySuccess(lines)
  let legacylines = a:lines->mapnew({_, v ->
                              \ v->substitute('\<VAR\>', 'let', 'g')
                              \  ->substitute('\<LET\>', 'let', 'g')
                              \  ->substitute('\<LSTART\>', '{', 'g')
                              \  ->substitute('\<LMIDDLE\>', '->', 'g')
                              \  ->substitute('\<LEND\>', '}', 'g')
                              \  ->substitute('\<TRUE\>', '1', 'g')
                              \  ->substitute('\<FALSE\>', '0', 'g')
                              \  ->substitute('#"', ' "', 'g')
                              \ })
  call CheckLegacySuccess(legacylines)
endfunc

func CheckTransDefSuccess(lines)
  return
endfunc

func CheckTransVim9Success(lines)
  return
endfunc

" Execute "lines" in a legacy function
" Use 'VAR' for a declaration.
" Use 'LET' for an assignment
" Use ' #"' for a comment
" Use LSTART arg LMIDDLE expr LEND for lambda
" Use 'TRUE' for 1
" Use 'FALSE' for 0
func CheckLegacyAndVim9Success(lines)
  call CheckTransLegacySuccess(a:lines)
endfunc

" Execute "lines" in a legacy function
" Use 'VAR' for a declaration.
" Use 'LET' for an assignment
" Use ' #"' for a comment
func CheckLegacyAndVim9Failure(lines, error)
  if type(a:error) == type('string')
    let legacyError = a:error
  else
    let legacyError = a:error[0]
  endif

  let legacylines = a:lines->mapnew({_, v ->
                              \ v->substitute('\<VAR\>', 'let', 'g')
                              \  ->substitute('\<LET\>', 'let', 'g')
                              \  ->substitute('#"', ' "', 'g')
                              \ })
  call CheckLegacyFailure(legacylines, legacyError)
endfunc

" :source a list of "lines" and check whether it fails with "error"
func CheckSourceScriptFailure(lines, error, lnum = -3)
  if get(a:lines, 0, '') ==# 'vim9script'
    return
  endif
  let cwd = getcwd()
  new
  call setline(1, a:lines)
  let bnr = bufnr()
  try
    call assert_fails('source', a:error, a:lines, a:lnum)
  finally
    call chdir(cwd)
    exe $':bw! {bnr}'
  endtry
endfunc

" :source a list of "lines" and check whether it fails with the list of
" "errors"
func CheckSourceScriptFailureList(lines, errors, lnum = -3)
  if get(a:lines, 0, '') ==# 'vim9script'
    return
  endif
  let cwd = getcwd()
  new
  let bnr = bufnr()
  call setline(1, a:lines)
  try
    call assert_fails('source', a:errors, a:lines, a:lnum)
  finally
    call chdir(cwd)
    exe $':bw! {bnr}'
  endtry
endfunc

" :source a list of "lines" and check whether it succeeds
func CheckSourceScriptSuccess(lines)
  if get(a:lines, 0, '') ==# 'vim9script'
    return
  endif
  let cwd = getcwd()
  new
  let bnr = bufnr()
  call setline(1, a:lines)
  try
    :source
  finally
    call chdir(cwd)
    exe $':bw! {bnr}'
  endtry
endfunc

func CheckSourceSuccess(lines)
  call CheckSourceScriptSuccess(a:lines)
endfunc

func CheckSourceFailure(lines, error, lnum = -3)
  call CheckSourceScriptFailure(a:lines, a:error, a:lnum)
endfunc

func CheckSourceFailureList(lines, errors, lnum = -3)
  call CheckSourceScriptFailureList(a:lines, a:errors, a:lnum)
endfunc

func CheckSourceDefSuccess(lines)
  return
endfunc

func CheckSourceDefAndScriptSuccess(lines)
  return
endfunc

func CheckSourceDefCompileSuccess(lines)
  return
endfunc

func CheckSourceDefFailure(lines, error, lnum = -3)
  return
endfunc

func CheckSourceDefExecFailure(lines, error, lnum = -3)
  return
endfunc

func CheckSourceDefAndScriptFailure(lines, error, lnum = -3)
  return
endfunc

func CheckSourceDefExecAndScriptFailure(lines, error, lnum = -3)
  return
endfunc

