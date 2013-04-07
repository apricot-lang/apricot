# Apricot [![Build Status](https://secure.travis-ci.org/programble/apricot.png?branch=master)](http://travis-ci.org/programble/apricot) [![Dependency Status](https://gemnasium.com/programble/apricot.png?travis)](https://gemnasium.com/programble/apricot)

A Clojure-like Lisp on Rubinius.

Try to contain your excitement, please.


## Setup
To get Apricot up and running, make sure you have Rubinius and Bundler
installed.  The easiest way to get Rubinius is with [RVM](https://rvm.io/).
Whenever you are using Apricot you need to be running Rubinius in Ruby 1.9
mode. We make this easy in the Apricot repository with the `.ruby-version`
file which RVM automatically reads to figure out which Ruby to switch to.

``` sh
$ rvm install rbx-head --1.9
$ rvm use rbx-head
$ gem install bundler
$ bundle
```

## The REPL
Apricot provides a nice read-eval-print-loop with line editing, history,
tab-completion, and some interesting commands like `!bytecode`. To enter the
REPL just run:

``` sh
$ bin/apricot
```

Once in the repl you can ask for help by using `!help` and you can exit with
`!exit`. See the documentation of any function with `(doc <name>)`. Play
around, read `kernel/core.apr` and try out our functions, and make some of
your own. Experiment. Tell us what you think!

``` clojure
apr> (+ 1 2 3)
=> 6
apr> (map (fn [x] (* x x)) (Range. 1 10))
=> [1 4 9 16 25 36 49 64 81 100]
apr> (defn square [x] (* x x))
=> nil
apr> (map square (Range. 1 10))
=> [1 4 9 16 25 36 49 64 81 100]
apr> (map (comp str square) (Range. 1 10))
=> ["1" "4" "9" "16" "25" "36" "49" "64" "81" "100"]
apr> (doc comp)
-------------------------
comp
([] [f] [f g] [f g h] [f1 f2 f3 & fs])
  Take a set of functions and return a fn that is the composition of those
  fns. The returned fn takes a variable number of args, applies the rightmost
  of fns to the args, the next fn (right-to-left) to the result, etc.
=> nil
```

## Hello World
So you want to put your program in a file and not type it into the REPL? Sure:

``` sh
$ cat hello.apr
(puts "Hello, world!")
$ bin/apricot hello.apr
Hello, world!
```

## Contact / Bug Reports
Come visit us on [freenode](http://freenode.net/) in the #apricot channel, or
drop one of us an email. Please send your bug reports to the GitHub
[issue tracker](https://github.com/programble/apricot/issues). They will be
greatly appreciated!


## License

Copyright (c) 2012-2013, Curtis McEnroe <programble@gmail.com>

Copyright (c) 2012-2013, Scott Olson <scott@scott-olson.org>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
