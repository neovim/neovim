-- TODO replace with a better implementation.
local function json_encode(data)
  local status, result = pcall(vim.fn.json_encode, data)
  if status then
    return result
  else
    return nil, result
  end
end
local function json_decode(data)
  local status, result = pcall(vim.fn.json_decode, data)
  if status then
    return result
  else
    return nil, result
  end
end

local function format_message_with_content_length(encoded_message)
  return table.concat {
    'Content-Length: '; tostring(#encoded_message); '\r\n\r\n';
    encoded_message;
  }
end

local function read_message()
	local line = io.read("*l")
	local length = line:lower():match("content%-length:%s*(%d+)")
	return assert(json_decode(io.read(2 + length):sub(2)))
end

local function send(payload)
	io.stdout:write(format_message_with_content_length(json_encode(payload)))
end

local function respond(id, err, result)
	assert(type(id) == 'number', "id must be a number")
	send { id = id, error = err, result = result }
end

local function notify(method, params)
	assert(type(method) == 'string', "method must be a string")
	send { method = method, params = params or {} }
end

io.stderr:setvbuf("no")
io.stderr:write("hello!")

local tests = {}

function tests.basic_init()
	local init_req = read_message()
	respond(init_req.id, nil, { capabilities = {} })
	notify('test')
	assert(read_message().method == "initialized")
	local shutdown_req = read_message()
	assert(shutdown_req.method == "shutdown", shutdown_req.method)
	respond(shutdown_req.id, nil, {})
	assert(read_message().method == 'exit')
end

local test_name = _G.TEST_NAME
assert(type(test_name) == 'string', 'TEST_NAME must be specified.')
assert(tests[test_name], "Test not found")()
os.exit(0)
