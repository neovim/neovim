local protocol = require'vim.lsp.protocol'

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

local function assert_eq(a, b, message)
	if not vim.deep_equal(a, b) then
		local errm = string.format("assert_eq failed: left == %q, right == %q", vim.inspect(a), vim.inspect(b))
		if message then
			errm = message..": "..errm
		end
		error(errm)
	end
end

local function assert_(a, message)
	if not a then
		local errm = string.format("assert_ failed: %q", vim.inspect(a))
		if message then
			errm = message..": "..errm
		end
		error(errm)
	end
end

local function expect_notification(method, params)
	local message = read_message()
	assert_eq(method, message.method, "expect_notification method")
	assert_eq(params, message.params, "expect_notification "..method.." params")
	assert_eq({jsonrpc = "2.0"; method=method, params=params}, message, "expect_notification "..method.." message")
end

io.stderr:setvbuf("no")
io.stderr:write("hello!")

local function skeleton(params)
	local on_init = assert(params.on_init)
	local body = assert(params.body)
	do
		local init_req = read_message()
		assert_eq("initialize", init_req.method)
		respond(init_req.id, nil, on_init(init_req.params))
	end
	assert_eq("initialized", read_message().method)
	body()
	do
		local shutdown_req = read_message()
		assert(shutdown_req.method == "shutdown", "expected shutdown, found "..shutdown_req.method)
		respond(shutdown_req.id, nil, {})
	end
	assert(read_message().method == 'exit')
end

local tests = {}

function tests.basic_init()
	skeleton {
		on_init = function(_params)
			return { capabilities = {} }
		end;
		body = function()
			notify('test')
		end;
	}
end

function tests.basic_check_capabilities()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
		end;
	}
end

function tests.basic_finish()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.basic_check_buffer_open()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
			notify('start')
			expect_notification('textDocument/didOpen', {
				textDocument = {
					languageId = "";
					text = table.concat({"testing"; "123"}, "\n");
					uri = "file://";
					version = 0;
				};
			})
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.basic_check_buffer_open_and_change()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
			notify('start')
			expect_notification('textDocument/didOpen', {
				textDocument = {
					languageId = "";
					text = table.concat({"testing"; "123"}, "\n");
					uri = "file://";
					version = 0;
				};
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 3;
				};
				contentChanges = {
					{ text = table.concat({"testing"; "boop"}, "\n"); };
				}
			})
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.basic_check_buffer_open_and_change_multi()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
			notify('start')
			expect_notification('textDocument/didOpen', {
				textDocument = {
					languageId = "";
					text = table.concat({"testing"; "123"}, "\n");
					uri = "file://";
					version = 0;
				};
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 3;
				};
				contentChanges = {
					{ text = table.concat({"testing"; "321"}, "\n"); };
				}
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 4;
				};
				contentChanges = {
					{ text = table.concat({"testing"; "boop"}, "\n"); };
				}
			})
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.basic_check_buffer_open_and_change_multi_and_close()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Full;
				}
			}
		end;
		body = function()
			notify('start')
			expect_notification('textDocument/didOpen', {
				textDocument = {
					languageId = "";
					text = table.concat({"testing"; "123"}, "\n");
					uri = "file://";
					version = 0;
				};
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 3;
				};
				contentChanges = {
					{ text = table.concat({"testing"; "321"}, "\n"); };
				}
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 4;
				};
				contentChanges = {
					{ text = table.concat({"testing"; "boop"}, "\n"); };
				}
			})
			expect_notification('textDocument/didClose', {
				textDocument = {
					uri = "file://";
				};
			})
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.basic_check_buffer_open_and_change_incremental()
	skeleton {
		on_init = function(params)
			local expected_capabilities = protocol.make_client_capabilities()
			assert(vim.deep_equal(params.capabilities, expected_capabilities))
			return {
				capabilities = {
					textDocumentSync = protocol.TextDocumentSyncKind.Incremental;
				}
			}
		end;
		body = function()
			notify('start')
			expect_notification('textDocument/didOpen', {
				textDocument = {
					languageId = "";
					text = table.concat({"testing"; "123"}, "\n");
					uri = "file://";
					version = 0;
				};
			})
			expect_notification('textDocument/didChange', {
				textDocument = {
					uri = "file://";
					version = 3;
				};
				contentChanges = {
					{
						range = {
							start = { line = 1; character = 0; };
							["end"] = { line = 2; character = 0; };
						};
						rangeLength = 4;
						text = "boop\n";
					};
				}
			})
			expect_notification("finish")
			notify('finish')
		end;
	}
end

function tests.invalid_header()
	io.stdout:write("Content-length: \r\n")
end

local test_name = _G.TEST_NAME
assert(type(test_name) == 'string', 'TEST_NAME must be specified.')
assert(tests[test_name], "Test not found")()
os.exit(0)
