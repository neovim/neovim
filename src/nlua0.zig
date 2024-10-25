const std = @import("std");
const ziglua = @import("ziglua");
const options = @import("options");

const embedded_data = @import("embedded_data");

const hashy = @embedFile("nvim/generators/hashy.lua");

const Lua = ziglua.Lua;

extern "c" fn luaopen_mpack(ptr: *anyopaque) c_int;
extern "c" fn luaopen_lpeg(ptr: *anyopaque) c_int;
extern "c" fn luaopen_bit(ptr: *anyopaque) c_int;

fn init() !*Lua {
    // Initialize the Lua vm
    var lua = try Lua.newStateLibc();
    lua.openLibs();

    // this sets _G.vim by itself, so we don't need to
    try lua.loadBuffer(embedded_data.shared_module, "shared.lua");
    lua.call(0, 1);

    try lua.loadBuffer(embedded_data.inspect_module, "inspect.lua");
    lua.call(0, 1);
    lua.setField(-2, "inspect");

    _ = try lua.getGlobal("package");
    _ = lua.getField(-1, "preload");
    try lua.loadBuffer(hashy, "hashy.lua"); // [package, preload, hashy]
    lua.setField(-2, "generators.hashy");
    lua.pop(2);

    const retval = luaopen_mpack(lua);
    if (retval != 1) return error.LoadError;
    _ = lua.getField(-1, "NIL"); // [vim, mpack, NIL]
    lua.setField(-3, "NIL"); // vim.NIL = mpack.NIL (wow BOB wow)
    lua.setField(-2, "mpack");

    const retval2 = luaopen_lpeg(lua);
    if (retval2 != 1) return error.LoadError;
    lua.setField(-3, "lpeg");

    lua.pop(2);

    if (!options.use_luajit) {
        lua.pop(luaopen_bit(lua));
    }
    return lua;
}

pub fn main() !void {
    const argv = std.os.argv;

    const lua = try init();
    defer lua.deinit();

    if (argv.len < 2) {
        std.debug.print("USAGE: nlua0 script.lua args...\n\n", .{});
        try lua.doString("print(vim.inspect(vim.uv.os_uname()))");
        return;
    }
    lua.createTable(@intCast(argv.len - 2), 1);
    for (0.., argv[1..]) |i, arg| {
        _ = lua.pushString(std.mem.span(arg));
        lua.rawSetIndex(-2, @intCast(i));
    }
    lua.setGlobal("arg");

    // Create an allocator
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer _ = gpa.deinit();

    //std.debug.print("All your {s} are belong to us.\n", .{argv[1]});

    _ = try lua.getGlobal("debug");
    _ = lua.getField(-1, "traceback");
    try lua.loadFile(std.mem.span(argv[1]));
    lua.protectedCall(0, 0, -2) catch |e| {
        if (e == error.Runtime) {
            const msg = try lua.toString(-1);
            std.debug.print("{s}\n", .{msg});
        }
        return e;
    };
}

fn do_ret1(lua: *Lua, str: [:0]const u8) !void {
    try lua.loadString(str);
    try lua.protectedCall(0, 1, 0);
}

test "simple test" {
    const lua = try init();
    defer lua.deinit();

    try do_ret1(lua, "return vim.isarray({2,3})");
    try std.testing.expectEqual(true, lua.toBoolean(-1));
    lua.pop(1);

    try do_ret1(lua, "return vim.isarray({a=2,b=3})");
    try std.testing.expectEqual(false, lua.toBoolean(-1));
    lua.pop(1);

    try do_ret1(lua, "return vim.inspect(vim.mpack.decode('\\146\\42\\69'))");
    try std.testing.expectEqualStrings("{ 42, 69 }", try lua.toString(-1));
    lua.pop(1);

    try do_ret1(lua, "return require'bit'.band(7,12)");
    try std.testing.expectEqualStrings("4", try lua.toString(-1));
    lua.pop(1);
}
