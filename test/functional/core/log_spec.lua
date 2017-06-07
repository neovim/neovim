local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')

local meths = helpers.meths
local command = helpers.command
local clear = helpers.clear
local exc_exec = helpers.exc_exec
local eval = helpers.eval
local eq = helpers.eq
local funcs = helpers.funcs
local insert = helpers.insert
local iswin = helpers.iswin
local neq = helpers.neq
local matches = helpers.matches
local mkdir = helpers.mkdir
local rmdir = helpers.rmdir
local alter_slashes = helpers.alter_slashes
local tbl_contains = helpers.tbl_contains

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
      -- meths.log('debug', 'low-level log message...', {})
      -- meths.log('info', 'you did it! :D', {})
      -- meths.log('warn', 'beware of dragons ノ( º _ ºノ)', {})
      meths.log('error', 'problem (╯°□°)╯︵ ┻━┻', {})

      local loglines = funcs.readfile(eval('$NVIM_LOG_FILE'))
      -- ERROR 2020-01-12T01:56:19.484 93296 (null):(null): test log message :D
      matches(
        'ERROR [^ ]+ %d+ testclient:remote: problem %(╯°□°%)╯︵ ┻━┻',
        loglines[2])
    end)
  end)
end)
