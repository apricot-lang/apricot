# Apricot [![Build Status](https://secure.travis-ci.org/programble/apricot.png?branch=master)](http://travis-ci.org/programble/apricot) [![Dependency Status](https://gemnasium.com/programble/apricot.png?travis)](https://gemnasium.com/programble/apricot)

A Clojure-like Lisp on Rubinius.

Try to contain your excitement, please.


## Setup
To get Apricot up and running, make sure you have rubinius and bundler installed.

    rvm install rubinius
    gem install bundler
    bundle

## Starting Apricot
To start Apricot

    ./bin/apricot

Once in the repl you can ask for help by using `!help` and you can exit with `!exit`


## Using Apricot
Here are a few of the ways you can use Apricot.

### Using Ruby Methods

````clojure
    ;    (. receiver method args*)
    ;    (. receiver method args* | block)
    ;    (. receiver (method args*))
    ;    (. receiver (method args* | block))

    (.puts STDOUT "HELLO")
    ; => "HELLO"

    (.each [1,2,3] | (fn [msg]
                       (.puts STDOUT msg)))
    ; => 1
    ; => 2
    ; => 3
````

### Defining variables

````clojure
    ; (def name value)

    (def color "RAINBOW")
    (.puts STDOUT color)
    ; => RAINBOW
````

### Conditionals

````clojure
    ; (if cond body else_body)

    (if (.eql? 4 ( 2 2)) (.puts STDOUT "1 is indeed larger than zero"))

    (if (.eql? color "RAINBOW")
      (.puts STDOUT "Its soo pretty")
      (.puts STDOUT "Ew."))
````

### Defining Functions

````clojure
    (def foo (fn []
               "Hello"))

    (def str (fn [& args]
               (.reduce args "" :+)))

    (def bar (fn []
               (str (foo) " " "World!")))

    (def print (fn [obj]
                 (.print STDOUT obj)))

    (def puts (fn [obj]
                (.puts STDOUT obj)))

    (puts (foo))
    ; => "Hello"

    (puts (bar))
    ; => "Hello World!"
````

## License

Copyright (c) 2012, Curtis McEnroe <programble@gmail.com>

Copyright (c) 2012, Scott Olson <scott@scott-olson.org>

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
