let s:netrw_path =        $VIMRUNTIME . '/pack/dist/opt/netrw/autoload/netrw.vim'
let s:netrw_test_dir  =   'samples'
let s:netrw_test_path =   s:netrw_test_dir . '/netrw.vim'

"make copy of netrw script and add function to print local variables"
func s:appendDebugToNetrw(netrw_path, netrw_test_path)
  let netrwScript = readfile(a:netrw_path)

  let netrwScript += [
       \ '\n',
       \ '"-- test helpers ---"',
       \ 'function! TestNetrwCaptureRemotePath(dirname)',
       \ '  call s:RemotePathAnalysis(a:dirname)',
       \ '  return {"method": s:method, "user": s:user, "machine": s:machine, "port": s:port, "path": s:path, "fname": s:fname}',
       \ 'endfunction'
       \ ]

  call writefile(netrwScript, a:netrw_test_path)
  execute 'source' a:netrw_test_path
endfunction

func s:setup()
  call s:appendDebugToNetrw(s:netrw_path, s:netrw_test_path)
endfunction

func s:cleanup()
  call delete(s:netrw_test_path)
endfunction

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
  call s:setup()
  let result = TestNetrwCaptureRemotePath('scp://user@localhost:2222/test.txt')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, 'user')
  call assert_equal(result.machine, 'localhost')
  call assert_equal(result.port, '2222')
  call assert_equal(result.path, 'test.txt')
  call s:cleanup()
endfunction

"testing different combinations"
func Test_netrw_parse_regular_usernames()
  call s:setup()

  " --- sample data for combinations ---"
  let usernames = ["root", "toor", "user01", "skillIssue"]
  let methods = ["scp", "ssh", "ftp", "sftp"]
  let hosts = ["localhost", "server.com", "fit-workspaces.ksi.fit.cvut.cz", "192.168.1.42"]
  let ports = ["", "22","420", "443", "2222", "1234"]
  let dirs = ["", "somefolder/", "path/to/the/bottom/of/the/world/please/send/help/"]
  let files = ["test.txt", "tttt.vim", "Makefile"]

  call s:combine(usernames, methods, hosts, ports, dirs, files)

  call s:cleanup()
endfunc

"Host myserver
"    HostName 192.168.1.42
"    User alice
func Test_netrw_parse_ssh_config_entries()
  call s:setup()
  let result = TestNetrwCaptureRemotePath('scp://myserver//etc/nginx/nginx.conf')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, '')
  call assert_equal(result.machine, 'myserver')
  call assert_equal(result.port, '')
  call assert_equal(result.path, '/etc/nginx/nginx.conf')
  call s:cleanup()
endfunction

"username containing special-chars"
func Test_netrw_parse_special_char_user()
  call s:setup()
  let result = TestNetrwCaptureRemotePath('scp://user-01@localhost:2222/test.txt')
  call assert_equal(result.method, 'scp')
  call assert_equal(result.user, 'user-01')
  call assert_equal(result.machine, 'localhost')
  call assert_equal(result.port, '2222')
  call assert_equal(result.path, 'test.txt')
  call s:cleanup()
endfunction

func Test_netrw_wipe_empty_buffer_fastpath()
  let g:netrw_fastbrowse=0
  packadd netrw
  call setline(1, 'foobar')
  let  bufnr = bufnr('%')
  tabnew
  Explore
  call search('README.txt', 'W')
  exe ":norm \<cr>"
  call assert_equal(4, bufnr('$'))
  call assert_true(bufexists(bufnr))
  bw

  unlet! netrw_fastbrowse
endfunction
