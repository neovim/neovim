" Tests for the backup function

func Test_backup()
  set backup backupdir=.
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
  set backup&vim backupdir&vim
  call delete('Xbackup.txt')
  call delete('Xbackup.txt~')
endfunc

func Test_backup2()
  set backup backupdir=.//
  new
  call setline(1, ['line1', 'line2', 'line3'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  sp *Xbackup.txt~
  call assert_equal(['line1', 'line2', 'line3'], getline(1,'$'))
  let f=expand('%')
  call assert_match('src%nvim%testdir%Xbackup.txt\~', f)
  bw!
  bw!
  call delete('Xbackup.txt')
  call delete(f)
  set backup&vim backupdir&vim
endfunc

func Test_backup2_backupcopy()
  set backup backupdir=.// backupcopy=yes
  new
  call setline(1, ['line1', 'line2', 'line3'])
  :f Xbackup.txt
  :w! Xbackup.txt
  " backup file is only created after
  " writing a second time (before overwriting)
  :w! Xbackup.txt
  sp *Xbackup.txt~
  call assert_equal(['line1', 'line2', 'line3'], getline(1,'$'))
  let f=expand('%')
  call assert_match('src%nvim%testdir%Xbackup.txt\~', f)
  bw!
  bw!
  call delete('Xbackup.txt')
  call delete(f)
  set backup&vim backupdir&vim backupcopy&vim
endfunc
