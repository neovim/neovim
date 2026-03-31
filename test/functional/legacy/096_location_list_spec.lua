-- Test for problems in quickfix/location list:
-- A. incorrectly copying location lists which caused the location list to show a
--    different name than the file that was actually being displayed.
-- B. not reusing the window for which the location list window is opened but
--    instead creating new windows.
-- C. make sure that the location list window is not reused instead of the window
--    it belongs to.

local n = require('test.functional.testnvim')()

local source = n.source
local clear, command, expect = n.clear, n.command, n.expect

describe('location list', function()
  local test_file = 'Xtest-096_location_list.out'
  setup(clear)
  teardown(function()
    os.remove(test_file)
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
      ]]
        -- Register the above buffer setup function to be executed before
        -- starting to edit a new "test protocol" buffer.
        .. [[
      augroup testgroup
        au!
        autocmd BufReadCmd test://* call ReadTestProtocol(expand("<amatch>"))
      augroup END
      ]]
        -- Populate the location list of the current window with some test
        -- protocol file locations such as "test://foo.txt".
        .. [[
      let words = [ "foo", "bar", "baz", "quux", "shmoo", "spam", "eggs" ]
      let qflist = []
      for word in words
        call add(qflist, {'filename': 'test://' . word . '.txt', 'text': 'file ' . word . '.txt', })
        " NOTE: problem 1:
        " Intentionally not setting 'lnum' so that the quickfix entries are not
        " valid.
        call setloclist(0, qflist, ' ')
      endfor
    ]]
    )

    -- Set up the result buffer.
    command('enew')
    command('w! ' .. test_file)
    command('b 1')

    -- Test A.

    -- Open a new buffer as the sole window, rewind and open the prepopulated
    -- location list and navigate through the entries.
    command('lrewind')
    command('enew')
    command('lopen')
    command(('lnext|'):rep(4))

    -- Split the window, copying the location list, then open the copied
    -- location list and again navigate forward.
    command('vert split')
    command('wincmd L')
    command('lopen')
    command('wincmd p')
    command('lnext')

    -- Record the current file name and the file name of the corresponding
    -- location list entry, then open the result buffer.
    command('let fileName = expand("%")')
    command('wincmd p')
    command([[let locationListFileName = substitute(getline(line('.')), '\([^|]*\)|.*', '\1', '')]])
    command('wincmd n')
    command('wincmd K')
    command('b ' .. test_file)

    -- Prepare test output and write it to the result buffer.
    command([[let fileName = substitute(fileName, '\\', '/', 'g')]])
    command([[let locationListFileName = substitute(locationListFileName, '\\', '/', 'g')]])
    command([[call append(line('$'), "Test A:")]])
    command([[call append(line('$'), "  - file name displayed: " . fileName)]])
    command(
      [[call append(line('$'), "  - quickfix claims that the file name displayed is: " . locationListFileName)]]
    )
    command('w')

    -- Clean slate for the next test.
    command('wincmd o')
    command('b 1')

    -- Test B.

    -- Rewind the location list, then open it and browse through it by running
    -- ":{number}" followed by Enter repeatedly in the location list window.
    command('lrewind')
    command('lopen')
    command('2')
    command([[exe "normal \\<CR>"]])
    command('wincmd p')
    command('3')
    command([[exe "normal \<CR>"]])
    command('wincmd p')
    command('4')
    command([[exe "normal \<CR>"]])

    -- Record the number of windows open, then go back to the result buffer.
    command('let numberOfWindowsOpen = winnr("$")')
    command('wincmd n')
    command('wincmd K')
    command('b ' .. test_file)

    -- Prepare test output and write it to the result buffer.
    command('call append(line("$"), "Test B:")')
    command('call append(line("$"), "  - number of window open: " . numberOfWindowsOpen)')
    command('w')

    -- Clean slate.
    command('wincmd o')
    command('b 1')

    -- Test C.

    -- Rewind the location list, then open it and again do the ":{number}" plus
    -- Enter browsing. But this time, move the location list window to the top
    -- to check whether it (the first window found) will be reused when we try
    -- to open new windows.
    command('lrewind')
    command('lopen')
    command('wincmd K')
    command('2')
    command([[exe "normal \<CR>"]])
    command('wincmd p')
    command('3')
    command([[exe "normal \<CR>"]])
    command('wincmd p')
    command('4')
    command([[exe "normal \<CR>"]])

    -- Record the 'buftype' of window 1 (the location list) and the buffer name
    -- of window 2 (the current "test protocol" buffer), then go back to the
    -- result buffer.
    command('1wincmd w')
    command('let locationListWindowBufType = &buftype')
    command('2wincmd w')
    command('let bufferName = expand("%")')
    command('wincmd n')
    command('wincmd K')
    command('b ' .. test_file)

    -- Prepare test output and write it to the result buffer.
    command([[let bufferName = substitute(bufferName, '\\', '/', 'g')]])
    command([[call append(line("$"), "Test C:")]])
    command(
      [[call append(line('$'), "  - 'buftype' of the location list window: " . locationListWindowBufType)]]
    )
    command([[call append(line('$'), "  - buffer displayed in the 2nd window: " . bufferName)]])
    command('w')
    command('wincmd o')
    command('b 1')

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
