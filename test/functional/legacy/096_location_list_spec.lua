-- Test for problems in quickfix/location list:
-- A. incorrectly copying location lists which caused the location list to show a
--    different name than the file that was actually being displayed.
-- B. not reusing the window for which the location list window is opened but
--    instead creating new windows.
-- C. make sure that the location list window is not reused instead of the window
--    it belongs to.

local helpers = require('test.functional.helpers')
local source = helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('location list', function()
  setup(clear)

  teardown(function()
    os.remove('test.out')
  end)

  it('is working', function()
    -- Set up the test environment.
    source(
      -- This function serves as a callback which is executed on editing a new
      -- buffer. It accepts a "test protocol" file name that looks like
      -- "test://foo.txt". It sets some buffer-local settings and populates the
      -- buffer with one line consisting of the base name ("foo").
      [[
      function! ReadTestProtocol(name)
        let base = substitute(a:name, '\v^test://(.*)%(\.[^.]+)?', '\1', '')
        let word = substitute(base, '\v(.*)\..*', '\1', '')
      
        setl modifiable
        setl noreadonly
        setl noswapfile
        setl bufhidden=delete
        %del _
        " For problem 2:
        " 'buftype' has to be set to reproduce the constant opening of new windows.
        setl buftype=nofile
      
        call setline(1, word)
      
        setl nomodified
        setl nomodifiable
        setl readonly
        exe 'doautocmd BufRead ' . substitute(a:name, '\v^test://(.*)', '\1', '')
      endfunction
      ]] ..

      -- Register the above buffer setup function to be executed before
      -- starting to edit a new "test protocol" buffer.
      [[
      augroup testgroup
        au!
        autocmd BufReadCmd test://* call ReadTestProtocol(expand("<amatch>"))
      augroup END
      ]] ..

      -- Populate the location list of the current window with some test
      -- protocol file locations such as "test://foo.txt".
      [[
      let words = [ "foo", "bar", "baz", "quux", "shmoo", "spam", "eggs" ]
      let qflist = []
      for word in words
        call add(qflist, {'filename': 'test://' . word . '.txt', 'text': 'file ' . word . '.txt', })
        " NOTE: problem 1:
        " Intentionally not setting 'lnum' so that the quickfix entries are not
        " valid.
        call setloclist(0, qflist, ' ')
      endfor
    ]])

    -- Set up the result buffer "test.out".
    execute('enew')
    execute('w! test.out')
    execute('b 1')

    -- Test A.

    -- Open a new buffer as the sole window, rewind and open the prepopulated
    -- location list and navigate through the entries.
    execute('lrewind')
    execute('enew')
    execute('lopen')
    execute('lnext', 'lnext', 'lnext', 'lnext')

    -- Split the window, copying the location list, then open the copied
    -- location list and again navigate forward.
    execute('vert split')
    execute('wincmd L')
    execute('lopen')
    execute('wincmd p')
    execute('lnext')

    -- Record the current file name and the file name of the corresponding
    -- location list entry, then open the result buffer.
    execute('let fileName = expand("%")')
    execute('wincmd p')
    execute([[let locationListFileName = substitute(getline(line('.')), '\([^|]*\)|.*', '\1', '')]])
    execute('wincmd n')
    execute('wincmd K')
    execute('b test.out')

    -- Prepare test output and write it to the result buffer.
    execute([[let fileName = substitute(fileName, '\\', '/', 'g')]])
    execute([[let locationListFileName = substitute(locationListFileName, '\\', '/', 'g')]])
    execute([[call append(line('$'), "Test A:")]])
    execute([[call append(line('$'), "  - file name displayed: " . fileName)]])
    execute([[call append(line('$'), "  - quickfix claims that the file name displayed is: " . locationListFileName)]])
    execute('w')

    -- Clean slate for the next test.
    execute('wincmd o')
    execute('b 1')

    -- Test B.

    -- Rewind the location list, then open it and browse through it by running
    -- ":{number}" followed by Enter repeatedly in the location list window.
    execute('lrewind')
    execute('lopen')
    execute('2', [[exe "normal \\<CR>"]])
    execute('wincmd p')
    execute('3', [[exe "normal \<CR>"]])
    execute('wincmd p')
    execute('4', [[exe "normal \<CR>"]])

    -- Record the number of windows open, then go back to the result buffer.
    execute('let numberOfWindowsOpen = winnr("$")')
    execute('wincmd n')
    execute('wincmd K')
    execute('b test.out')

    -- Prepare test output and write it to the result buffer.
    execute('call append(line("$"), "Test B:")')
    execute('call append(line("$"), "  - number of window open: " . numberOfWindowsOpen)')
    execute('w')

    -- Clean slate.
    execute('wincmd o')
    execute('b 1')

    -- Test C.

    -- Rewind the location list, then open it and again do the ":{number}" plus
    -- Enter browsing. But this time, move the location list window to the top
    -- to check whether it (the first window found) will be reused when we try
    -- to open new windows.
    execute('lrewind')
    execute('lopen')
    execute('wincmd K')
    execute('2', [[exe "normal \<CR>"]])
    execute('wincmd p')
    execute('3', [[exe "normal \<CR>"]])
    execute('wincmd p')
    execute('4', [[exe "normal \<CR>"]])

    -- Record the 'buftype' of window 1 (the location list) and the buffer name
    -- of window 2 (the current "test protocol" buffer), then go back to the
    -- result buffer.
    execute('1wincmd w')
    execute('let locationListWindowBufType = &buftype')
    execute('2wincmd w')
    execute('let bufferName = expand("%")')
    execute('wincmd n')
    execute('wincmd K')
    execute('b test.out')

    -- Prepare test output and write it to the result buffer.
    execute([[let bufferName = substitute(bufferName, '\\', '/', 'g')]])
    execute([[call append(line("$"), "Test C:")]])
    execute([[call append(line('$'), "  - 'buftype' of the location list window: " . locationListWindowBufType)]])
    execute([[call append(line('$'), "  - buffer displayed in the 2nd window: " . bufferName)]])
    execute('w')
    execute('wincmd o')
    execute('b 1')

    -- Assert buffer contents.
    expect([[
      
      Test A:
        - file name displayed: test://bar.txt
        - quickfix claims that the file name displayed is: test://bar.txt
      Test B:
        - number of window open: 2
      Test C:
        - 'buftype' of the location list window: quickfix
        - buffer displayed in the 2nd window: test://quux.txt]])
  end)
end)
