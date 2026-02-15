const s:testdir = expand("<script>:h")
const s:runtimedir = simplify(s:testdir . '/../../../runtime')
const s:netrw_path = s:runtimedir . '/pack/dist/opt/netrw/autoload/netrw.vim'
const s:netrw_test_path = s:testdir . '/samples/netrw.vim'
const s:testScript =<< trim END

" Testing functions: {{{1
function! TestNetrwCaptureRemotePath(dirname)
  call s:RemotePathAnalysis(a:dirname)
  return {"method": s:method, "user": s:user, "machine": s:machine, "port": s:port, "path": s:path, "fname": s:fname}
endfunction

" Test directory creation via s:NetrwMakeDir()
" Precondition: inputsave() and inputrestore() must be disabled in s:NetrwMakeDir

function s:test_inputsave()
    if exists("s:inputguards_disabled") && s:inputguards_disabled
        return
    endif
    call inputsave()
endfunction

function s:test_inputrestore()
    if exists("s:inputguards_disabled") && s:inputguards_disabled
        return
    endif
    call inputrestore()
endfunction

function s:test_input(prompt, text = v:null, completion = v:null)  " Nvim: use v:null instead of v:none

    if exists("s:inputdefaults_disabled") && s:inputdefaults_disabled || a:text == v:null
        return input(a:prompt)
    elseif a:completion == v:null
        return input(a:prompt, a:text)
    endif

    return input(a:prompt, a:text, a:completion)
endfunction

function Test_NetrwMakeDir(parentdir = $HOME, dirname = "NetrwMakeDir", symlink = 0) abort
    if a:symlink
        " Plainly delegate, this device is necessary because feedkeys() can't
        " access script functions directly.
        call s:NetrwMakeDir('')
        " wipe out the test buffer
        bw
        " reenable the guards
        let s:inputguards_disabled = 0
    else
        " Use feedkeys() to simulate user input (directory name)
        new
        let b:netrw_curdir = a:parentdir
        let s:inputguards_disabled = 1
        call feedkeys($"\<Cmd>call Test_NetrwMakeDir('{a:parentdir}', '{a:dirname}', 1)\<CR>{a:dirname}\<CR>", "x")
    endif
endfunction

" Test file copy operations via s:NetrwMarkFileCopy()
function Test_NetrwMarkFileCopy(source_dir, target_dir, marked_files) abort
    " set up
    new
    let b:netrw_curdir= a:source_dir
    let s:netrwmftgt = a:target_dir
    let s:netrwmarkfilelist_{bufnr("%")} = a:marked_files
    let s:netrwmftgt_islocal = 1
    " delegate
    call s:NetrwMarkFileCopy(1)
    " wipe out the test buffer
    bw
endfunction

" Corner case: copy into the same dir triggers a user prompt
function Test_NetrwMarkFileCopy_SameDir(dir = $HOME, symlink = 0) abort
    const filename = "filename.txt"
    const file = netrw#fs#PathJoin(a:dir, filename)

    const newfilename = "newfilename.txt"
    const newfile = netrw#fs#PathJoin(a:dir, newfilename)

    if a:symlink
        " Plainly delegate, this device is necessary because feedkeys() can't
        " access script functions directly.
        " set up
        new
        let b:netrw_curdir = a:dir
        let s:netrwmftgt = a:dir
        let s:netrwmarkfilelist_{bufnr("%")} = [filename]
        let s:netrwmftgt_islocal = 1

        " delegate
        call s:NetrwMarkFileCopy(1)

        " validate
        call assert_equalfile(file, newfile, "File copy in same dir failed")

        " tear down
        call delete(file)
        call delete(newfile)
        " wipe out the test buffer
        bw
        " reenable the guards
        let s:inputguards_disabled = 0
        let s:inputdefaults_disabled = 0
    else
        " Use feedkeys() to simulate user input (directory name)
        let s:inputguards_disabled = 1
        let s:inputdefaults_disabled = 1

        call writefile([$"NetrwMarkFileCopy test file"], file)

        call feedkeys($"\<Cmd>call Test_NetrwMarkFileCopy_SameDir('{a:dir}', 1)\<CR>{newfilename}\<CR>", "x")
    endif
