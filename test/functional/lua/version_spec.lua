local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local pcall_err = helpers.pcall_err
local matches = helpers.matches

local version = require('vim.version')

describe('version', function()
  describe('cmp()', function()
    local testcases = {
      {
        desc = 'v1 < v2',
        v1 = 'v0.0.0',
        v2 = 'v9.0.0',
        want = -1,
      },
      {
        desc = 'v1 < v2',
        v1 = 'v0.0.0',
        v2 = 'v0.9.0',
        want = -1,
      },
      {
        desc = 'v1 < v2',
        v1 = 'v0.0.0',
        v2 = 'v0.0.9',
        want = -1,
      },
      {
        desc = 'v1 == v2',
        v1 = 'v0.0.0',
        v2 = 'v0.0.0',
        want = 0,
      },
      {
        desc = 'v1 > v2',
        v1 = 'v9.0.0',
        v2 = 'v0.0.0',
        want = 1,
      },
      {
        desc = 'v1 > v2',
        v1 = 'v0.9.0',
        v2 = 'v0.0.0',
        want = 1,
      },
      {
        desc = 'v1 > v2',
        v1 = 'v0.0.9',
        v2 = 'v0.0.0',
        want = 1,
      },
      {
        desc = 'v1 < v2 when v1 has prerelease',
        v1 = 'v1.0.0-alpha',
        v2 = 'v1.0.0',
        want = -1,
      },
      {
        desc = 'v1 > v2 when v2 has prerelease',
        v1 = '1.0.0',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = 'v1 > v2 when v1 has a higher number identifier',
        v1 = '1.0.0-2',
        v2 = '1.0.0-1',
        want = 1,
      },
      {
        desc = 'v1 < v2 when v2 has a higher number identifier',
        v1 = '1.0.0-2',
        v2 = '1.0.0-9',
        want = -1,
      },
      {
        desc = 'v1 < v2 when v2 has more identifiers',
        v1 = '1.0.0-2',
        v2 = '1.0.0-2.0',
        want = -1,
      },
      {
        desc = 'v1 > v2 when v1 has more identifiers',
        v1 = '1.0.0-2.0',
        v2 = '1.0.0-2',
        want = 1,
      },
      {
        desc = 'v1 == v2 when v2 has same numeric identifiers',
        v1 = '1.0.0-2.0',
        v2 = '1.0.0-2.0',
        want = 0,
      },
      {
        desc = 'v1 == v2 when v2 has same alphabet identifiers',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha',
        want = 0,
      },
      {
        desc = 'v1 < v2 when v2 has an alphabet identifier with a higher ASCII sort order',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-beta',
        want = -1,
      },
      {
        desc = 'v1 > v2 when v1 has an alphabet identifier with a higher ASCII sort order',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = 'v1 < v2 when v2 has prerelease and number identifer',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha.1',
        want = -1,
      },
      {
        desc = 'v1 > v2 when v1 has prerelease and number identifer',
        v1 = '1.0.0-alpha.1',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = 'v1 > v2 when v1 has an additional alphabet identifier',
        v1 = '1.0.0-alpha.beta',
        v2 = '1.0.0-alpha',
        want = 1,
      },
      {
        desc = 'v1 < v2 when v2 has an additional alphabet identifier',
        v1 = '1.0.0-alpha',
        v2 = '1.0.0-alpha.beta',
        want = -1,
      },
      {
        desc = 'v1 < v2 when v2 has an a first alphabet identifier with higher precedence',
        v1 = '1.0.0-alpha.beta',
        v2 = '1.0.0-beta',
        want = -1,
      },
      {
        desc = 'v1 > v2 when v1 has an a first alphabet identifier with higher precedence',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-alpha.beta',
        want = 1,
      },
      {
        desc = 'v1 < v2 when v2 has an additional number identifer',
        v1 = '1.0.0-beta',
        v2 = '1.0.0-beta.2',
        want = -1,
      },
      {
        desc = 'v1 < v2 when v2 has same first alphabet identifier but has a higher number identifer',
        v1 = '1.0.0-beta.2',
        v2 = '1.0.0-beta.11',
        want = -1,
      },
      {
        desc = 'v1 < v2 when v2 has higher alphabet precedence',
        v1 = '1.0.0-beta.11',
        v2 = '1.0.0-rc.1',
        want = -1,
      },
    }
    for _, tc in ipairs(testcases) do
      it(
        string.format('returns %d if %s (v1 = %s, v2 = %s)', tc.want, tc.desc, tc.v1, tc.v2),
        function()
          eq(tc.want, version.cmp(tc.v1, tc.v2, { strict = true }))
        end
      )
    end
  end)

  describe('parse()', function()
    describe('parsing', function()
      describe('strict = true', function()
        local testcases = {
          {
            desc = 'a version without leading "v"',
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
            desc = 'a valid version with a leading "v"',
            version = 'v1.2.3',
            want = { major = 1, minor = 2, patch = 3 },
          },
          {
            desc = 'a valid version with leading "v" and whitespace',
            version = '  v1.2.3',
            want = { major = 1, minor = 2, patch = 3 },
          },
          {
            desc = 'a valid version with leading "v" and trailing whitespace',
            version = 'v1.2.3  ',
            want = { major = 1, minor = 2, patch = 3 },
          },
          {
            desc = 'a version with a prerelease',
            version = '1.2.3-alpha',
            want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha' },
          },
          {
            desc = 'a version with a prerelease with additional identifiers',
            version = '1.2.3-alpha.1',
            want = { major = 1, minor = 2, patch = 3, prerelease = 'alpha.1' },
          },
          {
            desc = 'a version with a build',
            version = '1.2.3+build.15',
            want = { major = 1, minor = 2, patch = 3, build = 'build.15' },
          },
          {
            desc = 'a version with a prerelease and build',
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
            string.format('returns correct table for %q: version = %q', tc.desc, tc.version),
            function()
              eq(tc.want, version.parse(tc.version, { strict = true }))
            end
          )
        end
      end)

      describe('strict = false', function()
        local testcases = {
          {
            desc = 'a version missing patch version',
            version = '1.2',
            want = { major = 1, minor = 2, patch = 0 },
          },
          {
            desc = 'a version missing minor and patch version',
            version = '1',
            want = { major = 1, minor = 0, patch = 0 },
          },
          {
            desc = 'a version missing patch version with prerelease',
            version = '1.1-0',
            want = { major = 1, minor = 1, patch = 0, prerelease = '0' },
          },
          {
            desc = 'a version missing minor and patch version with prerelease',
            version = '1-1.0',
            want = { major = 1, minor = 0, patch = 0, prerelease = '1.0' },
          },
        }
        for _, tc in ipairs(testcases) do
          it(
            string.format('returns correct table for %q: version = %q', tc.desc, tc.version),
            function()
              eq(tc.want, version.parse(tc.version, { strict = false }))
            end
          )
        end
      end)
    end)

    describe('errors', function()
      describe('returns nil', function()
        local testcases = {
          { desc = 'a word', version = 'foo' },
          { desc = 'an empty string', version = '' },
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
          it(string.format('for %s: version = %s', tc.desc, tostring(tc.version)), function()
            eq(nil, version.parse(tc.version, { strict = true }))
          end)
        end
      end)

      describe('raises error', function()
        local testcases = {
          { desc = 'no parameters' },
          { desc = 'nil', version = nil },
          { desc = 'a number', version = 0 },
          { desc = 'a float', version = 0.01 },
          { desc = 'a table', version = {} },
        }
        for _, tc in ipairs(testcases) do
          it(string.format('for %s: version = %s', tc.desc, tostring(tc.version)), function()
            matches(
              string.format('invalid version: "%s"', tostring(tc.version)),
              pcall_err(function()
                version.parse(tc.version, { strict = true })
              end)
            )
          end)
        end
      end)
    end)
  end)

  describe('eq', function()
    describe('valid versions', function()
      local testcases = {
        {
          version_1 = '1.0.0',
          version_2 = '1.0.0',
          want = true,
        },
        {
          version_1 = '1.0.0',
          version_2 = 'v1.0.0',
          want = true,
        },
        {
          version_1 = '1.0.0',
          version_2 = '1.0',
          want = true,
        },
        {
          version_1 = '1.0.0',
          version_2 = '1',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = 'v1.0.0-alpha',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha+build.5',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha.1',
          version_2 = '1.0.0-alpha.1+build.5',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha.1',
          want = false,
        },
        {
          version_1 = '1.0.0',
          version_2 = '2.0.0',
          want = false,
        },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('returns %s for %s = %s', tc.want, tc.version_1, tc.version_2), function()
          eq(tc.want, version.eq(tc.version_1, tc.version_2))
        end)
      end
    end)

    describe('errors', function()
      local testcases = {
        {
          version_1 = '',
          version_2 = '1.0.0',
          err_version = '',
        },
        {
          version_1 = '1.0.0',
          version_2 = '',
          err_version = '',
        },
        {
          version_1 = '',
          version_2 = '',
          err_version = '',
        },
        {
          version_1 = '1.0.0',
          version_2 = 'foo',
          err_version = 'foo',
        },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('for %s = %s', tc.version_1, tc.version_2), function()
          matches(
            string.format('invalid version: "%s"', tc.err_version),
            pcall_err(function()
              version.eq(tc.version_1, tc.version_2)
            end)
          )
        end)
      end
    end)
  end)

  describe('lt', function()
    describe('valid versions', function()
      local testcases = {
        {
          version_1 = '1.0.0',
          version_2 = '1.0.1',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.1',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.1-beta',
          want = true,
        },
        {
          version_1 = '1.0.1',
          version_2 = '1.0.0',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha+build.5',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha+build.4',
          version_2 = '1.0.0-alpha+build.5',
          want = false,
        },
      }
      for _, tc in ipairs(testcases) do
        it(
          string.format('returns %s for %s < %s', tostring(tc.want), tc.version_1, tc.version_2),
          function()
            eq(tc.want, version.lt(tc.version_1, tc.version_2))
          end
        )
      end
    end)

    describe('errors', function()
      local testcases = {
        {
          version_1 = '',
          version_2 = '1.0.0',
          err_version = '',
        },
        {
          version_1 = '1.0.0',
          version_2 = '',
          err_version = '',
        },
        {
          version_1 = '',
          version_2 = '',
          err_version = '',
        },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('for %s < %s', tc.version_1, tc.version_2), function()
          matches(
            string.format('invalid version: "%s"', tc.err_version),
            pcall_err(function()
              version.lt(tc.version_1, tc.version_2)
            end)
          )
        end)
      end
    end)
  end)

  describe('gt', function()
    describe('valid versions', function()
      local testcases = {
        {
          version_1 = '1.0.1',
          version_2 = '1.0.0',
          want = true,
        },
        {
          version_1 = '1.0.1',
          version_2 = '1.0.1-alpha',
          want = true,
        },
        {
          version_1 = '1.0.0',
          version_2 = '1.0.1',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.1',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.1-beta',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha',
          want = false,
        },
        {
          version_1 = '1.0.0-beta',
          version_2 = '1.0.0-alpha',
          want = true,
        },
        {
          version_1 = '1.0.0-alpha',
          version_2 = '1.0.0-alpha+build.5',
          want = false,
        },
        {
          version_1 = '1.0.0-alpha+build.4',
          version_2 = '1.0.0-alpha+build.5',
          want = false,
        },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('returns %s for %s > %s', tc.want, tc.version_1, tc.version_2), function()
          eq(tc.want, version.gt(tc.version_1, tc.version_2))
        end)
      end
    end)

    describe('errors', function()
      local testcases = {
        {
          version_1 = '',
          version_2 = '1.0.0',
          err_version = '',
        },
        {
          version_1 = '1.0.0',
          version_2 = '',
          err_version = '',
        },
        {
          version_1 = '',
          version_2 = '',
          err_version = '',
        },
      }
      for _, tc in ipairs(testcases) do
        it(string.format('for %s < %s', tc.version_1, tc.version_2), function()
          matches(
            string.format('invalid version: "%s"', tc.err_version),
            pcall_err(function()
              version.gt(tc.version_1, tc.version_2)
            end)
          )
        end)
      end
    end)
  end)
end)
