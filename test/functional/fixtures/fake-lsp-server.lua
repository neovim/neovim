local protocol = require 'vim.lsp.protocol'


-- Logs to $NVIM_LOG_FILE.
--
-- TODO(justinmk): remove after https://github.com/neovim/neovim/pull/7062
local function log(loglevel, area, msg)
  vim.fn.writefile(
    {string.format('%s %s: %s', loglevel, area, msg)},
    vim.env.NVIM_LOG_FILE,
    'a')
end

local function message_parts(sep, ...)
  local parts = {}
  for i = 1, select("#", ...) do
    local arg = select(i, ...)
    if arg ~= nil then
      table.insert(parts, arg)
    end
  end
  return table.concat(parts, sep)
end

-- Assert utility methods

local function assert_eq(a, b, ...)
  if not vim.deep_equal(a, b) then
    error(message_parts(": ",
      ..., "assert_eq failed",
      string.format("left == %q, right == %q", vim.inspect(a), vim.inspect(b))
    ))
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
  return vim.fn.json_decode(io.read(2 + length):sub(2))
end

local function send(payload)
  io.stdout:write(format_message_with_content_length(vim.fn.json_encode(payload)))
end

local function respond(id, err, result)
  assert(type(id) == 'number', "id must be a number")
  send { jsonrpc = "2.0"; id = id, error = err, result = result }
end

local function notify(method, params)
  assert(type(method) == 'string', "method must be a string")
  send { method = method, params = params or {} }
end

local function expect_notification(method, params, ...)
  local message = read_message()
  assert_eq(method, message.method,
      ..., "expect_notification", "method")
  assert_eq(params, message.params,
      ..., "expect_notification", method, "params")
  assert_eq({jsonrpc = "2.0"; method=method, params=params}, message,
      ..., "expect_notification", "message")
end

local function expect_request(method, handler, ...)
  local req = read_message()
  assert_eq(method, req.method,
      ..., "expect_request", "method")
  local err, result = handler(req.params)
  respond(req.id, err, result)
end

io.stderr:setvbuf("no")

local function skeleton(config)
  local on_init = assert(config.on_init)
  local body = assert(config.body)
  expect_request("initialize", function(params)
    return nil, on_init(params)
  end)
  expect_notification("initialized", {})
  body()
  expect_request("shutdown", function()
    return nil, {}
  end)
  expect_notification("exit", nil)
end

-- The actual tests.

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

function tests.check_workspace_configuration()
  skeleton {
    on_init = function(_params)
      return { capabilities = {} }
    end;
    body = function()
      notify('start')
      notify('workspace/configuration', { items = {
              { section = "testSetting1" };
              { section = "testSetting2" };
          } })
      expect_notification('workspace/configuration', { true; vim.NIL})
      notify('shutdown')
    end;
  }
end

function tests.basic_check_capabilities()
  skeleton {
    on_init = function(params)
      local expected_capabilities = protocol.make_client_capabilities()
      assert_eq(params.capabilities, expected_capabilities)
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

function tests.capabilities_for_client_supports_method()
  skeleton {
    on_init = function(params)
      local expected_capabilities = protocol.make_client_capabilities()
      assert_eq(params.capabilities, expected_capabilities)
      return {
        capabilities = {
          textDocumentSync = protocol.TextDocumentSyncKind.Full;
          completionProvider = true;
          hoverProvider = true;
          definitionProvider = false;
          referencesProvider = false;
          codeLensProvider = { resolveProvider = true; };
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
      assert_eq(params.capabilities, expected_capabilities)
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
      assert_eq(params.capabilities, expected_capabilities)
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
          text = table.concat({"testing"; "123"}, "\n") .. '\n';
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
      assert_eq(params.capabilities, expected_capabilities)
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
          text = table.concat({"testing"; "123"}, "\n") .. '\n';
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
          { text = table.concat({"testing"; "boop"}, "\n") .. '\n'; };
        }
      })
      expect_notification("finish")
      notify('finish')
    end;
  }
end

function tests.basic_check_buffer_open_and_change_noeol()
  skeleton {
    on_init = function(params)
      local expected_capabilities = protocol.make_client_capabilities()
      assert_eq(params.capabilities, expected_capabilities)
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
      assert_eq(params.capabilities, expected_capabilities)
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
          text = table.concat({"testing"; "123"}, "\n") .. '\n';
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
          { text = table.concat({"testing"; "321"}, "\n") .. '\n'; };
        }
      })
      expect_notification('textDocument/didChange', {
        textDocument = {
          uri = "file://";
          version = 4;
        };
        contentChanges = {
          { text = table.concat({"testing"; "boop"}, "\n") .. '\n'; };
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
      assert_eq(params.capabilities, expected_capabilities)
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
          text = table.concat({"testing"; "123"}, "\n") .. '\n';
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
          { text = table.concat({"testing"; "321"}, "\n") .. '\n'; };
        }
      })
      expect_notification('textDocument/didChange', {
        textDocument = {
          uri = "file://";
          version = 4;
        };
        contentChanges = {
          { text = table.concat({"testing"; "boop"}, "\n") .. '\n'; };
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
      assert_eq(params.capabilities, expected_capabilities)
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
          text = table.concat({"testing"; "123"}, "\n") .. '\n';
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
              start = { line = 1; character = 3; };
              ["end"] = { line = 1; character = 3; };
            };
            rangeLength = 0;
            text = "boop";
          };
        }
      })
      expect_notification("finish")
      notify('finish')
    end;
  }
end

function tests.basic_check_buffer_open_and_change_incremental_editing()
  skeleton {
    on_init = function(params)
      local expected_capabilities = protocol.make_client_capabilities()
      assert_eq(params.capabilities, expected_capabilities)
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
              start = { line = 0; character = 0; };
              ["end"] = { line = 1; character = 0; };
            };
            rangeLength = 4;
            text = "testing\n\n";
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

-- Tests will be indexed by TEST_NAME

local kill_timer = vim.loop.new_timer()
kill_timer:start(_G.TIMEOUT or 1e3, 0, function()
  kill_timer:stop()
  kill_timer:close()
  log('ERROR', 'LSP', 'TIMEOUT')
  io.stderr:write("TIMEOUT")
  os.exit(100)
end)

local test_name = _G.TEST_NAME -- lualint workaround
assert(type(test_name) == 'string', 'TEST_NAME must be specified.')
local status, err = pcall(assert(tests[test_name], "Test not found"))
kill_timer:stop()
kill_timer:close()
if not status then
  log('ERROR', 'LSP', tostring(err))
  io.stderr:write(err)
  os.exit(101)
end
os.exit(0)