endfunction


" Test file copy operations via s:NetrwMarkFileMove()
function Test_NetrwMarkFileMove(source_dir, target_dir, marked_files) abort
    " set up
    new
    let b:netrw_curdir= a:source_dir
    let s:netrwmftgt = a:target_dir
    let s:netrwmarkfilelist_{bufnr("%")} = a:marked_files
    let s:netrwmftgt_islocal = 1
    " delegate
    call s:NetrwMarkFileMove(1)
    " wipe out the test buffer
    bw
endfunction

" }}}
END

"make copy of netrw script and add function to print local variables"
func s:appendDebugToNetrw(netrw_path, netrw_test_path)

  " load the netrw script
  execute "split" a:netrw_test_path
  execute "read" a:netrw_path

  " replace input guards for convenient testing versions
  %substitute@call inputsave()@call s:test_inputsave()@g
  %substitute@call inputrestore()@call s:test_inputrestore()@g
  %substitute@\<input(@s:test_input(@g

  call cursor(1,1)
  let pos = search("Settings Restoration:")-1
  " insert the test functions before the end guard
  call assert_false(append(pos, s:testScript))

  " save the modified script content
  write
  bwipe!

endfunction

func SetUp()

  " prepare modified netrw script
  call s:appendDebugToNetrw(s:netrw_path, s:netrw_test_path)

  " source the modified script
  exe "source" s:netrw_test_path

  " Rig the package. The modified script guard prevents loading it again.
  let &runtimepath=s:runtimedir
  let &packpath=s:runtimedir
  packadd netrw

  " use proper path
  if has('win32')
    let $HOME = substitute($HOME, '/', '\\', 'g')
  endif

endfunction

func TearDown()
  " cleanup
  call delete(s:netrw_test_path)
endfunction

func SetShell(shell)
    " select different shells
    if a:shell == "default"
        set shell& shellcmdflag& shellxquote& shellpipe& shellredir&
    elseif a:shell == "powershell" " help dos-powershell
        " powershell desktop is windows only
        if !has("win32")
            throw 'Skipped: powershell desktop is missing'
        endif
        set shell=powershell shellcmdflag=-NoProfile\ -Command shellxquote=\"
        set shellpipe=2>&1\ \|\ Out-File\ -Encoding\ default shellredir=2>&1\ \|\ Out-File\ -Encoding\ default
    elseif a:shell == "pwsh" " help dos-powershell
        " powershell core works crossplatform
        if !executable("pwsh")
            throw 'Skipped: powershell core is missing'
        endif
        set shell=pwsh shellcmdflag=-NoProfile\ -c shellpipe=>%s\ 2>&1 shellredir=>%s\ 2>&1
        if has("win32")
            set shellxquote=\"
        else
            set shellxquote=
        endif
    else
        call assert_report("Trying to select an unknown shell")
    endif
endfunc

func s:combine
  \( usernames
  \, methods
  \, hosts
  \, ports
  \, dirs
  \, files)
  for username in a:usernames
    for method in a:methods
      for host in a:hosts
        for port in a:ports
          for dir in a:dirs
            for file in a:files
               " --- Build a full remote path ---

              let port_str = empty(port) ? "" : ':' . port
              let remote = printf('%s://%s@%s%s/%s%s', method, username, host, port_str, dir, file)

              let result = TestNetrwCaptureRemotePath(remote)

              call assert_equal(result.method, method)
              call assert_equal(result.user, username)
              call assert_equal(result.machine, host)
              call assert_equal(result.port, port)
              call assert_equal(result.path, dir . file)
            endfor
          endfor
        endfor
      endfor
    endfor
  endfor
endfunction


func Test_netrw_parse_remote_simple()
  let result = TestNetrwCaptureRemotePath('scp://user@localhost:2222/test.txt')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, 'user')
  call assert_equal(result.machine, 'localhost')
  call assert_equal(result.port, '2222')
  call assert_equal(result.path, 'test.txt')
endfunction

"testing different combinations"
func Test_netrw_parse_regular_usernames()

  " --- sample data for combinations ---"
  let usernames = ["root", "toor", "user01", "skillIssue"]
  let methods = ["scp", "ssh", "ftp", "sftp"]
  let hosts = ["localhost", "server.com", "fit-workspaces.ksi.fit.cvut.cz", "192.168.1.42"]
  let ports = ["", "22","420", "443", "2222", "1234"]
  let dirs = ["", "somefolder/", "path/to/the/bottom/of/the/world/please/send/help/"]
  let files = ["test.txt", "tttt.vim", "Makefile"]

  call s:combine(usernames, methods, hosts, ports, dirs, files)

endfunc

"Host myserver
"    HostName 192.168.1.42
"    User alice
func Test_netrw_parse_ssh_config_entries()
  let result = TestNetrwCaptureRemotePath('scp://myserver//etc/nginx/nginx.conf')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, '')
  call assert_equal(result.machine, 'myserver')
  call assert_equal(result.port, '')
  call assert_equal(result.path, '/etc/nginx/nginx.conf')
