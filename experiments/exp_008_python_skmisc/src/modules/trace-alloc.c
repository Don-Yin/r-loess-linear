/* Observe real prediction-time calloc requests on macOS. */

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static _Thread_local int logging;

static void record_request(const char *kind, size_t count, size_t size, void *result)
{
    if (logging || !size || count > SIZE_MAX / size) return;
    const char *path = getenv("LOESS_ALLOC_TRACE");
    if (!path) return;
    logging = 1;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR);
    if (fd >= 0) {
        char text[160];
        int length = snprintf(text, sizeof text, "%s,%zu,%zu,%zu,%d\n",
                              kind, count, size, count * size, result != NULL);
        write(fd, text, (size_t) length);
        close(fd);
    }
    logging = 0;
}

static void *traced_calloc(size_t count, size_t size)
{
    void *result = calloc(count, size);
    record_request("calloc", count, size, result);
    return result;
}

__attribute__((used)) static struct {
    const void *replacement;
    const void *original;
} calloc_interpose __attribute__((section("__DATA,__interpose"))) = {
    (const void *) traced_calloc, (const void *) calloc
};
