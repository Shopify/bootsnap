#ifndef BOOTSNAP_H
#define BOOTSNAP_H 1

#include <stdint.h>
#include <sys/types.h>
#include "ruby.h"

uint32_t crc32(const char *bytes, size_t size);

VALUE lol(VALUE self, VALUE depth_v);

#endif /* BOOTSNAP_H */
