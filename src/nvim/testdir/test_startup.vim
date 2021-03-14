" Tests for startup.

source shared.vim
source screendump.vim
source term_util.vim
source check.vim

" Check that loading startup.vim works.
func Test_startup_script()
  throw 'skipped: Nvim does not need defaults.vim'
  set compatible
  source $VIMRUNTIME/defaults.vim

  call assert_equal(0, &compatible)
endfunc

" Verify the order in which plugins are loaded:
" 1. plugins in non-after directories
" 2. packages
" 3. plugins in after directories
func Test_after_comes_later()
  if !has('packages')
    return
  endif
  let before =<< trim [CODE]
    set nocp viminfo+=nviminfo
    set guioptions+=M
    let $HOME = "/does/not/exist"
    set loadplugins
    set rtp=Xhere,Xafter,Xanother
    set packpath=Xhere,Xafter
    set nomore
    let g:sequence = ""
  [CODE]

  let after =<< trim [CODE]
    redir! > Xtestout
    scriptnames
    redir END
    redir! > Xsequence
    echo g:sequence
    redir END
    quit
  [CODE]

  call mkdir('Xhere/plugin', 'p')
  call writefile(['let g:sequence .= "here "'], 'Xhere/plugin/here.vim')
  call mkdir('Xanother/plugin', 'p')
  call writefile(['let g:sequence .= "another "'], 'Xanother/plugin/another.vim')
  call mkdir('Xhere/pack/foo/start/foobar/plugin', 'p')
  call writefile(['let g:sequence .= "pack "'], 'Xhere/pack/foo/start/foobar/plugin/foo.vim')

  call mkdir('Xafter/plugin', 'p')
  call writefile(['let g:sequence .= "after "'], 'Xafter/plugin/later.vim')

  if RunVim(before, after, '')

    let lines = readfile('Xtestout')
    let expected = ['Xbefore.vim', 'here.vim', 'another.vim', 'foo.vim', 'later.vim', 'Xafter.vim']
    let found = []
    for line in lines
      for one in expected
	if line =~ one
	  call add(found, one)
	endif
      endfor
    endfor
    call assert_equal(expected, found)
  endif

  call assert_equal('here another pack after', substitute(join(readfile('Xsequence', 1), ''), '\s\+$', '', ''))

  call delete('Xtestout')
  call delete('Xsequence')
  call delete('Xhere', 'rf')
  call delete('Xanother', 'rf')
  call delete('Xafter', 'rf')
endfunc

func Test_pack_in_rtp_when_plugins_run()
  if !has('packages')
    return
  endif
  let before =<< trim [CODE]
    set nocp viminfo+=nviminfo
    set guioptions+=M
    let $HOME = "/does/not/exist"
    set loadplugins
    set rtp=Xhere
    set packpath=Xhere
    set nomore
  [CODE]

  let after = [
	\ 'quit',
	\ ]
  call mkdir('Xhere/plugin', 'p')
  call writefile(['redir! > Xtestout', 'silent set runtimepath?', 'silent! call foo#Trigger()', 'redir END'], 'Xhere/plugin/here.vim')
  call mkdir('Xhere/pack/foo/start/foobar/autoload', 'p')
  call writefile(['function! foo#Trigger()', 'echo "autoloaded foo"', 'endfunction'], 'Xhere/pack/foo/start/foobar/autoload/foo.vim')

  if RunVim(before, after, '')

    let lines = filter(readfile('Xtestout'), '!empty(v:val)')
    call assert_match('Xhere[/\\]pack[/\\]foo[/\\]start[/\\]foobar', get(lines, 0))
    call assert_match('autoloaded foo', get(lines, 1))
  endif

  call delete('Xtestout')
  call delete('Xhere', 'rf')
endfunc

func Test_help_arg()
  CheckNotMSWindows

  if RunVim([], [], '--help >Xtestout')
    let lines = readfile('Xtestout')
    call assert_true(len(lines) > 20)
    call assert_match('Usage:', lines[0])

    " check if  couple of lines are there
    let found = []
    for line in lines
      if line =~ '-R.*Read-only mode'
        call add(found, 'Readonly mode')
      endif
      " Watch out for a second --version line in the Gnome version.
      if line =~ '--version.*Print version information'
        call add(found, "--version")
      endif
    endfor
    call assert_equal(['Readonly mode', '--version'], found)
  endif
  call delete('Xtestout')