endfunction

"username containing special-chars"
func Test_netrw_parse_special_char_user()
  let result = TestNetrwCaptureRemotePath('scp://user-01@localhost:2222/test.txt')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, 'user-01')
  call assert_equal(result.machine, 'localhost')
  call assert_equal(result.port, '2222')
  call assert_equal(result.path, 'test.txt')
endfunction

func Test_netrw_wipe_empty_buffer_fastpath()
  " SetUp() may have opened some buffers
  let previous = bufnr('$')
  let g:netrw_fastbrowse=0
  call setline(1, 'foobar')
  let  bufnr = bufnr('%')
  tabnew
  Explore
  call search('README.txt', 'W')
  exe ":norm \<cr>"
  call assert_equal(previous + 2, bufnr('$'))
  call assert_true(bufexists(bufnr))
  bw

  unlet! netrw_fastbrowse
endfunction

" ---------------------------------
" Testing file management functions
" ---------------------------------

" Browser directory creation
func s:netrw_mkdir()

  " create a testdir in the fake $HOME
  call Test_NetrwMakeDir($HOME, "NetrwMakeDir")

  " Check the test directory was created
  let test_dir = netrw#fs#PathJoin($HOME, "NetrwMakeDir")
  call WaitForAssert({-> assert_true(
  \     isdirectory(test_dir),
  \     "Unable to create a dir via s:NetrwMakeDir()")
  \ })

  " remove the test directory
  call delete(test_dir, 'd')
endfunc

func Test_netrw_mkdir_default()
  call SetShell('default')
  call s:netrw_mkdir()
endfunc

func Test_netrw_mkdir_powershell()
  call SetShell('powershell')
  call s:netrw_mkdir()
endfunc

func Test_netrw_mkdir_pwsh()
  call SetShell('pwsh')
  call s:netrw_mkdir()
endfunc

