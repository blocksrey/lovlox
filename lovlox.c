#include <stdio.h>
#include <unistd.h>
#include <luajit-2.1/lualib.h>
#include <luajit-2.1/lauxlib.h>

// Lua function to be called by the scheduler
static int start_scheduler(lua_State *L) {
	for (;;) {
		lua_getglobal(L, "scheduler_function"); // Call the Lua function
		lua_pcall(L, 0, 0, 0);
		sleep(1); // Sleep for the specified interval
	}

	return 0;
}

int main(int argc, char **argv) {
	lua_State *L = luaL_newstate();

	luaL_openlibs(L);

	// Command-line arguments
	{
		// Create a Lua table to hold command-line arguments
		lua_newtable(L);

		for (int i = 0; i < argc; i++) {
			// Push each command-line argument as a string onto the Lua stack
			lua_pushstring(L, argv[i]);

			// Set the argument at index i+1 in the Lua table (Lua tables are 1-based)
			lua_rawseti(L, -2, i + 1);
		}

		// Set the table of command-line arguments as a global variable in Lua
		lua_setglobal(L, "arg");
	}

	luaL_dofile(L, "main.lua");

	// Register the C scheduler function in Lua
	lua_register(L, "start_scheduler", start_scheduler);

	// Call the Lua function to start the scheduler
	start_scheduler(L);

	const char* error_message = lua_tostring(L, -1);
	luaL_traceback(L, L, error_message, 1); // Get traceback with line number
	const char* traceback = lua_tostring(L, -1);
	fprintf(stderr, "Lua error: %s\n", traceback);
	lua_pop(L, 2); // Pop traceback and error message from the stack
	lua_close(L);

	return 1; // You can return an error code or handle the error as needed
}
