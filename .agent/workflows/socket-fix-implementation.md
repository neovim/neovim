---
description: Implementation plan for socket handling enhancement
---

# Socket Handling Enhancement Implementation Plan

## Problem Summary

When Neovim crashes or is killed (SIGKILL), it leaves behind a stale socket file. When trying to start a new server with `--listen` or `serverstart()`, Neovim fails with "address already in use" error, even though no process is actually listening on that socket.

## Solution Approach

Implement graceful handling of existing socket files by:

1. Detecting when bind fails due to existing socket
2. Attempting to connect to the existing socket
3. Sending a test RPC request to verify if it's a live Neovim server
4. If dead/unresponsive, remove the stale socket and retry
5. If alive, report error to user
6. Log all actions at appropriate levels

## Files to Modify

### 1. `src/nvim/event/socket.c`

- Add function to test if socket is alive
- Modify `socket_watcher_start()` to handle existing sockets gracefully
- Add helper function to check if socket responds to RPC

### 2. `src/nvim/msgpack_rpc/server.c`

- Update `server_start()` to use enhanced socket handling
- Add appropriate logging

## Implementation Steps

### Step 1: Add socket liveness check function

Create a function that:

- Attempts to connect to the socket
- Sends a simple RPC request (e.g., `nvim_get_api_info`)
- Returns true if valid response, false otherwise

### Step 2: Modify socket_watcher_start()

- When `uv_pipe_bind()` fails, check if it's due to existing file
- Call liveness check function
- If dead, remove file and retry bind
- Log actions at INFO level

### Step 3: Update error messages

- Distinguish between "socket in use by another Nvim" vs other errors
- Provide helpful error messages

### Step 4: Add tests

- Test stale socket removal
- Test live socket detection
- Test error messages

## Technical Details

### RPC Test Request

Use `nvim_get_api_info` as it's:

- Simple and fast
- Available in all Nvim versions
- Doesn't modify state

### Timeout

- Use short timeout (500ms) for connection attempt
- Use short timeout (1000ms) for RPC response

### Error Codes

- `UV_EADDRINUSE` - Address already in use (socket exists)
- `UV_ECONNREFUSED` - Connection refused (dead socket)
- `UV_ETIMEDOUT` - Timeout (dead/slow socket)

### Logging

- INFO: "Removing stale socket: {path}"
- INFO: "Socket already in use by another Nvim instance: {path}"
- WARN: "Failed to test socket liveness: {error}"
