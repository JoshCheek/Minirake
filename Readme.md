Minirake
========

A small implementation of Rake, for the purposes of learning/playing.


Setup
-----

```
$ bundle
$ bundle exec mrspec
```


Examples
--------

```sh
# default task
$ bin/minirake
task b
task a

# choose a task
$ bin/minirake b
task b

# task with dependencies
$ bin/minirake a
task b
task a

# task with multiple dependencies
$ bin/minirake c
task b
task b2
task c

# task with multiple deps, declared across lines with symbols and strings
$ bin/minirake d
task b
task b2
task d

# task with multiple bodies
$ bin/minirake e
body1
body2

# multiple tasks
$ bin/minirake b b2
task b
task b2

# multiple tasks in another order
$ bin/minirake b2 b
task b2
task b

# Environment variables
$ bin/minirake envvar
ENV['C'] = nil

$ bin/minirake C=X envvar
ENV['C'] = "X"

$ bin/minirake envvar C=X
ENV['C'] = "X"

# show that we can define methods without affecting global state
$ bin/minirake show_context
I'm an instance of Minirake
I can call methods: content from a method
```

License
-------

[Just do what the fuck you want to](http://www.wtfpl.net/about/)
