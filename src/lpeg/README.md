# LPeg - Parsing Expression Grammars For Lua

For more information,
see [Lpeg](//www.inf.puc-rio.br/~roberto/lpeg/).

Vendored @ v1.1.0 with patch to prevent conflict with LuaJIT extensions:
```diff
diff --git a/src/lpeg/lptree.c b/src/lpeg/lptree.c
index 475b0c36bf..94a3171d5a 100644
--- a/src/lpeg/lptree.c
+++ b/src/lpeg/lptree.c
@@ -1388,7 +1388,7 @@ int luaopen_lpeg (lua_State *L) {
   lua_pushnumber(L, MAXBACK);  /* initialize maximum backtracking */
   lua_setfield(L, LUA_REGISTRYINDEX, MAXSTACKIDX);
   luaL_setfuncs(L, metareg, 0);
-  luaL_newlib(L, pattreg);
+  luaL_register(L, "lpeg", pattreg); // Nvim: inline conflicting luaL_newlib macro
   lua_pushvalue(L, -1);
   lua_setfield(L, -3, "__index");
   lua_pushliteral(L, "LPeg " VERSION);
diff --git a/src/lpeg/lptypes.h b/src/lpeg/lptypes.h
index 3f860b973f..98974e1b88 100644
--- a/src/lpeg/lptypes.h
+++ b/src/lpeg/lptypes.h
@@ -35,7 +35,7 @@
 #define lua_rawlen		lua_objlen
 
 #define luaL_setfuncs(L,f,n)	luaL_register(L,NULL,f)
-#define luaL_newlib(L,f)	luaL_register(L,"lpeg",f)
+// #define luaL_newlib(L,f)	luaL_register(L,"lpeg",f) // Nvim: conflicts with LuaJIT
 
 typedef size_t lua_Unsigned;
 
```
