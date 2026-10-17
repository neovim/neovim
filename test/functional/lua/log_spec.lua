local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local assert_log = t.assert_log
local assert_nolog = t.assert_nolog
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local write_file = t.write_file

describe('vim.log', function()
  local xstate = 'Xstate-log'

  ---@param name string
  ---@return string
  local function get_logfile(name)
    return exec_lua(function(logger_name)
      return vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath('log'), logger_name:lower() .. '.log'))
    end, name)
  end

  before_each(function()
    clear({ env = { XDG_STATE_HOME = xstate } })
  end)

  it('new() creates a logger with the documented defaults', function()
    local info = exec_lua(function()
      local logger = vim.log.new('MyPlugin')
      local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'myplugin.log')
      logger.info('skip')
      logger.warn('keep')
      return {
        level = logger:get_level(),
        writers = {
          type(logger.trace),
          type(logger.debug),
          type(logger.info),
          type(logger.warn),
          type(logger.error),
        },
        logfile = vim.fs.normalize(logfile),
        exists = vim.uv.fs_stat(logfile) ~= nil,
      }
    end)

    eq(3, info.level)
    eq({ 'function', 'function', 'function', 'function', 'function' }, info.writers)
    eq(get_logfile('MyPlugin'), info.logfile)
    eq(true, info.exists)

    local logfile = get_logfile('MyPlugin')
    assert_log('%[START%]%[.+%] MyPlugin logging initiated', logfile, 10)
    assert_log('%[WARN%].-\t"keep"', logfile, 10)
    assert_nolog('skip', logfile, 10)
  end)

  it('writer methods do nothing when called nil arguments', function()
    eq(
      { true, true, true, true, true, false },
      exec_lua(function()
        local logger = vim.log.new('NoArgs', { level = vim.log.levels.TRACE })
        local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'noargs.log')
        return {
          logger.trace(),
          logger.debug(),
          logger.info(),
          logger.warn(),
          logger.error(),
          vim.uv.fs_stat(logfile) ~= nil,
        }
      end)
    )
  end)

  it('writer methods called with no args report should-log status', function()
    eq(
      { false, false, true, true, true, false },
      exec_lua(function()
        local logger = vim.log.new('ShouldLog', { level = vim.log.levels.INFO })
        local logfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'shouldlog.log')
        return {
          logger.trace(),
          logger.debug(),
          logger.info(),
          logger.warn(),
          logger.error(),
          vim.uv.fs_stat(logfile) ~= nil,
        }
      end)
    )
  end)

  it('new() respects level and fmt opts', function()
    exec_lua(function()
      local logger = vim.log.new('CustomFormat', {
        level = vim.log.levels.INFO,
        fmt = function(min_level, level, ...)
          if level < min_level then
            return nil
          end
          return tostring(select(1, ...)) .. '\n'
        end,
      })

      logger.trace('trace')
      logger.debug('debug')
      logger.info('info')
      logger.warn('warn')
      logger.error('error')
    end)

    local logfile = get_logfile('CustomFormat')
    assert_log('%[START%]%[.+%] CustomFormat logging initiated', logfile, 10)
    assert_nolog('trace', logfile, 10)
    assert_nolog('debug', logfile, 10)
    assert_log('info', logfile, 10)
    assert_log('warn', logfile, 10)
    assert_log('error', logfile, 10)
  end)

  it('set_level() changes filtering and get_level() reports the new level', function()
    local level = exec_lua(function()
      local logger = vim.log.new('SetLevel')

      logger:set_level(vim.log.levels.INFO)
      logger.debug('skip')
      logger.info('keep')

      return logger:get_level()
    end)

    eq(2, level)

    local logfile = get_logfile('SetLevel')
    assert_log('%[START%]%[.+%] SetLevel logging initiated', logfile, 10)
    assert_log('keep', logfile, 10)
    assert_nolog('skip', logfile, 10)
  end)

  it('overriding log.fmt replaces the formatter and can skip entries', function()
    exec_lua(function()
      local logger = vim.log.new('SetFormat', {
        level = vim.log.levels.TRACE,
        fmt = function()
          return 'old\n'
        end,
      })

      logger.fmt = function(min_level, level, ...)
        return table.concat({ 'new', min_level, level, tostring(select(1, ...)) }, '|') .. '\n'
      end

      logger.error('formatted')

      logger.fmt = function()
        return nil
      end

      logger.error('skip-me')
    end)

    local logfile = get_logfile('SetFormat')
    assert_log('%[START%]%[.+%] SetFormat logging initiated', logfile, 10)
    assert_log('formatted', logfile, 10)
    assert_nolog('old', logfile, 10)
    assert_nolog('skip%-me', logfile, 10)
  end)

  it('default formatter logs the real caller source and line', function()
    local caller_script = t.tmpname(false) .. '.lua'
    write_file(
      caller_script,
      "local logger = vim.log.new('Caller', { level = vim.log.levels.TRACE })\n"
        .. "logger.info('from-script')\n",
      true
    )

    exec_lua(function(path)
      vim.cmd('source ' .. vim.fn.fnameescape(path))
    end, caller_script)

    local logfile = get_logfile('Caller')
    local expected = exec_lua(function(path)
      return vim.pesc(vim.fn.fnamemodify(path, ':t'))
    end, caller_script)
    assert_log(expected .. ':2', logfile, 10)
    assert_log('from%-script', logfile, 10)
    assert_nolog('runtime/lua/vim/log%.lua', logfile, 10)
  end)
end)
