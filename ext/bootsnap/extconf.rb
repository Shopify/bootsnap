require "mkmf"
$CFLAGS << ' -O3 -std=c99'
$CFLAGS << ' -Wall -Wextra -Wpedantic -Werror'
$CFLAGS << ' -Wno-unused-parameter' # VALUE self has to be there but we don't care what it is.
$CFLAGS << ' -Wno-keyword-macro' # hiding return
create_makefile("bootsnap/bootsnap")
