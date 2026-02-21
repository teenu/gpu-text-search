#include "vk_init.h"
#include "vk_search.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void usage(void) {
    fprintf(stderr, "Usage: gts <file> <pattern> [--benchmark N]\n");
    exit(1);
}

static int run_search(SearchPipeline *sp, const uint8_t *data, size_t file_size,
                      uint32_t pat_len, const char *pattern, uint64_t *out_count) {
    *out_count = 0;
    if (pat_len == 0 || file_size == 0 || pat_len > file_size) return 0;

    size_t offset = 0;
    while (offset < file_size) {
        size_t remain = file_size - offset;
        uint32_t chunk_len = remain > CHUNK_SIZE ? CHUNK_SIZE : (uint32_t)remain;
        if (chunk_len < pat_len) break;

        SearchResult result = {0};
        if (vk_search_run(sp, data + offset, chunk_len,
                          pattern, pat_len, &result) != 0)
            return -1;

        *out_count += result.count;
        free(result.positions);

        size_t step = chunk_len - (pat_len - 1);
        if (step == 0) break;
        offset += step;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) usage();

    const char *filepath = argv[1];
    const char *pattern  = argv[2];
    int bench_n = 0;

    if (argc >= 5 && strcmp(argv[3], "--benchmark") == 0)
        bench_n = atoi(argv[4]);

    int fd = open(filepath, O_RDONLY);
    if (fd < 0) { perror("open"); return 1; }

    struct stat st;
    if (fstat(fd, &st) != 0) { perror("fstat"); close(fd); return 1; }

    if (st.st_size == 0) {
        printf("Found 0 matches\n");
        close(fd);
        return 0;
    }

    size_t file_size = (size_t)st.st_size;
    void *data = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    uint32_t pat_len = (uint32_t)strlen(pattern);

    VkContext ctx;
    if (vk_init(&ctx) != 0) { fprintf(stderr, "Vulkan init failed\n"); return 1; }

    SearchPipeline sp;
    if (vk_search_init(&sp, &ctx) != 0) { fprintf(stderr, "Pipeline init failed\n"); return 1; }

    int iters = bench_n > 0 ? bench_n : 1;
    double *times = NULL;
    if (bench_n > 0) times = malloc(bench_n * sizeof(double));

    uint64_t total_count = 0;
    for (int i = 0; i < iters; i++) {
        double t0 = now_sec();
        if (run_search(&sp, data, file_size, pat_len, pattern, &total_count) != 0) {
            fprintf(stderr, "Search failed\n");
            return 1;
        }
        double elapsed = now_sec() - t0;

        if (bench_n > 0) {
            times[i] = elapsed;
        } else {
            double gbps = (file_size / 1e9) / elapsed;
            printf("Found %lu matches in %.3fs (%.1f GB/s)\n",
                   (unsigned long)total_count, elapsed, gbps);
        }
    }

    if (bench_n > 0) {
        double mn = times[0], mx = times[0], sum = 0, sum2 = 0;
        for (int i = 0; i < bench_n; i++) {
            if (times[i] < mn) mn = times[i];
            if (times[i] > mx) mx = times[i];
            sum += times[i];
            sum2 += times[i] * times[i];
        }
        double avg = sum / bench_n;
        double var = sum2 / bench_n - avg * avg;
        double sd  = var > 0 ? sqrt(var) : 0;
        double gbps_avg = (file_size / 1e9) / avg;
        double gbps_max = (file_size / 1e9) / mn;

        printf("Found %lu matches (%d runs)\n", (unsigned long)total_count, bench_n);
        printf("  avg: %.3fs  min: %.3fs  max: %.3fs  stddev: %.3fs\n",
               avg, mn, mx, sd);
        printf("  avg: %.1f GB/s  peak: %.1f GB/s\n", gbps_avg, gbps_max);
        free(times);
    }

    vk_search_cleanup(&sp);
    vk_cleanup(&ctx);
    munmap(data, file_size);
    close(fd);
    return 0;
}
