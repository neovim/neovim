local helpers = require('test.functional.helpers')(after_each)
local global_helpers = require('test.helpers')

local meths = helpers.meths
local clear = helpers.clear
local eval = helpers.eval
local eq = helpers.eq
local iswin = helpers.iswin
local matches = helpers.matches
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir

describe('logging', function()
  local datasubdir = iswin() and 'nvim-data' or 'nvim'
  local xdgdir = 'Xtest-xdg-logpath'
  local xdgdatadir = xdgdir..'/'..datasubdir
  after_each(function()
    os.remove('Xtest-logpath')
    rmdir(xdgdir)
  end)

  describe('$NVIM_LOG_FILE', function()
    it('is used if expansion succeeds', function()
      clear({env={
        NVIM_LOG_FILE='Xtest-logpath',
      }})
      eq('Xtest-logpath', eval('$NVIM_LOG_FILE'))
    end)
    it('defaults to stdpath("data")/log if empty', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgdatadir))
      clear({env={
        XDG_DATA_HOME=xdgdir,
        NVIM_LOG_FILE='',  -- Empty is invalid.
      }})
      eq(xdgdir..'/'..datasubdir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
    it('defaults to stdpath("data")/log if invalid', function()
      eq(true, mkdir(xdgdir) and mkdir(xdgdatadir))
      clear({env={
        XDG_DATA_HOME=xdgdir,
        NVIM_LOG_FILE='.',  -- Any directory is invalid.
      }})
      eq(xdgdir..'/'..datasubdir..'/log', string.gsub(eval('$NVIM_LOG_FILE'), '\\', '/'))
    end)
    it('defaults to .nvimlog if stdpath("data") is invalid', function()
      clear({env={
        XDG_DATA_HOME='Xtest-missing-xdg-dir',
        NVIM_LOG_FILE='.',  -- Any directory is invalid.
      }})
      eq('.nvimlog', eval('$NVIM_LOG_FILE'))
    end)
  end)

  describe('nvim_log()', function()
    it('acceptance', function()
      clear({env={
        NVIM_LOG_FILE='Xtest-logpath',
      }})

      -- TODO
      -- The tests are commented out because only error logs are printed
      -- in the ci. Can run the tests locally by specifying a low enough
      -- MIN_LOG_LEVEL.
      -- meths.log('debug', 'low-level log message...', {})
      -- meths.log('info', 'you did it! :D', {})
      -- meths.log('warn', 'beware of dragons ノ( º _ ºノ)', {})
      meths.log('error', 'problem (╯°□°)╯︵ ┻━┻', {})

      print(eval('$NVIM_LOG_FILE'))
      local loglines = global_helpers.read_file(eval('$NVIM_LOG_FILE'))
      -- ERROR 2020-01-12T01:56:19.484 93296 (null):(null): test log message :D
      -- matches{
      --    '.*DEBUG%s+[^ ]+ %d+%s+%(null%):%(null%): you did it! :D.*',
      --    loglines)
      -- matches(
      --   '.*INFO%s+[^ ]+ %d+%s+%(null%):%(null%): you did it! :D.*',
      --   loglines)
      -- matches(
      --   '.*WARN%s+[^ ]+ %d+%s+%(null%):%(null%): beware of dragons ノ%( º _ ºノ%).*',
      --   loglines)
      matches(
        '.*ERROR%s+[^ ]+ %d+%s+testclient:remote: problem %(╯°□°%)╯︵ ┻━┻.*',
        loglines)
    end)
  end)
end)
