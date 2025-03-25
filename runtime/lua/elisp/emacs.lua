local vars = require 'elisp.vars'
local lread = require 'elisp.lread'
local alloc = require 'elisp.alloc'
local M = {}
function M.init()
  if _G.vim_elisp_later then
    error('TODO: command-line-args how should it be initialized?')
    error('TODO: system-type should also be initialized')
  end

  vars.V.system_type = lread.intern_c_string('gnu/linux')

  vars.V.emacs_version = alloc.make_string('29.4')
end
function M.init_syms()
  vars.defsym('Qrisky_local_variable', 'risky-local-variable')
  vars.defsym('Qfile_name_handler_alist', 'file-name-handler-alist')

  vars.defvar_lisp('dump_mode', 'dump-mode', 'Non-nil when Emacs is dumping itself.')
  vars.V.dump_mode = vars.Qnil
  vars.defvar_lisp(
    'command_line_args',
    'command-line-args',
    [[Args passed by shell to Emacs, as a list of strings.
Many arguments are deleted from the list as they are processed.]]
  )
  vars.V.command_line_args = vars.Qnil

  vars.defvar_lisp(
    'system_type',
    'system-type',
    [[The value is a symbol indicating the type of operating system you are using.
Special values:
  `gnu'          compiled for a GNU Hurd system.
  `gnu/linux'    compiled for a GNU/Linux system.
  `gnu/kfreebsd' compiled for a GNU system with a FreeBSD kernel.
  `darwin'       compiled for Darwin (GNU-Darwin, macOS, ...).
  `ms-dos'       compiled as an MS-DOS application.
  `windows-nt'   compiled as a native W32 application.
  `cygwin'       compiled using the Cygwin library.
  `haiku'        compiled for a Haiku system.
Anything else (in Emacs 26, the possibilities are: aix, berkeley-unix,
hpux, usg-unix-v) indicates some sort of Unix system.]]
  )

  vars.defvar_lisp(
    'emacs_version',
    'emacs-version',
    [[Version numbers of this version of Emacs.
This has the form: MAJOR.MINOR[.MICRO], where MAJOR/MINOR/MICRO are integers.
MICRO is only present in unreleased development versions,
and is not especially meaningful.  Prior to Emacs 26.1, an extra final
component .BUILD is present.  This is now stored separately in
`emacs-build-number'.]]
  )

  vars.defvar_bool(
    'inhibit_x_resources',
    'inhibit-x-resources',
    [[If non-nil, X resources, Windows Registry settings, and NS defaults are not used.]]
  )
  vars.V.inhibit_x_resources = vars.Qnil

  vars.defvar_bool(
    'noninteractive',
    'noninteractive',
    [[Non-nil means Emacs is running without interactive terminal.]]
  )
  vars.V.noninteractive = vars.Qnil

  vars.defvar_lisp(
    'after_init_time',
    'after-init-time',
    [[Value of `current-time' after loading the init files.
This is nil during initialization.]]
  )
  vars.V.after_init_time = vars.Qnil

  vars.defvar_forward(
    'top_level',
    'top-level',
    [[Form to evaluate when Emacs starts up.
Useful to set before you dump a modified Emacs.]],
    function()
      return vars.Qnil
    end,
    function() end
  )
end
return M
