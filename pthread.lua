collectgarbage("stop")

local ffi = require('ffi')

ffi.cdef([[
typedef uint64_t pthread_t;

typedef struct {
	uint32_t flags;
	void *stack_base;
	size_t stack_size;
	size_t guard_size;
	int32_t sched_policy;
	int32_t sched_priority;
} pthread_attr_t;

typedef void *(*thread_func)(void *);

int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void *), void *arg);
int pthread_tryjoin_np(pthread_t thread, void **retval);
int pthread_join(pthread_t thread, void **value_ptr);
]])

-- Function to create a new thread
local function create_thread(func)
	local thread = ffi.new('pthread_t [1]')
	ffi.C.pthread_create(thread, nil, ffi.cast('void *(*)(void *)', func), ffi.cast('void *', thread_id))
	print(thread, result)
	local retval = ffi.new('void *[1]')
	ffi.C.pthread_tryjoin_np(thread, retval)
end

for i = 1, 4 do
	create_thread(function()
		print('ad')
	end)
end