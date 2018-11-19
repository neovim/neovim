-- TODO(jkeyes): Use the upstream version when busted releases it. (But how to
-- inject our call to global_helpers.read_nvim_log() ?)

local pretty = require 'pl.pretty'
local global_helpers = require('test.helpers')

return function(options)
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'()

  local success = 'ok %u - %s'
  local failure = 'not ' .. success
  local skip = 'ok %u - # SKIP %s'
  local counter = 0

  handler.suiteReset = function()
    counter = 0
    return nil, true
  end

  handler.suiteEnd = function()
    io.write(global_helpers.read_nvim_log())
    print('1..' .. counter)
    io.flush()
    return nil, true
  end

  local function showFailure(t)
    local message = t.message
    local trace = t.trace or {}

    if message == nil then
      message = 'Nil error'
    elseif type(message) ~= 'string' then
      message = pretty.write(message)
    end

    print(failure:format(counter, t.name))
    print('# ' .. t.element.trace.short_src .. ' @ ' .. t.element.trace.currentline)
    if t.randomseed then print('# Random seed: ' .. t.randomseed) end
    print('# Failure message: ' .. message:gsub('\n', '\n# '))
    if options.verbose and trace.traceback then
      print('# ' .. trace.traceback:gsub('^\n', '', 1):gsub('\n', '\n# '))
    end
  end

  handler.testStart = function(element, parent)
    local trace = element.trace
    if options.verbose and trace and trace.short_src then
      local fileline = trace.short_src .. ' @ ' ..  trace.currentline .. ': '
      local testName = fileline .. handler.getFullName(element)
      print('# ' .. testName)
    end
    io.flush()

    return nil, true
  end

  handler.testEnd = function(element, parent, status, trace)
    counter = counter + 1
    if status == 'success' then
      local t = handler.successes[#handler.successes]
      print(success:format(counter, t.name))
    elseif status == 'pending' then
      local t = handler.pendings[#handler.pendings]
      print(skip:format(counter, (t.message or t.name)))
    elseif status == 'failure' then
      showFailure(handler.failures[#handler.failures])
    elseif status == 'error' then
      showFailure(handler.errors[#handler.errors])
    end
    io.flush()

    return nil, true
  end

  handler.error = function(element, parent, message, debug)
    if element.descriptor ~= 'it' then
      counter = counter + 1
      showFailure(handler.errors[#handler.errors])
    end
    io.flush()

    return nil, true
  end

  busted.subscribe({ 'suite', 'reset' }, handler.suiteReset)
  busted.subscribe({ 'suite', 'end' }, handler.suiteEnd)
  busted.subscribe({ 'test', 'start' }, handler.testStart, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'test', 'end' }, handler.testEnd, { predicate = handler.cancelOnPending })
  busted.subscribe({ 'error' }, handler.error)

  return handler
end
