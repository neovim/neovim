local pretty = require 'pl.pretty'
local global_helpers = require('test.helpers')

local colors

local isWindows = package.config:sub(1,1) == '\\'

if isWindows then
  colors = setmetatable({}, {__index = function() return function(s) return s end end})
else
  colors = require 'term.colors'
end

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  local c = {
    succ = function(s) return colors.bright(colors.green(s)) end,
    skip = function(s) return colors.bright(colors.yellow(s)) end,
    fail = function(s) return colors.bright(colors.magenta(s)) end,
    errr = function(s) return colors.bright(colors.red(s)) end,
    test = tostring,
    file = colors.cyan,
    time = colors.dim,
    note = colors.yellow,
    sect = function(s) return colors.green(colors.dim(s)) end,
    nmbr = colors.bright,
  }

  local repeatSuiteString = '\nRepeating all tests (run %d of %d) . . .\n\n'
  local randomizeString  = c.note('Note: Randomizing test order with a seed of %d.\n')
  local globalSetup      = c.sect('[----------]') .. ' Global test environment setup.\n'
  local fileStartString  = c.sect('[----------]') .. ' Running tests from ' .. c.file('%s') .. '\n'
  local runString        = c.sect('[ RUN      ]') .. ' ' .. c.test('%s') .. ': '
  local successString    = c.succ('OK')   .. '\n'
  local skippedString    = c.skip('SKIP') .. '\n'
  local failureString    = c.fail('FAIL') .. '\n'
  local errorString      = c.errr('ERR')  .. '\n'
  local fileEndString    = c.sect('[----------]') .. ' '.. c.nmbr('%d') .. ' %s from ' .. c.file('%s') .. ' ' .. c.time('(%.2f ms total)') .. '\n\n'
  local globalTeardown   = c.sect('[----------]') .. ' Global test environment teardown.\n'
  local suiteEndString   = c.sect('[==========]') .. ' ' .. c.nmbr('%d') .. ' %s from ' .. c.nmbr('%d') .. ' test %s ran. ' .. c.time('(%.2f ms total)') .. '\n'
  local successStatus    = c.succ('[  PASSED  ]') .. ' ' .. c.nmbr('%d') .. ' %s.\n'
  local timeString       = c.time('%.2f ms')

  local summaryStrings = {
    skipped = {
      header = c.skip('[ SKIPPED  ]') .. ' ' .. c.nmbr('%d') .. ' %s, listed below:\n',
      test   = c.skip('[ SKIPPED  ]') .. ' %s\n',
      footer = ' ' .. c.nmbr('%d') .. ' SKIPPED %s\n',
    },

    failure = {
      header = c.fail('[  FAILED  ]') .. ' ' .. c.nmbr('%d') .. ' %s, listed below:\n',
      test   = c.fail('[  FAILED  ]') .. ' %s\n',
      footer = ' ' .. c.nmbr('%d') .. ' FAILED %s\n',
    },

    error = {
      header = c.errr('[  ERROR   ]') .. ' ' .. c.nmbr('%d') .. ' %s, listed below:\n',
      test   = c.errr('[  ERROR   ]') .. ' %s\n',
      footer = ' ' .. c.nmbr('%d') .. ' %s\n',
    },
  }

  local fileCount = 0
  local fileTestCount = 0
  local testCount = 0
  local successCount = 0
  local skippedCount = 0
  local failureCount = 0
  local errorCount = 0

  local pendingDescription = function(pending)
    local string = ''

    if type(pending.message) == 'string' then
      string = string .. pending.message .. '\n'
    elseif pending.message ~= nil then
      string = string .. pretty.write(pending.message) .. '\n'
    end

    return string
  end

  local failureDescription = function(failure)
    local string = failure.randomseed and ('Random seed: ' .. failure.randomseed .. '\n') or ''
    if type(failure.message) == 'string' then
      string = string .. failure.message
    elseif failure.message == nil then
      string = string .. 'Nil error'
    else
      string = string .. pretty.write(failure.message)
    end

    string = string .. '\n'

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. failure.trace.traceback .. '\n'
    end

    return string
  end

  local getFileLine = function(element)
    local fileline = ''
    if element.trace or element.trace.short_src then
      fileline = colors.cyan(element.trace.short_src) .. ' @ ' ..
                 colors.cyan(element.trace.currentline) .. ': '
    end
    return fileline
  end

  local getTestList = function(status, count, list, getDescription)
    local string = ''
    local header = summaryStrings[status].header
    if count > 0 and header then
      local tests = (count == 1 and 'test' or 'tests')
      local errors = (count == 1 and 'error' or 'errors')
      string = header:format(count, status == 'error' and errors or tests)

      local testString = summaryStrings[status].test
      if testString then
        for _, t in ipairs(list) do
          local fullname = getFileLine(t.element) .. colors.bright(t.name)
          string = string .. testString:format(fullname)
          string = string .. getDescription(t)
        end
      end
    end
    return string
  end

  local getSummary = function(status, count)
    local string = ''
    local footer = summaryStrings[status].footer
    if count > 0 and footer then
      local tests = (count == 1 and 'TEST' or 'TESTS')
      local errors = (count == 1 and 'ERROR' or 'ERRORS')
      string = footer:format(count, status == 'error' and errors or tests)
    end
    return string
  end

  local getSummaryString = function()
    local tests = (successCount == 1 and 'test' or 'tests')
    local string = successStatus:format(successCount, tests)

    string = string .. getTestList('skipped', skippedCount, handler.pendings, pendingDescription)
    string = string .. getTestList('failure', failureCount, handler.failures, failureDescription)
    string = string .. getTestList('error', errorCount, handler.errors, failureDescription)

    string = string .. ((skippedCount + failureCount + errorCount) > 0 and '\n' or '')
    string = string .. getSummary('skipped', skippedCount)
    string = string .. getSummary('failure', failureCount)
    string = string .. getSummary('error', errorCount)

    return string
  end

  handler.suiteReset = function()
    fileCount = 0
    fileTestCount = 0
    testCount = 0
    successCount = 0
    skippedCount = 0
    failureCount = 0
    errorCount = 0

    return nil, true
  end

  handler.suiteStart = function(_suite, count, total, randomseed)
    if total > 1 then
      io.write(repeatSuiteString:format(count, total))
    end
    if randomseed then
      io.write(randomizeString:format(randomseed))
    end
    io.write(globalSetup)
    io.flush()

    return nil, true
  end

  local function getElapsedTime(tbl)
    if tbl.duration then
      return tbl.duration * 1000
    else
      return tonumber('nan')
    end
  end

  handler.suiteEnd = function(suite, _count, _total)
    local elapsedTime_ms = getElapsedTime(suite)
    local tests = (testCount == 1 and 'test' or 'tests')
    local files = (fileCount == 1 and 'file' or 'files')
    io.write(globalTeardown)
    io.write(global_helpers.read_nvim_log())
    io.write(suiteEndString:format(testCount, tests, fileCount, files, elapsedTime_ms))
    io.write(getSummaryString())
    io.flush()

    return nil, true
  end

  handler.fileStart = function(file)
    fileTestCount = 0
    io.write(fileStartString:format(file.name))
    io.flush()
    return nil, true
  end

  handler.fileEnd = function(file)
    local elapsedTime_ms = getElapsedTime(file)
    local tests = (fileTestCount == 1 and 'test' or 'tests')
    fileCount = fileCount + 1
    io.write(fileEndString:format(fileTestCount, tests, file.name, elapsedTime_ms))
    io.flush()
    return nil, true
  end

  handler.testStart = function(element, _parent)
    io.write(runString:format(handler.getFullName(element)))
    io.flush()

    return nil, true
  end

  local function write_status(element, string)
    io.write(timeString:format(getElapsedTime(element)) .. ' ' .. string)
    io.flush()
  end

  handler.testEnd = function(element, _parent, status, _debug)
    local string

    fileTestCount = fileTestCount + 1
    testCount = testCount + 1
    if status == 'success' then
      successCount = successCount + 1
      string = successString
    elseif status == 'pending' then
      skippedCount = skippedCount + 1
      string = skippedString
    elseif status == 'failure' then
      failureCount = failureCount + 1
      string = failureString .. failureDescription(handler.failures[#handler.failures])
    elseif status == 'error' then
      errorCount = errorCount + 1
      string = errorString .. failureDescription(handler.errors[#handler.errors])
    else
      string = "unexpected test status! ("..status..")"
    end
    write_status(element, string)

    return nil, true
  end

  handler.error = function(element, _parent, _message, _debug)
    if element.descriptor ~= 'it' then
      write_status(element, failureDescription(handler.errors[#handler.errors]))
      errorCount = errorCount + 1
    end

    return nil, true
  end

  busted.subscribe({ 'suite', 'reset' }, handler.suiteReset)
  busted.subscribe({ 'suite', 'start' }, handler.suiteStart)
  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)
  busted.subscribe({ 'file', 'start' }, handler.fileStart)
  busted.subscribe({ 'file', 'end' }, handler.fileEnd)
  busted.subscribe({ 'test', 'start' }, handler.testStart, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'test', 'end' }, handler.testEnd, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'failure' }, handler.error)
  busted.subscribe({ 'error' }, handler.error)

  return handler
end