endfunc

func Test_compatible_args()
  throw "skipped: Nvim is always 'nocompatible'"
  let after =<< trim [CODE]
    call writefile([string(&compatible)], "Xtestout")
    set viminfo+=nviminfo
    quit
  [CODE]

  if RunVim([], after, '-C')
    let lines = readfile('Xtestout')
    call assert_equal('1', lines[0])
  endif

  if RunVim([], after, '-N')
    let lines = readfile('Xtestout')
    call assert_equal('0', lines[0])
  endif

  call delete('Xtestout')
endfunc

" Test the -o[N] and -O[N] arguments to open N windows split
" horizontally or vertically.
func Test_o_arg()
  let after =<< trim [CODE]
    call writefile([winnr("$"),
		\ winheight(1), winheight(2), &lines,
		\ winwidth(1), winwidth(2), &columns,
		\ bufname(winbufnr(1)), bufname(winbufnr(2))],
		\ "Xtestout")
    qall
  [CODE]

  if RunVim([], after, '-o2')
    " Open 2 windows split horizontally. Expect:
    " - 2 windows
    " - both windows should have the same or almost the same height
    " - sum of both windows height (+ 3 for both statusline and Ex command)
    "   should be equal to the number of lines
    " - both windows should have the same width which should be equal to the
    "   number of columns
    " - buffer of both windows should have no name
    let [wn, wh1, wh2, ln, ww1, ww2, cn, bn1, bn2] = readfile('Xtestout')
    call assert_equal('2', wn)
    call assert_inrange(0, 1, wh1 - wh2)
    call assert_equal(string(wh1 + wh2 + 3), ln)
    call assert_equal(ww1, ww2)
    call assert_equal(ww1, cn)
    call assert_equal('', bn1)
    call assert_equal('', bn2)
  endif

  if RunVim([], after, '-o foo bar')
    " Same expectations as for -o2 but buffer names should be foo and bar
    let [wn, wh1, wh2, ln, ww1, ww2, cn, bn1, bn2] = readfile('Xtestout')
    call assert_equal('2', wn)
    call assert_inrange(0, 1, wh1 - wh2)
    call assert_equal(string(wh1 + wh2 + 3), ln)
    call assert_equal(ww1, ww2)
    call assert_equal(ww1, cn)
    call assert_equal('foo', bn1)
    call assert_equal('bar', bn2)
  endif

  if RunVim([], after, '-O2')
    " Open 2 windows split vertically. Expect:
    " - 2 windows
    " - both windows should have the same or almost the same width
    " - sum of both windows width (+ 1 for the separator) should be equal to
    "   the number of columns
    " - both windows should have the same height
    " - window height (+ 2 for the statusline and Ex command) should be equal
    "   to the number of lines
    " - buffer of both windows should have no name
    let [wn, wh1, wh2, ln, ww1, ww2, cn, bn1, bn2] = readfile('Xtestout')
    call assert_equal('2', wn)
    call assert_inrange(0, 1, ww1 - ww2)
    call assert_equal(string(ww1 + ww2 + 1), cn)
    call assert_equal(wh1, wh2)
    call assert_equal(string(wh1 + 2), ln)
    call assert_equal('', bn1)
    call assert_equal('', bn2)
  endif

  if RunVim([], after, '-O foo bar')
    " Same expectations as for -O2 but buffer names should be foo and bar
    let [wn, wh1, wh2, ln, ww1, ww2, cn, bn1, bn2] = readfile('Xtestout')
    call assert_equal('2', wn)
    call assert_inrange(0, 1, ww1 - ww2)
    call assert_equal(string(ww1 + ww2 + 1), cn)
    call assert_equal(wh1, wh2)
    call assert_equal(string(wh1 + 2), ln)
    call assert_equal('foo', bn1)
    call assert_equal('bar', bn2)
  endif

  call delete('Xtestout')
endfunc

