#include "aot_compile_cache.h"

#include <x86intrin.h>

uint32_t
crc32(const char *bytes, size_t size)
{
  size_t i;
  uint32_t hash = 0;

  for (i = 0; i < size; i++) {
    hash = _mm_crc32_u8(hash, bytes[i]);
  }
  return hash;
}

