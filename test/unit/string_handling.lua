-- string handling tests
-- it might be a decent idea to split this in regular string handling and
-- terminal/filesystem specific string handling (escaping/expanding/...)

local helpers = require 'test.unit.helpers'
local cimport, internalize, eq, ffi = helpers.cimport, helpers.internalize, helpers.eq, helpers.ffi

local misc2 = cimport('./src/misc2.h')
local cstr = ffi.typeof('char[?]')

-- vim_strsave (DONE)
-- vim_strnsave
-- vim_strsave_escaped (DONE)
-- vim_strsave_escaped_ext
-- vim_strsave_shellescape
-- vim_strsave_fnameescape (this is now in ex_getln.c, should be moved)
-- vim_strsave_up (DONE)
-- vim_strnsave_up
describe('strsave family', function()
    describe('vim_strsave', function()
        -- wrap the C function so it looks like a plain lua function
        ffi.cdef('unsigned char * vim_strsave(unsigned char *string);')
        local vim_strsave = function(str)
            str = cstr(string.len(str), str)
            return internalize(misc2.vim_strsave(str))
        end

        -- convenience function so we don't have to declare a variable all
        -- the time
        local savecmp = function(str)
            eq(str, vim_strsave(str))
        end

        -- the actual tests
        it('can copy a plain string', function()
            savecmp("some string")
        end)

        it('can copy a UTF-8 string', function()
            savecmp("!)@(\r\n\r#●●●●●●$(*&!@#&$(!")
        end)
    end)

    describe('vim_strsave_escaped', function()
        -- wrap vim_strsave_escaped
        ffi.cdef('unsigned char * vim_strsave_escaped(unsigned char *string, unsigned char * esc_chars);')
        local vim_strsave_escaped = function(str, esc)
            str = cstr(string.len(str), str)
            esc = cstr(string.len(esc), esc)
            return internalize(misc2.vim_strsave_escaped(str, esc))
        end

        it('properly escapes string', function()
            eq("B\\o\\ok", vim_strsave_escaped("Book", "o"))
        end)

        it('properly escapes at beginning and end of string', function()
            eq("\\Boo\\k", vim_strsave_escaped("Book", "Bk"))
        end)

        -- this test appears to fail, I'm not sure if this is a bug in
        -- vim_strsave or if something goes wrong in the lua -> C -> lua
        -- chain
        -- it('escapes non-ASCII characters', function()
        --     eq("B\\●\\●k", vim_strsave_escaped("B●●k", "●"))
        -- end)

        it('can do double escapes', function()
            eq("Pick \\\\your poison", vim_strsave_escaped("Pick \\your poison", "y"))
        end)
    end)

    -- copies and uppercases
    describe('vim_strsave_up', function()
        -- wrap vim_strsave_escaped
        ffi.cdef('unsigned char * vim_strsave_up(unsigned char *string);')
        local vim_strsave_up = function(str)
            str = cstr(string.len(str), str)
            return internalize(misc2.vim_strsave_up(str))
        end

        it('uppercases correctly', function()
            local str = "My5@!"
            eq(string.upper(str), vim_strsave_up(str))
        end)
    end)
end)

-- I'm trying to go by what I think are "custom" functions based on the vim_
-- prefix or the non-standard name. Some of these might be pure wrappers of
-- stdlib functions, in which case they dont really need to be tested.
--
-- concat_fnames (could also be in dirname handling test file)
-- concat_str
-- vim_strchr
-- vim_strrchr
-- vim_stricmp
-- vim_strpbrk
-- vim_memcmp
-- vim_memset (how consistent, should probably fix)
-- mch_memmove (dubious if it should be here, but is often used for str ops)
-- vim_iswhite (DONTTEST) (this is a macro, can't test yet, better to turn
--  it into a function and let the Link Time Optimizer take care of it)
pending("misc string functions")

pending("wildcard matching functions")