" Test the -p[N] argument to open N tabpages.
func Test_p_arg()
  let after =<< trim [CODE]
    call writefile(split(execute("tabs"), "\n"), "Xtestout")
    qall
  [CODE]

  if RunVim([], after, '-p2')
    let lines = readfile('Xtestout')
    call assert_equal(4, len(lines))
    call assert_equal('Tab page 1',    lines[0])
    call assert_equal('>   [No Name]', lines[1])
    call assert_equal('Tab page 2',    lines[2])
    call assert_equal('#   [No Name]', lines[3])
  endif

  if RunVim([], after, '-p foo bar')
    let lines = readfile('Xtestout')
    call assert_equal(4, len(lines))
    call assert_equal('Tab page 1', lines[0])
    call assert_equal('>   foo',    lines[1])
    call assert_equal('Tab page 2', lines[2])
    call assert_equal('#   bar',    lines[3])
  endif

  call delete('Xtestout')
endfunc

" Test the -V[N] argument to set the 'verbose' option to [N]
func Test_V_arg()
  if has('gui_running')
    " Can't catch the output of gvim.
    return
  endif
  let out = system(GetVimCommand() . ' --clean -es -X -V0 -c "set verbose?" -cq')
  call assert_equal("  verbose=0\n", out)

  let out = system(GetVimCommand() . ' --clean -es -X -V2 -c "set verbose?" -cq')
  " call assert_match("sourcing \"$VIMRUNTIME[\\/]defaults\.vim\"\r\nline \\d\\+: sourcing \"[^\"]*runtime[\\/]filetype\.vim\".*\n", out)
  call assert_match("  verbose=2\n", out)

  let out = system(GetVimCommand() . ' --clean -es -X -V15 -c "set verbose?" -cq')
   " call assert_match("sourcing \"$VIMRUNTIME[\\/]defaults\.vim\"\r\nline 1: \" The default vimrc file\..*  verbose=15\n", out)
endfunc

" Test the '-q [errorfile]' argument.
func Test_q_arg()
  CheckFeature quickfix

  let lines =<< trim END
    /* some file with an error */
    main() {
      functionCall(arg; arg, arg);
      return 666
    }
  END
  call writefile(lines, 'Xbadfile.c')

  let after =<< trim [CODE]
    call writefile([&errorfile, string(getpos("."))], "Xtestout")
    copen
    w >> Xtestout
    qall
  [CODE]

  " Test with default argument '-q'.
  call assert_equal('errors.err', &errorfile)
  call writefile(["Xbadfile.c:4:12: error: expected ';' before '}' token"], 'errors.err')
  if RunVim([], after, '-q')
    let lines = readfile('Xtestout')
    call assert_equal(['errors.err',
	\              '[0, 4, 12, 0]',
	\              "Xbadfile.c|4 col 12| error: expected ';' before '}' token"],
	\             lines)
  endif
  call delete('Xtestout')
  call delete('errors.err')

  " Test with explicit argument '-q Xerrors' (with space).
  call writefile(["Xbadfile.c:4:12: error: expected ';' before '}' token"], 'Xerrors')
  if RunVim([], after, '-q Xerrors')
    let lines = readfile('Xtestout')
    call assert_equal(['Xerrors',
	\              '[0, 4, 12, 0]',
	\              "Xbadfile.c|4 col 12| error: expected ';' before '}' token"],
	\             lines)
  endif
  call delete('Xtestout')

  " Test with explicit argument '-qXerrors' (without space).
  if RunVim([], after, '-qXerrors')
    let lines = readfile('Xtestout')
    call assert_equal(['Xerrors',
	\              '[0, 4, 12, 0]',
	\              "Xbadfile.c|4 col 12| error: expected ';' before '}' token"],
	\             lines)
  endif

  " Test with a non-existing error file (exits with value 3)
  let out = system(GetVimCommand() .. ' -q xyz.err')
  call assert_equal(3, v:shell_error)

  call delete('Xbadfile.c')
  call delete('Xtestout')
  call delete('Xerrors')
endfunc

" Test the -V[N]{filename} argument to set the 'verbose' option to N
" and set 'verbosefile' to filename.
func Test_V_file_arg()
  if RunVim([], [], ' --clean -V2Xverbosefile -c "set verbose? verbosefile?" -cq')
    let out = join(readfile('Xverbosefile'), "\n")
    " call assert_match("sourcing \"$VIMRUNTIME[\\/]defaults\.vim\"\n", out)
    call assert_match("\n  verbose=2\n", out)
    call assert_match("\n  verbosefile=Xverbosefile", out)
  endif

  call delete('Xverbosefile')
endfunc

