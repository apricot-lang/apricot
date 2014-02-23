# Apricot [![Gem Version](https://badge.fury.io/rb/apricot.png)](http://badge.fury.io/rb/apricot) [![Build Status](https://secure.travis-ci.org/apricot-lang/apricot.png?branch=master)](http://travis-ci.org/apricot-lang/apricot) [![Dependency Status](https://gemnasium.com/apricot-lang/apricot.png?travis)](https://gemnasium.com/apricot-lang/apricot)

A Clojure-like Lisp on [Rubinius](http://rubini.us/).

Try to contain your excitement, please.


## Install

First of all, you're going to need Rubinius. If you're using
[RVM](https://rvm.io/):

``` sh
$ rvm install rbx
$ rvm use rbx
$ gem install apricot
```


## The REPL

Apricot provides an awesome read-eval-print-loop with line editing, history,
tab-completion, and some interesting commands like `!bytecode`. To enter the
REPL just run `apricot`.

Once in the repl you can get help with `!help` or use `(doc <name>)` to see
the documentation of any function or macro. Play around, read
`kernel/core.apr` and try out our functions, and make some of your own.
Experiment. Tell us what you think!

``` clojure
apr> (+ 1 2 3)
=> 6
apr> (map (fn [x] (* x x)) (Range. 1 10))
=> [1 4 9 16 25 36 49 64 81 100]
apr> (defn square [x] (* x x))
=> #<Proc:0x330@(eval):3 (lambda)>
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
(println "Hello, world!")
$ apricot hello.apr
Hello, world!
```


## Development

If you want to hack on Apricot, first install Rubinius as explained above.
When you `cd` to the Apricot git repo, RVM should automatically switch to
Rubinius thanks to the `.ruby-version` file. Now install and run Bundler:

``` sh
$ gem install bundler
$ bundle
```

You're all set. Run the tests with `rake` and run the bleeding edge REPL with
`ruby -Ilib bin/apricot`. Similarily, use `irb -Ilib -rapricot` for an IRB
session with Apricot loaded.


## Contact / Bug Reports

If you have any questions don't hesitate to email us or visit us in `#apricot`
on [freenode](http://freenode.net/) (we are `curtism` and `scott`). And we'd
really appreciate it if you opened bug reports on the GitHub [issue
tracker](https://github.com/programble/apricot/issues)!


## License

Copyright (c) 2012-2013, Curtis McEnroe \<programble@gmail.com>

Copyright (c) 2012-2013, Scott Olson \<scott@scott-olson.org>

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
