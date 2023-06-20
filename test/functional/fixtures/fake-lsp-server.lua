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
      string.format("left == %q, right == %q",
        table.concat(vim.split(vim.inspect(a), "\n"), ""),
        table.concat(vim.split(vim.inspect(b), "\n"), "")
      )
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
  return vim.json.decode(io.read(2 + length):sub(2))
end

local function send(payload)
  io.stdout:write(format_message_with_content_length(vim.json.encode(payload)))
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
  if params then
    assert_eq(params, message.params,
        ..., "expect_notification", method, "params")
    assert_eq({jsonrpc = "2.0"; method=method, params=params}, message,
        ..., "expect_notification", "message")
  end
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
    on_init = function(_)
      return {
        capabilities = {
          textDocumentSync = protocol.TextDocumentSyncKind.None;
        }
      }
    end;
    body = function()
      notify('test')
    end;
  }
end

function tests.basic_init_did_change_configuration()
  skeleton({
    on_init = function(_)
      return {
        capabilities = {},
      }
    end,
    body = function()
      expect_notification('workspace/didChangeConfiguration', { settings = { dummy = 1 } })
    end,
  })
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
              { section = "test.Setting3" };
              { section = "test.Setting4" };
          } })
      expect_notification('workspace/configuration', { true; false; 'nested'; vim.NIL})
      notify('shutdown')
    end;
  }
end

function tests.prepare_rename_nil()
  skeleton {
    on_init = function()
      return { capabilities = {
        renameProvider = {
            prepareProvider = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_request('textDocument/prepareRename', function()
        return nil, nil
      end)
      notify('shutdown')
    end;
  }
end

function tests.prepare_rename_placeholder()
  skeleton {
    on_init = function()
      return { capabilities = {
        renameProvider = {
            prepareProvider = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_request('textDocument/prepareRename', function()
        return nil, {placeholder = 'placeholder'}
      end)
      expect_request('textDocument/rename', function(params)
        assert_eq(params.newName, 'renameto')
        return nil, nil
      end)
      notify('shutdown')
    end;
  }
end

function tests.prepare_rename_range()
  skeleton {
    on_init = function()
      return { capabilities = {
        renameProvider = {
            prepareProvider = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_request('textDocument/prepareRename', function()
        return nil, {
          start = { line = 1, character = 8 },
          ['end'] = { line = 1, character = 12 },
        }
      end)
      expect_request('textDocument/rename', function(params)
        assert_eq(params.newName, 'renameto')
        return nil, nil
      end)
      notify('shutdown')
    end;
  }
end

function tests.prepare_rename_error()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          renameProvider = {
            prepareProvider = true
          },
        }
      }
    end;
    body = function()
      notify('start')
      expect_request('textDocument/prepareRename', function()
        return {}, nil
      end)
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
          codeLensProvider = false
        }
      }
    end;
    body = function()
    end;
  }
end

function tests.text_document_save_did_open()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          textDocumentSync = {
            save = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_notification('textDocument/didClose')
      expect_notification('textDocument/didOpen')
      expect_notification('textDocument/didSave')
      notify('shutdown')
    end;
  }
end

function tests.text_document_sync_save_bool()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          textDocumentSync = {
            save = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_notification('textDocument/didSave', {textDocument = { uri = "file://" }})
      notify('shutdown')
    end;
  }
end

function tests.text_document_sync_save_includeText()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          textDocumentSync = {
            save = {
              includeText = true
            }
          }
        }
      }
    end;
    body = function()
      notify('start')
      expect_notification('textDocument/didSave', {
        textDocument = {
          uri = "file://"
        },
        text = "help me\n"
      })
      notify('shutdown')
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
          renameProvider = false;
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

function tests.check_forward_request_cancelled()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
      expect_request("error_code_test", function()
        return {code = -32800}, nil, {method = "error_code_test", client_id=1}
      end)
      notify('finish')
    end;
  }
end

function tests.check_forward_content_modified()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
      expect_request("error_code_test", function()
        return {code = -32801}, nil, {method = "error_code_test", client_id=1}
      end)
      expect_notification('finish')
      notify('finish')
    end;
  }
end

function tests.check_pending_request_tracked()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
        local msg = read_message()
        assert_eq('slow_request', msg.method)
        expect_notification('release')
        respond(msg.id, nil, {})
        expect_notification('finish')
        notify('finish')
    end;
  }
end

function tests.check_cancel_request_tracked()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
        local msg = read_message()
        assert_eq('slow_request', msg.method)
        expect_notification('$/cancelRequest', {id=msg.id})
        expect_notification('release')
        respond(msg.id, {code = -32800}, nil)
        notify('finish')
    end;
  }
end

function tests.check_tracked_requests_cleared()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
        local msg = read_message()
        assert_eq('slow_request', msg.method)
        expect_notification('$/cancelRequest', {id=msg.id})
        expect_notification('release')
        respond(msg.id, nil, {})
        expect_notification('finish')
        notify('finish')
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
          textDocumentSync = {
            openClose = true,
            change = protocol.TextDocumentSyncKind.Incremental,
            willSave = true,
            willSaveWaitUntil = true,
            save = {
              includeText = true,
            }
          }
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

