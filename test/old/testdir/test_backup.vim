" Tests for the backup function

source check.vim

func Test_backup()
  set backup backupdir=. backupskip=
  new
  call setline(1, ['line1', 'line2'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  let l = readfile('Xbackup.txt~')
  call assert_equal(['line1', 'line2'], l)
  bw!
  set backup&vim backupdir&vim backupskip&vim
  call delete('Xbackup.txt')
  call delete('Xbackup.txt~')
endfunc

func Test_backup_backupskip()
  set backup backupdir=. backupskip=*.txt
  new
  call setline(1, ['line1', 'line2'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  call assert_false(filereadable('Xbackup.txt~'))
  bw!
  set backup&vim backupdir&vim backupskip&vim
  call delete('Xbackup.txt')
  call delete('Xbackup.txt~')
endfunc

func Test_backup2()
  set backup backupdir=.// backupskip=
  new
  call setline(1, ['line1', 'line2', 'line3'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  sp *Xbackup.txt~
  call assert_equal(['line1', 'line2', 'line3'], getline(1,'$'))
  let f = expand('%')
  call assert_match('%testdir%Xbackup.txt\~', f)
  bw!
  bw!
  call delete('Xbackup.txt')
  call delete(f)
  set backup&vim backupdir&vim backupskip&vim
endfunc

func Test_backup2_backupcopy()
  set backup backupdir=.// backupcopy=yes backupskip=
  new
  call setline(1, ['line1', 'line2', 'line3'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  sp *Xbackup.txt~
  call assert_equal(['line1', 'line2', 'line3'], getline(1,'$'))
  let f = expand('%')
  call assert_match('%testdir%Xbackup.txt\~', f)
  bw!
  bw!
  call delete('Xbackup.txt')
  call delete(f)
  set backup&vim backupdir&vim backupcopy&vim backupskip&vim
endfunc

" Test for using a non-existing directory as a backup directory
func Test_non_existing_backupdir()
  throw 'Skipped: Nvim auto-creates backup directory'
  set backupdir=./non_existing_dir backupskip=
  call writefile(['line1'], 'Xbackupdir', 'D')
  new Xbackupdir
  call assert_fails('write', 'E510:')

  set backupdir&vim backupskip&vim
endfunc

" vim: shiftwidth=2 sts=2 expandtab
