#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

#define NUM_THREADS 8

void thread_function() {
    printf("from thread\n");
}

int main() {
    pthread_t threads[NUM_THREADS];

    for (int i = 0; i < NUM_THREADS; i++) {
	    pthread_atfork(NULL, NULL, thread_function);
    }

    becomeDaemon(BD_NO_CHDIR & BD_NO_CLOSE_FILES & BD_NO_REOPEN_STD_FDS & BD_NO_UMASK0 & BD_MAX_CLOSE);
    printf("wow\n");

    return 0;
}