function tests.decode_nil()
  skeleton {
    on_init = function(_)
      return { capabilities = {} }
    end;
    body = function()
      notify('start')
      notify("workspace/executeCommand", {
        arguments = { "EXTRACT_METHOD", {metadata = {field = vim.NIL}}, 3, 0, 6123, vim.NIL },
        command = "refactor.perform",
        title = "EXTRACT_METHOD"
      })
      notify('finish')
    end;
  }
end


function tests.code_action_with_resolve()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          codeActionProvider = {
            resolveProvider = true
          }
        }
      }
    end;
    body = function()
      notify('start')
      local cmd = {
        title = 'Command 1',
        command = 'dummy1'
      }
      expect_request('textDocument/codeAction', function()
        return nil, { cmd, }
      end)
      expect_request('codeAction/resolve', function()
        return nil, cmd
      end)
      notify('shutdown')
    end;
  }
end

function tests.code_action_server_side_command()
  skeleton({
    on_init = function()
      return {
        capabilities = {
          codeActionProvider = {
            resolveProvider = false,
          },
          executeCommandProvider = {
            commands = {"dummy1"}
          },
        },
      }
    end,
    body = function()
      notify('start')
      local cmd = {
        title = 'Command 1',
        command = 'dummy1',
      }
      expect_request('textDocument/codeAction', function()
        return nil, { cmd }
      end)
      expect_request('workspace/executeCommand', function()
        return nil, cmd
      end)
      notify('shutdown')
    end,
  })
end


function tests.code_action_filter()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          codeActionProvider = {
            resolveProvider = false
          }
        }
      }
    end;
    body = function()
      notify('start')
      local action = {
        title = 'Action 1',
        command = 'command'
      }
      local preferred_action = {
        title = 'Action 2',
        isPreferred = true,
        command = 'preferred_command',
      }
      local type_annotate_action = {
        title = 'Action 3',
        kind = 'type-annotate',
        command = 'type_annotate_command',
      }
      local type_annotate_foo_action = {
        title = 'Action 4',
        kind = 'type-annotate.foo',
        command = 'type_annotate_foo_command',
      }
      expect_request('textDocument/codeAction', function()
        return nil, { action, preferred_action, type_annotate_action, type_annotate_foo_action, }
      end)
      expect_request('textDocument/codeAction', function()
        return nil, { action, preferred_action, type_annotate_action, type_annotate_foo_action, }
      end)
      notify('shutdown')
    end;
  }
end

function tests.clientside_commands()
  skeleton {
    on_init = function()
      return {
        capabilities = {}
      }
    end;
    body = function()
      notify('start')
      notify('shutdown')
    end;
  }
end

function tests.codelens_refresh_lock()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          codeLensProvider = { resolveProvider = true; };
        }
      }
    end;
    body = function()
      notify('start')
      expect_request("textDocument/codeLens", function ()
        return {code = -32002, message = "ServerNotInitialized"}, nil
      end)
      expect_request("textDocument/codeLens", function ()
        local lenses = {
          {
            range = {
              start = { line = 0, character = 0, },
              ['end'] = { line = 0, character = 3 }
            },
            command = { title = 'Lens1', command = 'Dummy' }
          },
        }
        return nil, lenses
      end)
      expect_request("textDocument/codeLens", function ()
        local lenses = {
          {
            range = {
              start = { line = 0, character = 0, },
              ['end'] = { line = 0, character = 3 }
            },
            command = { title = 'Lens2', command = 'Dummy' }
          },
        }
        return nil, lenses
      end)
      notify('shutdown')
    end;
  }
end

function tests.basic_formatting()
  skeleton {
    on_init = function()
      return {
        capabilities = {
          documentFormattingProvider = true,
        }
      }
    end;
    body = function()
      notify('start')
      expect_request('textDocument/formatting', function()
        return nil, {}
      end)
      notify('shutdown')
    end;
  }
end

function tests.set_defaults_all_capabilities()
  skeleton {
    on_init = function(_)
      return {
        capabilities = {
          definitionProvider = true,
          completionProvider = true,
          documentRangeFormattingProvider = true,
        }
      }
    end;
    body = function()
      notify('test')
    end;
  }
end

-- Tests will be indexed by test_name
local test_name = arg[1]
local timeout = arg[2]
assert(type(test_name) == 'string', 'test_name must be specified as first arg.')

local kill_timer = vim.uv.new_timer()
kill_timer:start(timeout or 1e3, 0, function()
  kill_timer:stop()
  kill_timer:close()
  log('ERROR', 'LSP', 'TIMEOUT')
  io.stderr:write("TIMEOUT")
  os.exit(100)
end)

local status, err = pcall(assert(tests[test_name], "Test not found"))
kill_timer:stop()
kill_timer:close()
if not status then
  log('ERROR', 'LSP', tostring(err))
  io.stderr:write(err)
  vim.cmd [[101cquit]]
end
