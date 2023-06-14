local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local ok = helpers.ok
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local pcall_err = helpers.pcall_err

local function v(ver)
  return vim.version._version(ver)
end

describe('version', function()

  it('package', function()
    clear()
    eq({ major = 42, minor = 3, patch = 99 }, exec_lua("return vim.version.parse('v42.3.99')"))
  end)

  it('version() returns Nvim version', function()
    local expected = exec_lua('return vim.fn.api_info().version')
    local actual = exec_lua('return vim.version()')
    eq(expected.major, actual.major)
    eq(expected.minor, actual.minor)
    eq(expected.patch, actual.patch)
    eq(expected.prerelease and 'dev' or nil, actual.prerelease)

    -- tostring() #23863
    matches([[%d+%.%d+%.%d+]], exec_lua('return tostring(vim.version())'))
  end)

  describe('_version()', function()
    local tests = {
      ['v1.2.3'] = { major = 1, minor = 2, patch = 3 },
      ['v1.2'] = { major = 1, minor = 2, patch = 0 },
      ['v1.2.3-prerelease'] = { major = 1, minor = 2, patch = 3, prerelease = 'prerelease' },
      ['v1.2-prerelease'] = { major = 1, minor = 2, patch = 0, prerelease = 'prerelease' },
      ['v1.2.3-prerelease+build'] = { major = 1, minor = 2, patch = 3, prerelease = 'prerelease', build = 'build' },
      ['1.2.3+build'] = { major = 1, minor = 2, patch = 3, build = 'build' },
    }
    for input, output in pairs(tests) do
      it('parses ' .. input, function()
        eq(output, v(input))
      end)
    end
  end)

  describe('range', function()
    local tests = {
      ['1.2.3'] = { from = { 1, 2, 3 }, to = { 1, 2, 4 } },
      ['1.2'] = { from = { 1, 2, 0 }, to = { 1, 3, 0 } },
      ['=1.2.3'] = { from = { 1, 2, 3 }, to = { 1, 2, 4 } },
      ['>1.2.3'] = { from = { 1, 2, 4 } },
      ['>=1.2.3'] = { from = { 1, 2, 3 } },
      ['<1.2.3'] = { from = { 0, 0, 0 }, to = { 1, 2, 3 } },
      ['<=1.2.3'] = { from = { 0, 0, 0 }, to = { 1, 2, 4 } },
      ['~1.2.3'] = { from = { 1, 2, 3 }, to = { 1, 3, 0 } },
      ['^1.2.3'] = { from = { 1, 2, 3 }, to = { 2, 0, 0 } },
      ['^0.2.3'] = { from = { 0, 2, 3 }, to = { 0, 3, 0 } },
      ['^0.0.1'] = { from = { 0, 0, 1 }, to = { 0, 0, 2 } },
      ['^1.2'] = { from = { 1, 2, 0 }, to = { 2, 0, 0 } },
      ['~1.2'] = { from = { 1, 2, 0 }, to = { 1, 3, 0 } },
      ['~1'] = { from = { 1, 0, 0 }, to = { 2, 0, 0 } },
      ['^1'] = { from = { 1, 0, 0 }, to = { 2, 0, 0 } },
      ['1.*'] = { from = { 1, 0, 0 }, to = { 2, 0, 0 } },
      ['1'] = { from = { 1, 0, 0 }, to = { 2, 0, 0 } },
      ['1.x'] = { from = { 1, 0, 0 }, to = { 2, 0, 0 } },
      ['1.2.x'] = { from = { 1, 2, 0 }, to = { 1, 3, 0 } },
      ['1.2.*'] = { from = { 1, 2, 0 }, to = { 1, 3, 0 } },
      ['*'] = { from = { 0, 0, 0 } },
      ['1.2 - 2.3.0'] = { from = { 1, 2, 0 }, to = { 2, 3, 0 } },
      ['1.2.3 - 2.3.4'] = { from = { 1, 2, 3 }, to = { 2, 3, 4 } },
      ['1.2.3 - 2'] = { from = { 1, 2, 3 }, to = { 3, 0, 0 } },
    }
    for input, output in pairs(tests) do
      output.from = v(output.from)
      output.to = output.to and v(output.to)
      local range = vim.version.range(input)

      it('parses ' .. input, function()
        eq(output, range)
      end)

      it('[from] in range ' .. input, function()
        assert(range:has(output.from))
      end)

      it('[from-1] not in range ' .. input, function()
        local lower = vim.deepcopy(range.from)
        lower.major = lower.major - 1
        assert(not range:has(lower))
      end)

      it('[to] not in range ' .. input .. ' to:' .. tostring(range.to), function()
        if range.to then
          assert(not (range.to < range.to))
          assert(not range:has(range.to))
        end
      end)
    end

    it('handles prerelease', function()
      assert(not vim.version.range('1.2.3'):has('1.2.3-alpha'))
      assert(vim.version.range('1.2.3-alpha'):has('1.2.3-alpha'))
      assert(not vim.version.range('1.2.3-alpha'):has('1.2.3-beta'))
    end)
  end)

  describe('cmp()', function()
    local testcases = {
      { v1 = 'v0.0.99',          v2 = 'v9.0.0',           want = -1, },
      { v1 = 'v0.4.0',           v2 = 'v0.9.99',          want = -1, },
      { v1 = 'v0.2.8',           v2 = 'v1.0.9',           want = -1, },
      { v1 = 'v0.0.0',           v2 = 'v0.0.0',           want = 0, },
      { v1 = 'v9.0.0',           v2 = 'v0.9.0',           want = 1, },
      { v1 = 'v0.9.0',           v2 = 'v0.0.0',           want = 1, },
      { v1 = 'v0.0.9',           v2 = 'v0.0.0',           want = 1, },
      { v1 = 'v0.0.9+aaa',       v2 = 'v0.0.9+bbb',       want = 0, },

      -- prerelease 💩 https://semver.org/#spec-item-11
      { v1 = 'v1.0.0-alpha',     v2 = 'v1.0.0',           want = -1, },
      { v1 = '1.0.0',            v2 = '1.0.0-alpha',      want = 1, },
      { v1 = '1.0.0-2',          v2 = '1.0.0-1',          want = 1, },
      { v1 = '1.0.0-2',          v2 = '1.0.0-9',          want = -1, },
      { v1 = '1.0.0-2',          v2 = '1.0.0-2.0',        want = -1, },
      { v1 = '1.0.0-2.0',        v2 = '1.0.0-2',          want = 1, },
      { v1 = '1.0.0-2.0',        v2 = '1.0.0-2.0',        want = 0, },
      { v1 = '1.0.0-alpha',      v2 = '1.0.0-alpha',      want = 0, },
      { v1 = '1.0.0-alpha',      v2 = '1.0.0-beta',       want = -1, },
      { v1 = '1.0.0-beta',       v2 = '1.0.0-alpha',      want = 1, },
      { v1 = '1.0.0-alpha',      v2 = '1.0.0-alpha.1',    want = -1, },
      { v1 = '1.0.0-alpha.1',    v2 = '1.0.0-alpha',      want = 1, },
      { v1 = '1.0.0-alpha.beta', v2 = '1.0.0-alpha',      want = 1, },
      { v1 = '1.0.0-alpha',      v2 = '1.0.0-alpha.beta', want = -1, },
      { v1 = '1.0.0-alpha.beta', v2 = '1.0.0-beta',       want = -1, },
      { v1 = '1.0.0-beta.2',     v2 = '1.0.0-beta.11',    want = -1, },
      { v1 = '1.0.0-beta.20',    v2 = '1.0.0-beta.11',    want = 1, },
      { v1 = '1.0.0-alpha.20',   v2 = '1.0.0-beta.11',    want = -1, },
      { v1 = '1.0.0-a.01.x.3',   v2 = '1.0.0-a.1.x.003',  want = 0, },
      { v1 = 'v0.9.0-dev-92+9',  v2 = 'v0.9.0-dev-120+3', want = -1, },
    }
    for _, tc in ipairs(testcases) do
      local msg = function(s) return ('v1 %s v2'):format(s == 0 and '==' or (s == 1 and '>' or '<')) end
      it(string.format('(v1 = %s, v2 = %s)', tc.v1, tc.v2),
        function()
          local rv = vim.version.cmp(tc.v1, tc.v2, { strict = true })
          ok(tc.want == rv, msg(tc.want), msg(rv))
        end
      )
    end
  end)

  describe('parse()', function()
    describe('strict=true', function()
      local testcases = {
        { desc = 'Nvim version',         version = 'v0.9.0-dev-1233+g210120dde81e', want = { major = 0, minor = 9, patch = 0, prerelease = 'dev-1233', build = 'g210120dde81e', }, },
        { desc = 'no v',                 version = '10.20.123', want = { major = 10, minor = 20, patch = 123, prerelease = nil, build = nil, }, },
        { desc = 'with v',               version = 'v1.2.3', want = { major = 1, minor = 2, patch = 3 }, },
        { desc = 'prerelease',           version = '1.2.3-alpha', want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha' }, },
        { desc = 'prerelease.x',         version = '1.2.3-alpha.1', want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha.1' }, },
        { desc = 'build.x',              version = '1.2.3+build.15', want = { major = 1, minor = 2, patch = 3, build = 'build.15' }, },
        { desc = 'prerelease and build', version = '1.2.3-rc1+build.15', want = { major = 1, minor = 2, patch = 3, prerelease = 'rc1', build = 'build.15', }, },
      }
      for _, tc in ipairs(testcases) do
        it(
          string.format('%q: version = %q', tc.desc, tc.version),
          function()
            eq(tc.want, vim.version.parse(tc.version))
          end
        )
      end
    end)

    describe('strict=false', function()
      local testcases = {
        { version = '1.2',      want = { major = 1, minor = 2, patch = 0 }, },
        { version = '1',        want = { major = 1, minor = 0, patch = 0 }, },
        { version = '1.1-0',    want = { major = 1, minor = 1, patch = 0, prerelease = '0' }, },
        { version = '1-1.0',    want = { major = 1, minor = 0, patch = 0, prerelease = '1.0' }, },
        { version = 'v1.2.3  ', want = { major = 1, minor = 2, patch = 3 }, },
        { version = '  v1.2.3', want = { major = 1, minor = 2, patch = 3 }, },
        { version = 'tmux 3.2a', want = { major = 3, minor = 2, patch = 0, }, },
      }
      for _, tc in ipairs(testcases) do
        it(
          string.format('version = %q', tc.version),
          function()
            eq(tc.want, vim.version.parse(tc.version, { strict = false }))
          end
        )
      end
    end)

    describe('invalid semver', function()
      local testcases = {
        { version = 'foo' },
        { version = '' },
        { version = '0.0.0.' },
        { version = '.0.0.0' },
        { version = '-1.0.0' },
        { version = '0.-1.0' },
        { version = '0.0.-1' },
        { version = 'foobar1.2.3' },
        { version = '1.2.3foobar' },
        { version = '1.2.3-%?' },
        { version = '1.2.3+%?' },
        { version = '1.2.3+build.0-rc1' },
        { version = '3.2a', },
        { version = 'tmux 3.2a', },
      }

      local function quote_empty(s)
        return tostring(s) == '' and '""' or tostring(s)
      end

      for _, tc in ipairs(testcases) do
        it(quote_empty(tc.version), function()
          eq(nil, vim.version.parse(tc.version, { strict = true }))
        end)
      end
    end)

    describe('invalid shape', function()
      local testcases = {
        { desc = 'no parameters' },
        { desc = 'nil', version = nil },
        { desc = 'number', version = 0 },
        { desc = 'float', version = 0.01 },
        { desc = 'table', version = {} },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('(%s): %s', tc.desc, tostring(tc.version)), function()
          local expected = string.format(type(tc.version) == 'string'
            and 'invalid version: "%s"' or 'invalid version: %s', tostring(tc.version))
          matches(expected, pcall_err(vim.version.parse, tc.version, { strict = true }))
        end)
      end
    end)
  end)

  it('relational metamethods (== < >)', function()
    assert(v('v1.2.3') == v('1.2.3'))
    assert(not (v('v1.2.3') < v('1.2.3')))
    assert(v('v1.2.3') > v('1.2.3-prerelease'))
    assert(v('v1.2.3-alpha') < v('1.2.3-beta'))
    assert(v('v1.2.3-prerelease') < v('1.2.3'))
    assert(v('v1.2.3') >= v('1.2.3'))
    assert(v('v1.2.3') >= v('1.0.3'))
    assert(v('v1.2.3') >= v('1.2.2'))
    assert(v('v1.2.3') > v('1.2.2'))
    assert(v('v1.2.3') > v('1.0.3'))
    eq(vim.version.last({ v('1.2.3'), v('2.0.0') }), v('2.0.0'))
    eq(vim.version.last({ v('2.0.0'), v('1.2.3') }), v('2.0.0'))
  end)

  it('lt()', function()
    eq(true, vim.version.lt('1', '2'))
    eq(false, vim.version.lt({3}, {0, 7, 4}))
    eq(false, vim.version.lt({major=3, minor=3, patch=0}, {3, 2, 0}))
  end)

  it('gt()', function()
    eq(true, vim.version.gt('2', '1'))
    eq(true, vim.version.gt({3}, {0, 7, 4}))
    eq(true, vim.version.gt({major=3, minor=3, patch=0}, {3, 2, 0}))
  end)

  it('eq()', function()
    eq(true, vim.version.eq('2', '2'))
    eq(true, vim.version.eq({3, 1, 0}, '3.1.0'))
    eq(true, vim.version.eq({major=3, minor=3, patch=0}, {3, 3, 0}))
  end)
end)
