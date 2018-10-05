#!/usr/bin/env python
# vim: set fileencoding=utf-8
#
# Copyright (c) 2009 Google Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#    * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""Does neovim-lint on c files.

The goal of this script is to identify places in the code that *may*
be in non-compliance with neovim style.  It does not attempt to fix
up these problems -- the point is to educate.  It does also not
attempt to find all problems, or to ensure that everything it does
find is legitimately a problem.

In particular, we can get very confused by /* and // inside strings!
We do a small hack, which is to ignore //'s with "'s after them on the
same line, but it is far from perfect (in either direction).
"""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function
from __future__ import unicode_literals

import codecs
import copy
import fileinput
import getopt
import math  # for log
import os
import re
import sre_compile
import string
import sys
import unicodedata
import json
import collections  # for defaultdict


_USAGE = """
Syntax: clint.py [--verbose=#] [--output=vs7] [--filter=-x,+y,...]
                 [--counting=total|toplevel|detailed] [--root=subdir]
                 [--linelength=digits] [--record-errors=file]
                 [--suppress-errors=file] [--stdin-filename=filename]
        <file> [file] ...

  The style guidelines this tries to follow are those in
    http://neovim.io/development-wiki/style-guide/style-guide.xml

  Note: This is Google's cpplint.py modified for use with the Neovim project,
  which follows the Google C++ coding convention except with the following
  modifications:

   * Function names are lower_case.
   * Struct and enum names that are not typedef-ed are struct lower_case and
     enum lower_case.
   * The opening brace for functions appear on the next line.
   * All control structures must always use braces.

  Neovim is a C project. As a result, for .c and .h files, the following rules
  are suppressed:

   * [whitespace/braces] { should almost always be at the end of the previous
     line
   * [build/include] Include the directory when naming .h files
   * [runtime/int] Use int16/int64/etc, rather than the C type.

  Every problem is given a confidence score from 1-5, with 5 meaning we are
  certain of the problem, and 1 meaning it could be a legitimate construct.
  This will miss some errors, and is not a substitute for a code review.

  To suppress false-positive errors of a certain category, add a
  'NOLINT(category)' comment to the line.  NOLINT or NOLINT(*)
  suppresses errors of all categories on that line.

  The files passed in will be linted; at least one file must be provided.
  Default linted extensions are .cc, .cpp, .cu, .cuh and .h.  Change the
  extensions with the --extensions flag.

  Flags:

    output=vs7
      By default, the output is formatted to ease emacs parsing.  Visual Studio
      compatible output (vs7) may also be used.  Other formats are unsupported.

    verbose=#
      Specify a number 0-5 to restrict errors to certain verbosity levels.

    filter=-x,+y,...
      Specify a comma-separated list of category-filters to apply: only
      error messages whose category names pass the filters will be printed.
      (Category names are printed with the message and look like
      "[whitespace/indent]".)  Filters are evaluated left to right.
      "-FOO" and "FOO" means "do not print categories that start with FOO".
      "+FOO" means "do print categories that start with FOO".

      Examples: --filter=-whitespace,+whitespace/braces
                --filter=whitespace,runtime/printf,+runtime/printf_format
                --filter=-,+build/include_what_you_use

      To see a list of all the categories used in cpplint, pass no arg:
         --filter=

    counting=total|toplevel|detailed
      The total number of errors found is always printed. If
      'toplevel' is provided, then the count of errors in each of
      the top-level categories like 'build' and 'whitespace' will
      also be printed. If 'detailed' is provided, then a count
      is provided for each category.

    root=subdir
      The root directory used for deriving header guard CPP variable.
      By default, the header guard CPP variable is calculated as the relative
      path to the directory that contains .git, .hg, or .svn.  When this flag
      is specified, the relative path is calculated from the specified
      directory. If the specified directory does not exist, this flag is
      ignored.

      Examples:
        Assuing that src/.git exists, the header guard CPP variables for
        src/chrome/browser/ui/browser.h are:

        No flag => CHROME_BROWSER_UI_BROWSER_H_
        --root=chrome => BROWSER_UI_BROWSER_H_
        --root=chrome/browser => UI_BROWSER_H_

    linelength=digits
      This is the allowed line length for the project. The default value is
      80 characters.

      Examples:
        --linelength=120

    extensions=extension,extension,...
      The allowed file extensions that cpplint will check

      Examples:
        --extensions=hpp,cpp

    record-errors=file
      Record errors to the given location. This file may later be used for error
      suppression using suppress-errors flag.

    suppress-errors=file
      Errors listed in the given file will not be reported.

    stdin-filename=filename
      Use specified filename when reading from stdin (file "-").
"""

# We categorize each error message we print.  Here are the categories.
# We want an explicit list so we can list them all in cpplint --filter=.
# If you add a new error message with a new category, add it to the list
# here!  cpplint_unittest.py should tell you if you forget to do this.
_ERROR_CATEGORIES = [
    'build/deprecated',
    'build/endif_comment',
    'build/header_guard',
    'build/include',
    'build/include_alpha',
    'build/include_order',
    'build/printf_format',
    'build/storage_class',
    'build/useless_fattr',
    'readability/alt_tokens',
    'readability/bool',
    'readability/braces',
    'readability/fn_size',
    'readability/multiline_comment',
    'readability/multiline_string',
    'readability/nolint',
    'readability/nul',
    'readability/todo',
    'readability/utf8',
    'readability/increment',
    'runtime/arrays',
    'runtime/int',
    'runtime/invalid_increment',
    'runtime/memset',
    'runtime/printf',
    'runtime/printf_format',
    'runtime/threadsafe_fn',
    'runtime/deprecated',
    'syntax/parenthesis',
    'whitespace/alignment',
    'whitespace/blank_line',
    'whitespace/braces',
    'whitespace/comma',
    'whitespace/comments',
    'whitespace/empty_conditional_body',
    'whitespace/empty_loop_body',
    'whitespace/end_of_line',
    'whitespace/ending_newline',
    'whitespace/indent',
    'whitespace/line_length',
    'whitespace/newline',
    'whitespace/operators',
    'whitespace/parens',
    'whitespace/semicolon',
    'whitespace/tab',
    'whitespace/todo',
    'whitespace/line_continuation',
    'whitespace/cast',
]

# The default state of the category filter. This is overrided by the --filter=
# flag. By default all errors are on, so only add here categories that should be
# off by default (i.e., categories that must be enabled by the --filter= flags).
# All entries here should start with a '-' or '+', as in the --filter= flag.
_DEFAULT_FILTERS = ['-build/include_alpha']

# We used to check for high-bit characters, but after much discussion we
# decided those were OK, as long as they were in UTF-8 and didn't represent
# hard-coded international strings, which belong in a separate i18n file.

# Alternative tokens and their replacements.  For full list, see section 2.5
# Alternative tokens [lex.digraph] in the C++ standard.
#
# Digraphs (such as '%:') are not included here since it's a mess to
# match those on a word boundary.
_ALT_TOKEN_REPLACEMENT = {
    'and': '&&',
    'bitor': '|',
    'or': '||',
    'xor': '^',
    'compl': '~',
    'bitand': '&',
    'and_eq': '&=',
    'or_eq': '|=',
    'xor_eq': '^=',
    'not': '!',
    'not_eq': '!='
}

# Compile regular expression that matches all the above keywords.  The "[ =()]"
# bit is meant to avoid matching these keywords outside of boolean expressions.
#
# False positives include C-style multi-line comments and multi-line strings
# but those have always been troublesome for cpplint.
_ALT_TOKEN_REPLACEMENT_PATTERN = re.compile(
    r'[ =()](' + ('|'.join(_ALT_TOKEN_REPLACEMENT.keys())) + r')(?=[ (]|$)')


# These constants define types of headers for use with
# _IncludeState.CheckNextIncludeOrder().
_C_SYS_HEADER = 1
_OTHER_HEADER = 5

# These constants define the current inline assembly state
_NO_ASM = 0       # Outside of inline assembly block
_INSIDE_ASM = 1   # Inside inline assembly block
_END_ASM = 2      # Last line of inline assembly block
_BLOCK_ASM = 3    # The whole block is an inline assembly block

# Match start of assembly blocks
_MATCH_ASM = re.compile(r'^\s*(?:asm|_asm|__asm|__asm__)'
                        r'(?:\s+(volatile|__volatile__))?'
                        r'\s*[{(]')


_regexp_compile_cache = {}

# Finds occurrences of NOLINT or NOLINT(...).
_RE_SUPPRESSION = re.compile(r'\bNOLINT\b(\([^)]*\))?')

# {str, set(int)}: a map from error categories to sets of linenumbers
# on which those errors are expected and should be suppressed.
_error_suppressions = {}

# {(str, int)}: a set of error categories and line numbers which are expected to
# be suppressed
_error_suppressions_2 = set()

# The allowed line length of files.
# This is set by --linelength flag.
_line_length = 80

# The allowed extensions for file names
# This is set by --extensions flag.
_valid_extensions = set(['c', 'h'])


def ParseNolintSuppressions(filename, raw_line, linenum, error):
    """Updates the global list of error-suppressions.

    Parses any NOLINT comments on the current line, updating the global
    error_suppressions store.  Reports an error if the NOLINT comment
    was malformed.

    Args:
      filename: str, the name of the input file.
      raw_line: str, the line of input text, with comments.
      linenum: int, the number of the current line.
      error: function, an error handler.
    """
    # FIXME(adonovan): "NOLINT(" is misparsed as NOLINT(*).
    matched = _RE_SUPPRESSION.search(raw_line)
    if matched:
        category = matched.group(1)
        if category in (None, '(*)'):  # => "suppress all"
            _error_suppressions.setdefault(None, set()).add(linenum)
        else:
            if category.startswith('(') and category.endswith(')'):
                category = category[1:-1]
                if category in _ERROR_CATEGORIES:
                    _error_suppressions.setdefault(
                        category, set()).add(linenum)
                else:
                    error(filename, linenum, 'readability/nolint', 5,
                          'Unknown NOLINT error category: %s' % category)


def ParseKnownErrorSuppressions(filename, raw_lines, linenum):
    """Updates the global list of error-suppressions from suppress-file.

    Args:
      filename: str, the name of the input file.
      raw_lines: list, all file lines
      linenum: int, the number of the current line.
    """
    key = tuple(raw_lines[linenum - 1 if linenum else 0:linenum + 2])
    if key in _cpplint_state.suppressed_errors[filename]:
        for category in _cpplint_state.suppressed_errors[filename][key]:
            _error_suppressions_2.add((category, linenum))


def ResetNolintSuppressions():
    "Resets the set of NOLINT suppressions to empty."
    _error_suppressions.clear()


def ResetKnownErrorSuppressions():
    "Resets the set of suppress-errors=file suppressions to empty."
    _error_suppressions_2.clear()


def IsErrorSuppressedByNolint(category, linenum):
    """Returns true if the specified error category is suppressed on this line.

    Consults the global error_suppressions map populated by
    ParseNolintSuppressions/ResetNolintSuppressions.

    Args:
      category: str, the category of the error.
      linenum: int, the current line number.
    Returns:
      bool, True iff the error should be suppressed due to a NOLINT comment.
    """
    return (linenum in _error_suppressions.get(category, set()) or
            linenum in _error_suppressions.get(None, set()))


def IsErrorInSuppressedErrorsList(category, linenum):
    """Returns true if the specified error is suppressed by suppress-errors=file

    Args:
      category: str, the category of the error.
      linenum: int, the current line number.
    Returns:
      bool, True iff the error should be suppressed due to presense in
            suppressions file.
    """
    return (category, linenum) in _error_suppressions_2


def Match(pattern, s):
    """Matches the string with the pattern, caching the compiled regexp."""
    # The regexp compilation caching is inlined in both Match and Search for
    # performance reasons; factoring it out into a separate function turns out
    # to be noticeably expensive.
    if pattern not in _regexp_compile_cache:
        _regexp_compile_cache[pattern] = sre_compile.compile(pattern)
    return _regexp_compile_cache[pattern].match(s)


def Search(pattern, s):
    """Searches the string for the pattern, caching the compiled regexp."""
    if pattern not in _regexp_compile_cache:
        _regexp_compile_cache[pattern] = sre_compile.compile(pattern)
    return _regexp_compile_cache[pattern].search(s)


class _IncludeState(dict):

    """Tracks line numbers for includes, and the order in which includes appear.

    As a dict, an _IncludeState object serves as a mapping between include
    filename and line number on which that file was included.

    Call CheckNextIncludeOrder() once for each header in the file, passing
    in the type constants defined above.

    """
    # self._section will move monotonically through this set. If it ever
    # needs to move backwards, CheckNextIncludeOrder will raise an error.
    _INITIAL_SECTION = 0
    _C_SECTION = 2
    _OTHER_H_SECTION = 4

    _TYPE_NAMES = {
        _C_SYS_HEADER: 'C system header',
        _OTHER_HEADER: 'other header',
    }
    _SECTION_NAMES = {
        _INITIAL_SECTION: "... nothing. (This can't be an error.)",
        _C_SECTION: 'C system header',
        _OTHER_H_SECTION: 'other header',
    }

    def __init__(self):
        dict.__init__(self)
        self.ResetSection()

    def ResetSection(self):
        # The name of the current section.
        self._section = self._INITIAL_SECTION
        # The path of last found header.
        self._last_header = ''

    def SetLastHeader(self, header_path):
        self._last_header = header_path

    def CanonicalizeAlphabeticalOrder(self, header_path):
        """Returns a path canonicalized for alphabetical comparison.

        - replaces "-" with "_" so they both cmp the same.
        - lowercase everything, just in case.

        Args:
          header_path: Path to be canonicalized.

        Returns:
          Canonicalized path.
        """
        return header_path.replace('-', '_').lower()

    def CheckNextIncludeOrder(self, header_type):
        """Returns a non-empty error message if the next header is out of order.

        This function also updates the internal state to be ready to check
        the next include.

        Args:
          header_type: One of the _XXX_HEADER constants defined above.

        Returns:
          The empty string if the header is in the right order, or an
          error message describing what's wrong.

        """
        error_message = ('Found %s after %s' %
                         (self._TYPE_NAMES[header_type],
                          self._SECTION_NAMES[self._section]))

        last_section = self._section

        if header_type == _C_SYS_HEADER:
            if self._section <= self._C_SECTION:
                self._section = self._C_SECTION
            else:
                self._last_header = ''
                return error_message
        else:
            assert header_type == _OTHER_HEADER
            self._section = self._OTHER_H_SECTION

        if last_section != self._section:
            self._last_header = ''

        return ''


class _CppLintState(object):

    """Maintains module-wide state.."""

    def __init__(self):
        self.verbose_level = 1  # global setting.
        self.error_count = 0    # global count of reported errors
        # filters to apply when emitting error messages
        self.filters = _DEFAULT_FILTERS[:]
        self.counting = 'total'  # In what way are we counting errors?
        self.errors_by_category = {}  # string to int dict storing error counts

        # output format:
        # "emacs" - format that emacs can parse (default)
        # "vs7" - format that Microsoft Visual Studio 7 can parse
        self.output_format = 'emacs'

        self.record_errors_file = None
        self.suppressed_errors = collections.defaultdict(
            lambda: collections.defaultdict(set))

    def SetOutputFormat(self, output_format):
        """Sets the output format for errors."""
        self.output_format = output_format

    def SetVerboseLevel(self, level):
        """Sets the module's verbosity, and returns the previous setting."""
        last_verbose_level = self.verbose_level
        self.verbose_level = level
        return last_verbose_level

    def SetCountingStyle(self, counting_style):
        """Sets the module's counting options."""
        self.counting = counting_style

    def SetFilters(self, filters):
        """Sets the error-message filters.

        These filters are applied when deciding whether to emit a given
        error message.

        Args:
          filters: A string of comma-separated filters.
                   E.g. "+whitespace/indent".
                   Each filter should start with + or -; else we die.

        Raises:
          ValueError: The comma-separated filters did not all start with
                      '+' or '-'.
                      E.g. "-,+whitespace,-whitespace/indent,whitespace/bad"
        """
        # Default filters always have less priority than the flag ones.
        self.filters = _DEFAULT_FILTERS[:]
        for filt in filters.split(','):
            clean_filt = filt.strip()
            if clean_filt:
                self.filters.append(clean_filt)
        for filt in self.filters:
            if not (filt.startswith('+') or filt.startswith('-')):
                raise ValueError('Every filter in --filters must start with '
                                 '+ or - (%s does not)' % filt)

    def ResetErrorCounts(self):
        """Sets the module's error statistic back to zero."""
        self.error_count = 0
        self.errors_by_category = {}

    def IncrementErrorCount(self, category):
        """Bumps the module's error statistic."""
        self.error_count += 1
        if self.counting in ('toplevel', 'detailed'):
            if self.counting != 'detailed':
                category = category.split('/')[0]
            if category not in self.errors_by_category:
                self.errors_by_category[category] = 0
            self.errors_by_category[category] += 1

    def PrintErrorCounts(self):
        """Print a summary of errors by category, and the total."""
        for category, count in self.errors_by_category.items():
            sys.stdout.write('Category \'%s\' errors found: %d\n' %
                             (category, count))
        if self.error_count:
            sys.stdout.write('Total errors found: %d\n' % self.error_count)

    def SuppressErrorsFrom(self, fname):
        """Open file and read a list of suppressed errors from it"""
        if fname is None:
            return
        try:
            with open(fname) as fp:
                for line in fp:
                    fname, lines, category = json.loads(line)
                    lines = tuple(lines)
                    self.suppressed_errors[fname][lines].add(category)
        except IOError:
            pass

    def RecordErrorsTo(self, fname):
        """Open file with suppressed errors for writing"""
        if fname is None:
            return
        self.record_errors_file = open(fname, 'w')

_cpplint_state = _CppLintState()


def _OutputFormat():
    """Gets the module's output format."""
    return _cpplint_state.output_format


def _SetOutputFormat(output_format):
    """Sets the module's output format."""
    _cpplint_state.SetOutputFormat(output_format)


def _VerboseLevel():
    """Returns the module's verbosity setting."""
    return _cpplint_state.verbose_level


def _SetVerboseLevel(level):
    """Sets the module's verbosity, and returns the previous setting."""
    return _cpplint_state.SetVerboseLevel(level)


def _SetCountingStyle(level):
    """Sets the module's counting options."""
    _cpplint_state.SetCountingStyle(level)


def _SuppressErrorsFrom(fname):
    """Sets the file containing suppressed errors."""
    _cpplint_state.SuppressErrorsFrom(fname)


def _RecordErrorsTo(fname):
    """Sets the file containing suppressed errors to write to."""
    _cpplint_state.RecordErrorsTo(fname)


def _Filters():
    """Returns the module's list of output filters, as a list."""
    return _cpplint_state.filters


def _SetFilters(filters):
    """Sets the module's error-message filters.

    These filters are applied when deciding whether to emit a given
    error message.

    Args:
      filters: A string of comma-separated filters (eg "whitespace/indent").
               Each filter should start with + or -; else we die.
    """
    _cpplint_state.SetFilters(filters)


class _FunctionState(object):

    """Tracks current function name and the number of lines in its body."""

    _NORMAL_TRIGGER = 250  # for --v=0, 500 for --v=1, etc.
    _TEST_TRIGGER = 400    # about 50% more than _NORMAL_TRIGGER.

    def __init__(self):
        self.in_a_function = False
        self.lines_in_function = 0
        self.current_function = ''

    def Begin(self, function_name):
        """Start analyzing function body.

        Args:
          function_name: The name of the function being tracked.
        """
        self.in_a_function = True
        self.lines_in_function = 0
        self.current_function = function_name

    def Count(self):
        """Count line in current function body."""
        if self.in_a_function:
            self.lines_in_function += 1

    def Check(self, error, filename, linenum):
        """Report if too many lines in function body.

        Args:
          error: The function to call with any errors found.
          filename: The name of the current file.
          linenum: The number of the line to check.
        """
        if Match(r'T(EST|est)', self.current_function):
            base_trigger = self._TEST_TRIGGER
        else:
            base_trigger = self._NORMAL_TRIGGER
        trigger = base_trigger * 2**_VerboseLevel()

        if self.lines_in_function > trigger:
            error_level = int(
                math.log(self.lines_in_function / base_trigger, 2))
            # 50 => 0, 100 => 1, 200 => 2, 400 => 3, 800 => 4, 1600 => 5, ...
            if error_level > 5:
                error_level = 5
            error(filename, linenum, 'readability/fn_size', error_level,
                  'Small and focused functions are preferred:'
                  ' %s has %d non-comment lines'
                  ' (error triggered by exceeding %d lines).' % (
                      self.current_function, self.lines_in_function, trigger))

    def End(self):
        """Stop analyzing function body."""
        self.in_a_function = False


class FileInfo:

    """Provides utility functions for filenames.

    FileInfo provides easy access to the components of a file's path
    relative to the project root.
    """

    def __init__(self, filename):
        self._filename = filename

    def FullName(self):
        """Make Windows paths like Unix."""
        return os.path.abspath(self._filename).replace('\\', '/')

    def RelativePath(self):
        """FullName with <prefix>/src/nvim/ chopped off."""
        fullname = self.FullName()

        if os.path.exists(fullname):
            project_dir = os.path.dirname(fullname)

            root_dir = os.path.dirname(fullname)
            while (root_dir != os.path.dirname(root_dir) and
                   not os.path.exists(os.path.join(root_dir, ".git"))):
                root_dir = os.path.dirname(root_dir)

            if os.path.exists(os.path.join(root_dir, ".git")):
                root_dir = os.path.join(root_dir, "src", "nvim")
                prefix = os.path.commonprefix([root_dir, project_dir])
                return fullname[len(prefix) + 1:]

        # Don't know what to do; header guard warnings may be wrong...
        return fullname

    def Split(self):
        """Splits the file into the directory, basename, and extension.

        For 'chrome/browser/browser.cc', Split() would
        return ('chrome/browser', 'browser', '.cc')

        Returns:
          A tuple of (directory, basename, extension).
        """

        googlename = self.RelativePath()
        project, rest = os.path.split(googlename)
        return (project,) + os.path.splitext(rest)

    def BaseName(self):
        """File base name - text after the final slash, before final period."""
        return self.Split()[1]

    def Extension(self):
        """File extension - text following the final period."""
        return self.Split()[2]


def _ShouldPrintError(category, confidence, linenum):
    """If confidence >= verbose, category passes filter and isn't suppressed."""

    # There are three ways we might decide not to print an error message:
    # a "NOLINT(category)" comment appears in the source,
    # the verbosity level isn't high enough, or the filters filter it out.
    if IsErrorSuppressedByNolint(category, linenum):
        return False
    if IsErrorInSuppressedErrorsList(category, linenum):
        return False
    if confidence < _cpplint_state.verbose_level:
        return False

    is_filtered = False
    for one_filter in _Filters():
        if one_filter.startswith('-'):
            if category.startswith(one_filter[1:]):
                is_filtered = True
        elif one_filter.startswith('+'):
            if category.startswith(one_filter[1:]):
                is_filtered = False
        else:
            assert False  # should have been checked for in SetFilter.
    if is_filtered:
        return False

    return True


def Error(filename, linenum, category, confidence, message):
    """Logs the fact we've found a lint error.

    We log where the error was found, and also our confidence in the error,
    that is, how certain we are this is a legitimate style regression, and
    not a misidentification or a use that's sometimes justified.

    False positives can be suppressed by the use of
    "cpplint(category)"  comments on the offending line.  These are
    parsed into _error_suppressions.

    Args:
      filename: The name of the file containing the error.
      linenum: The number of the line containing the error.
      category: A string used to describe the "category" this bug
        falls under: "whitespace", say, or "runtime".  Categories
        may have a hierarchy separated by slashes: "whitespace/indent".
      confidence: A number from 1-5 representing a confidence score for
        the error, with 5 meaning that we are certain of the problem,
        and 1 meaning that it could be a legitimate construct.
      message: The error message.
    """
    if _ShouldPrintError(category, confidence, linenum):
        _cpplint_state.IncrementErrorCount(category)
        if _cpplint_state.output_format == 'vs7':
            sys.stdout.write('%s(%s):  %s  [%s] [%d]\n' % (
                filename, linenum, message, category, confidence))
        elif _cpplint_state.output_format == 'eclipse':
            sys.stdout.write('%s:%s: warning: %s  [%s] [%d]\n' % (
                filename, linenum, message, category, confidence))
        else:
            sys.stdout.write('%s:%s:  %s  [%s] [%d]\n' % (
                filename, linenum, message, category, confidence))


# Matches standard C++ escape sequences per 2.13.2.3 of the C++ standard.
_RE_PATTERN_CLEANSE_LINE_ESCAPES = re.compile(
    r'\\([abfnrtv?"\\\']|\d+|x[0-9a-fA-F]+)')
# Matches strings.  Escape codes should already be removed by ESCAPES.
_RE_PATTERN_CLEANSE_LINE_DOUBLE_QUOTES = re.compile(r'"([^"]*)"')
# Matches characters.  Escape codes should already be removed by ESCAPES.
_RE_PATTERN_CLEANSE_LINE_SINGLE_QUOTES = re.compile(r"'(.)'")
# Matches multi-line C++ comments.
# This RE is a little bit more complicated than one might expect, because we
# have to take care of space removals tools so we can handle comments inside
# statements better.
# The current rule is: We only clear spaces from both sides when we're at the
# end of the line. Otherwise, we try to remove spaces from the right side,
# if this doesn't work we try on left side but only if there's a non-character
# on the right.
_RE_PATTERN_CLEANSE_LINE_C_COMMENTS = re.compile(
    r"""(\s*/\*.*\*/\s*$|
            /\*.*\*/\s+|
         \s+/\*.*\*/(?=\W)|
            /\*.*\*/)""", re.VERBOSE)


def IsCppString(line):
    """Does line terminate so, that the next symbol is in string constant.

    This function does not consider single-line nor multi-line comments.

    Args:
      line: is a partial line of code starting from the 0..n.

    Returns:
      True, if next character appended to 'line' is inside a
      string constant.
    """

    line = line.replace(r'\\', 'XX')  # after this, \\" does not match to \"
    return ((line.count('"') - line.count(r'\"') - line.count("'\"'")) & 1) == 1


def FindNextMultiLineCommentStart(lines, lineix):
    """Find the beginning marker for a multiline comment."""
    while lineix < len(lines):
        if lines[lineix].strip().startswith('/*'):
            # Only return this marker if the comment goes beyond this line
            if lines[lineix].strip().find('*/', 2) < 0:
                return lineix
        lineix += 1
    return len(lines)


def FindNextMultiLineCommentEnd(lines, lineix):
    """We are inside a comment, find the end marker."""
    while lineix < len(lines):
        if lines[lineix].strip().endswith('*/'):
            return lineix
        lineix += 1
    return len(lines)


def RemoveMultiLineCommentsFromRange(lines, begin, end):
    """Clears a range of lines for multi-line comments."""
    # Having // dummy comments makes the lines non-empty, so we will not get
    # unnecessary blank line warnings later in the code.
    for i in range(begin, end):
        lines[i] = '// dummy'


def RemoveMultiLineComments(filename, lines, error):
    """Removes multiline (c-style) comments from lines."""
    lineix = 0
    while lineix < len(lines):
        lineix_begin = FindNextMultiLineCommentStart(lines, lineix)
        if lineix_begin >= len(lines):
            return
        lineix_end = FindNextMultiLineCommentEnd(lines, lineix_begin)
        if lineix_end >= len(lines):
            error(filename, lineix_begin + 1, 'readability/multiline_comment',
                  5, 'Could not find end of multi-line comment')
            return
        RemoveMultiLineCommentsFromRange(lines, lineix_begin, lineix_end + 1)
        lineix = lineix_end + 1


def CleanseComments(line):
    """Removes //-comments and single-line C-style /* */ comments.

    Args:
      line: A line of C++ source.

    Returns:
      The line with single-line comments removed.
    """
    commentpos = line.find('//')
    if commentpos != -1 and not IsCppString(line[:commentpos]):
        line = line[:commentpos].rstrip()
    # get rid of /* ... */
    return _RE_PATTERN_CLEANSE_LINE_C_COMMENTS.sub('', line)


class CleansedLines(object):

    """Holds 5 copies of all lines with different preprocessing applied to them.

    1) elided member contains lines without strings and comments,
    2) lines member contains lines without comments, and
    3) raw_lines member contains all the lines with multiline comments replaced.
    4) init_lines member contains all the lines without processing.
    5) elided_with_space_strings is like elided, but with string literals
       looking like `"   "`.
    All these three members are of <type 'list'>, and of the same length.
    """

    def __init__(self, lines, init_lines):
        self.elided = []
        self.lines = []
        self.raw_lines = lines
        self.num_lines = len(lines)
        self.init_lines = init_lines
        self.lines_without_raw_strings = lines
        self.elided_with_space_strings = []
        for linenum in range(len(self.lines_without_raw_strings)):
            self.lines.append(CleanseComments(
                self.lines_without_raw_strings[linenum]))
            elided = self._CollapseStrings(
                self.lines_without_raw_strings[linenum])
            self.elided.append(CleanseComments(elided))
            elided = CleanseComments(self._CollapseStrings(
                self.lines_without_raw_strings[linenum], True))
            self.elided_with_space_strings.append(elided)

    def NumLines(self):
        """Returns the number of lines represented."""
        return self.num_lines

    @staticmethod
    def _CollapseStrings(elided, keep_spaces=False):
        """Collapses strings and chars on a line to simple "" or '' blocks.

        We nix strings first so we're not fooled by text like '"http://"'

        Args:
          elided: The line being processed.
          keep_spaces: If true, collapse to

        Returns:
          The line with collapsed strings.
        """
        if not _RE_PATTERN_INCLUDE.match(elided):
            # Remove escaped characters first to make quote/single quote
            # collapsing basic.  Things that look like escaped characters
            # shouldn't occur outside of strings and chars.
            elided = _RE_PATTERN_CLEANSE_LINE_ESCAPES.sub(
                '' if not keep_spaces else lambda m: ' ' * len(m.group(0)),
                elided)
            elided = _RE_PATTERN_CLEANSE_LINE_SINGLE_QUOTES.sub(
                "''" if not keep_spaces
                else lambda m: "'" + (' ' * len(m.group(1))) + "'",
                elided)
            elided = _RE_PATTERN_CLEANSE_LINE_DOUBLE_QUOTES.sub(
                '""' if not keep_spaces
                else lambda m: '"' + (' ' * len(m.group(1))) + '"',
                elided)
        return elided


BRACES = {
    '(': ')',
    '{': '}',
    '[': ']',
    # '<': '>',  C++-specific pair removed
}


CLOSING_BRACES = dict(((v, k) for k, v in BRACES.items()))


def GetExprBracesPosition(clean_lines, linenum, pos):
    """List positions of all kinds of braces

    If input points to ( or { or [ then function proceeds until finding the
    position which closes it.

    Args:
      clean_lines: A CleansedLines instance containing the file.
      linenum: Current line number.
      pos: A position on the line.

    Yields:
      A tuple (linenum, pos, brace, depth) that points to each brace.
      Additionally each new line (linenum, pos, 's', depth) is yielded, for each
      line end (linenum, pos, 'e', depth) is yielded and at the very end it
      yields (linenum, pos, None, None).
    """
    depth = 0
    yielded_line_start = True
    startpos = pos
    while linenum < clean_lines.NumLines() - 1:
        line = clean_lines.elided_with_space_strings[linenum]
        if not line.startswith('#') or yielded_line_start:
            # Ignore #ifdefs, but not if it is macros that are checked
            for i, brace in enumerate(line[startpos:]):
                pos = i + startpos
                if brace != ' ' and not yielded_line_start:
                    yield (linenum, pos, 's', depth)
                    yielded_line_start = True
                if brace in BRACES:
                    depth += 1
                    yield (linenum, pos, brace, depth)
                elif brace in CLOSING_BRACES:
                    yield (linenum, pos, brace, depth)
                    depth -= 1
                if depth == 0:
                    yield (linenum, pos, None, None)
                    return
            yield (linenum, len(line) - 1, 'e', depth)
        yielded_line_start = False
        startpos = 0
        linenum += 1


def FindEndOfExpressionInLine(line, startpos, depth, startchar, endchar):
    """Find the position just after the matching endchar.

    Args:
      line: a CleansedLines line.
      startpos: start searching at this position.
      depth: nesting level at startpos.
      startchar: expression opening character.
      endchar: expression closing character.

    Returns:
      On finding matching endchar: (index just after matching endchar, 0)
      Otherwise: (-1, new depth at end of this line)
    """
    for i in range(startpos, len(line)):
        if line[i] == startchar:
            depth += 1
        elif line[i] == endchar:
            depth -= 1
            if depth == 0:
                return (i + 1, 0)
    return (-1, depth)


def CloseExpression(clean_lines, linenum, pos):
    """If input points to ( or { or [, finds the position that closes it.

    If lines[linenum][pos] points to a '(' or '{' or '[', finds the
    linenum/pos that correspond to the closing of the expression.

    Args:
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      pos: A position on the line.

    Returns:
      A tuple (line, linenum, pos) pointer *past* the closing brace, or
      (line, len(lines), -1) if we never find a close.  Note we ignore
      strings and comments when matching; and the line we return is the
      'cleansed' line at linenum.
    """

    line = clean_lines.elided[linenum]
    startchar = line[pos]
    if startchar not in BRACES:
        return (line, clean_lines.NumLines(), -1)
    endchar = BRACES[startchar]

    # Check first line
    (end_pos, num_open) = FindEndOfExpressionInLine(
        line, pos, 0, startchar, endchar)
    if end_pos > -1:
        return (line, linenum, end_pos)

    # Continue scanning forward
    while linenum < clean_lines.NumLines() - 1:
        linenum += 1
        line = clean_lines.elided[linenum]
        (end_pos, num_open) = FindEndOfExpressionInLine(
            line, 0, num_open, startchar, endchar)
        if end_pos > -1:
            return (line, linenum, end_pos)

    # Did not find endchar before end of file, give up
    return (line, clean_lines.NumLines(), -1)


def FindStartOfExpressionInLine(line, endpos, depth, startchar, endchar):
    """Find position at the matching startchar.

    This is almost the reverse of FindEndOfExpressionInLine, but note
    that the input position and returned position differs by 1.

    Args:
      line: a CleansedLines line.
      endpos: start searching at this position.
      depth: nesting level at endpos.
      startchar: expression opening character.
      endchar: expression closing character.

    Returns:
      On finding matching startchar: (index at matching startchar, 0)
      Otherwise: (-1, new depth at beginning of this line)
    """
    for i in range(endpos, -1, -1):
        if line[i] == endchar:
            depth += 1
        elif line[i] == startchar:
            depth -= 1
            if depth == 0:
                return (i, 0)
    return (-1, depth)


def ReverseCloseExpression(clean_lines, linenum, pos):
    """If input points to ) or } or ] or >, finds the position that opens it.

    If lines[linenum][pos] points to a ')' or '}' or ']' or '>', finds the
    linenum/pos that correspond to the opening of the expression.

    Args:
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      pos: A position on the line.

    Returns:
      A tuple (line, linenum, pos) pointer *at* the opening brace, or
      (line, 0, -1) if we never find the matching opening brace.  Note
      we ignore strings and comments when matching; and the line we
      return is the 'cleansed' line at linenum.
    """
    line = clean_lines.elided[linenum]
    endchar = line[pos]
    if endchar not in ')}]>':
        return (line, 0, -1)
    if endchar == ')':
        startchar = '('
    if endchar == ']':
        startchar = '['
    if endchar == '}':
        startchar = '{'
    if endchar == '>':
        startchar = '<'

    # Check last line
    (start_pos, num_open) = FindStartOfExpressionInLine(
        line, pos, 0, startchar, endchar)
    if start_pos > -1:
        return (line, linenum, start_pos)

    # Continue scanning backward
    while linenum > 0:
        linenum -= 1
        line = clean_lines.elided[linenum]
        (start_pos, num_open) = FindStartOfExpressionInLine(
            line, len(line) - 1, num_open, startchar, endchar)
        if start_pos > -1:
            return (line, linenum, start_pos)

    # Did not find startchar before beginning of file, give up
    return (line, 0, -1)


def GetHeaderGuardCPPVariable(filename):
    """Returns the CPP variable that should be used as a header guard.

    Args:
      filename: The name of a C++ header file.

    Returns:
      The CPP variable that should be used as a header guard in the
      named file.

    """

    # Restores original filename in case that cpplint is invoked from Emacs's
    # flymake.
    filename = re.sub(r'_flymake\.h$', '.h', filename)
    filename = re.sub(r'/\.flymake/([^/]*)$', r'/\1', filename)

    fileinfo = FileInfo(filename)
    file_path_from_root = fileinfo.RelativePath()
    return 'NVIM_' + re.sub(r'[-./\s]', '_', file_path_from_root).upper()


def CheckForHeaderGuard(filename, lines, error):
    """Checks that the file contains a header guard.

    Logs an error if no #ifndef header guard is present.  For other
    headers, checks that the full pathname is used.

    Args:
      filename: The name of the C++ header file.
      lines: An array of strings, each representing a line of the file.
      error: The function to call with any errors found.
    """
    if filename.endswith('.c.h') or FileInfo(filename).RelativePath() in set((
        'func_attr.h',
    )):
        return

    cppvar = GetHeaderGuardCPPVariable(filename)

    ifndef = None
    ifndef_linenum = 0
    define = None
    endif = None
    endif_linenum = 0
    for linenum, line in enumerate(lines):
        linesplit = line.split()
        if len(linesplit) >= 2:
            # find the first occurrence of #ifndef and #define, save arg
            if not ifndef and linesplit[0] == '#ifndef':
                # set ifndef to the header guard presented on the #ifndef line.
                ifndef = linesplit[1]
                ifndef_linenum = linenum
            if not define and linesplit[0] == '#define':
                define = linesplit[1]
        # find the last occurrence of #endif, save entire line
        if line.startswith('#endif'):
            endif = line
            endif_linenum = linenum

    if not ifndef:
        error(filename, 0, 'build/header_guard', 5,
              'No #ifndef header guard found, suggested CPP variable is: %s' %
              cppvar)
        return

    if not define:
        error(filename, 0, 'build/header_guard', 5,
              'No #define header guard found, suggested CPP variable is: %s' %
              cppvar)
        return

    # The guard should be PATH_FILE_H_, but we also allow PATH_FILE_H__
    # for backward compatibility.
    if ifndef != cppvar:
        error_level = 0
        if ifndef != cppvar + '_':
            error_level = 5

        ParseNolintSuppressions(filename, lines[ifndef_linenum], ifndef_linenum,
                                error)
        error(filename, ifndef_linenum, 'build/header_guard', error_level,
              '#ifndef header guard has wrong style, please use: %s' % cppvar)

    if define != ifndef:
        error(filename, 0, 'build/header_guard', 5,
              '#ifndef and #define don\'t match, suggested CPP variable is: %s'
              % cppvar)
        return

    if endif != ('#endif  // %s' % cppvar):
        error_level = 0
        if endif != ('#endif  // %s' % (cppvar + '_')):
            error_level = 5

        ParseNolintSuppressions(filename, lines[endif_linenum], endif_linenum,
                                error)
        error(filename, endif_linenum, 'build/header_guard', error_level,
              '#endif line should be "#endif  // %s"' % cppvar)


def CheckForBadCharacters(filename, lines, error):
    """Logs an error for each line containing bad characters.

    Two kinds of bad characters:

    1. Unicode replacement characters: These indicate that either the file
    contained invalid UTF-8 (likely) or Unicode replacement characters (which
    it shouldn't).  Note that it's possible for this to throw off line
    numbering if the invalid UTF-8 occurred adjacent to a newline.

    2. NUL bytes.  These are problematic for some tools.

    Args:
      filename: The name of the current file.
      lines: An array of strings, each representing a line of the file.
      error: The function to call with any errors found.
    """
    for linenum, line in enumerate(lines):
        if u'\ufffd' in line:
            error(filename, linenum, 'readability/utf8', 5,
                  'Line contains invalid UTF-8'
                  ' (or Unicode replacement character).')
        if '\0' in line:
            error(filename, linenum, 'readability/nul',
                  5, 'Line contains NUL byte.')


def CheckForNewlineAtEOF(filename, lines, error):
    """Logs an error if there is no newline char at the end of the file.

    Args:
      filename: The name of the current file.
      lines: An array of strings, each representing a line of the file.
      error: The function to call with any errors found.
    """

    # The array lines() was created by adding two newlines to the
    # original file (go figure), then splitting on \n.
    # To verify that the file ends in \n, we just have to make sure the
    # last-but-two element of lines() exists and is empty.
    if len(lines) < 3 or lines[-2]:
        error(filename, len(lines) - 2, 'whitespace/ending_newline', 5,
              'Could not find a newline character at the end of the file.')


def CheckForMultilineCommentsAndStrings(filename, clean_lines, linenum, error):
    """Logs an error if we see /* ... */ or "..." that extend past one line.

    /* ... */ comments are legit inside macros, for one line.
    Otherwise, we prefer // comments, so it's ok to warn about the
    other.  Likewise, it's ok for strings to extend across multiple
    lines, as long as a line continuation character (backslash)
    terminates each line. Although not currently prohibited by the C++
    style guide, it's ugly and unnecessary. We don't do well with either
    in this lint program, so we warn about both.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    line = clean_lines.elided[linenum]

    # Remove all \\ (escaped backslashes) from the line. They are OK, and the
    # second (escaped) slash may trigger later \" detection erroneously.
    line = line.replace('\\\\', '')

    if line.count('/*') > line.count('*/'):
        error(filename, linenum, 'readability/multiline_comment', 5,
              'Complex multi-line /*...*/-style comment found. '
              'Lint may give bogus warnings.  '
              'Consider replacing these with //-style comments, '
              'with #if 0...#endif, '
              'or with more clearly structured multi-line comments.')

    if (line.count('"') - line.count('\\"')) % 2:
        error(filename, linenum, 'readability/multiline_string', 5,
              'Multi-line string ("...") found.  This lint script doesn\'t '
              'do well with such strings, and may give bogus warnings.  '
              'Use C++11 raw strings or concatenation instead.')


def CheckForOldStyleComments(filename, line, linenum, error):
    """Logs an error if we see /*-style comment

    Args:
      filename: The name of the current file.
      line: The text of the line to check.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    if line.find('/*') >= 0 and line[-1] != '\\':
        error(filename, linenum, 'readability/old_style_comment', 5,
              '/*-style comment found, it should be replaced with //-style.  '
              '/*-style comments are only allowed inside macros.  '
              'Note that you should not use /*-style comments to document '
              'macros itself, use doxygen-style comments for this.')


threading_list = (
    ('asctime(', 'os_asctime_r('),
    ('ctime(', 'os_ctime_r('),
    ('getgrgid(', 'os_getgrgid_r('),
    ('getgrnam(', 'os_getgrnam_r('),
    ('getlogin(', 'os_getlogin_r('),
    ('getpwnam(', 'os_getpwnam_r('),
    ('getpwuid(', 'os_getpwuid_r('),
    ('gmtime(', 'os_gmtime_r('),
    ('localtime(', 'os_localtime_r('),
    ('strtok(', 'os_strtok_r('),
    ('ttyname(', 'os_ttyname_r('),
    ('asctime_r(', 'os_asctime_r('),
    ('ctime_r(', 'os_ctime_r('),
    ('getgrgid_r(', 'os_getgrgid_r('),
    ('getgrnam_r(', 'os_getgrnam_r('),
    ('getlogin_r(', 'os_getlogin_r('),
    ('getpwnam_r(', 'os_getpwnam_r('),
    ('getpwuid_r(', 'os_getpwuid_r('),
    ('gmtime_r(', 'os_gmtime_r('),
    ('localtime_r(', 'os_localtime_r('),
    ('strtok_r(', 'os_strtok_r('),
    ('ttyname_r(', 'os_ttyname_r('),
)


def CheckPosixThreading(filename, clean_lines, linenum, error):
    """Checks for calls to thread-unsafe functions.

    Much code has been originally written without consideration of
    multi-threading. Also, engineers are relying on their old experience;
    they have learned posix before threading extensions were added. These
    tests guide the engineers to use thread-safe functions (when using
    posix directly).

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    line = clean_lines.elided[linenum]
    for single_thread_function, multithread_safe_function in threading_list:
        ix = line.find(single_thread_function)
        # Comparisons made explicit for clarity -- pylint:
        # disable=g-explicit-bool-comparison
        if ix >= 0 and (ix == 0 or (not line[ix - 1].isalnum() and
                                    line[ix - 1] not in ('_', '.', '>'))):
            error(filename, linenum, 'runtime/threadsafe_fn', 2,
                  'Use ' + multithread_safe_function +
                  '...) instead of ' + single_thread_function +
                  '...). If it is missing, consider implementing it;' +
                  ' see os_localtime_r for an example.')


memory_functions = (
    ('malloc(', 'xmalloc('),
    ('calloc(', 'xcalloc('),
    ('realloc(', 'xrealloc('),
    ('strdup(', 'xstrdup('),
    ('free(', 'xfree('),
)
memory_ignore_pattern = re.compile(r'src/nvim/memory.c$')


def CheckMemoryFunctions(filename, clean_lines, linenum, error):
    """Checks for calls to invalid functions.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    if memory_ignore_pattern.search(filename):
        return
    line = clean_lines.elided[linenum]
    for function, suggested_function in memory_functions:
        ix = line.find(function)
        # Comparisons made explicit for clarity -- pylint:
        # disable=g-explicit-bool-comparison
        if ix >= 0 and (ix == 0 or (not line[ix - 1].isalnum() and
                                    line[ix - 1] not in ('_', '.', '>'))):
            error(filename, linenum, 'runtime/memory_fn', 2,
                  'Use ' + suggested_function +
                  '...) instead of ' + function + '...).')


# Matches invalid increment: *count++, which moves pointer instead of
# incrementing a value.
_RE_PATTERN_INVALID_INCREMENT = re.compile(
    r'^\s*\*\w+(\+\+|--);')


class _BlockInfo(object):

    """Stores information about a generic block of code."""

    def __init__(self, seen_open_brace):
        self.seen_open_brace = seen_open_brace
        self.open_parentheses = 0
        self.inline_asm = _NO_ASM


class _PreprocessorInfo(object):

    """Stores checkpoints of nesting stacks when #if/#else is seen."""

    def __init__(self, stack_before_if):
        # The entire nesting stack before #if
        self.stack_before_if = stack_before_if

        # The entire nesting stack up to #else
        self.stack_before_else = []

        # Whether we have already seen #else or #elif
        self.seen_else = False


class _NestingState(object):

    """Holds states related to parsing braces."""

    def __init__(self):
        # Stack for tracking all braces.  An object is pushed whenever we
        # see a "{", and popped when we see a "}".  Only 1 type of
        # object is possible:
        # - _BlockInfo: some type of block.
        self.stack = []

        # Stack of _PreprocessorInfo objects.
        self.pp_stack = []

    def SeenOpenBrace(self):
        """Check if we have seen the opening brace for the innermost block.

        Returns:
          True if we have seen the opening brace, False if the innermost
          block is still expecting an opening brace.
        """
        return (not self.stack) or self.stack[-1].seen_open_brace

    def UpdatePreprocessor(self, line):
        """Update preprocessor stack.

        We need to handle preprocessors due to classes like this:
          #ifdef SWIG
          struct ResultDetailsPageElementExtensionPoint {
          #else
          struct ResultDetailsPageElementExtensionPoint : public Extension {
          #endif

        We make the following assumptions (good enough for most files):
        - Preprocessor condition evaluates to true from #if up to first
          #else/#elif/#endif.

        - Preprocessor condition evaluates to false from #else/#elif up
          to #endif.  We still perform lint checks on these lines, but
          these do not affect nesting stack.

        Args:
          line: current line to check.
        """
        if Match(r'^\s*#\s*(if|ifdef|ifndef)\b', line):
            # Beginning of #if block, save the nesting stack here.  The saved
            # stack will allow us to restore the parsing state in the #else
            # case.
            self.pp_stack.append(_PreprocessorInfo(copy.deepcopy(self.stack)))
        elif Match(r'^\s*#\s*(else|elif)\b', line):
            # Beginning of #else block
            if self.pp_stack:
                if not self.pp_stack[-1].seen_else:
                    # This is the first #else or #elif block.  Remember the
                    # whole nesting stack up to this point.  This is what we
                    # keep after the #endif.
                    self.pp_stack[-1].seen_else = True
                    self.pp_stack[-1].stack_before_else = copy.deepcopy(
                        self.stack)

                # Restore the stack to how it was before the #if
                self.stack = copy.deepcopy(self.pp_stack[-1].stack_before_if)
            else:
                # TODO(unknown): unexpected #else, issue warning?
                pass
        elif Match(r'^\s*#\s*endif\b', line):
            # End of #if or #else blocks.
            if self.pp_stack:
                # If we saw an #else, we will need to restore the nesting
                # stack to its former state before the #else, otherwise we
                # will just continue from where we left off.
                if self.pp_stack[-1].seen_else:
                    # Here we can just use a shallow copy since we are the last
                    # reference to it.
                    self.stack = self.pp_stack[-1].stack_before_else
                # Drop the corresponding #if
                self.pp_stack.pop()
            else:
                # TODO(unknown): unexpected #endif, issue warning?
                pass

    def Update(self, filename, clean_lines, linenum, error):
        """Update nesting state with current line.

        Args:
          filename: The name of the current file.
          clean_lines: A CleansedLines instance containing the file.
          linenum: The number of the line to check.
          error: The function to call with any errors found.
        """
        line = clean_lines.elided[linenum]

        # Update pp_stack first
        self.UpdatePreprocessor(line)

        # Count parentheses.  This is to avoid adding struct arguments to
        # the nesting stack.
        if self.stack:
            inner_block = self.stack[-1]
            depth_change = line.count('(') - line.count(')')
            inner_block.open_parentheses += depth_change

            # Also check if we are starting or ending an inline assembly block.
            if inner_block.inline_asm in (_NO_ASM, _END_ASM):
                if (depth_change != 0 and
                        inner_block.open_parentheses == 1 and
                        _MATCH_ASM.match(line)):
                    # Enter assembly block
                    inner_block.inline_asm = _INSIDE_ASM
                else:
                    # Not entering assembly block.  If previous line was
                    # _END_ASM, we will now shift to _NO_ASM state.
                    inner_block.inline_asm = _NO_ASM
            elif (inner_block.inline_asm == _INSIDE_ASM and
                  inner_block.open_parentheses == 0):
                # Exit assembly block
                inner_block.inline_asm = _END_ASM

        # Consume braces or semicolons from what's left of the line
        while True:
            # Match first brace, semicolon, or closed parenthesis.
            matched = Match(r'^[^{;)}]*([{;)}])(.*)$', line)
            if not matched:
                break

            token = matched.group(1)
            if token == '{':
                # If namespace or class hasn't seen an opening brace yet, mark
                # namespace/class head as complete.  Push a new block onto the
                # stack otherwise.
                if not self.SeenOpenBrace():
                    self.stack[-1].seen_open_brace = True
                else:
                    self.stack.append(_BlockInfo(True))
                    if _MATCH_ASM.match(line):
                        self.stack[-1].inline_asm = _BLOCK_ASM
            elif token == ';' or token == ')':
                # If we haven't seen an opening brace yet, but we already saw
                # a semicolon, this is probably a forward declaration.  Pop
                # the stack for these.
                #
                # Similarly, if we haven't seen an opening brace yet, but we
                # already saw a closing parenthesis, then these are probably
                # function arguments with extra "class" or "struct" keywords.
                # Also pop these stack for these.
                if not self.SeenOpenBrace():
                    self.stack.pop()
            else:  # token == '}'
                # Perform end of block checks and pop the stack.
                if self.stack:
                    self.stack.pop()
            line = matched.group(2)


def CheckForNonStandardConstructs(filename, clean_lines, linenum,
                                  nesting_state, error):
    r"""Logs an error if we see certain non-ANSI constructs ignored by gcc-2.

    Complain about several constructs which gcc-2 accepts, but which are
    not standard C++.  Warning about these in lint is one way to ease the
    transition to new compilers.
    - put storage class first (e.g. "static const" instead of "const static").
    - "%" PRId64 instead of %qd" in printf-type functions.
    - "%1$d" is non-standard in printf-type functions.
    - "\%" is an undefined character escape sequence.
    - text after #endif is not allowed.
    - invalid inner-style forward declaration.
    - >? and <? operators, and their >?= and <?= cousins.

    Additionally, check for constructor/destructor style violations and
    reference members, as it is very convenient to do so while checking for
    gcc-2 compliance.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      nesting_state: A _NestingState instance which maintains information about
                     the current stack of nested blocks being parsed.
      error: A callable to which errors are reported, which takes 4 arguments:
             filename, line number, error level, and message
    """

    # Remove comments from the line, but leave in strings for now.
    line = clean_lines.lines[linenum]

    if Search(r'printf\s*\(.*".*%[-+ ]?\d*q', line):
        error(filename, linenum, 'runtime/printf_format', 3,
              '"%q" in format strings is deprecated.  Use "%" PRId64 instead.')

    if Search(r'printf\s*\(.*".*%\d+\$', line):
        error(filename, linenum, 'runtime/printf_format', 2,
              '%N$ formats are unconventional.  Try rewriting to avoid them.')

    # Remove escaped backslashes before looking for undefined escapes.
    line = line.replace('\\\\', '')

    if Search(r'("|\').*\\(%|\[|\(|{)', line):
        error(filename, linenum, 'build/printf_format', 3,
              '%, [, (, and { are undefined character escapes.  Unescape them.')

    # For the rest, work with both comments and strings removed.
    line = clean_lines.elided[linenum]

    if Search(r'\b(const|volatile|void|char|short|int|long'
              r'|float|double|signed|unsigned'
              r'|u?int8_t|u?int16_t|u?int32_t|u?int64_t'
              r'|u?int_least8_t|u?int_least16_t|u?int_least32_t'
              r'|u?int_least64_t'
              r'|u?int_fast8_t|u?int_fast16_t|u?int_fast32_t'
              r'|u?int_fast64_t'
              r'|u?intptr_t|u?intmax_t)'
              r'\s+(register|static|extern|typedef)\b',
              line):
        error(filename, linenum, 'build/storage_class', 5,
              'Storage class (static, extern, typedef, etc) should be first.')

    if Match(r'\s*#\s*endif\s*[^/\s]+', line):
        error(filename, linenum, 'build/endif_comment', 5,
              'Uncommented text after #endif is non-standard.  Use a comment.')

    if Search(r'(\w+|[+-]?\d+(\.\d*)?)\s*(<|>)\?=?\s*(\w+|[+-]?\d+)(\.\d*)?',
              line):
        error(filename, linenum, 'build/deprecated', 3,
              '>? and <? (max and min) operators are'
              ' non-standard and deprecated.')


def CheckSpacingForFunctionCall(filename, line, linenum, error):
    """Checks for the correctness of various spacing around function calls.

    Args:
      filename: The name of the current file.
      line: The text of the line to check.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """

    # Since function calls often occur inside if/for/while/switch
    # expressions - which have their own, more liberal conventions - we
    # first see if we should be looking inside such an expression for a
    # function call, to which we can apply more strict standards.
    fncall = line    # if there's no control flow construct, look at whole line
    for pattern in (r'\bif\s*\((.*)\)\s*{',
                    r'\bfor\s*\((.*)\)\s*{',
                    r'\bwhile\s*\((.*)\)\s*[{;]',
                    r'\bswitch\s*\((.*)\)\s*{'):
        match = Search(pattern, line)
        if match:
            # look inside the parens for function calls
            fncall = match.group(1)
            break

    # Except in if/for/while/switch, there should never be space
    # immediately inside parens (eg "f( 3, 4 )").  We make an exception
    # for nested parens ( (a+b) + c ).  Likewise, there should never be
    # a space before a ( when it's a function argument.  I assume it's a
    # function argument when the char before the whitespace is legal in
    # a function name (alnum + _) and we're not starting a macro. Also ignore
    # pointers and references to arrays and functions coz they're too tricky:
    # we use a very simple way to recognize these:
    # " (something)(maybe-something)" or
    # " (something)(maybe-something," or
    # " (something)[something]"
    # Note that we assume the contents of [] to be short enough that
    # they'll never need to wrap.
    if (  # Ignore control structures.
            not Search(r'\b(if|for|while|switch|return|sizeof)\b', fncall) and
            # Ignore pointers/references to functions.
            not Search(r' \([^)]+\)\([^)]*(\)|,$)', fncall) and
            # Ignore pointers/references to arrays.
            not Search(r' \([^)]+\)\[[^\]]+\]', fncall)):
        # a ( used for a fn call
        if Search(r'\w\s*\(\s(?!\s*\\$)', fncall):
            error(filename, linenum, 'whitespace/parens', 4,
                  'Extra space after ( in function call')
        elif Search(r'\(\s+(?!(\s*\\)|\()', fncall):
            error(filename, linenum, 'whitespace/parens', 2,
                  'Extra space after (')
        if (Search(r'\w\s+\(', fncall) and
                not Search(r'#\s*define|typedef', fncall) and
                not Search(r'\w\s+\((\w+::)*\*\w+\)\(', fncall)):
            error(filename, linenum, 'whitespace/parens', 4,
                  'Extra space before ( in function call')
        # If the ) is followed only by a newline or a { + newline, assume it's
        # part of a control statement (if/while/etc), and don't complain
        if Search(r'[^)]\s+\)\s*[^{\s]', fncall):
            # If the closing parenthesis is preceded by only whitespaces,
            # try to give a more descriptive error message.
            if Search(r'^\s+\)', fncall):
                error(filename, linenum, 'whitespace/parens', 2,
                      'Closing ) should be moved to the previous line')
            else:
                error(filename, linenum, 'whitespace/parens', 2,
                      'Extra space before )')


def IsBlankLine(line):
    """Returns true if the given line is blank.

    We consider a line to be blank if the line is empty or consists of
    only white spaces.

    Args:
      line: A line of a string.

    Returns:
      True, if the given line is blank.
    """
    return not line or line.isspace()


def CheckForFunctionLengths(filename, clean_lines, linenum,
                            function_state, error):
    """Reports for long function bodies.

    For an overview why this is done, see:
    http://google-styleguide.googlecode.com/svn/trunk/cppguide.xml#Write_Short_Functions

    Uses a simplistic algorithm assuming other style guidelines
    (especially spacing) are followed.
    Only checks unindented functions, so class members are unchecked.
    Trivial bodies are unchecked, so constructors with huge initializer lists
    may be missed.
    Blank/comment lines are not counted so as to avoid encouraging the removal
    of vertical space and comments just to get through a lint check.
    NOLINT *on the last line of a function* disables this check.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      function_state: Current function name and lines in body so far.
      error: The function to call with any errors found.
    """
    lines = clean_lines.lines
    line = lines[linenum]
    joined_line = ''

    starting_func = False
    regexp = r'(\w(\w|::|\*|\&|\s)*)\('  # decls * & space::name( ...
    match_result = Match(regexp, line)
    if match_result:
        # If the name is all caps and underscores, figure it's a macro and
        # ignore it, unless it's TEST or TEST_F.
        function_name = match_result.group(1).split()[-1]
        if function_name == 'TEST' or function_name == 'TEST_F' or (
                not Match(r'[A-Z_]+$', function_name)):
            starting_func = True

    if starting_func:
        body_found = False
        for start_linenum in range(linenum, clean_lines.NumLines()):
            start_line = lines[start_linenum]
            joined_line += ' ' + start_line.lstrip()
            # Declarations and trivial functions
            if Search(r'(;|})', start_line):
                body_found = True
                break                              # ... ignore
            elif Search(r'{', start_line):
                body_found = True
                function = Search(r'((\w|:)*)\(', line).group(1)
                if Match(r'TEST', function):    # Handle TEST... macros
                    parameter_regexp = Search(r'(\(.*\))', joined_line)
                    if parameter_regexp:             # Ignore bad syntax
                        function += parameter_regexp.group(1)
                else:
                    function += '()'
                function_state.Begin(function)
                break
        if not body_found:
            # No body for the function (or evidence of a non-function) was
            # found.
            error(filename, linenum, 'readability/fn_size', 5,
                  'Lint failed to find start of function body.')
    elif Match(r'^\}\s*$', line):  # function end
        function_state.Check(error, filename, linenum)
        function_state.End()
    elif not Match(r'^\s*$', line):
        function_state.Count()  # Count non-blank/non-comment lines.


_RE_PATTERN_TODO = re.compile(r'^//(\s*)TODO(\(.+?\))?(:?)(\s|$)?')


def CheckComment(comment, filename, linenum, error):
    """Checks for common mistakes in TODO comments.

    Args:
      comment: The text of the comment from the line in question.
      filename: The name of the current file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    match = _RE_PATTERN_TODO.match(comment)
    if match:
        # One whitespace is correct; zero whitespace is handled elsewhere.
        leading_whitespace = match.group(1)
        if len(leading_whitespace) > 1:
            error(filename, linenum, 'whitespace/todo', 2,
                  'Too many spaces before TODO')

        username = match.group(2)
        if not username:
            error(filename, linenum, 'readability/todo', 2,
                  'Missing username in TODO; it should look like '
                  '"// TODO(my_username): Stuff."')

        colon = match.group(3)
        if not colon:
            error(filename, linenum, 'readability/todo', 2,
                  'Missing colon in TODO; it should look like '
                  '"// TODO(my_username): Stuff."')

        middle_whitespace = match.group(4)
        # Comparisons made explicit for correctness -- pylint:
        # disable=g-explicit-bool-comparison
        if middle_whitespace != ' ' and middle_whitespace != '':
            error(filename, linenum, 'whitespace/todo', 2,
                  'TODO(my_username): should be followed by a space')


def FindNextMatchingAngleBracket(clean_lines, linenum, init_suffix):
    """Find the corresponding > to close a template.

    Args:
      clean_lines: A CleansedLines instance containing the file.
      linenum: Current line number.
      init_suffix: Remainder of the current line after the initial <.

    Returns:
      True if a matching bracket exists.
    """
    line = init_suffix
    nesting_stack = ['<']
    while True:
        # Find the next operator that can tell us whether < is used as an
        # opening bracket or as a less-than operator.  We only want to
        # warn on the latter case.
        #
        # We could also check all other operators and terminate the search
        # early, e.g. if we got something like this "a<b+c", the "<" is
        # most likely a less-than operator, but then we will get false
        # positives for default arguments and other template expressions.
        match = Search(r'^[^<>(),;\[\]]*([<>(),;\[\]])(.*)$', line)
        if match:
            # Found an operator, update nesting stack
            operator = match.group(1)
            line = match.group(2)

            if nesting_stack[-1] == '<':
                # Expecting closing angle bracket
                if operator in ('<', '(', '['):
                    nesting_stack.append(operator)
                elif operator == '>':
                    nesting_stack.pop()
                    if not nesting_stack:
                        # Found matching angle bracket
                        return True
                elif operator == ',':
                    # Got a comma after a bracket, this is most likely a
                    # template argument.  We have not seen a closing angle
                    # bracket yet, but it's probably a few lines later if we
                    # look for it, so just return early here.
                    return True
                else:
                    # Got some other operator.
                    return False

            else:
                # Expecting closing parenthesis or closing bracket
                if operator in ('<', '(', '['):
                    nesting_stack.append(operator)
                elif operator in (')', ']'):
                    # We don't bother checking for matching () or [].  If we got
                    # something like (] or [), it would have been a syntax
                    # error.
                    nesting_stack.pop()

        else:
            # Scan the next line
            linenum += 1
            if linenum >= len(clean_lines.elided):
                break
            line = clean_lines.elided[linenum]

    # Exhausted all remaining lines and still no matching angle bracket.
    # Most likely the input was incomplete, otherwise we should have
    # seen a semicolon and returned early.
    return True


def FindPreviousMatchingAngleBracket(clean_lines, linenum, init_prefix):
    """Find the corresponding < that started a template.

    Args:
      clean_lines: A CleansedLines instance containing the file.
      linenum: Current line number.
      init_prefix: Part of the current line before the initial >.

    Returns:
      True if a matching bracket exists.
    """
    line = init_prefix
    nesting_stack = ['>']
    while True:
        # Find the previous operator
        match = Search(r'^(.*)([<>(),;\[\]])[^<>(),;\[\]]*$', line)
        if match:
            # Found an operator, update nesting stack
            operator = match.group(2)
            line = match.group(1)

            if nesting_stack[-1] == '>':
                # Expecting opening angle bracket
                if operator in ('>', ')', ']'):
                    nesting_stack.append(operator)
                elif operator == '<':
                    nesting_stack.pop()
                    if not nesting_stack:
                        # Found matching angle bracket
                        return True
                elif operator == ',':
                    # Got a comma before a bracket, this is most likely a
                    # template argument.  The opening angle bracket is probably
                    # there if we look for it, so just return early here.
                    return True
                else:
                    # Got some other operator.
                    return False

            else:
                # Expecting opening parenthesis or opening bracket
                if operator in ('>', ')', ']'):
                    nesting_stack.append(operator)
                elif operator in ('(', '['):
                    nesting_stack.pop()

        else:
            # Scan the previous line
            linenum -= 1
            if linenum < 0:
                break
            line = clean_lines.elided[linenum]

    # Exhausted all earlier lines and still no matching angle bracket.
    return False


def CheckExpressionAlignment(filename, clean_lines, linenum, error, startpos=0):
    """Checks for the correctness of alignment inside expressions

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
      startpos: Position where to start searching for expression start.
    """
    level_starts = {}
    line = clean_lines.elided_with_space_strings[linenum]
    prev_line_start = Search(r'\S', line).start()
    depth_line_starts = {}
    pos = min([
        idx
        for idx in (
            line.find(k, startpos)
            for k in BRACES
            if k != '{'
        )
        if idx >= 0
    ] + [len(line) + 1])
    if pos == len(line) + 1:
        return
    ignore_error_levels = set()
    firstlinenum = linenum
    for linenum, pos, brace, depth in GetExprBracesPosition(
        clean_lines, linenum, pos
    ):
        line = clean_lines.elided_with_space_strings[linenum]
        if depth is None:
            if pos < len(line) - 1:
                CheckExpressionAlignment(filename, clean_lines, linenum, error,
                                         pos + 1)
            return
        elif depth <= 0:
            error(filename, linenum, 'syntax/parenthesis', 4,
                  'Unbalanced parenthesis')
            return
        if brace == 's':
            assert firstlinenum != linenum
            if level_starts[depth][1]:
                if line[pos] == BRACES[depth_line_starts[depth][1]]:
                    if pos != depth_line_starts[depth][0]:
                        if depth not in ignore_error_levels:
                            error(filename, linenum, 'whitespace/indent', 2,
                                  'End of the inner expression should have '
                                  'the same indent as start')
                else:
                    if (pos != depth_line_starts[depth][0] + 4
                        and not (depth_line_starts[depth][1] == '{'
                                 and pos == depth_line_starts[depth][0] + 2)):
                        if depth not in ignore_error_levels:
                            error(filename, linenum, 'whitespace/indent', 2,
                                  'Inner expression indentation should be 4')
            else:
                if (pos != level_starts[depth][0] + 1
                    + (level_starts[depth][2] == '{')):
                    if depth not in ignore_error_levels:
                        error(filename, linenum, 'whitespace/alignment', 2,
                              ('Inner expression should be aligned '
                               'as opening brace + 1 (+ 2 in case of {{). '
                               'Relevant opening is on line {0!r}').format(
                                   level_starts[depth][3]))
            prev_line_start = pos
        elif brace == 'e':
            pass
        else:
            opening = brace in BRACES
            if opening:
                # Only treat {} as part of the expression if it is preceded by
                # "=" (brace initializer) or "(type)" (construct like (struct
                # foo) { ... }).
                if brace == '{' and not (Search(
                    r'(?:= *|\((?:struct )?\w+(\s*\[\w*\])?\)) *$',
                    line[:pos])
                ):
                    ignore_error_levels.add(depth)
                line_ended_with_opening = (
                    pos == len(line) - 2 * (line.endswith(' \\')) - 1)
                level_starts[depth] = (pos, line_ended_with_opening, brace,
                                       linenum)
                if line_ended_with_opening:
                    depth_line_starts[depth] = (prev_line_start, brace)
            else:
                del level_starts[depth]


def CheckSpacing(filename, clean_lines, linenum, nesting_state, error):
    """Checks for the correctness of various spacing issues in the code.

    Things we check for: spaces around operators, spaces after
    if/for/while/switch, no spaces around parens in function calls, two
    spaces between code and comment, don't start a block with a blank
    line, don't end a function with a blank line, don't add a blank line
    after public/protected/private, don't have too many blank lines in a row,
    spaces after {, spaces before }.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      nesting_state: A _NestingState instance which maintains information about
                     the current stack of nested blocks being parsed.
      error: The function to call with any errors found.
    """

    # Don't use "elided" lines here, otherwise we can't check commented lines.
    # Don't want to use "raw" either, because we don't want to check inside
    # C++11 raw strings,
    raw = clean_lines.lines_without_raw_strings
    line = raw[linenum]

    # Before nixing comments, check if the line is blank for no good
    # reason.  This includes the first line after a block is opened, and
    # blank lines at the end of a function (ie, right before a line like '}'
    #
    # Skip all the blank line checks if we are immediately inside a
    # namespace body.  In other words, don't issue blank line warnings
    # for this block:
    #   namespace {
    #
    #   }
    #
    # A warning about missing end of namespace comments will be issued instead.
    if IsBlankLine(line):
        elided = clean_lines.elided
        prev_line = elided[linenum - 1]
        prevbrace = prev_line.rfind('{')
        # TODO(unknown): Don't complain if line before blank line, and line
        #                after,both start with alnums and are indented the same
        #                amount.  This ignores whitespace at the start of a
        #                namespace block because those are not usually indented.
        if prevbrace != -1 and prev_line[prevbrace:].find('}') == -1:
            # OK, we have a blank line at the start of a code block.  Before we
            # complain, we check if it is an exception to the rule: The previous
            # non-empty line has the parameters of a function header that are
            # indented 4 spaces (because they did not fit in a 80 column line
            # when placed on the same line as the function name).  We also check
            # for the case where the previous line is indented 6 spaces, which
            # may happen when the initializers of a constructor do not fit into
            # a 80 column line.
            exception = False
            if Match(r' {6}\w', prev_line):  # Initializer list?
                # We are looking for the opening column of initializer list,
                # which should be indented 4 spaces to cause 6 space indentation
                # afterwards.
                search_position = linenum - 2
                while (search_position >= 0
                       and Match(r' {6}\w', elided[search_position])):
                    search_position -= 1
                exception = (search_position >= 0
                             and elided[search_position][:5] == '    :')
            else:
                # Search for the function arguments or an initializer list.  We
                # use a simple heuristic here: If the line is indented 4 spaces;
                # and we have a closing paren, without the opening paren,
                # followed by an opening brace or colon (for initializer lists)
                # we assume that it is the last line of a function header.  If
                # we have a colon indented 4 spaces, it is an initializer list.
                exception = (Match(r' {4}\w[^\(]*\)\s*(const\s*)?(\{\s*$|:)',
                                   prev_line)
                             or Match(r' {4}:', prev_line))

            if not exception:
                error(filename, linenum, 'whitespace/blank_line', 2,
                      'Redundant blank line at the start of a code block '
                      'should be deleted.')
        # Ignore blank lines at the end of a block in a long if-else
        # chain, like this:
        #   if (condition1) {
        #     // Something followed by a blank line
        #
        #   } else if (condition2) {
        #     // Something else
        #   }
        if linenum + 1 < clean_lines.NumLines():
            next_line = raw[linenum + 1]
            if (next_line
                    and Match(r'\s*}', next_line)
                    and next_line.find('} else ') == -1):
                error(filename, linenum, 'whitespace/blank_line', 3,
                      'Redundant blank line at the end of a code block '
                      'should be deleted.')

    # Next, we complain if there's a comment too near the text
    commentpos = line.find('//')
    if commentpos != -1:
        # Check if the // may be in quotes.  If so, ignore it
        # Comparisons made explicit for clarity -- pylint:
        # disable=g-explicit-bool-comparison
        if (line.count('"', 0, commentpos) -
                line.count('\\"', 0, commentpos)) % 2 == 0:   # not in quotes
            # Allow one space for new scopes, two spaces otherwise:
            if (not Match(r'^\s*{ //', line) and
                ((commentpos >= 1 and
                  line[commentpos - 1] not in string.whitespace) or
                 (commentpos >= 2 and
                  line[commentpos - 2] not in string.whitespace))):
                error(filename, linenum, 'whitespace/comments', 2,
                      'At least two spaces is best between code and comments')
            # There should always be a space between the // and the comment
            commentend = commentpos + 2
            if commentend < len(line) and not line[commentend] == ' ':
                # but some lines are exceptions -- e.g. if they're big
                # comment delimiters like:
                # //----------------------------------------------------------
                # or are an empty C++ style Doxygen comment, like:
                # ///
                # or C++ style Doxygen comments placed after the variable:
                # ///<  Header comment
                # //!<  Header comment
                # or they begin with multiple slashes followed by a space:
                # //////// Header comment
                # or they are Vim {{{ fold markers
                match = (Search(r'[=/-]{4,}\s*$', line[commentend:]) or
                         Search(r'^/$', line[commentend:]) or
                         Search(r'^!< ', line[commentend:]) or
                         Search(r'^/< ', line[commentend:]) or
                         Search(r'^/+ ', line[commentend:]) or
                         Search(r'^(?:\{{3}|\}{3})\d*(?: |$)',
                                line[commentend:]))
                if not match:
                    error(filename, linenum, 'whitespace/comments', 4,
                          'Should have a space between // and comment')
            CheckComment(line[commentpos:], filename, linenum, error)

    line = clean_lines.elided[linenum]  # get rid of comments and strings

    # Don't try to do spacing checks for operator methods
    line = re.sub(r'operator(==|!=|<|<<|<=|>=|>>|>)\(', 'operator\(', line)

    # We allow no-spaces around = within an if: "if ( (a=Foo()) == 0 )".
    # Otherwise not.  Note we only check for non-spaces on *both* sides;
    # sometimes people put non-spaces on one side when aligning ='s among
    # many lines (not that this is behavior that I approve of...)
    if Search(r'[\w.]=[\w.]', line) and not Search(r'\b(if|while) ', line):
        error(filename, linenum, 'whitespace/operators', 4,
              'Missing spaces around =')

    # It's ok not to have spaces around binary operators like + - * /, but if
    # there's too little whitespace, we get concerned.  It's hard to tell,
    # though, so we punt on this one for now.  TODO.

    match = Search(r'(?:[^ (*/![])+(?<!\+\+|--)\*', line)
    if match:
        error(filename, linenum, 'whitespace/operators', 2,
              'Missing space before asterisk in %s' % match.group(0))

    # You should always have whitespace around binary operators.
    #
    # Check <= and >= first to avoid false positives with < and >, then
    # check non-include lines for spacing around < and >.
    match = Search(r'[^<>=!\s](==|!=|<=|>=)[^<>=!\s]', line)
    if match:
        error(filename, linenum, 'whitespace/operators', 3,
              'Missing spaces around %s' % match.group(1))

    # Boolean operators should be placed on the next line.
    if Search(r'(?:&&|\|\|)$', line):
        error(filename, linenum, 'whitespace/operators', 4,
              'Boolean operator should be placed on the same line as the start '
              'of its right operand')

    # We allow no-spaces around << when used like this: 10<<20, but
    # not otherwise (particularly, not when used as streams)
    # Also ignore using ns::operator<<;
    match = Search(r'(operator|\S)(?:L|UL|ULL|l|ul|ull)?<<(\S)', line)
    if (match and
            not (match.group(1).isdigit() and match.group(2).isdigit()) and
            not (match.group(1) == 'operator' and match.group(2) == ';')):
        error(filename, linenum, 'whitespace/operators', 3,
              'Missing spaces around <<')
    elif not Match(r'#.*include', line):
        # Avoid false positives on ->
        reduced_line = line.replace('->', '')

        # Look for < that is not surrounded by spaces.  This is only
        # triggered if both sides are missing spaces, even though
        # technically should should flag if at least one side is missing a
        # space.  This is done to avoid some false positives with shifts.
        match = Search(r'[^\s<]<([^\s=<].*)', reduced_line)
        if (match and not FindNextMatchingAngleBracket(clean_lines, linenum,
                                                       match.group(1))):
            error(filename, linenum, 'whitespace/operators', 3,
                  'Missing spaces around <')

        # Look for > that is not surrounded by spaces.  Similar to the
        # above, we only trigger if both sides are missing spaces to avoid
        # false positives with shifts.
        match = Search(r'^(.*[^\s>])>[^\s=>]', reduced_line)
        if (match and
            not FindPreviousMatchingAngleBracket(clean_lines, linenum,
                                                 match.group(1))):
            error(filename, linenum, 'whitespace/operators', 3,
                  'Missing spaces around >')

    # We allow no-spaces around >> for almost anything.  This is because
    # C++11 allows ">>" to close nested templates, which accounts for
    # most cases when ">>" is not followed by a space.
    #
    # We still warn on ">>" followed by alpha character, because that is
    # likely due to ">>" being used for right shifts, e.g.:
    #   value >> alpha
    #
    # When ">>" is used to close templates, the alphanumeric letter that
    # follows would be part of an identifier, and there should still be
    # a space separating the template type and the identifier.
    #   type<type<type>> alpha
    match = Search(r'>>[a-zA-Z_]', line)
    if match:
        error(filename, linenum, 'whitespace/operators', 3,
              'Missing spaces around >>')

    # There shouldn't be space around unary operators
    match = Search(r'(!\s|~\s|[\s]--[\s;]|[\s]\+\+[\s;])', line)
    if match:
        error(filename, linenum, 'whitespace/operators', 4,
              'Extra space for operator %s' % match.group(1))

    # A pet peeve of mine: no spaces after an if, while, switch, or for
    match = Search(r' (if\(|for\(|while\(|switch\()', line)
    if match:
        error(filename, linenum, 'whitespace/parens', 5,
              'Missing space before ( in %s' % match.group(1))

    # For if/for/while/switch, the left and right parens should be
    # consistent about how many spaces are inside the parens, and
    # there should either be zero or one spaces inside the parens.
    # We don't want: "if ( foo)" or "if ( foo   )".
    # Exception: "for ( ; foo; bar)" and "for (foo; bar; )" are allowed.
    match = Search(r'\b(if|for|while|switch)\s*'
                   r'\(([ ]*)(.).*[^ ]+([ ]*)\)\s*{\s*$',
                   line)
    if match:
        if len(match.group(2)) != len(match.group(4)):
            if not (match.group(3) == ';' and
                    len(match.group(2)) == 1 + len(match.group(4)) or
                    not match.group(2) and Search(r'\bfor\s*\(.*; \)', line)):
                error(filename, linenum, 'whitespace/parens', 5,
                      'Mismatching spaces inside () in %s' % match.group(1))
        if len(match.group(2)) not in [0, 1]:
            error(filename, linenum, 'whitespace/parens', 5,
                  'Should have zero or one spaces inside ( and ) in %s' %
                  match.group(1))

    # You should always have a space after a comma (either as fn arg or
    # operator).
    #
    # This does not apply when the non-space character following the
    # comma is another comma, since the only time when that happens is
    # for empty macro arguments.
    #
    # We run this check in two passes: first pass on elided lines to
    # verify that lines contain missing whitespaces, second pass on raw
    # lines to confirm that those missing whitespaces are not due to
    # elided comments.
    if Search(r',[^,\s]', line) and Search(r',[^,\s]', raw[linenum]):
        error(filename, linenum, 'whitespace/comma', 3,
              'Missing space after ,')

    # You should always have a space after a semicolon
    # except for few corner cases
    # TODO(unknown): clarify if 'if (1) { return 1;}' is requires one more
    # space after ;
    if Search(r';[^\s};\\)/]', line):
        error(filename, linenum, 'whitespace/semicolon', 3,
              'Missing space after ;')

    # Next we will look for issues with function calls.
    CheckSpacingForFunctionCall(filename, line, linenum, error)

    # Check whether everything inside expressions is aligned correctly
    if any((line.find(k) >= 0 for k in BRACES if k != '{')):
        CheckExpressionAlignment(filename, clean_lines, linenum, error)

    # Except after an opening paren, or after another opening brace (in case of
    # an initializer list, for instance), you should have spaces before your
    # braces. And since you should never have braces at the beginning of a line,
    # this is an easy test.
    match = Match(r'^(.*[^ ({]){', line)
    if match:
        # Try a bit harder to check for brace initialization.  This
        # happens in one of the following forms:
        #   Constructor() : initializer_list_{} { ... }
        #   Constructor{}.MemberFunction()
        #   Type variable{};
        #   FunctionCall(type{}, ...);
        #   LastArgument(..., type{});
        #   LOG(INFO) << type{} << " ...";
        #   map_of_type[{...}] = ...;
        #
        # We check for the character following the closing brace, and
        # silence the warning if it's one of those listed above, i.e.
        # "{.;,)<]".
        #
        # To account for nested initializer list, we allow any number of
        # closing braces up to "{;,)<".  We can't simply silence the
        # warning on first sight of closing brace, because that would
        # cause false negatives for things that are not initializer lists.
        #   Silence this:         But not this:
        #     Outer{                if (...) {
        #       Inner{...}            if (...){  // Missing space before {
        #     };                    }
        #
        # There is a false negative with this approach if people inserted
        # spurious semicolons, e.g. "if (cond){};", but we will catch the
        # spurious semicolon with a separate check.
        (endline, endlinenum, endpos) = CloseExpression(
            clean_lines, linenum, len(match.group(1)))
        trailing_text = ''
        if endpos > -1:
            trailing_text = endline[endpos:]
        for offset in range(endlinenum + 1,
                            min(endlinenum + 3, clean_lines.NumLines() - 1)):
            trailing_text += clean_lines.elided[offset]
        if not Match(r'^[\s}]*[{.;,)<\]]', trailing_text):
            error(filename, linenum, 'whitespace/braces', 5,
                  'Missing space before {')

    # Make sure '} else {' has spaces.
    if Search(r'}else', line):
        error(filename, linenum, 'whitespace/braces', 5,
              'Missing space before else')

    # You shouldn't have spaces before your brackets, except maybe after
    # 'delete []' or 'new char * []'.
    if Search(r'\w\s+\[', line):
        error(filename, linenum, 'whitespace/braces', 5,
              'Extra space before [')

    # You shouldn't have a space before a semicolon at the end of the line.
    if Search(r':\s*;\s*$', line):
        error(filename, linenum, 'whitespace/semicolon', 5,
              'Semicolon defining empty statement. Use {} instead.')
    elif Search(r'^\s*;\s*$', line):
        error(filename, linenum, 'whitespace/semicolon', 5,
              'Line contains only semicolon. If this should be an empty'
              ' statement, use {} instead.')
    elif Search(r'\s+;\s*$', line):
        error(filename, linenum, 'whitespace/semicolon', 5,
              'Extra space before last semicolon. If this should be an empty '
              'statement, use {} instead.')

    if Search(r'\{(?!\})\S', line):
        error(filename, linenum, 'whitespace/braces', 5,
              'Missing space after {')
    if Search(r'\S(?<!\{)\}', line):
        error(filename, linenum, 'whitespace/braces', 5,
              'Missing space before }')

    if Search(r'\S {2,}\\$', line):
        error(filename, linenum, 'whitespace/line_continuation', 5,
              'Too many spaces before \\, line continuation character must be '
              'preceded by exactly one space. For “blank lines” '
              'it is preferred to use the same amount of spaces as preceding '
              'indent')

    if Match(r'^ +#', line):
        error(filename, linenum, 'whitespace/indent', 5,
              'Must not indent preprocessor directives, use 1-space indent '
              'after the hash')

    cast_line = re.sub(r'^# *define +\w+\([^)]*\)', '', line)
    match = Search(r'(?<!\bkvec_t)'
                   r'(?<!\bkvec_withinit_t)'
                   r'(?<!\bklist_t)'
                   r'(?<!\bkliter_t)'
                   r'(?<!\bkhash_t)'
                   r'(?<!\bkbtree_t)'
                   r'(?<!\bkbitr_t)'
                   r'(?<!\bPMap)'
                   r'\((?:const )?(?:struct )?[a-zA-Z_]\w*(?: *\*(?:const)?)*\)'
                   r' +'
                   r'-?(?:\*+|&)?(?:\w+|\+\+|--|\()', cast_line)
    if match and line[0] == ' ':
        error(filename, linenum, 'whitespace/cast', 2,
              'Should leave no spaces after a cast: {!r}'.format(
                  match.group(0)))


def GetPreviousNonBlankLine(clean_lines, linenum):
    """Return the most recent non-blank line and its line number.

    Args:
      clean_lines: A CleansedLines instance containing the file contents.
      linenum: The number of the line to check.

    Returns:
      A tuple with two elements.  The first element is the contents of the last
      non-blank line before the current line, or the empty string if this is the
      first non-blank line.  The second is the line number of that line, or -1
      if this is the first non-blank line.
    """

    prevlinenum = linenum - 1
    while prevlinenum >= 0:
        prevline = clean_lines.elided[prevlinenum]
        if not IsBlankLine(prevline):     # if not a blank line...
            return (prevline, prevlinenum)
        prevlinenum -= 1
    return ('', -1)


def CheckBraces(filename, clean_lines, linenum, error):
    """Looks for misplaced braces (e.g. at the end of line).

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """

    line = clean_lines.elided[linenum]        # get rid of comments and strings

    if Match(r'\s+{\s*$', line):
        # We allow an open brace to start a line in the case where someone
        # is using braces in a block to explicitly create a new scope, which
        # is commonly used to control the lifetime of stack-allocated
        # variables.  Braces are also used for brace initializers inside
        # function calls.  We don't detect this perfectly: we just don't
        # complain if the last non-whitespace character on the previous
        # non-blank line is ',', ';', ':', '(', '{', or '}', or if the
        # previous line starts a preprocessor block.
        prevline = GetPreviousNonBlankLine(clean_lines, linenum)[0]
        if (not Search(r'[,;:}{(]\s*$', prevline) and
                not Match(r'\s*#', prevline)):
            error(filename, linenum, 'whitespace/braces', 4,
                    '{ should almost always be at the end'
                    ' of the previous line')

    # Brace must appear after function signature, but on the *next* line
    if Match(r'^(?:\w+(?: ?\*+)? )+\w+\(', line):
        pos = line.find('(')
        (endline, end_linenum, endpos) = CloseExpression(
            clean_lines, linenum, pos)
        if endline.endswith('{'):
            error(filename, end_linenum, 'readability/braces', 5,
                  'Brace starting function body must be placed on its own line')
        else:
            func_start_linenum = end_linenum + 1
            while not clean_lines.lines[func_start_linenum] == '{':
                attrline = Match(r'^((?!# *define).*?)(?:FUNC_ATTR|FUNC_API|REAL_FATTR)_\w+(?:\(\d+(, \d+)*\))?',
                                 clean_lines.lines[func_start_linenum])
                if attrline:
                    if len(attrline.group(1)) != 2:
                        error(filename, func_start_linenum,
                              'whitespace/indent', 5,
                              'Function attribute line should have 2-space '
                              'indent')

                    func_start_linenum += 1
                else:
                    func_start = clean_lines.lines[func_start_linenum]
                    if not func_start.startswith('enum ') and func_start.endswith('{'):
                        error(filename, func_start_linenum,
                              'readability/braces', 5,
                              'Brace starting function body must be placed '
                              'after the function signature')
                    break

    # An else clause should be on the same line as the preceding closing brace.
    # If there is no preceding closing brace, there should be one.
    if Match(r'\s*else\s*', line):
        prevline = GetPreviousNonBlankLine(clean_lines, linenum)[0]
        if Match(r'\s*}\s*$', prevline):
            error(filename, linenum, 'whitespace/newline', 4,
                  'An else should appear on the same line as the preceding }')
        else:
            error(filename, linenum, 'readability/braces', 5,
                  'An else should always have braces before it')

    # If should always have a brace
    for blockstart in ('if', 'while', 'for'):
        if Match(r'\s*{0}(?!\w)[^{{]*$'.format(blockstart), line):
            pos = line.find(blockstart)
            pos = line.find('(', pos)
            if pos > 0:
                (endline, _, endpos) = CloseExpression(
                    clean_lines, linenum, pos)
                if endline[endpos:].find('{') == -1:
                    error(filename, linenum, 'readability/braces', 5,
                          '{0} should always use braces'.format(blockstart))

    # If braces come on one side of an else, they should be on both.
    # However, we have to worry about "else if" that spans multiple lines!
    if Search(r'}\s*else[^{]*$', line) or Match(r'[^}]*else\s*{', line):
        if Search(r'}\s*else if([^{]*)$', line):       # could be multi-line if
            # find the ( after the if
            pos = line.find('else if')
            pos = line.find('(', pos)
            if pos > 0:
                (endline, _, endpos) = CloseExpression(
                    clean_lines, linenum, pos)
                # must be brace after if
                if endline[endpos:].find('{') == -1:
                    error(filename, linenum, 'readability/braces', 5,
                          'If an else has a brace on one side,'
                          ' it should have it on both')
        else:            # common case: else not followed by a multi-line if
            error(filename, linenum, 'readability/braces', 5,
                  'If an else has a brace on one side,'
                  ' it should have it on both')

    # Likewise, an else should never have the else clause on the same line
    if Search(r'\belse [^\s{]', line) and not Search(r'\belse if\b', line):
        error(filename, linenum, 'whitespace/newline', 4,
              'Else clause should never be on same line as else (use 2 lines)')

    # In the same way, a do/while should never be on one line
    if Match(r'\s*do [^\s{]', line):
        error(filename, linenum, 'whitespace/newline', 4,
              'do/while clauses should not be on a single line')

    # Block bodies should not be followed by a semicolon.  Due to C++11
    # brace initialization, there are more places where semicolons are
    # required than not, so we use a whitelist approach to check these
    # rather than a blacklist.  These are the places where "};" should
    # be replaced by just "}":
    # 1. Some flavor of block following closing parenthesis:
    #    for (;;) {};
    #    while (...) {};
    #    switch (...) {};
    #    Function(...) {};
    #    if (...) {};
    #    if (...) else if (...) {};
    #
    # 2. else block:
    #    if (...) else {};
    #
    # 3. const member function:
    #    Function(...) const {};
    #
    # 4. Block following some statement:
    #    x = 42;
    #    {};
    #
    # 5. Block at the beginning of a function:
    #    Function(...) {
    #      {};
    #    }
    #
    #    Note that naively checking for the preceding "{" will also match
    #    braces inside multi-dimensional arrays, but this is fine since
    #    that expression will not contain semicolons.
    #
    # 6. Block following another block:
    #    while (true) {}
    #    {};
    #
    # 7. End of namespaces:
    #    namespace {};
    #
    #    These semicolons seems far more common than other kinds of
    #    redundant semicolons, possibly due to people converting classes
    #    to namespaces.  For now we do not warn for this case.
    #
    # Try matching case 1 first.
    match = Match(r'^(.*\)\s*)\{', line)
    if match:
        # Matched closing parenthesis (case 1).  Check the token before the
        # matching opening parenthesis, and don't warn if it looks like a
        # macro.  This avoids these false positives:
        #  - macro that defines a base class
        #  - multi-line macro that defines a base class
        #  - macro that defines the whole class-head
        #
        # But we still issue warnings for macros that we know are safe to
        # warn, specifically:
        #  - TEST, TEST_F, TEST_P, MATCHER, MATCHER_P
        #  - TYPED_TEST
        #  - INTERFACE_DEF
        #  - EXCLUSIVE_LOCKS_REQUIRED, SHARED_LOCKS_REQUIRED, LOCKS_EXCLUDED:
        #
        # We implement a whitelist of safe macros instead of a blacklist of
        # unsafe macros, even though the latter appears less frequently in
        # google code and would have been easier to implement.  This is because
        # the downside for getting the whitelist wrong means some extra
        # semicolons, while the downside for getting the blacklist wrong
        # would result in compile errors.
        #
        # In addition to macros, we also don't want to warn on compound
        # literals.
        closing_brace_pos = match.group(1).rfind(')')
        opening_parenthesis = ReverseCloseExpression(
            clean_lines, linenum, closing_brace_pos)
        if opening_parenthesis[2] > -1:
            line_prefix = opening_parenthesis[0][0:opening_parenthesis[2]]
            macro = Search(r'\b([A-Z_]+)\s*$', line_prefix)
            if ((macro and
                 macro.group(1) not in (
                     'TEST', 'TEST_F', 'MATCHER', 'MATCHER_P', 'TYPED_TEST',
                     'EXCLUSIVE_LOCKS_REQUIRED', 'SHARED_LOCKS_REQUIRED',
                     'LOCKS_EXCLUDED', 'INTERFACE_DEF')) or
                    Search(r'\s+=\s*$', line_prefix) or
                    Search(r'^\s*return\s*$', line_prefix)):
                match = None

    else:
        # Try matching cases 2-3.
        match = Match(r'^(.*(?:else|\)\s*const)\s*)\{', line)
        if not match:
            # Try matching cases 4-6.  These are always matched on separate
            # lines.
            #
            # Note that we can't simply concatenate the previous line to the
            # current line and do a single match, otherwise we may output
            # duplicate warnings for the blank line case:
            #   if (cond) {
            #     // blank line
            #   }
            prevline = GetPreviousNonBlankLine(clean_lines, linenum)[0]
            if prevline and Search(r'[;{}]\s*$', prevline):
                match = Match(r'^(\s*)\{', line)

    # Check matching closing brace
    if match:
        (endline, endlinenum, endpos) = CloseExpression(
            clean_lines, linenum, len(match.group(1)))
        if endpos > -1 and Match(r'^\s*;', endline[endpos:]):
            # Current {} pair is eligible for semicolon check, and we have found
            # the redundant semicolon, output warning here.
            #
            # Note: because we are scanning forward for opening braces, and
            # outputting warnings for the matching closing brace, if there are
            # nested blocks with trailing semicolons, we will get the error
            # messages in reversed order.
            error(filename, endlinenum, 'readability/braces', 4,
                  "You don't need a ; after a }")


def CheckEmptyBlockBody(filename, clean_lines, linenum, error):
    """Look for empty loop/conditional body with only a single semicolon.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """

    # Search for loop keywords at the beginning of the line.  Because only
    # whitespaces are allowed before the keywords, this will also ignore most
    # do-while-loops, since those lines should start with closing brace.
    #
    # We also check "if" blocks here, since an empty conditional block
    # is likely an error.
    line = clean_lines.elided[linenum]
    matched = Match(r'\s*(for|while|if)\s*\(', line)
    if matched:
        # Find the end of the conditional expression
        (end_line, end_linenum, end_pos) = CloseExpression(
            clean_lines, linenum, line.find('('))

        # Output warning if what follows the condition expression is a
        # semicolon.  No warning for all other cases, including whitespace or
        # newline, since we have a separate check for semicolons preceded by
        # whitespace.
        if end_pos >= 0 and Match(r';', end_line[end_pos:]):
            if matched.group(1) == 'if':
                error(filename, end_linenum,
                      'whitespace/empty_conditional_body', 5,
                      'Empty conditional bodies should use {}')
            else:
                error(filename, end_linenum, 'whitespace/empty_loop_body', 5,
                      'Empty loop bodies should use {} or continue')


def CheckAltTokens(filename, clean_lines, linenum, error):
    """Check alternative keywords being used in boolean expressions.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      error: The function to call with any errors found.
    """
    line = clean_lines.elided[linenum]

    # Avoid preprocessor lines
    if Match(r'^\s*#', line):
        return

    # Last ditch effort to avoid multi-line comments.  This will not help
    # if the comment started before the current line or ended after the
    # current line, but it catches most of the false positives.  At least,
    # it provides a way to workaround this warning for people who use
    # multi-line comments in preprocessor macros.
    #
    # TODO(unknown): remove this once cpplint has better support for
    # multi-line comments.
    if line.find('/*') >= 0 or line.find('*/') >= 0:
        return

    for match in _ALT_TOKEN_REPLACEMENT_PATTERN.finditer(line):
        error(filename, linenum, 'readability/alt_tokens', 2,
              'Use operator %s instead of %s' % (
                  _ALT_TOKEN_REPLACEMENT[match.group(1)], match.group(1)))


def GetLineWidth(line):
    """Determines the width of the line in column positions.

    Args:
      line: A string, which may be a Unicode string.

    Returns:
      The width of the line in column positions, accounting for Unicode
      combining characters and wide characters.
    """
    if isinstance(line, str):
        width = 0
        for uc in unicodedata.normalize('NFC', line):
            if unicodedata.east_asian_width(uc) in ('W', 'F'):
                width += 2
            elif not unicodedata.combining(uc):
                width += 1
        return width
    else:
        return len(line)


def CheckStyle(filename, clean_lines, linenum, file_extension, nesting_state,
               error):
    """Checks rules from the 'C++ style rules' section of cppguide.html.

    Most of these rules are hard to test (naming, comment style), but we
    do what we can.  In particular we check for 2-space indents, line lengths,
    tab usage, spaces inside code, etc.

    Args:
      filename: The name of the current file.
      clean_lines: A CleansedLines instance containing the file.
      linenum: The number of the line to check.
      file_extension: The extension (without the dot) of the filename.
      nesting_state: A _NestingState instance which maintains information about
                     the current stack of nested blocks being parsed.
      error: The function to call with any errors found.
    """

    # Don't use "elided" lines here, otherwise we can't check commented lines.
    # Don't want to use "raw" either, because we don't want to check inside
    # C++11 raw strings,
    raw_lines = clean_lines.lines_without_raw_strings
    line = raw_lines[linenum]

    if line.find('\t') != -1:
        error(filename, linenum, 'whitespace/tab', 1,
              'Tab found; better to use spaces')

    # One or three blank spaces at the beginning of the line is weird; it's
    # hard to reconcile that with 2-space indents.
    # NOTE: here are the conditions rob pike used for his tests.  Mine aren't
    # as sophisticated, but it may be worth becoming so:
    # RLENGTH==initial_spaces
    # if(RLENGTH > 20) complain = 0;
    # if(match($0, " +(error|private|public|protected):")) complain = 0;
    # if(match(prev, "&& *$")) complain = 0;
    # if(match(prev, "\\|\\| *$")) complain = 0;
    # if(match(prev, "[\",=><] *$")) complain = 0;
    # if(match($0, " <<")) complain = 0;
    # if(match(prev, " +for \\(")) complain = 0;
    # if(prevodd && match(prevprev, " +for \\(")) complain = 0;
    initial_spaces = 0
    cleansed_line = clean_lines.elided[linenum]
    while initial_spaces < len(line) and line[initial_spaces] == ' ':
        initial_spaces += 1
    if line and line[-1].isspace():
        error(filename, linenum, 'whitespace/end_of_line', 4,
              'Line ends in whitespace.  Consider deleting these extra spaces.')
    # There are certain situations we allow one space, notably for section
    # labels
    elif ((initial_spaces == 1 or initial_spaces == 3) and
          not Match(r'\s*\w+\s*:\s*$', cleansed_line)):
        error(filename, linenum, 'whitespace/indent', 3,
              'Weird number of spaces at line-start.  '
              'Are you using a 2-space indent?')

    # Check if the line is a header guard.
    is_header_guard = False
    if file_extension == 'h':
        cppvar = GetHeaderGuardCPPVariable(filename)
        if (line.startswith('#ifndef %s' % cppvar) or
                line.startswith('#define %s' % cppvar) or
                line.startswith('#endif  // %s' % cppvar)):
            is_header_guard = True
    # #include lines and header guards can be long, since there's no clean way
    # to split them.
    #
    # URLs can be long too.  It's possible to split these, but it makes them
    # harder to cut&paste.
    #
    # The "$Id:...$" comment may also get very long without it being the
    # developers fault.
    if (not line.startswith('#include') and not is_header_guard and
            not Match(r'^\s*//.*http(s?)://\S*$', line) and
            not Match(r'^// \$Id:.*#[0-9]+ \$$', line)):
        line_width = GetLineWidth(line)
        extended_length = int((_line_length * 1.25))
        if line_width > extended_length:
            error(filename, linenum, 'whitespace/line_length', 4,
                  'Lines should very rarely be longer than %i characters' %
                  extended_length)
        elif line_width > _line_length:
            error(filename, linenum, 'whitespace/line_length', 2,
                  'Lines should be <= %i characters long' % _line_length)

    if (cleansed_line.count(';') > 1 and
        # for loops are allowed two ;'s (and may run over two lines).
        cleansed_line.find('for') == -1 and
        (GetPreviousNonBlankLine(clean_lines, linenum)[0].find('for') == -1 or
         GetPreviousNonBlankLine(clean_lines, linenum)[0].find(';') != -1) and
        # It's ok to have many commands in a switch case that fits in 1 line
        not ((cleansed_line.find('case ') != -1 or
              cleansed_line.find('default:') != -1) and
             cleansed_line.find('break;') != -1)):
        error(filename, linenum, 'whitespace/newline', 0,
              'More than one command on the same line')

    # Some more style checks
    CheckBraces(filename, clean_lines, linenum, error)
    CheckEmptyBlockBody(filename, clean_lines, linenum, error)
    CheckSpacing(filename, clean_lines, linenum, nesting_state, error)
    CheckAltTokens(filename, clean_lines, linenum, error)


_RE_PATTERN_INCLUDE_NEW_STYLE = re.compile(r'#include +"[^/]+\.h"')
_RE_PATTERN_INCLUDE = re.compile(r'^\s*#\s*include\s*([<"])([^>"]*)[>"].*$')
# Matches the first component of a filename delimited by -s and _s. That is:
#  _RE_FIRST_COMPONENT.match('foo').group(0) == 'foo'
#  _RE_FIRST_COMPONENT.match('foo.cc').group(0) == 'foo'
#  _RE_FIRST_COMPONENT.match('foo-bar_baz.cc').group(0) == 'foo'
#  _RE_FIRST_COMPONENT.match('foo_bar-baz.cc').group(0) == 'foo'
_RE_FIRST_COMPONENT = re.compile(r'^[^-_.]+')


def _ClassifyInclude(fileinfo, include, is_system):
    """Figures out what kind of header 'include' is.

    Args:
      fileinfo: The current file cpplint is running over. A FileInfo instance.
      include: The path to a #included file.
      is_system: True if the #include used <> rather than "".

    Returns:
      One of the _XXX_HEADER constants.
    """
    if is_system:
        return _C_SYS_HEADER
    return _OTHER_HEADER


def CheckIncludeLine(filename, clean_lines, linenum, include_state, error):
    """Check rules that are applicable to #include lines.

    Strings on #include lines are NOT removed from elided line, to make
    certain tasks easier. However, to prevent false positives, checks
    applicable to #include lines in CheckLanguage must be put here.

    Args:
      filename      : The name of the current file.
      clean_lines   : A CleansedLines instance containing the file.
      linenum       : The number of the line to check.
      include_state : An _IncludeState instance in which the headers are
                      inserted.
      error         : The function to call with any errors found.
    """
    fileinfo = FileInfo(filename)

    line = clean_lines.lines[linenum]

    # "include" should use the new style "foo/bar.h" instead of just "bar.h"
    # XXX: neovim doesn't currently use this style
    # if _RE_PATTERN_INCLUDE_NEW_STYLE.search(line):
    #   error(filename, linenum, 'build/include', 4,
    #         'Include the directory when naming .h files')

    # we shouldn't include a file more than once. actually, there are a
    # handful of instances where doing so is okay, but in general it's
    # not.
    match = _RE_PATTERN_INCLUDE.search(line)
    if match:
        include = match.group(2)
        is_system = (match.group(1) == '<')
        if include in include_state:
            if is_system or not include.endswith('.c.h'):
                error(filename, linenum, 'build/include', 4,
                      '"%s" already included at %s:%s' %
                      (include, filename, include_state[include]))
        else:
            include_state[include] = linenum

            # We want to ensure that headers appear in the right order:
            # 1) for foo.cc, foo.h  (preferred location)
            # 2) c system files
            # 3) cpp system files
            # 4) for foo.cc, foo.h  (deprecated location)
            # 5) other google headers
            #
            # We classify each include statement as one of those 5 types
            # using a number of techniques. The include_state object keeps
            # track of the highest type seen, and complains if we see a
            # lower type after that.
            error_message = include_state.CheckNextIncludeOrder(
                _ClassifyInclude(fileinfo, include, is_system))
            if error_message:
                error(filename, linenum, 'build/include_order', 4,
                      '%s. Should be: c system, c++ system, other.'
                      % error_message)
            canonical_include = include_state.CanonicalizeAlphabeticalOrder(
                include)
            include_state.SetLastHeader(canonical_include)


def _GetTextInside(text, start_pattern):
    r"""Retrieves all the text between matching open and close parentheses.

    Given a string of lines and a regular expression string, retrieve all the
    text following the expression and between opening punctuation symbols like
    (, [, or {, and the matching close-punctuation symbol. This properly nested
    occurrences of the punctuations, so for the text like
      printf(a(), b(c()));
    a call to _GetTextInside(text, r'printf\(') will return 'a(), b(c())'.
    start_pattern must match string having an open punctuation symbol at the
    end.

    Args:
      text: The lines to extract text. Its comments and strings must be elided.
             It can be single line and can span multiple lines.
      start_pattern: The regexp string indicating where to start extracting
                     the text.
    Returns:
      The extracted text.
      None if either the opening string or ending punctuation couldn't be found.
    """
    # TODO(sugawarayu): Audit cpplint.py to see what places could be profitably
    # rewritten to use _GetTextInside (and use inferior regexp matching today).

    # Give opening punctuations to get the matching close-punctuations.
    matching_punctuation = {'(': ')', '{': '}', '[': ']'}
    closing_punctuation = set(matching_punctuation.values())

    # Find the position to start extracting text.
    match = re.search(start_pattern, text, re.M)
    if not match:  # start_pattern not found in text.
        return None
    start_position = match.end(0)

    assert start_position > 0, (
        'start_pattern must ends with an opening punctuation.')
    assert text[start_position - 1] in matching_punctuation, (
        'start_pattern must ends with an opening punctuation.')
    # Stack of closing punctuations we expect to have in text after position.
    punctuation_stack = [matching_punctuation[text[start_position - 1]]]
    position = start_position
    while punctuation_stack and position < len(text):
        if text[position] == punctuation_stack[-1]:
            punctuation_stack.pop()
        elif text[position] in closing_punctuation:
            # A closing punctuation without matching opening punctuations.
            return None
        elif text[position] in matching_punctuation:
            punctuation_stack.append(matching_punctuation[text[position]])
        position += 1
    if punctuation_stack:
        # Opening punctuations left without matching close-punctuations.
        return None
    # punctuations match.
    return text[start_position:position - 1]


def CheckLanguage(filename, clean_lines, linenum, file_extension,
                  include_state, nesting_state, error):
    """Checks rules from the 'C++ language rules' section of cppguide.html.

    Some of these rules are hard to test (function overloading, using
    uint32 inappropriately), but we do the best we can.

    Args:
      filename       : The name of the current file.
      clean_lines    : A CleansedLines instance containing the file.
      linenum        : The number of the line to check.
      file_extension : The extension (without the dot) of the filename.
      include_state  : An _IncludeState instance in which the headers are
                       inserted.
      nesting_state  : A _NestingState instance which maintains information
                       about the current stack of nested blocks being parsed.
      error          : The function to call with any errors found.
    """
    # If the line is empty or consists of entirely a comment, no need to
    # check it.
    line = clean_lines.elided[linenum]
    if not line:
        return

    match = _RE_PATTERN_INCLUDE.search(line)
    if match:
        CheckIncludeLine(filename, clean_lines, linenum, include_state, error)
        return

    # Reset include state across preprocessor directives.  This is meant
    # to silence warnings for conditional includes.
    if Match(r'^\s*#\s*(?:ifdef|elif|else|endif)\b', line):
        include_state.ResetSection()

    # TODO(unknown): figure out if they're using default arguments in fn proto.

    # Check if people are using the verboten C basic types.
    match = Search(r'\b(short|long long)\b', line)
    if match:
        error(filename, linenum, 'runtime/int', 4,
              'Use int16_t/int64_t/etc, rather than the C type %s'
              % match.group(1))

    # When snprintf is used, the second argument shouldn't be a literal.
    match = Search(r'snprintf\s*\(([^,]*),\s*([0-9]*)\s*,', line)
    if match and match.group(2) != '0':
        # If 2nd arg is zero, snprintf is used to calculate size.
        error(filename, linenum, 'runtime/printf', 3,
              'If you can, use sizeof(%s) instead of %s as the 2nd arg '
              'to snprintf.' % (match.group(1), match.group(2)))

    # Check if some verboten C functions are being used.
    if Search(r'\bsprintf\b', line):
        error(filename, linenum, 'runtime/printf', 5,
              'Use snprintf instead of sprintf.')
    match = Search(r'\b(strncpy|STRNCPY)\b', line)
    if match:
        error(filename, linenum, 'runtime/printf', 4,
              'Use xstrlcpy or snprintf instead of %s (unless this is from Vim)'
              % match.group(1))
    match = Search(r'\b(strcpy)\b', line)
    if match:
        error(filename, linenum, 'runtime/printf', 4,
              'Use xstrlcpy or snprintf instead of %s' % match.group(1))
    match = Search(r'\b(STRNCAT|strncat|strcat|vim_strcat)\b', line)
    if match:
        error(filename, linenum, 'runtime/printf', 4,
              'Use xstrlcat or snprintf instead of %s' % match.group(1))
    if not Search(r'eval/typval\.[ch]$', filename):
        match = Search(r'(?:\.|->)'
                       r'(?:lv_(?:first|last|refcount|len|watch|idx(?:_item)?'
                                r'|copylist|lock)'
                          r'|li_(?:next|prev|tv))\b', line)
        if match:
            error(filename, linenum, 'runtime/deprecated', 4,
                  'Accessing list_T internals directly is prohibited')

    # Check for suspicious usage of "if" like
    # } if (a == b) {
    if Search(r'\}\s*if\s*\(', line):
        error(filename, linenum, 'readability/braces', 4,
              'Did you mean "else if"? If not, start a new line for "if".')

    # Check for potential format string bugs like printf(foo).
    # We constrain the pattern not to pick things like DocidForPrintf(foo).
    # Not perfect but it can catch printf(foo.c_str()) and printf(foo->c_str())
    # TODO(sugawarayu): Catch the following case. Need to change the calling
    # convention of the whole function to process multiple line to handle it.
    #   printf(
    #       boy_this_is_a_really_long_variable_that_cannot_fit_on_the_prev_line);
    printf_args = _GetTextInside(line, r'(?i)\b(string)?printf\s*\(')
    if printf_args:
        match = Match(r'([\w.\->()]+)$', printf_args)
        if match and match.group(1) != '__VA_ARGS__':
            function_name = re.search(r'\b((?:string)?printf)\s*\(',
                                      line, re.I).group(1)
            error(filename, linenum, 'runtime/printf', 4,
                  'Potential format string bug. Do %s("%%s", %s) instead.'
                  % (function_name, match.group(1)))

    # Check for potential memset bugs like memset(buf, sizeof(buf), 0).
    match = Search(r'memset\s*\(([^,]*),\s*([^,]*),\s*0\s*\)', line)
    if match and not Match(r"^''|-?[0-9]+|0x[0-9A-Fa-f]$", match.group(2)):
        error(filename, linenum, 'runtime/memset', 4,
              'Did you mean "memset(%s, 0, %s)"?'
              % (match.group(1), match.group(2)))

    # Detect variable-length arrays.
    match = Match(r'\s*(.+::)?(\w+) [a-z]\w*\[(.+)];', line)
    if (match and match.group(2) != 'return' and match.group(2) != 'delete' and
            match.group(3).find(']') == -1):
        # Split the size using space and arithmetic operators as delimiters.
        # If any of the resulting tokens are not compile time constants then
        # report the error.
        tokens = re.split(r'\s|\+|\-|\*|\/|<<|>>]', match.group(3))
        is_const = True
        skip_next = False
        for tok in tokens:
            if skip_next:
                skip_next = False
                continue

            if Search(r'sizeof\(.+\)', tok):
                continue
            if Search(r'arraysize\(\w+\)', tok):
                continue

            tok = tok.lstrip('(')
            tok = tok.rstrip(')')
            if not tok:
                continue
            if Match(r'\d+', tok):
                continue
            if Match(r'0[xX][0-9a-fA-F]+', tok):
                continue
            if Match(r'k[A-Z0-9]\w*', tok):
                continue
            if Match(r'(.+::)?k[A-Z0-9]\w*', tok):
                continue
            if Match(r'(.+::)?[A-Z][A-Z0-9_]*', tok):
                continue
            # A catch all for tricky sizeof cases, including
            # 'sizeof expression', 'sizeof(*type)', 'sizeof(const type)',
            # 'sizeof(struct StructName)' requires skipping the next token
            # because we split on ' ' and '*'.
            if tok.startswith('sizeof'):
                skip_next = True
                continue
            is_const = False
            break
        if not is_const:
            error(filename, linenum, 'runtime/arrays', 1,
                  "Do not use variable-length arrays.  Use an appropriately"
                  " named ('k' followed by CamelCase) compile-time constant for"
                  " the size.")

    # Detect TRUE and FALSE.
    match = Search(r'\b(TRUE|FALSE)\b', line)
    if match:
        token = match.group(1)
        error(filename, linenum, 'readability/bool', 4,
              'Use %s instead of %s.' % (token.lower(), token))

    # Detect MAYBE
    match = Search(r'\b(MAYBE)\b', line)
    if match:
        token = match.group(1)
        error(filename, linenum, 'readability/bool', 4,
              'Use kNONE from TriState instead of %s.' % token)

    # Detect preincrement/predecrement
    match = Match(r'^\s*(?:\+\+|--)', line)
    if match:
        error(filename, linenum, 'readability/increment', 5,
              'Do not use preincrement in statements, '
              'use postincrement instead')
    # Detect preincrement/predecrement in for(;; preincrement)
    match = Search(r';\s*(\+\+|--)', line)
    if match:
        end_pos, end_depth = FindEndOfExpressionInLine(line, match.start(1), 1,
                                                       '(', ')')
        expr = line[match.start(1):end_pos]
        if end_depth == 0 and ';' not in expr and ' = ' not in expr:
            error(filename, linenum, 'readability/increment', 4,
                  'Do not use preincrement in statements, including '
                  'for(;; action)')


def ProcessLine(filename, file_extension, clean_lines, line,
                include_state, function_state, nesting_state, error,
                extra_check_functions=[]):
    """Processes a single line in the file.

    Args:
      filename              : Filename of the file that is being processed.
      file_extension        : The extension (dot not included) of the file.
      clean_lines           : An array of strings, each representing a line of
                              the file, with comments stripped.
      line                  : Number of line being processed.
      include_state         : An _IncludeState instance in which the headers are
                              inserted.
      function_state        : A _FunctionState instance which counts function
                              lines, etc.
      nesting_state         : A _NestingState instance which maintains
                              information about the current stack of nested
                              blocks being parsed.
      error                 : A callable to which errors are reported, which
                              takes 4 arguments: filename, line number, error
                              level, and message
      extra_check_functions : An array of additional check functions that will
                              be run on each source line. Each function takes 4
                              arguments : filename, clean_lines, line, error
    """
    raw_lines = clean_lines.raw_lines
    init_lines = clean_lines.init_lines
    ParseNolintSuppressions(filename, raw_lines[line], line, error)
    nesting_state.Update(filename, clean_lines, line, error)
    if nesting_state.stack and nesting_state.stack[-1].inline_asm != _NO_ASM:
        return
    CheckForFunctionLengths(filename, clean_lines, line, function_state, error)
    CheckForMultilineCommentsAndStrings(filename, clean_lines, line, error)
    CheckForOldStyleComments(filename, init_lines[line], line, error)
    CheckStyle(
        filename, clean_lines, line, file_extension, nesting_state, error)
    CheckLanguage(filename, clean_lines, line, file_extension, include_state,
                  nesting_state, error)
    CheckForNonStandardConstructs(filename, clean_lines, line,
                                  nesting_state, error)
    CheckPosixThreading(filename, clean_lines, line, error)
    CheckMemoryFunctions(filename, clean_lines, line, error)
    for check_fn in extra_check_functions:
        check_fn(filename, clean_lines, line, error)


def ProcessFileData(filename, file_extension, lines, error,
                    extra_check_functions=[]):
    """Performs lint checks and reports any errors to the given error function.

    Args:
      filename: Filename of the file that is being processed.
      file_extension: The extension (dot not included) of the file.
      lines: An array of strings, each representing a line of the file, with the
             last element being empty if the file is terminated with a newline.
      error: A callable to which errors are reported, which takes 4 arguments:
             filename, line number, error level, and message
      extra_check_functions: An array of additional check functions that will be
                             run on each source line. Each function takes 4
                             arguments: filename, clean_lines, line, error
    """
    lines = (['// marker so line numbers and indices both start at 1'] + lines +
             ['// marker so line numbers end in a known way'])

    include_state = _IncludeState()
    function_state = _FunctionState()
    nesting_state = _NestingState()

    ResetNolintSuppressions()
    ResetKnownErrorSuppressions()

    for line in range(1, len(lines)):
        ParseKnownErrorSuppressions(filename, lines, line)

    init_lines = lines[:]

    if _cpplint_state.record_errors_file:
        def RecordedError(filename, linenum, category, confidence, message):
            if not IsErrorSuppressedByNolint(category, linenum):
                key = init_lines[linenum - 1 if linenum else 0:linenum + 2]
                err = [filename, key, category]
                json.dump(err, _cpplint_state.record_errors_file)
                _cpplint_state.record_errors_file.write('\n')
            Error(filename, linenum, category, confidence, message)

        error = RecordedError

    if file_extension == 'h':
        CheckForHeaderGuard(filename, lines, error)

    RemoveMultiLineComments(filename, lines, error)
    clean_lines = CleansedLines(lines, init_lines)
    for line in range(clean_lines.NumLines()):
        ProcessLine(filename, file_extension, clean_lines, line,
                    include_state, function_state, nesting_state, error,
                    extra_check_functions)

    # We check here rather than inside ProcessLine so that we see raw
    # lines rather than "cleaned" lines.
    CheckForBadCharacters(filename, lines, error)

    CheckForNewlineAtEOF(filename, lines, error)


def ProcessFile(filename, vlevel, extra_check_functions=[]):
    """Does neovim-lint on a single file.

    Args:
      filename: The name of the file to parse.

      vlevel: The level of errors to report.  Every error of confidence
      >= verbose_level will be reported.  0 is a good default.

      extra_check_functions: An array of additional check functions that will be
                             run on each source line. Each function takes 4
                             arguments: filename, clean_lines, line, error
    """

    _SetVerboseLevel(vlevel)

    try:
        # Support the Unix convention of using "-" for stdin.  Note that
        # we are not opening the file with universal newline support
        # (which codecs doesn't support anyway), so the resulting lines do
        # contain trailing '\r' characters if we are reading a file that
        # has CRLF endings.
        # If after the split a trailing '\r' is present, it is removed
        # below. If it is not expected to be present (i.e. os.linesep !=
        # '\r\n' as in Windows), a warning is issued below if this file
        # is processed.

        if filename == '-':
            stdin = sys.stdin.read()
            if sys.version_info < (3, 0):
                stdin = stdin.decode('utf8')
            lines = stdin.split('\n')
            if _cpplint_state.stdin_filename is not None:
                filename = _cpplint_state.stdin_filename
        else:
            lines = codecs.open(
                filename, 'r', 'utf8', 'replace').read().split('\n')

        carriage_return_found = False
        # Remove trailing '\r'.
        for linenum in range(len(lines)):
            if lines[linenum].endswith('\r'):
                lines[linenum] = lines[linenum].rstrip('\r')
                carriage_return_found = True

    except IOError:
        sys.stderr.write(
            "Skipping input '%s': Can't open for reading\n" % filename)
        return

    # Note, if no dot is found, this will give the entire filename as the ext.
    file_extension = filename[filename.rfind('.') + 1:]

    # When reading from stdin, the extension is unknown, so no cpplint tests
    # should rely on the extension.
    if filename != '-' and file_extension not in _valid_extensions:
        sys.stderr.write('Ignoring {}; only linting {} files\n'.format(
                filename,
                ', '.join('.{}'.format(ext) for ext in _valid_extensions)))
    else:
        ProcessFileData(filename, file_extension, lines, Error,
                        extra_check_functions)
        if carriage_return_found and os.linesep != '\r\n':
            # Use 0 for linenum since outputting only one error for potentially
            # several lines.
            Error(filename, 0, 'whitespace/newline', 1,
                  'One or more unexpected \\r (^M) found;'
                  'better to use only a \\n')


def PrintUsage(message):
    """Prints a brief usage string and exits, optionally with an error message.

    Args:
      message: The optional error message.
    """
    if message:
        sys.stderr.write(_USAGE)
        sys.exit('\nFATAL ERROR: ' + message)
    else:
        sys.stdout.write(_USAGE)
        sys.exit(0)


def PrintCategories():
    """Prints a list of all the error-categories used by error messages.

    These are the categories used to filter messages via --filter.
    """
    sys.stdout.write(''.join('  %s\n' % cat for cat in _ERROR_CATEGORIES))
    sys.exit(0)


def ParseArguments(args):
    """Parses the command line arguments.

    This may set the output format and verbosity level as side-effects.

    Args:
      args: The command line arguments:

    Returns:
      The list of filenames to lint.
    """
    try:
        (opts, filenames) = getopt.getopt(args, '', ['help',
                                                     'output=',
                                                     'verbose=',
                                                     'counting=',
                                                     'filter=',
                                                     'root=',
                                                     'linelength=',
                                                     'extensions=',
                                                     'record-errors=',
                                                     'suppress-errors=',
                                                     'stdin-filename=',
                                                     ])
    except getopt.GetoptError:
        PrintUsage('Invalid arguments.')

    verbosity = _VerboseLevel()
    output_format = _OutputFormat()
    filters = ''
    counting_style = ''
    record_errors_file = None
    suppress_errors_file = None
    stdin_filename = None

    for (opt, val) in opts:
        if opt == '--help':
            PrintUsage(None)
        elif opt == '--output':
            if val not in ('emacs', 'vs7', 'eclipse'):
                PrintUsage('The only allowed output formats are emacs,'
                           ' vs7 and eclipse.')
            output_format = val
        elif opt == '--verbose':
            verbosity = int(val)
        elif opt == '--filter':
            filters = val
            if not filters:
                PrintCategories()
        elif opt == '--counting':
            if val not in ('total', 'toplevel', 'detailed'):
                PrintUsage(
                    'Valid counting options are total, toplevel, and detailed')
            counting_style = val
        elif opt == '--linelength':
            global _line_length
            try:
                _line_length = int(val)
            except ValueError:
                PrintUsage('Line length must be digits.')
        elif opt == '--extensions':
            global _valid_extensions
            try:
                _valid_extensions = set(val.split(','))
            except ValueError:
                PrintUsage('Extensions must be comma separated list.')
        elif opt == '--record-errors':
            record_errors_file = val
        elif opt == '--suppress-errors':
            suppress_errors_file = val
        elif opt == '--stdin-filename':
            stdin_filename = val

    if not filenames:
        PrintUsage('No files were specified.')

    _SetOutputFormat(output_format)
    _SetVerboseLevel(verbosity)
    _SetFilters(filters)
    _SetCountingStyle(counting_style)
    _SuppressErrorsFrom(suppress_errors_file)
    _RecordErrorsTo(record_errors_file)
    _cpplint_state.stdin_filename = stdin_filename

    return filenames


def main():
    filenames = ParseArguments(sys.argv[1:])

    _cpplint_state.ResetErrorCounts()
    for filename in filenames:
        ProcessFile(filename, _cpplint_state.verbose_level)
    _cpplint_state.PrintErrorCounts()

    sys.exit(_cpplint_state.error_count > 0)


if __name__ == '__main__':
    main()

# vim: ts=4 sts=4 sw=4 foldmarker=▶,▲

# Ignore "too complex" warnings when using pymode.
# pylama:ignore=C901
