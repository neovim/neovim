local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)
--{:cimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'

local eq      = helpers.eq
local ffi     = helpers.ffi
local to_cstr = helpers.to_cstr
local NULL    = helpers.NULL

local fileio = helpers.cimport("./src/nvim/fileio.h")

describe('file_pat functions', function()
  describe('file_pat_to_reg_pat', function()

    local file_pat_to_reg_pat = function(pat)
      local res = fileio.file_pat_to_reg_pat(to_cstr(pat), NULL, NULL, 0)
      return ffi.string(res)
    end

    itp('returns ^path$ regex for literal path input', function()
      eq( '^path$', file_pat_to_reg_pat('path'))
    end)

    itp('does not prepend ^ when there is a starting glob (*)', function()
      eq('path$', file_pat_to_reg_pat('*path'))
    end)

    itp('does not append $ when there is an ending glob (*)', function()
      eq('^path', file_pat_to_reg_pat('path*'))
    end)

    itp('does not include ^ or $ when surrounded by globs (*)', function()
      eq('path', file_pat_to_reg_pat('*path*'))
    end)

    itp('replaces the bash any character (?) with the regex any character (.)', function()
     eq('^foo.bar$', file_pat_to_reg_pat('foo?bar'))
    end)

    itp('replaces a glob (*) in the middle of a path with regex multiple any character (.*)',
       function()
      eq('^foo.*bar$', file_pat_to_reg_pat('foo*bar'))
    end)

    itp([[unescapes \? to ?]], function()
      eq('^foo?bar$', file_pat_to_reg_pat([[foo\?bar]]))
    end)

    itp([[unescapes \% to %]], function()
      eq('^foo%bar$', file_pat_to_reg_pat([[foo\%bar]]))
    end)

    itp([[unescapes \, to ,]], function()
      eq('^foo,bar$', file_pat_to_reg_pat([[foo\,bar]]))
    end)

    itp([[unescapes '\ ' to ' ']], function()
      eq('^foo bar$', file_pat_to_reg_pat([[foo\ bar]]))
    end)

    itp([[escapes . to \.]], function()
      eq([[^foo\.bar$]], file_pat_to_reg_pat('foo.bar'))
    end)

    itp('Converts bash brace expansion {a,b} to regex options (a|b)', function()
      eq([[^foo\(bar\|baz\)$]], file_pat_to_reg_pat('foo{bar,baz}'))
    end)

    itp('Collapses multiple consecutive * into a single character', function()
      eq([[^foo.*bar$]], file_pat_to_reg_pat('foo*******bar'))
      eq([[foobar$]], file_pat_to_reg_pat('********foobar'))
      eq([[^foobar]], file_pat_to_reg_pat('foobar********'))
    end)

    itp('Does not escape ^', function()
      eq([[^^blah$]], file_pat_to_reg_pat('^blah'))
      eq([[^foo^bar$]], file_pat_to_reg_pat('foo^bar'))
    end)

    itp('Does not escape $', function()
      eq([[^blah$$]], file_pat_to_reg_pat('blah$'))
      eq([[^foo$bar$]], file_pat_to_reg_pat('foo$bar'))
    end)
  end)
end)
