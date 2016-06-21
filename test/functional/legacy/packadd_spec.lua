-- Tests for 'packpath' and :packadd

local helpers = require('test.functional.helpers')(after_each)
local clear, source, execute = helpers.clear, helpers.source, helpers.execute
local call, eq, nvim = helpers.call, helpers.eq, helpers.meths
local feed = helpers.feed

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('packadd', function()
  before_each(function()
    clear()

    source([=[
      func SetUp()
        let s:topdir = expand('%:p:h') . '/Xdir'
        exe 'set packpath=' . s:topdir
        let s:plugdir = s:topdir . '/pack/mine/opt/mytest'
      endfunc

      func TearDown()
        call delete(s:topdir, 'rf')
      endfunc

      func Test_packadd()
        call mkdir(s:plugdir . '/plugin', 'p')
        call mkdir(s:plugdir . '/ftdetect', 'p')
        set rtp&
        let rtp = &rtp
        filetype on

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq

        exe 'split ' . s:plugdir . '/ftdetect/test.vim'
        call setline(1, 'let g:ftdetect_works = 17')
        wq

        packadd mytest

        call assert_true(42, g:plugin_works)
        call assert_true(17, g:ftdetect_works)
        call assert_true(len(&rtp) > len(rtp))
        call assert_true(&rtp =~ (s:plugdir . '\($\|,\)'))

        " Check exception
        call assert_fails("packadd directorynotfound", 'E919:')
        call assert_fails("packadd", 'E471:')
      endfunc

      func Test_packadd_noload()
        call mkdir(s:plugdir . '/plugin', 'p')
        call mkdir(s:plugdir . '/syntax', 'p')
        set rtp&
        let rtp = &rtp

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq
        let g:plugin_works = 0

        packadd! mytest

        call assert_true(len(&rtp) > len(rtp))
        call assert_true(&rtp =~ (s:plugdir . '\($\|,\)'))
        call assert_equal(0, g:plugin_works)

        " check the path is not added twice
        let new_rtp = &rtp
        packadd! mytest
        call assert_equal(new_rtp, &rtp)
      endfunc

      func Test_packloadall()
        let plugindir = &packpath . '/pack/mine/start/foo/plugin'
        call mkdir(plugindir, 'p')
        call writefile(['let g:plugin_foo_number = 1234'], plugindir . '/bar.vim')
        packloadall
        call assert_equal(1234, g:plugin_foo_number)

        " only works once
        call writefile(['let g:plugin_bar_number = 4321'], plugindir . '/bar2.vim')
        packloadall
        call assert_false(exists('g:plugin_bar_number'))

        " works when ! used
        packloadall!
        call assert_equal(4321, g:plugin_bar_number)
      endfunc
    ]=])
    call('SetUp')
  end)

  after_each(function()
    call('TearDown')
  end)

  it('is working', function()
    call('Test_packadd')
    expected_empty()
  end)

  it('works with packadd!', function()
    call('Test_packadd_noload')
    expected_empty()
  end)

  it('works with :packloadall', function()
    call('Test_packloadall')
    expected_empty()
  end)

  describe('command line completion', function()
    local Screen = require('test.functional.ui.screen')
    local screen

    before_each(function()
      screen = Screen.new(30, 5)
      screen:attach()
      screen:set_default_attr_ids({
        [1] = {
          foreground = Screen.colors.Black,
          background = Screen.colors.Yellow,
        },
        [2] = {bold = true, reverse = true}
      })
      local NonText = Screen.colors.Blue
      screen:set_default_attr_ignore({{}, {bold=true, foreground=NonText}})

      execute([[let optdir1 = &packpath . '/pack/mine/opt']])
      execute([[let optdir2 = &packpath . '/pack/candidate/opt']])
      execute([[call mkdir(optdir1 . '/pluginA', 'p')]])
      execute([[call mkdir(optdir1 . '/pluginC', 'p')]])
      execute([[call mkdir(optdir2 . '/pluginB', 'p')]])
      execute([[call mkdir(optdir2 . '/pluginC', 'p')]])
    end)

    it('works', function()
      feed(':packadd <Tab>')
      screen:expect([=[
                                      |
        ~                             |
        ~                             |
        {1:pluginA}{2:  pluginB  pluginC     }|
        :packadd pluginA^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        ~                             |
        ~                             |
        {2:pluginA  }{1:pluginB}{2:  pluginC     }|
        :packadd pluginB^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        ~                             |
        ~                             |
        {2:pluginA  pluginB  }{1:pluginC}{2:     }|
        :packadd pluginC^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        ~                             |
        ~                             |
        {2:pluginA  pluginB  pluginC     }|
        :packadd ^                     |
      ]=])
    end)
  end)
end)
