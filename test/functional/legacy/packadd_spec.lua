-- Tests for 'packpath' and :packadd

local helpers = require('test.functional.helpers')(after_each)
local clear, source, command = helpers.clear, helpers.source, helpers.command
local call, eq, nvim = helpers.call, helpers.eq, helpers.meths
local feed = helpers.feed

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('packadd', function()
  before_each(function()
    clear()

    source([=[
      func Escape(s)
        return escape(a:s, '\~')
      endfunc

      func SetUp()
        let s:topdir = expand(getcwd() . '/Xdir')
        if isdirectory(s:topdir)
          call delete(s:topdir, 'rf')
        endif
        exe 'set packpath=' . s:topdir
        let s:plugdir = expand(s:topdir . '/pack/mine/opt/mytest')
      endfunc

      func TearDown()
        call delete(s:topdir, 'rf')
      endfunc

      func Test_packadd()
        if !exists('s:plugdir')
          echomsg 'when running this test manually, call SetUp() first'
          return
        endif

        call mkdir(s:plugdir . '/plugin/also', 'p')
        call mkdir(s:plugdir . '/ftdetect', 'p')
        call mkdir(s:plugdir . '/after', 'p')
        set rtp&
        let rtp = &rtp
        filetype on

        let rtp_entries = split(rtp, ',')
        for entry in rtp_entries
          if entry =~? '\<after\>'
            let first_after_entry = entry
            break
          endif
        endfor

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq

        exe 'split ' . s:plugdir . '/plugin/also/loaded.vim'
        call setline(1, 'let g:plugin_also_works = 77')
        wq

        exe 'split ' . s:plugdir . '/ftdetect/test.vim'
        call setline(1, 'let g:ftdetect_works = 17')
        wq

        packadd mytest

        call assert_true(42, g:plugin_works)
        call assert_equal(77, g:plugin_also_works)
        call assert_true(17, g:ftdetect_works)
        call assert_true(len(&rtp) > len(rtp))
        call assert_match(Escape(s:plugdir) . '\($\|,\)', &rtp)

        let new_after = match(&rtp, Escape(expand(s:plugdir . '/after') . ','))
        let forwarded = substitute(first_after_entry, '\\', '[/\\\\]', 'g')
        let old_after = match(&rtp, ',' . escape(forwarded, '~') . '\>')
        call assert_true(new_after > 0, 'rtp is ' . &rtp)
        call assert_true(old_after > 0, 'match ' . forwarded . ' in ' . &rtp)
        call assert_true(new_after < old_after, 'rtp is ' . &rtp)

        " NOTE: '/.../opt/myte' forwardly matches with '/.../opt/mytest'
        call mkdir(fnamemodify(s:plugdir, ':h') . '/myte', 'p')
        let rtp = &rtp
        packadd myte

        " Check the path of 'myte' is added
        call assert_true(len(&rtp) > len(rtp))
        call assert_match(Escape(s:plugdir) . '\($\|,\)', &rtp)

        " Check exception
        call assert_fails("packadd directorynotfound", 'E919:')
        call assert_fails("packadd", 'E471:')
      endfunc

      func Test_packadd_start()
        let plugdir = expand(s:topdir . '/pack/mine/start/other')
        call mkdir(plugdir . '/plugin', 'p')
        set rtp&
        let rtp = &rtp
        filetype on

        exe 'split ' . plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 24')
        wq

        exe 'split ' . plugdir . '/plugin/test.lua'
        call setline(1, 'vim.g.plugin_lua_works = 24')
        wq

        packadd other

        call assert_equal(24, g:plugin_works)
        call assert_equal(24, g:plugin_lua_works)
        call assert_true(len(&rtp) > len(rtp))
        call assert_match(Escape(plugdir) . '\($\|,\)', &rtp)
      endfunc

      func Test_packadd_noload()
        call mkdir(s:plugdir . '/plugin', 'p')
        call mkdir(s:plugdir . '/syntax', 'p')
        set rtp&
        let rtp = &rtp

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 42')
        wq
        exe 'split ' . s:plugdir . '/plugin/test.lua'
        call setline(1, 'let g:plugin_lua_works = 42')
        wq
        let g:plugin_works = 0
        let g:plugin_lua_works = 0

        packadd! mytest

        call assert_true(len(&rtp) > len(rtp))
        call assert_match(Escape(s:plugdir) . '\($\|,\)', &rtp)
        call assert_equal(0, g:plugin_works)
        call assert_equal(0, g:plugin_lua_works)

        " check the path is not added twice
        let new_rtp = &rtp
        packadd! mytest
        call assert_equal(new_rtp, &rtp)
      endfunc

      func Test_packadd_symlink_dir()
        let top2_dir = expand(s:topdir . '/Xdir2')
        let real_dir = expand(s:topdir . '/Xsym')
        call mkdir(real_dir, 'p')
        if has('win32')
          exec "silent! !mklink /d" top2_dir "Xsym"
        else
          exec "silent! !ln -s Xsym" top2_dir
        endif
        let &rtp = top2_dir . ',' . expand(top2_dir . '/after')
        let &packpath = &rtp

        let s:plugdir = expand(top2_dir . '/pack/mine/opt/mytest')
        call mkdir(s:plugdir . '/plugin', 'p')

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 44')
        wq
        let g:plugin_works = 0

        packadd mytest

        " Must have been inserted in the middle, not at the end
        call assert_match(Escape(expand('/pack/mine/opt/mytest').','), &rtp)
        call assert_equal(44, g:plugin_works)

        " No change when doing it again.
        let rtp_before = &rtp
        packadd mytest
        call assert_equal(rtp_before, &rtp)

        set rtp&
        let rtp = &rtp
        exec "silent !" (has('win32') ? "rd /q/s" : "rm") top2_dir
      endfunc

      func Test_packadd_symlink_dir2()
        let top2_dir = expand(s:topdir . '/Xdir2')
        let real_dir = expand(s:topdir . '/Xsym/pack')
        call mkdir(top2_dir, 'p')
        call mkdir(real_dir, 'p')
        let &rtp = top2_dir . ',' . top2_dir . '/after'
        let &packpath = &rtp

        if has('win32')
          exec "silent! !mklink /d" top2_dir "Xsym"
        else
          exec "silent !ln -s ../Xsym/pack"  top2_dir . '/pack'
        endif
        let s:plugdir = expand(top2_dir . '/pack/mine/opt/mytest')
        call mkdir(s:plugdir . '/plugin', 'p')

        exe 'split ' . s:plugdir . '/plugin/test.vim'
        call setline(1, 'let g:plugin_works = 48')
        wq
        let g:plugin_works = 0

        packadd mytest

        " Must have been inserted in the middle, not at the end
        call assert_match(Escape(expand('/Xdir2/pack/mine/opt/mytest').','), &rtp)
        call assert_equal(48, g:plugin_works)

        " No change when doing it again.
        let rtp_before = &rtp
        packadd mytest
        call assert_equal(rtp_before, &rtp)

        set rtp&
        let rtp = &rtp
        if has('win32')
          exec "silent !rd /q/s" top2_dir
        else
          exec "silent !rm" top2_dir . '/pack'
          exec "silent !rmdir" top2_dir
        endif
      endfunc

      func Test_packloadall()
        " plugin foo with an autoload directory
        let fooplugindir = &packpath . '/pack/mine/start/foo/plugin'
        call mkdir(fooplugindir, 'p')
        call writefile(['let g:plugin_foo_number = 1234',
          \ 'let g:plugin_foo_auto = bbb#value',
          \ 'let g:plugin_extra_auto = extra#value'], fooplugindir . '/bar.vim')
        let fooautodir = &packpath . '/pack/mine/start/foo/autoload'
        call mkdir(fooautodir, 'p')
        call writefile(['let bar#value = 77'], fooautodir . '/bar.vim')

        " plugin aaa with an autoload directory
        let aaaplugindir = &packpath . '/pack/mine/start/aaa/plugin'
        call mkdir(aaaplugindir, 'p')
        call writefile(['let g:plugin_aaa_number = 333',
          \ 'let g:plugin_aaa_auto = bar#value'], aaaplugindir . '/bbb.vim')
        let aaaautodir = &packpath . '/pack/mine/start/aaa/autoload'
        call mkdir(aaaautodir, 'p')
        call writefile(['let bbb#value = 55'], aaaautodir . '/bbb.vim')

        " plugin extra with only an autoload directory
        let extraautodir = &packpath . '/pack/mine/start/extra/autoload'
        call mkdir(extraautodir, 'p')
        call writefile(['let extra#value = 99'], extraautodir . '/extra.vim')

        packloadall
        call assert_equal(1234, g:plugin_foo_number)
        call assert_equal(55, g:plugin_foo_auto)
        call assert_equal(99, g:plugin_extra_auto)
        call assert_equal(333, g:plugin_aaa_number)
        call assert_equal(77, g:plugin_aaa_auto)

        " only works once
        call writefile(['let g:plugin_bar_number = 4321'],
          \ fooplugindir . '/bar2.vim')
        packloadall
        call assert_false(exists('g:plugin_bar_number'))

        " works when ! used
        packloadall!
        call assert_equal(4321, g:plugin_bar_number)
      endfunc

      func Test_helptags()
        let docdir1 = &packpath . '/pack/mine/start/foo/doc'
        let docdir2 = &packpath . '/pack/mine/start/bar/doc'
        call mkdir(docdir1, 'p')
        call mkdir(docdir2, 'p')
        call writefile(['look here: *look-here*'], docdir1 . '/bar.txt')
        call writefile(['look away: *look-away*'], docdir2 . '/foo.txt')
        exe 'set rtp=' . &packpath . '/pack/mine/start/foo,' . &packpath . '/pack/mine/start/bar'

        helptags ALL

        let tags1 = readfile(docdir1 . '/tags')
        call assert_match('look-here', tags1[0])
        let tags2 = readfile(docdir2 . '/tags')
        call assert_match('look-away', tags2[0])

        call assert_fails('helptags abcxyz', 'E150:')
      endfunc

      func Test_colorscheme()
        let colordirrun = &packpath . '/runtime/colors'
        let colordirstart = &packpath . '/pack/mine/start/foo/colors'
        let colordiropt = &packpath . '/pack/mine/opt/bar/colors'
        call mkdir(colordirrun, 'p')
        call mkdir(colordirstart, 'p')
        call mkdir(colordiropt, 'p')
        call writefile(['let g:found_one = 1'], colordirrun . '/one.vim')
        call writefile(['let g:found_two = 1'], colordirstart . '/two.vim')
        call writefile(['let g:found_three = 1'], colordiropt . '/three.vim')
        exe 'set rtp=' . &packpath . '/runtime'

        colorscheme one
        call assert_equal(1, g:found_one)
        colorscheme two
        call assert_equal(1, g:found_two)
        colorscheme three
        call assert_equal(1, g:found_three)
      endfunc

      func Test_runtime()
        let rundir = &packpath . '/runtime/extra'
        let startdir = &packpath . '/pack/mine/start/foo/extra'
        let optdir = &packpath . '/pack/mine/opt/bar/extra'
        call mkdir(rundir, 'p')
        call mkdir(startdir, 'p')
        call mkdir(optdir, 'p')
        call writefile(['let g:sequence .= "run"'], rundir . '/bar.vim')
        call writefile(['let g:sequence .= "start"'], startdir . '/bar.vim')
        call writefile(['let g:sequence .= "foostart"'], startdir . '/foo.vim')
        call writefile(['let g:sequence .= "opt"'], optdir . '/bar.vim')
        call writefile(['let g:sequence .= "xxxopt"'], optdir . '/xxx.vim')
        exe 'set rtp=' . &packpath . '/runtime'

        let g:sequence = ''
        runtime extra/bar.vim
        call assert_equal('run', g:sequence)
        let g:sequence = ''
        runtime START extra/bar.vim
        call assert_equal('start', g:sequence)
        let g:sequence = ''
        runtime OPT extra/bar.vim
        call assert_equal('opt', g:sequence)
        let g:sequence = ''
        runtime PACK extra/bar.vim
        call assert_equal('start', g:sequence)
        let g:sequence = ''
        runtime! PACK extra/bar.vim
        call assert_equal('startopt', g:sequence)
        let g:sequence = ''
        runtime PACK extra/xxx.vim
        call assert_equal('xxxopt', g:sequence)

        let g:sequence = ''
        runtime ALL extra/bar.vim
        call assert_equal('run', g:sequence)
        let g:sequence = ''
        runtime ALL extra/foo.vim
        call assert_equal('foostart', g:sequence)
        let g:sequence = ''
        runtime! ALL extra/xxx.vim
        call assert_equal('xxxopt', g:sequence)
        let g:sequence = ''
        runtime! ALL extra/bar.vim
        call assert_equal('runstartopt', g:sequence)
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

  it('works with symlinks', function()
    call('Test_packadd_symlink_dir')
    expected_empty()
  end)

  it('works with :packloadall', function()
    call('Test_packloadall')
    expected_empty()
  end)

  it('works with helptags', function()
    call('Test_helptags')
    expected_empty()
  end)

  it('works with colorschemes', function()
    call('Test_colorscheme')
    expected_empty()
  end)

  it('works with :runtime [what]', function()
    call('Test_runtime')
    expected_empty()
  end)

  it('loads packages from "start" directory', function()
    call('Test_packadd_start')
    expected_empty()
  end)

  describe('command line completion', function()
    local Screen = require('test.functional.ui.screen')
    local screen

    before_each(function()
      screen = Screen.new(30, 5)
      screen:attach()
      screen:set_default_attr_ids({
        [0] = {bold=true, foreground=Screen.colors.Blue},
        [1] = {
          foreground = Screen.colors.Black,
          background = Screen.colors.Yellow,
        },
        [2] = {bold = true, reverse = true}
      })

      command([[let optdir1 = &packpath . '/pack/mine/opt']])
      command([[let optdir2 = &packpath . '/pack/candidate/opt']])
      command([[call mkdir(optdir1 . '/pluginA', 'p')]])
      command([[call mkdir(optdir1 . '/pluginC', 'p')]])
      command([[call mkdir(optdir2 . '/pluginB', 'p')]])
      command([[call mkdir(optdir2 . '/pluginC', 'p')]])
    end)

    it('works', function()
      feed(':packadd <Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {1:pluginA}{2:  pluginB  pluginC     }|
        :packadd pluginA^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:pluginA  }{1:pluginB}{2:  pluginC     }|
        :packadd pluginB^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:pluginA  pluginB  }{1:pluginC}{2:     }|
        :packadd pluginC^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:pluginA  pluginB  pluginC     }|
        :packadd ^                     |
      ]=])
    end)

    it('works for colorschemes', function()
      source([[
        let colordirrun = &packpath . '/runtime/colors'
        let colordirstart = &packpath . '/pack/mine/start/foo/colors'
        let colordiropt = &packpath . '/pack/mine/opt/bar/colors'
        call mkdir(colordirrun, 'p')
        call mkdir(colordirstart, 'p')
        call mkdir(colordiropt, 'p')
        call writefile(['let g:found_one = 1'], colordirrun . '/one.vim')
        call writefile(['let g:found_two = 1'], colordirstart . '/two.vim')
        call writefile(['let g:found_three = 1'], colordiropt . '/three.vim')
        exe 'set rtp=' . &packpath . '/runtime']])

      feed(':colorscheme <Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {1:one}{2:  three  two               }|
        :colorscheme one^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:one  }{1:three}{2:  two               }|
        :colorscheme three^            |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:one  three  }{1:two}{2:               }|
        :colorscheme two^              |
      ]=])
      feed('<Tab>')
      screen:expect([=[
                                      |
        {0:~                             }|
        {0:~                             }|
        {2:one  three  two               }|
        :colorscheme ^                 |
      ]=])
    end)
  end)
end)