" Test the -m, -M and -R arguments:
" -m resets 'write'
" -M resets 'modifiable' and 'write'
" -R sets 'readonly'
func Test_m_M_R()
  let after =<< trim [CODE]
    call writefile([&write, &modifiable, &readonly, &updatecount], "Xtestout")
    qall
  [CODE]

  if RunVim([], after, '')
    let lines = readfile('Xtestout')
    call assert_equal(['1', '1', '0', '200'], lines)
  endif
  if RunVim([], after, '-m')
    let lines = readfile('Xtestout')
    call assert_equal(['0', '1', '0', '200'], lines)
  endif
  if RunVim([], after, '-M')
    let lines = readfile('Xtestout')
    call assert_equal(['0', '0', '0', '200'], lines)
  endif
  if RunVim([], after, '-R')
    let lines = readfile('Xtestout')
    call assert_equal(['1', '1', '1', '10000'], lines)
  endif

  call delete('Xtestout')
endfunc

" Test the -A, -F and -H arguments (Arabic, Farsi and Hebrew modes).
func Test_A_F_H_arg()
  let after =<< trim [CODE]
    call writefile([&rightleft, &arabic, 0, &hkmap], "Xtestout")
    qall
  [CODE]

  " Use silent Ex mode to avoid the hit-Enter prompt for the warning that
  " 'encoding' is not utf-8.
  if has('arabic') && &encoding == 'utf-8' && RunVim([], after, '-e -s -A')
    let lines = readfile('Xtestout')
    call assert_equal(['1', '1', '0', '0'], lines)
  endif

  if has('farsi') && RunVim([], after, '-F')
    let lines = readfile('Xtestout')
    call assert_equal(['1', '0', '1', '0'], lines)
  endif

  if has('rightleft') && RunVim([], after, '-H')
    let lines = readfile('Xtestout')
    call assert_equal(['1', '0', '0', '1'], lines)
  endif

  call delete('Xtestout')
endfunc

" Test the --echo-wid argument (for GTK GUI only).
func Test_echo_wid()
  CheckCanRunGui
  CheckFeature gui_gtk

  if RunVim([], [], '-g --echo-wid -cq >Xtest_echo_wid')
    let lines = readfile('Xtest_echo_wid')
    call assert_equal(1, len(lines))
    call assert_match('^WID: \d\+$', lines[0])
  endif

  call delete('Xtest_echo_wid')
endfunction

" Test the -reverse and +reverse arguments (for GUI only).
func Test_reverse()
  CheckCanRunGui
  CheckNotMSWindows

  let after =<< trim [CODE]
    call writefile([&background], "Xtest_reverse")
    qall
  [CODE]
  if RunVim([], after, '-f -g -reverse')
    let lines = readfile('Xtest_reverse')
    call assert_equal(['dark'], lines)
  endif
  if RunVim([], after, '-f -g +reverse')
    let lines = readfile('Xtest_reverse')
    call assert_equal(['light'], lines)
  endif

  call delete('Xtest_reverse')
endfunc

" Test the -background and -foreground arguments (for GUI only).
func Test_background_foreground()
  CheckCanRunGui
  CheckNotMSWindows

  " Is there a better way to check the effect of -background & -foreground
  " other than merely looking at &background (dark or light)?
  let after =<< trim [CODE]
    call writefile([&background], "Xtest_fg_bg")
    qall
  [CODE]
  if RunVim([], after, '-f -g -background darkred -foreground yellow')
    let lines = readfile('Xtest_fg_bg')
    call assert_equal(['dark'], lines)
  endif
  if RunVim([], after, '-f -g -background ivory -foreground darkgreen')
    let lines = readfile('Xtest_fg_bg')
    call assert_equal(['light'], lines)
  endif

  call delete('Xtest_fg_bg')
endfunc

" Test the -font argument (for GUI only).
func Test_font()
  CheckCanRunGui
  CheckNotMSWindows

  if has('gui_gtk')
    let font = 'Courier 14'
  elseif has('gui_motif') || has('gui_athena')
    let font = '-misc-fixed-bold-*'
  else
    throw 'Skipped: test does not set a valid font for this GUI'
  endif

  let after =<< trim [CODE]
    call writefile([&guifont], "Xtest_font")
    qall
  [CODE]

  if RunVim([], after, '--nofork -g -font "' .. font .. '"')
    let lines = readfile('Xtest_font')
    call assert_equal([font], lines)
  endif

  call delete('Xtest_font')
endfunc

