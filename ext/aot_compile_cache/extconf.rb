require "mkmf"
$CFLAGS << ' -O3 -msse4.2 -std=c99'
have_header('x86intrin.h')
$CFLAGS << ' -Wall -Wextra -Wpedantic -Werror'
$CFLAGS << ' -Wno-unused-parameter' # VALUE self has to be there but we don't care what it is.
$CFLAGS << ' -Wno-keyword-macro' # hiding return
create_makefile("aot_compile_cache/aot_compile_cache")
