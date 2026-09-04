#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <libkern/OSAtomic.h>

int __darwin_check_fd_set_overflow(int fd, const void *p, int flags) {
    return 1;
}

int neo_atomic_is_lock_free(size_t size, const void *ptr) __asm__("___atomic_is_lock_free");
int neo_atomic_is_lock_free(size_t size, const void *ptr) {
    return (size <= 4) ? 1 : 0;
}

uint64_t __atomic_fetch_add_8(volatile void *ptr, uint64_t val, int model) {
    return (uint64_t)(OSAtomicAdd64Barrier((int64_t)val, (volatile int64_t *)ptr) - (int64_t)val);
}

uint64_t __atomic_fetch_sub_8(volatile void *ptr, uint64_t val, int model) {
    return (uint64_t)(OSAtomicAdd64Barrier(-(int64_t)val, (volatile int64_t *)ptr) + (int64_t)val);
}

uint64_t __atomic_fetch_and_8(volatile void *ptr, uint64_t val, int model) {
    volatile int64_t *p = (volatile int64_t *)ptr;
    int64_t old;
    do {
        old = *p;
    } while (!OSAtomicCompareAndSwap64Barrier(old, old & (int64_t)val, p));
    return (uint64_t)old;
}

uint64_t __atomic_fetch_or_8(volatile void *ptr, uint64_t val, int model) {
    volatile int64_t *p = (volatile int64_t *)ptr;
    int64_t old;
    do {
        old = *p;
    } while (!OSAtomicCompareAndSwap64Barrier(old, old | (int64_t)val, p));
    return (uint64_t)old;
}

uint64_t __atomic_load_8(const volatile void *ptr, int model) {
    volatile int64_t *p = (volatile int64_t *)ptr;
    int64_t old;
    do {
        old = *p;
    } while (!OSAtomicCompareAndSwap64Barrier(old, old, p));
    return (uint64_t)old;
}

void neo_atomic_load(size_t size, const volatile void *src, void *dest, int model) __asm__("___atomic_load");
void neo_atomic_load(size_t size, const volatile void *src, void *dest, int model) {
    if (size == 8) {
        *(uint64_t *)dest = __atomic_load_8(src, model);
    } else {
        memcpy(dest, (const void *)src, size);
    }
}

void neo_atomic_store(size_t size, volatile void *dest, const void *src, int model) __asm__("___atomic_store");
void neo_atomic_store(size_t size, volatile void *dest, const void *src, int model) {
    if (size == 8) {
        volatile int64_t *p = (volatile int64_t *)dest;
        int64_t val = *(const int64_t *)src;
        int64_t old;
        do {
            old = *p;
        } while (!OSAtomicCompareAndSwap64Barrier(old, val, p));
    } else {
        memcpy((void *)dest, src, size);
    }
}