" Test the -geometry argument (for GUI only).
func Test_geometry()
  CheckCanRunGui
  CheckNotMSWindows

  if has('gui_motif') || has('gui_athena')
    " FIXME: With GUI Athena or Motif, the value of getwinposx(),
    "        getwinposy() and getwinpos() do not match exactly the
    "        value given in -geometry. Why?
    "        So only check &columns and &lines for those GUIs.
    let after =<< trim [CODE]
      call writefile([&columns, &lines], "Xtest_geometry")
      qall
    [CODE]
    if RunVim([], after, '-f -g -geometry 31x13+41+43')
      let lines = readfile('Xtest_geometry')
      call assert_equal(['31', '13'], lines)
    endif
  else
    let after =<< trim [CODE]
      call writefile([&columns, &lines, getwinposx(), getwinposy(), string(getwinpos())], "Xtest_geometry")
      qall
    [CODE]
    if RunVim([], after, '-f -g -geometry 31x13+41+43')
      let lines = readfile('Xtest_geometry')
      call assert_equal(['31', '13', '41', '43', '[41, 43]'], lines)
    endif
  endif

  call delete('Xtest_geometry')
endfunc

" Test the -iconic argument (for GUI only).
func Test_iconic()
  CheckCanRunGui
  CheckNotMSWindows

  call RunVim([], [], '-f -g -iconic -cq')

  " TODO: currently only start vim iconified, but does not
  "       check that vim is iconified. How could this be checked?
endfunc


func Test_invalid_args()
  if !has('unix') || has('gui_running')
    " can't get output of Vim.
    return
  endif

  for opt in ['-Y', '--does-not-exist']
    let out = split(system(GetVimCommand() .. ' ' .. opt), "\n")
    call assert_equal(1, v:shell_error)
    call assert_equal('nvim: Unknown option argument: "' .. opt .. '"', out[0])
    call assert_equal('More info with "nvim -h"',                       out[1])
  endfor

  for opt in ['-c', '-i', '-s', '-t', '-u', '-U', '-w', '-W', '--cmd', '--startuptime']
    let out = split(system(GetVimCommand() .. ' '  .. opt), "\n")
    call assert_equal(1, v:shell_error)
    call assert_equal('nvim: Argument missing after: "' .. opt .. '"', out[0])
    call assert_equal('More info with "nvim -h"',                      out[1])
  endfor

  if has('clientserver')
    for opt in ['--remote', '--remote-send', '--remote-silent', '--remote-expr',
          \     '--remote-tab', '--remote-tab-wait',
          \     '--remote-tab-wait-silent', '--remote-tab-silent',
          \     '--remote-wait', '--remote-wait-silent',
          \     '--servername',
          \    ]
      let out = split(system(GetVimCommand() .. ' '  .. opt), "\n")
      call assert_equal(1, v:shell_error)
      call assert_match('^VIM - Vi IMproved .* (.*)$',             out[0])
      call assert_equal('Argument missing after: "' .. opt .. '"', out[1])
      call assert_equal('More info with: "vim -h"',                out[2])
    endfor
  endif

  if has('gui_gtk')
    let out = split(system(GetVimCommand() .. ' --display'), "\n")
    call assert_equal(1, v:shell_error)
    call assert_match('^VIM - Vi IMproved .* (.*)$',         out[0])
    call assert_equal('Argument missing after: "--display"', out[1])
    call assert_equal('More info with: "vim -h"',            out[2])
  endif

  if has('xterm_clipboard')
    let out = split(system(GetVimCommand() .. ' -display'), "\n")
    call assert_equal(1, v:shell_error)
    call assert_match('^VIM - Vi IMproved .* (.*)$',         out[0])
    call assert_equal('Argument missing after: "-display"', out[1])
    call assert_equal('More info with: "vim -h"',            out[2])
  endif

  let out = split(system(GetVimCommand() .. ' -ix'), "\n")
  call assert_equal(1, v:shell_error)
  call assert_equal('nvim: Garbage after option argument: "-ix"', out[0])
  call assert_equal('More info with "nvim -h"',                   out[1])

  " Not an error in Nvim.  The "-" file is allowed with -t, -q, or [file].
  let out = split(system(GetVimCommand() .. ' - xxx -cq'), "\n")
  call assert_equal(0, v:shell_error)

  if has('quickfix')
    " Detect invalid repeated arguments '-t foo -t foo", '-q foo -q foo'.
    for opt in ['-t', '-q']
      let out = split(system(GetVimCommand() .. repeat(' ' .. opt .. ' foo', 2)), "\n")
      call assert_equal(1, v:shell_error)
      call assert_equal('nvim: Too many edit arguments: "' .. opt .. '"', out[0])
      call assert_equal('More info with "nvim -h"',                       out[1])
    endfor
  endif

  for opt in [' -cq', ' --cmd q', ' +', ' -S foo']
    let out = split(system(GetVimCommand() .. repeat(opt, 11)), "\n")
    call assert_equal(1, v:shell_error)
    " FIXME: The error message given by Vim is not ideal in case of repeated
    " -S foo since it does not mention -S.
    call assert_equal('nvim: Too many "+command", "-c command" or "--cmd command" arguments', out[0])
    call assert_equal('More info with "nvim -h"',                                             out[1])
  endfor

  if has('gui_gtk')
    for opt in ['--socketid x', '--socketid 0xg']
      let out = split(system(GetVimCommand() .. ' ' .. opt), "\n")
      call assert_equal(1, v:shell_error)
      call assert_match('^VIM - Vi IMproved .* (.*)$',        out[0])
      call assert_equal('Invalid argument for: "--socketid"', out[1])
      call assert_equal('More info with: "vim -h"',           out[2])
    endfor
  endif
