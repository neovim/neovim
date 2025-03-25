local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local coding = require 'elisp.coding'
local M = {}

---@type vim.elisp.F
local F = {}
F.find_file_name_handler = {
  'find-file-name-handler',
  2,
  2,
  0,
  [[Return FILENAME's handler function for OPERATION, if it has one.
Otherwise, return nil.
A file name is handled if one of the regular expressions in
`file-name-handler-alist' matches it.

If OPERATION equals `inhibit-file-name-operation', then ignore
any handlers that are members of `inhibit-file-name-handlers',
but still do run any other handlers.  This lets handlers
use the standard functions without calling themselves recursively.]],
}
function F.find_file_name_handler.f(filename, operation)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return vars.Qnil
end
F.substitute_in_file_name = {
  'substitute-in-file-name',
  1,
  1,
  0,
  [[Substitute environment variables referred to in FILENAME.
`$FOO' where FOO is an environment variable name means to substitute
the value of that variable.  The variable name should be terminated
with a character not a letter, digit or underscore; otherwise, enclose
the entire variable name in braces.

If FOO is not defined in the environment, `$FOO' is left unchanged in
the value of this function.

If `/~' appears, all of FILENAME through that `/' is discarded.
If `//' appears, everything up to and including the first of
those `/' is discarded.]],
}
function F.substitute_in_file_name.f(filename)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return filename
end
F.expand_file_name = {
  'expand-file-name',
  1,
  2,
  0,
  [[Convert filename NAME to absolute, and canonicalize it.
Second arg DEFAULT-DIRECTORY is directory to start with if NAME is relative
\(does not start with slash or tilde); both the directory name and
a directory's file name are accepted.  If DEFAULT-DIRECTORY is nil or
missing, the current buffer's value of `default-directory' is used.
NAME should be a string that is a valid file name for the underlying
filesystem.

File name components that are `.' are removed, and so are file name
components followed by `..', along with the `..' itself; note that
these simplifications are done without checking the resulting file
names in the file system.

Multiple consecutive slashes are collapsed into a single slash, except
at the beginning of the file name when they are significant (e.g., UNC
file names on MS-Windows.)

An initial \"~\" in NAME expands to your home directory.

An initial \"~USER\" in NAME expands to USER's home directory.  If
USER doesn't exist, \"~USER\" is not expanded.

To do other file name substitutions, see `substitute-in-file-name'.

For technical reasons, this function can return correct but
non-intuitive results for the root directory; for instance,
\(expand-file-name ".." "/") returns "/..".  For this reason, use
\(directory-file-name (file-name-directory dirname)) to traverse a
filesystem tree, not (expand-file-name ".." dirname).  Note: make
sure DIRNAME in this example doesn't end in a slash, unless it's
the root directory.]],
}
function F.expand_file_name.f(name, default_directory)
  if _G.vim_elisp_later then
    error('TODO')
  end
  if not lisp.nilp(default_directory) then
    if not lisp.IS_DIRECTORY_SEP(lisp.sref(name, 0)) then
      local path = vim.fs.normalize(lisp.sdata(default_directory) .. '/' .. lisp.sdata(name))
      return alloc.make_specified_string(vim.fn.expand(path), -1, false)
    end
  end
  return alloc.make_specified_string(vim.fn.expand(lisp.sdata(name)), -1, false)
end
F.file_directory_p = {
  'file-directory-p',
  1,
  1,
  0,
  [[Return t if FILENAME names an existing directory.
Return nil if FILENAME does not name a directory, or if there
was trouble determining whether FILENAME is a directory.

As a special case, this function will also return t if FILENAME is the
empty string (\"\").  This quirk is due to Emacs interpreting the
empty string (in some cases) as the current directory.

Symbolic links to directories count as directories.
See `file-symlink-p' to distinguish symlinks.]],
}
function F.file_directory_p.f(filename)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return vim.fn.isdirectory(lisp.sdata(filename)) == 1 and vars.Qt or vars.Qnil
end
F.file_name_directory = {
  'file-name-directory',
  1,
  1,
  0,
  [[Return the directory component in file name FILENAME.
Return nil if FILENAME does not include a directory.
Otherwise return a directory name.
Given a Unix syntax file name, returns a string ending in slash.]],
}
function F.file_name_directory.f(filename)
  if _G.vim_elisp_later then
    error('TODO')
  end
  local dir = vim.fs.dirname(lisp.sdata(filename)) .. '/'
  return alloc.make_specified_string(dir, -1, lisp.string_multibyte(filename))
end
F.car_less_than_car =
  { 'car-less-than-car', 2, 2, 0, [[Return t if (car A) is numerically less than (car B).]] }
function F.car_less_than_car.f(a, b)
  return vars.F.lss { vars.F.car(a), vars.F.car(b) }
end
---@param filename string
---@return boolean
local function file_name_absolute_p(filename)
  if filename:sub(1, 1) == '~' then
    error('TODO')
  end
  return filename:sub(1, 1) == '/'
end
F.file_name_absolute_p = {
  'file-name-absolute-p',
  1,
  1,
  0,
  [[Return t if FILENAME is an absolute file name.
On Unix, absolute file names start with `/'.  In Emacs, an absolute
file name can also start with an initial `~' or `~USER' component,
where USER is a valid login name.]],
}
function F.file_name_absolute_p.f(filename)
  lisp.check_string(filename)
  return file_name_absolute_p(lisp.sdata(filename)) and vars.Qt or vars.Qnil
end
F.file_name_nondirectory = {
  'file-name-nondirectory',
  1,
  1,
  0,
  [[Return file name FILENAME sans its directory.
For example, in a Unix-syntax file name,
this is everything after the last slash,
or the entire name if it contains no slash.]],
}
function F.file_name_nondirectory.f(filename)
  lisp.check_string(filename)
  local handler = vars.F.find_file_name_handler(filename, vars.Qfile_name_nondirectory)
  if not lisp.nilp(handler) then
    error('TODO')
  end
  local p = lisp.sbytes(filename) - 1
  while p > 0 and not lisp.IS_DIRECTORY_SEP(lisp.sref(filename, p - 1)) do
    p = p - 1
  end
  return alloc.make_specified_string(
    lisp.sdata(filename):sub(p + 1),
    -1,
    lisp.string_multibyte(filename)
  )
end
---@param filename vim.elisp.obj
---@param operation vim.elisp.obj
---@param mode 'f'
---@return vim.elisp.obj
local function check_file_access(filename, operation, mode)
  local file = vars.F.expand_file_name(filename, vars.Qnil)
  local handler = vars.F.find_file_name_handler(file, operation)
  if not lisp.nilp(handler) then
    error('TODO')
  end
  local encoded_filename = lisp.sdata(coding.encode_file_name(file))
  if mode == 'f' then
    return vim.uv.fs_stat(encoded_filename) and vars.Qt or vars.Qnil
  else
    error('TODO')
  end
end
F.file_exists_p = {
  'file-exists-p',
  1,
  1,
  0,
  [[Return t if file FILENAME exists (whether or not you can read it).
Return nil if FILENAME does not exist, or if there was trouble
determining whether the file exists.
See also `file-readable-p' and `file-attributes'.
This returns nil for a symlink to a nonexistent file.
Use `file-symlink-p' to test for such links.]],
}
function F.file_exists_p.f(filename)
  return check_file_access(filename, vars.Qfile_exists_p, 'f')
end
F.directory_file_name = {
  'directory-file-name',
  1,
  1,
  0,
  [[Returns the file name of the directory named DIRECTORY.
This is the name of the file that holds the data for the directory DIRECTORY.
This operation exists because a directory is also a file, but its name as
a directory is different from its name as a file.
In Unix-syntax, this function just removes the final slash.]],
}
function F.directory_file_name.f(directory)
  lisp.check_string(directory)
  local handler = vars.F.find_file_name_handler(directory, vars.Qdirectory_file_name)
  if not lisp.nilp(handler) then
    error('TODO')
  end
  local name = lisp.sdata(directory)
  local out
  if name == '//' then
    out = '//'
  elseif name:match('^/+$') then
    out = '/'
  else
    out = name:gsub('/+$', '')
  end
  return alloc.make_specified_string(out, -1, lisp.string_multibyte(directory))
end

function M.init_syms()
  vars.defsubr(F, 'find_file_name_handler')
  vars.defsubr(F, 'substitute_in_file_name')
  vars.defsubr(F, 'expand_file_name')
  vars.defsubr(F, 'file_directory_p')
  vars.defsubr(F, 'file_name_directory')
  vars.defsubr(F, 'car_less_than_car')
  vars.defsubr(F, 'file_name_absolute_p')
  vars.defsubr(F, 'file_name_nondirectory')
  vars.defsubr(F, 'file_exists_p')
  vars.defsubr(F, 'directory_file_name')

  vars.defsym('Qfile_exists_p', 'file-exists-p')
  vars.defsym('Qdirectory_file_name', 'directory-file-name')
  vars.defsym('Qfile_name_nondirectory', 'file-name-nondirectory')

  vars.defvar_lisp(
    'file_name_handler_alist',
    'file-name-handler-alist',
    [[Alist of elements (REGEXP . HANDLER) for file names handled specially.
If a file name matches REGEXP, all I/O on that file is done by calling
HANDLER.  If a file name matches more than one handler, the handler
whose match starts last in the file name gets precedence.  The
function `find-file-name-handler' checks this list for a handler for
its argument.

HANDLER should be a function.  The first argument given to it is the
name of the I/O primitive to be handled; the remaining arguments are
the arguments that were passed to that primitive.  For example, if you
do (file-exists-p FILENAME) and FILENAME is handled by HANDLER, then
HANDLER is called like this:

  (funcall HANDLER \\='file-exists-p FILENAME)

Note that HANDLER must be able to handle all I/O primitives; if it has
nothing special to do for a primitive, it should reinvoke the
primitive to handle the operation \"the usual way\".
See Info node `(elisp)Magic File Names' for more details.]]
  )
  vars.V.file_name_handler_alist = vars.Qnil
end
return M