func s:netrw_filecopy(count = 1)
  " setup
  let marked_files = []
  let source_dir = netrw#fs#PathJoin($HOME, "src")
  let target_dir = netrw#fs#PathJoin($HOME, "target")

  call mkdir(source_dir, "R")
  call mkdir(target_dir, "R")

  for i in range(a:count)
    call add(marked_files, $"testfile{i}.txt")
    call writefile(
    \   [$"NetrwMarkFileCopy test file {i}"],
    \   netrw#fs#PathJoin(source_dir, marked_files[-1]))
  endfor

  " delegate
  call Test_NetrwMarkFileCopy(source_dir, target_dir, marked_files)

  " verify
  for file in marked_files
    call assert_equalfile(
    \   netrw#fs#PathJoin(source_dir, file),
    \   netrw#fs#PathJoin(target_dir, file),
    \   "File copy failed for " . file)
  endfor
endfunc

" Browser file copy
func s:test_netrw_filecopy()

  " if shellslash is available, check both settings
  if exists('+shellslash')
    set shellslash&
    call s:netrw_filecopy(1)
    call s:netrw_filecopy(10)
    set shellslash!
  endif

  call s:netrw_filecopy(1)
  call s:netrw_filecopy(10)

endfunc

func Test_netrw_filecopy_default()
  call SetShell('default')
  call s:test_netrw_filecopy()
endfunc

func Test_netrw_filecopy_powershell()
  call SetShell('powershell')
  call s:test_netrw_filecopy()
endfunc

func Test_netrw_filecopy_pwsh()
  call SetShell('pwsh')
  call s:test_netrw_filecopy()
endfunc

" Browser recursive directory copy
func s:netrw_dircopy(count = 1)

  " setup
  let marked_dirname = "test_dir"
  let marked_dir = netrw#fs#PathJoin($HOME, marked_dirname)
  let target_dir = netrw#fs#PathJoin($HOME, "target")

  call mkdir(marked_dir, "R")
  call mkdir(target_dir, "R")

  let dir_content = []
  for i in range(a:count)
    call add(dir_content, $"testfile{i}.txt")
    call writefile(
    \   [$"NetrwMarkFileCopy test dir content {i}"],
    \   netrw#fs#PathJoin(marked_dir, dir_content[-1]))
  endfor

  " delegate
  call Test_NetrwMarkFileCopy($HOME, target_dir, [marked_dirname])

  " verify
  for file in dir_content
    call assert_equalfile(
    \   netrw#fs#PathJoin(marked_dir, file),
    \   netrw#fs#PathJoin(target_dir, marked_dirname, file),
    \   "File copy failed for " . file)
  endfor

endfunc

func s:test_netrw_dircopy()

  " if shellslash is available, check both settings
  if exists('+shellslash')
    set shellslash&
    call s:netrw_dircopy(10)
    set shellslash!
  endif

  call s:netrw_dircopy(10)

endfunc

func Test_netrw_dircopy_default()
  call SetShell('default')
  call s:test_netrw_dircopy()
endfunc

func Test_netrw_dircopy_powershell()
  call SetShell('powershell')
  call s:test_netrw_dircopy()
endfunc

func Test_netrw_dircopy_pwsh()
  call SetShell('pwsh')
  call s:test_netrw_dircopy()
endfunc

" Copy file into the same directory with a different name
func Test_netrw_dircopy_rename_default()
  call SetShell('default')
  call Test_NetrwMarkFileCopy_SameDir()
endfunc

func Test_netrw_dircopy_rename_powershell()
  call SetShell('powershell')
  call Test_NetrwMarkFileCopy_SameDir()
endfunc

func Test_netrw_dircopy_rename_pwsh()
  call SetShell('pwsh')
  call Test_NetrwMarkFileCopy_SameDir()
endfunc

" Browser file move
func s:netrw_filemove(count = 1)
  " setup
  let marked_files = []
  let source_dir = netrw#fs#PathJoin($HOME, "src")
  let target_dir = netrw#fs#PathJoin($HOME, "target")

  call mkdir(source_dir, "R")
  call mkdir(target_dir, "R")

  for i in range(a:count)
    call add(marked_files, $"testfile{i}.txt")
    call writefile(
    \   [$"NetrwMarkFileMove test file {i}"],
    \   netrw#fs#PathJoin(source_dir, marked_files[-1]))
  endfor

  " delegate
  call Test_NetrwMarkFileMove(source_dir, target_dir, marked_files)

  " verify
  for i in range(a:count)
    call assert_equal(
    \   [$"NetrwMarkFileMove test file {i}"],
    \   readfile(netrw#fs#PathJoin(target_dir, $"testfile{i}.txt")),
    \   $"File move failed for testfile{i}.txt")
  endfor
endfunc

func s:test_netrw_filemove()

  " if shellslash is available, check both settings
  if exists('+shellslash')
    set shellslash&
    call s:netrw_filemove(10)
    set shellslash!
  endif

  call s:netrw_filemove(10)

endfunc

func Test_netrw_filemove_default()
  call SetShell('default')
  call s:test_netrw_filemove()
endfunc

func Test_netrw_filemove_powershell()
  call SetShell('powershell')
  call s:test_netrw_filemove()
endfunc

func Test_netrw_filemove_pwsh()
  call SetShell('pwsh')
  call s:test_netrw_filemove()
endfunc

" vim:ts=8 sts=2 sw=2 et