endfunc

func Test_file_args()
  let after =<< trim [CODE]
    call writefile(argv(), "Xtestout")
    qall
  [CODE]

  if RunVim([], after, '')
    let lines = readfile('Xtestout')
    call assert_equal(0, len(lines))
  endif

  if RunVim([], after, 'one')
    let lines = readfile('Xtestout')
    call assert_equal(1, len(lines))
    call assert_equal('one', lines[0])
  endif

  if RunVim([], after, 'one two three')
    let lines = readfile('Xtestout')
    call assert_equal(3, len(lines))
    call assert_equal('one', lines[0])
    call assert_equal('two', lines[1])
    call assert_equal('three', lines[2])
  endif

  if RunVim([], after, 'one -c echo two')
    let lines = readfile('Xtestout')
    call assert_equal(2, len(lines))
    call assert_equal('one', lines[0])
    call assert_equal('two', lines[1])
  endif

  if RunVim([], after, 'one -- -c echo two')
    let lines = readfile('Xtestout')
    call assert_equal(4, len(lines))
    call assert_equal('one', lines[0])
    call assert_equal('-c', lines[1])
    call assert_equal('echo', lines[2])
    call assert_equal('two', lines[3])
  endif

  call delete('Xtestout')
endfunc

func Test_startuptime()
  if !has('startuptime')
    return
  endif
  let after = ['qall']
  if RunVim([], after, '--startuptime Xtestout one')
    let lines = readfile('Xtestout')
    let expected = ['parsing arguments', 'inits 3', 'opening buffers']
    let found = []
    for line in lines
      for exp in expected
	if line =~ exp
	  call add(found, exp)
	endif
      endfor
    endfor
    call assert_equal(expected, found)
  endif
  call delete('Xtestout')
endfunc

func Test_read_stdin()
  let after =<< trim [CODE]
    write Xtestout
    quit!
  [CODE]

  if RunVimPiped([], after, '-', 'echo something | ')
    let lines = readfile('Xtestout')
    " MS-Windows adds a space after the word
    call assert_equal(['something'], split(lines[0]))
  endif
  call delete('Xtestout')
endfunc

func Test_set_shell()
  let after =<< trim [CODE]
    call writefile([&shell], "Xtestout")
    quit!
  [CODE]

  if has('win32')
    let $SHELL = 'C:\with space\cmd.exe'
    let expected = '"C:\with space\cmd.exe"'
  else
    let $SHELL = '/bin/with space/sh'
    let expected = '"/bin/with space/sh"'
  endif

  if RunVimPiped([], after, '', '')
    let lines = readfile('Xtestout')
    call assert_equal(expected, lines[0])
  endif
  call delete('Xtestout')
endfunc

func Test_progpath()
  " Tests normally run with "./vim" or "../vim", these must have been expanded
  " to a full path.
  if has('unix')
    call assert_equal('/', v:progpath[0])
  elseif has('win32')
    call assert_equal(':', v:progpath[1])
    call assert_match('[/\\]', v:progpath[2])
  endif

  " Only expect "vim" to appear in v:progname.
  call assert_match('vim\c', v:progname)
