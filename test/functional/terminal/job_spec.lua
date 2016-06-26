local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local wait = helpers.wait

describe('job handler', function()
  local screen
  local script_file = 'Xtest_job_4569.vim'
  local input_file = 'test/functional/fixtures/job_spec_124KB.txt'

  after_each(function()
    os.remove(script_file)
  end)

  -- Note: This convoluted approach (spawned child nvim hosted in :terminal) is
  -- the only way #4569 could be reproduced in a test. See also #4646.
  function test_job_output_collection()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    screen:set_default_attr_ids({})
    screen:set_default_attr_ignore(true)
    screen.timeout = 15000

    helpers.write_file(script_file, [=[
      let g:job_stdout = []
      function! s:JobHandler(job_id, data, event)
        if 'stdout' ==# a:event
          let g:job_stdout += a:data
        elseif 'stderr' ==# a:event
          put =join(a:data,"\n")
        elseif 'exit' ==# a:event
          put =g:job_stdout[0]    " First line of received data.
          put =g:job_stdout[-2]   " Last line of received data.
        endif
      endfunction

      let g:callbacks = {
          \ 'on_stdout': function('s:JobHandler'),
          \ 'on_stderr': function('s:JobHandler'),
          \ 'on_exit'  : function('s:JobHandler')
          \ }
    ]=])

    -- Source the script in the child nvim.
    thelpers.feed_data(':source Xtest_job_4569.vim\n')

    -- Start the job in the child nvim.
    if helpers.os_name == 'windows' then
      thelpers.feed_data(":call jobstart(['powershell', '-c', 'cat \""..input_file.."\"], g:callbacks)\n")
    else
      thelpers.feed_data(":call jobstart(['sh', '-c', 'cat "..input_file.."'], g:callbacks)\n")
    end

    screen:expect([[
                                                        |
           1 HelloWorld:qa                              |
        5989 HelloWorld:qa                              |
      ~                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end

  -- it('does not lose data (#4569)', function()
  --   test_job_output_collection()
  --   test_job_output_collection()
  --   test_job_output_collection()
  -- end)
end)

describe('job handler', function()
  local screen
  local script_file = 'Xtest_job_4569.vim'
  local input_file = 'test/functional/fixtures/job_spec_124KB.txt'

  after_each(function()
    os.remove(script_file)
  end)

  -- Note: This convoluted approach (spawned child nvim hosted in :terminal) is
  -- the only way #4569 could be reproduced in a test. See also #4646.
  function test_job_output_collection()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..helpers.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    screen:set_default_attr_ids({})
    screen:set_default_attr_ignore(true)
    screen.timeout = 15000

    helpers.write_file(script_file, [=[
      function! JobHandler(job_id, data, event)
        if 'stdout' ==# a:event || 'stderr' ==# a:event
          call append(line('$'), a:data)
        elseif 'exit' ==# a:event
          norm! G
        endif
        " imitation of some complex actions
        for i in range(1,400) | let dummy_var = i | endfor
      endfunction

      let g:callbacks = {
            \ 'on_stdout': function('JobHandler'),
            \ 'on_stderr': function('JobHandler'),
            \ 'on_exit':   function('JobHandler'),
            \}
    ]=])

    -- Source the script in the child nvim.
    thelpers.feed_data(":source Xtest_job_4569.vim\n")

    -- Start the job in the child nvim.
    if helpers.os_name == 'windows' then
      thelpers.feed_data(":call jobstart(['powershell', '-c', 'grep -r -i a unicode'], g:callbacks)\n")
    else
      thelpers.feed_data(":call jobstart(['sh', '-c', 'grep -r -i --color=never a unicode'], g:callbacks)\n")
    end

    screen:expect([[
      unicode/UnicodeData.txt:10FFFD;<Plane 16 Private U|
      se, Last>;Co;0;L;;;;;N;;;;;                       |
                                                        |
      ~                                                 |
      [No Name] [+]                                     |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end

  it('does not lose data (#4897)', function()
    test_job_output_collection()
  end)
end)

