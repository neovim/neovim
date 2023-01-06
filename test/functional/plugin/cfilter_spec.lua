local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs

describe('cfilter.lua', function()
  before_each(function()
    clear()
    command('packadd cfilter')
  end)

  for _, list in ipairs({
    {
      name = 'Cfilter',
      get = funcs.getqflist,
      set = funcs.setqflist,
    },
    {
      name = 'Lfilter',
      get = function()
        return funcs.getloclist(0)
      end,
      set = function(items)
        return funcs.setloclist(0, items)
      end,
    },
  }) do
    local filter = function(s, bang)
      if not bang then
        bang = ''
      else
        bang = '!'
      end

      command(string.format('%s%s %s', list.name, bang, s))
    end

    describe((':%s'):format(list.name), function()
      it('does not error on empty list', function()
        filter('nothing')
        eq({}, funcs.getqflist())
      end)

      it('requires an argument', function()
        local ok = pcall(filter, '')
        eq(false, ok)
      end)

      local test = function(name, s, res, map, bang)
        it(('%s (%s)'):format(name, s), function()
          list.set({
            { filename = 'foo', lnum = 1, text = 'bar' },
            { filename = 'foo', lnum = 2, text = 'baz' },
            { filename = 'foo', lnum = 3, text = 'zed' },
          })

          filter(s, bang)

          local got = list.get()
          if map then
            got = map(got)
          end
          eq(res, got)
        end)
      end

      local toname = function(qflist)
        return funcs.map(qflist, 'v:val.text')
      end

      test('filters with no matches', 'does not match', {})

      test('filters with matches', 'ba', { 'bar', 'baz' }, toname)
      test('filters with matches', 'z', { 'baz', 'zed' }, toname)
      test('filters with matches', '^z', { 'zed' }, toname)
      test('filters with not matches', '^z', { 'bar', 'baz' }, toname, true)

      it('also supports using the / register', function()
        list.set({
          { filename = 'foo', lnum = 1, text = 'bar' },
          { filename = 'foo', lnum = 2, text = 'baz' },
          { filename = 'foo', lnum = 3, text = 'zed' },
        })

        funcs.setreg('/', 'ba')
        filter('/')

        eq({ 'bar', 'baz' }, toname(list.get()))
      end)

      it('also supports using the / register with bang', function()
        list.set({
          { filename = 'foo', lnum = 1, text = 'bar' },
          { filename = 'foo', lnum = 2, text = 'baz' },
          { filename = 'foo', lnum = 3, text = 'zed' },
        })

        funcs.setreg('/', 'ba')
        filter('/', true)

        eq({ 'zed' }, toname(list.get()))
      end)
    end)
  end
end)