endfunc

func Test_silent_ex_mode()
  if !has('unix') || has('gui_running')
    " can't get output of Vim.
    return
  endif

  " This caused an ml_get error.
  let out = system(GetVimCommand() . ' -u NONE -es -c''set verbose=1|h|exe "%norm\<c-y>\<c-d>"'' -c cq')
  call assert_notmatch('E315:', out)
endfunc

func Test_default_term()
  if !has('unix') || has('gui_running')
    " can't get output of Vim.
    return
  endif

  let save_term = $TERM
  let $TERM = 'unknownxxx'
  let out = system(GetVimCommand() . ' -c ''echo &term'' -c cq')
  call assert_match('nvim', out)
  let $TERM = save_term
endfunc

func Test_zzz_startinsert()
  " Test :startinsert
  call writefile(['123456'], 'Xtestout')
  let after =<< trim [CODE]
    :startinsert
    call feedkeys("foobar\<c-o>:wq\<cr>","t")
  [CODE]

  if RunVim([], after, 'Xtestout')
    let lines = readfile('Xtestout')
    call assert_equal(['foobar123456'], lines)
  endif
  " Test :startinsert!
  call writefile(['123456'], 'Xtestout')
  let after =<< trim [CODE]
    :startinsert!
    call feedkeys("foobar\<c-o>:wq\<cr>","t")
  [CODE]

  if RunVim([], after, 'Xtestout')
    let lines = readfile('Xtestout')
    call assert_equal(['123456foobar'], lines)
  endif
  call delete('Xtestout')
endfunc

