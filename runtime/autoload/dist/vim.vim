vim9script

# Vim runtime support library
#
# Maintainer:	The Vim Project <https://github.com/vim/vim>
# Last Change:	2023 Oct 25

export def IsSafeExecutable(filetype: string, executable: string): bool
  var cwd = getcwd()
  return get(g:, filetype .. '_exec', get(g:, 'plugin_exec', 0))
    && (fnamemodify(exepath(executable), ':p:h') !=# cwd
        || (split($PATH, has('win32') ? ';' : ':')->index(cwd) != -1
            && cwd != '.'))
enddef

# Uncomment this line to check for compilation errors early
# defcompile
