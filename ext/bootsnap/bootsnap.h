#ifndef BOOTSNAP_H
#define BOOTSNAP_H 1

#include <stdint.h>
#include <sys/types.h>
#include "ruby.h"

uint32_t crc32(const char *bytes, size_t size);

#endif /* BOOTSNAP_H */