func Test_start_with_tabs()
  if !CanRunVimInTerminal()
    return
  endif

  let buf = RunVimInTerminal('-p a b c', {})
  call VerifyScreenDump(buf, 'Test_start_with_tabs', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc

func Test_v_argv()
  let out = system(GetVimCommand() . ' -es -V1 -X arg1 --cmd "echo v:argv" --cmd q')
  let list = split(out, "', '")
  call assert_match('vim', list[0])
  let idx = index(list, 'arg1')
  call assert_true(idx > 2)
  call assert_equal(['arg1', '--cmd', 'echo v:argv', '--cmd', 'q'']'], list[idx:])
endfunc

" Test the '-T' argument which sets the 'term' option.
func Test_T_arg()
  throw 'skipped: Nvim does not support "-T" argument'
  CheckNotGui
  let after =<< trim [CODE]
    call writefile([&term], "Xtest_T_arg")
    qall
  [CODE]

  for t in ['builtin_dumb', 'builtin_ansi']
    if RunVim([], after, '-T ' .. t)
      let lines = readfile('Xtest_T_arg')
      call assert_equal([t], lines)
    endif
  endfor

  call delete('Xtest_T_arg')
endfunc

" Test the '-x' argument to read/write encrypted files.
func Test_x_arg()
  CheckRunVimInTerminal
  CheckFeature cryptv

  " Create an encrypted file Xtest_x_arg.
  let buf = RunVimInTerminal('-n -x Xtest_x_arg', #{rows: 10, wait_for_ruler: 0})
  call WaitForAssert({-> assert_match('^Enter encryption key: ', term_getline(buf, 10))})
  call term_sendkeys(buf, "foo\n")
  call WaitForAssert({-> assert_match('^Enter same key again: ', term_getline(buf, 10))})
  call term_sendkeys(buf, "foo\n")
  call WaitForAssert({-> assert_match(' All$', term_getline(buf, 10))})
  call term_sendkeys(buf, "itest\<Esc>:w\<Enter>")
  call WaitForAssert({-> assert_match('"Xtest_x_arg" \[New\]\[blowfish2\] 1L, 5B written',
        \            term_getline(buf, 10))})
  call StopVimInTerminal(buf)

  " Read the encrypted file and check that it contains the expected content "test"
  let buf = RunVimInTerminal('-n -x Xtest_x_arg', #{rows: 10, wait_for_ruler: 0})
  call WaitForAssert({-> assert_match('^Enter encryption key: ', term_getline(buf, 10))})
  call term_sendkeys(buf, "foo\n")
  call WaitForAssert({-> assert_match('^Enter same key again: ', term_getline(buf, 10))})
  call term_sendkeys(buf, "foo\n")
  call WaitForAssert({-> assert_match('^test', term_getline(buf, 1))})
  call StopVimInTerminal(buf)

  call delete('Xtest_x_arg')
endfunc

" Test starting vim with various names: vim, ex, view, evim, etc.
func Test_progname()
  CheckUnix

  call mkdir('Xprogname', 'p')
  call writefile(['silent !date',
  \               'call writefile([mode(1), '
  \               .. '&insertmode, &diff, &readonly, &updatecount, '
  \               .. 'join(split(execute("message"), "\n")[1:])], "Xprogname_out")',
  \               'qall'], 'Xprogname_after')

  "  +---------------------------------------------- progname
  "  |            +--------------------------------- mode(1)
  "  |            |     +--------------------------- &insertmode
  "  |            |     |    +---------------------- &diff
  "  |            |     |    |    +----------------- &readonly
  "  |            |     |    |    |        +-------- &updatecount
  "  |            |     |    |    |        |    +--- :messages
  "  |            |     |    |    |        |    |
  " let expectations = {
  " \ 'vim':      ['n',  '0', '0', '0',   '200', ''],
  " \ 'gvim':     ['n',  '0', '0', '0',   '200', ''],
  " \ 'ex':       ['ce', '0', '0', '0',   '200', ''],
  " \ 'exim':     ['cv', '0', '0', '0',   '200', ''],
  " \ 'view':     ['n',  '0', '0', '1', '10000', ''],
  " \ 'gview':    ['n',  '0', '0', '1', '10000', ''],
  " \ 'evim':     ['n',  '1', '0', '0',   '200', ''],
  " \ 'eview':    ['n',  '1', '0', '1', '10000', ''],
  " \ 'rvim':     ['n',  '0', '0', '0',   '200', 'line    1: E145: Shell commands and some functionality not allowed in rvim'],
  " \ 'rgvim':    ['n',  '0', '0', '0',   '200', 'line    1: E145: Shell commands and some functionality not allowed in rvim'],
  " \ 'rview':    ['n',  '0', '0', '1', '10000', 'line    1: E145: Shell commands and some functionality not allowed in rvim'],
  " \ 'rgview':   ['n',  '0', '0', '1', '10000', 'line    1: E145: Shell commands and some functionality not allowed in rvim'],
  " \ 'vimdiff':  ['n',  '0', '1', '0',   '200', ''],
  " \ 'gvimdiff': ['n',  '0', '1', '0',   '200', '']}
  let expectations = {'nvim': ['n',  '0', '0', '0',   '200', '']}

  " let prognames = ['vim', 'gvim', 'ex', 'exim', 'view', 'gview',
  " \                'evim', 'eview', 'rvim', 'rgvim', 'rview', 'rgview',
  " \                'vimdiff', 'gvimdiff']
  let prognames = ['nvim']

  for progname in prognames
    let run_with_gui = (progname =~# 'g') || (has('gui') && (progname ==# 'evim' || progname ==# 'eview'))

    if empty($DISPLAY) && run_with_gui
      " Can't run gvim, gview  (etc.) if $DISPLAY is not setup.
      continue
     endif

    exe 'silent !ln -s -f ' ..exepath(GetVimProg()) .. ' Xprogname/' .. progname

    let stdout_stderr = ''
    if progname =~# 'g'
      let stdout_stderr = system('Xprogname/'..progname..' -f --clean --not-a-term -S Xprogname_after')
    else
      exe 'sil !Xprogname/'..progname..' -f --clean -S Xprogname_after'
    endif

    if progname =~# 'g' && !has('gui')
      call assert_equal("E25: GUI cannot be used: Not enabled at compile time\n", stdout_stderr, progname)
    else
      " GUI motif can output some warnings like this:
      "   Warning:
      "       Name: subMenu
      "       Class: XmCascadeButton
      "       Illegal mnemonic character;  Could not convert X KEYSYM to a keycode
      " So don't check that stderr is empty with GUI Motif.
      if run_with_gui && !has('gui_motif')
        call assert_equal('', stdout_stderr, progname)
      endif
      call assert_equal(expectations[progname], readfile('Xprogname_out'), progname)
    endif

    call delete('Xprogname/' .. progname)
    call delete('Xprogname_out')
  endfor

  call delete('Xprogname_after')
  call delete('Xprogname', 'd')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
