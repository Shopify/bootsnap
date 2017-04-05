require './lib/bootsnap/bootsnap.bundle'

STDERR.puts "\x1b[1;34m"
at_exit { STDERR.puts "\x1b[0m" }

def neato
  yield
end

neato do
  puts Bootsnap.lol(2).inspect # ["foo.rb", 7]  (yield in neato)
  puts Bootsnap.lol(1).inspect # ["foo.rb", 12] (here)
  puts Bootsnap.lol(0).inspect # :cfunc         (Bootsnap.lol)
end
