#ifndef AOT_COMPILE_CACHE_H
#define AOT_COMPILE_CACHE_H 1

#include <stdint.h>
#include <sys/types.h>
#include "ruby.h"

uint32_t crc32(const char *bytes, size_t size);

#endif /* AOT_COMPILE_CACHE_H */
