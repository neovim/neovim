local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local pcall_err = helpers.pcall_err

local version = require('vim.version')

local function quote_empty(s)
  return tostring(s) == '' and '""' or tostring(s)
end

describe('version', function()
  it('package', function()
    clear()
    eq({ major = 42, minor = 3, patch = 99 }, exec_lua("return vim.version.parse('v42.3.99')"))
  end)

  describe('cmp()', function()
    local testcases = {
      {
        desc = '(v1 < v2)',
        v1 = 'v0.0.99',
        v2 = 'v9.0.0',
        want = -1,
      },
      {
        desc = '(v1 < v2)',
        v1 = 'v0.4.0',
        v2 = 'v0.9.99',
        want = -1,
      },
      {
        desc = '(v1 < v2)',
        v1 = 'v0.2.8',
        v2 = 'v1.0.9',
        want = -1,
      },
      {
        desc = '(v1 == v2)',
        v1 = 'v0.0.0',
        v2 = 'v0.0.0',
        want = 0,
      },
      {
        desc = '(v1 > v2)',
        v1 = 'v9.0.0',
        v2 = 'v0.9.0',
        want = 1,
      },
      {
        desc = '(v1 > v2)',
        v1 = 'v0.9.0',
        v2 = 'v0.0.0',
        want = 1,
      },
      {
        desc = '(v1 > v2)',
        v1 = 'v0.0.9',
        v2 = 'v0.0.0',
        want = 1,
      },
      {
        desc = '(v1 < v2) when v1 has prerelease',
        v1 = 'v1.0.0-alpha',
        v2 = 'v1.0.0',
        want = -1,
      },
      {
        desc = '(v1 > v2) when v2 has prerelease',
        v1 = '1.0.0',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = '(v1 > v2) when v1 has a higher number identifier',
        v1 = '1.0.0-2',
        v2 = '1.0.0-1',
        want = 1,
      },
      {
        desc = '(v1 < v2) when v2 has a higher number identifier',
        v1 = '1.0.0-2',
        v2 = '1.0.0-9',
        want = -1,
      },
      {
        desc = '(v1 < v2) when v2 has more identifiers',
        v1 = '1.0.0-2',
        v2 = '1.0.0-2.0',
        want = -1,
      },
      {
        desc = '(v1 > v2) when v1 has more identifiers',
        v1 = '1.0.0-2.0',
        v2 = '1.0.0-2',
        want = 1,
      },
      {
        desc = '(v1 == v2) when v2 has same numeric identifiers',
        v1 = '1.0.0-2.0',
        v2 = '1.0.0-2.0',
        want = 0,
      },
      {
        desc = '(v1 == v2) when v2 has same alphabet identifiers',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha',
        want = 0,
      },
      {
        desc = '(v1 < v2) when v2 has an alphabet identifier with higher ASCII sort order',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-beta',
        want = -1,
      },
      {
        desc = '(v1 > v2) when v1 has an alphabet identifier with higher ASCII sort order',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = '(v1 < v2) when v2 has prerelease and number identifer',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha.1',
        want = -1,
      },
      {
        desc = '(v1 > v2) when v1 has prerelease and number identifer',
        v1 = '1.0.0-alpha.1',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = '(v1 > v2) when v1 has an additional alphabet identifier',
        v1 = '1.0.0-alpha.beta',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = '(v1 < v2) when v2 has an additional alphabet identifier',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha.beta',
        want = -1,
      },
      {
        desc = '(v1 < v2) when v2 has an a first alphabet identifier with higher precedence',
        v1 = '1.0.0-alpha.beta',
        v2 = '1.0.0-beta',
        want = -1,
      },
      {
        desc = '(v1 > v2) when v1 has an a first alphabet identifier with higher precedence',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-alpha.beta',
        want = 1,
      },
      {
        desc = '(v1 < v2) when v2 has an additional number identifer',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-beta.2',
        want = -1,
      },
      {
        desc = '(v1 < v2) when v2 has same first alphabet identifier but has a higher number identifer',
        v1 = '1.0.0-beta.2',
        v2 = '1.0.0-beta.11',
        want = -1,
      },
      {
        desc = '(v1 < v2) when v2 has higher alphabet precedence',
        v1 = '1.0.0-beta.11',
        v2 = '1.0.0-rc.1',
        want = -1,
      },
    }
    for _, tc in ipairs(testcases) do
      it(
        string.format('%d %s (v1 = %s, v2 = %s)', tc.want, tc.desc, tc.v1, tc.v2),
        function()
          eq(tc.want, version.cmp(tc.v1, tc.v2, { strict = true }))
        end
      )
    end
  end)

  describe('parse()', function()
    describe('strict=true', function()
      local testcases = {
        {
          desc = 'version without leading "v"',
          version = '10.20.123',
          want = {
            major = 10,
            minor = 20,
            patch = 123,
            prerelease = nil,
            build = nil,
          },
        },
        {
          desc = 'valid version with leading "v"',
          version = 'v1.2.3',
          want = { major = 1, minor = 2, patch = 3 },
        },
        {
          desc = 'valid version with leading "v" and whitespace',
          version = '  v1.2.3',
          want = { major = 1, minor = 2, patch = 3 },
        },
        {
          desc = 'valid version with leading "v" and trailing whitespace',
          version = 'v1.2.3  ',
          want = { major = 1, minor = 2, patch = 3 },
        },
        {
          desc = 'version with prerelease',
          version = '1.2.3-alpha',
          want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha' },
        },
        {
          desc = 'version with prerelease with additional identifiers',
          version = '1.2.3-alpha.1',
          want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha.1' },
        },
        {
          desc = 'version with build',
          version = '1.2.3+build.15',
          want = { major = 1, minor = 2, patch = 3, build = 'build.15' },
        },
        {
          desc = 'version with prerelease and build',
          version = '1.2.3-rc1+build.15',
          want = {
            major = 1,
            minor = 2,
            patch = 3,
            prerelease = 'rc1',
            build = 'build.15',
          },
        },
      }
      for _, tc in ipairs(testcases) do
        it(
          string.format('for %q: version = %q', tc.desc, tc.version),
          function()
            eq(tc.want, version.parse(tc.version, { strict = true }))
          end
        )
      end
    end)

    describe('strict=false', function()
      local testcases = {
        {
          desc = 'version missing patch version',
          version = '1.2',
          want = { major = 1, minor = 2, patch = 0 },
        },
        {
          desc = 'version missing minor and patch version',
          version = '1',
          want = { major = 1, minor = 0, patch = 0 },
        },
        {
          desc = 'version missing patch version with prerelease',
          version = '1.1-0',
          want = { major = 1, minor = 1, patch = 0, prerelease = '0' },
        },
        {
          desc = 'version missing minor and patch version with prerelease',
          version = '1-1.0',
          want = { major = 1, minor = 0, patch = 0, prerelease = '1.0' },
        },
      }
      for _, tc in ipairs(testcases) do
        it(
          string.format('for %q: version = %q', tc.desc, tc.version),
          function()
            eq(tc.want, version.parse(tc.version, { strict = false }))
          end
        )
      end
    end)

    describe('invalid semver', function()
      local testcases = {
        { desc = 'a word', version = 'foo' },
        { desc = 'empty string', version = '' },
        { desc = 'trailing period character', version = '0.0.0.' },
        { desc = 'leading period character', version = '.0.0.0' },
        { desc = 'negative major version', version = '-1.0.0' },
        { desc = 'negative minor version', version = '0.-1.0' },
        { desc = 'negative patch version', version = '0.0.-1' },
        { desc = 'leading invalid string', version = 'foobar1.2.3' },
        { desc = 'trailing invalid string', version = '1.2.3foobar' },
        { desc = 'an invalid prerelease', version = '1.2.3-%?' },
        { desc = 'an invalid build', version = '1.2.3+%?' },
        { desc = 'build metadata before prerelease', version = '1.2.3+build.0-rc1' },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('(%s): %s', tc.desc, quote_empty(tc.version)), function()
          eq(nil, version.parse(tc.version, { strict = true }))
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
          matches(expected, pcall_err(version.parse, tc.version, { strict = true }))
        end)
      end
    end)
  end)

  it('lt()', function()
    eq(true, version.lt('1', '2'))
  end)

  it('gt()', function()
    eq(true, version.gt('2', '1'))
  end)

  it('eq()', function()
    eq(true, version.eq('2', '2'))
  end)
end)
