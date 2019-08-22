if 1
  " This is executed only with the eval feature
  set nocompatible
  func Count(match, type)
    if a:type ==# 'executed'
      let g:executed += (a:match+0)
    elseif a:type ==# 'failed'
      let g:failed += a:match+0
    elseif a:type ==# 'skipped'
      let g:skipped += 1
      call extend(g:skipped_output, ["\t".a:match])
    endif
  endfunc

  let g:executed = 0
  let g:skipped = 0
  let g:failed = 0
  let g:skipped_output = []
  let g:failed_output = []
  let output = [""]

  try
    " This uses the :s command to just fetch and process the output of the
    " tests, it doesn't acutally replace anything.
    " And it uses "silent" to avoid reporting the number of matches.
    silent %s/^Executed\s\+\zs\d\+\ze\s\+tests/\=Count(submatch(0),'executed')/egn
    silent %s/^SKIPPED \zs.*/\=Count(submatch(0), 'skipped')/egn
    silent %s/^\(\d\+\)\s\+FAILED:/\=Count(submatch(1), 'failed')/egn

    call extend(output, ["Skipped:"]) 
    call extend(output, skipped_output)

    call extend(output, [
          \ "",
          \ "-------------------------------",
          \ printf("Executed: %5d Tests", g:executed),
          \ printf(" Skipped: %5d Tests", g:skipped),
          \ printf("  %s: %5d Tests", g:failed == 0 ? 'Failed' : 'FAILED', g:failed),
          \ "",
          \ ])
    if filereadable('test.log')
      " outputs and indents the failed test result
      call extend(output, ["", "Failures: "])
      let failed_output = filter(readfile('test.log'), { v,k -> !empty(k)})
      call extend(output, map(failed_output, { v,k -> "\t".k}))
      " Add a final newline
      call extend(output, [""])
    endif

  catch  " Catch-all
  finally
    call writefile(output, 'test_result.log')  " overwrites an existing file
  endtry
endif

q!
