# grall

a (hopefully) fast and memory efficient markov trainer/runner

![zig](https://img.shields.io/badge/zig-0.14.1-orange?style=flat-square)
![license](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![last release](https://img.shields.io/github/release-date/dragsbruh/grall?style=flat-square)
![issues](https://img.shields.io/github/issues/dragsbruh/grall?style=flat-square)
![stars](https://img.shields.io/github/stars/dragsbruh/grall?style=flat-square)
![last commit](https://img.shields.io/github/last-commit/dragsbruh/grall?style=flat-square)

## demo

> I must say also a few words. Leave me; I am inexorable.
> 
> \- _Grall, trained on Frankenstein_

## installation

currently windows support is not tested and is not a priority. this may simply not work on windows

if there are [releases](https://github.com/dragsbruh/grall/releases) available, download
the binaries for your os from there. otherwise you can [compile from source](#compiling-from-source).

### compiling from source

1. make sure you have [zig 0.14.1](https://ziglang.org/download/), and clone this repository

2. build the executable

  ```bash
  zig build -Doptimize=ReleaseFast # ReleaseFast is important, otherwise its terribly slow
  ```

3. run this command to test

  ```bash
  ./zig-out/bin/grall version
  ```

  move grall to your `/usr/local/bin/` or similar directory

## usage

> note: termination styles are not gonna be implemented for a while. all generations will use the [never](./docs/termination.md#never) style.

```yaml
usage: grall <command> [...args]

commands:
  train   <modelfile> <depth> [...text-files]
  run     <modelfile>
  yaml    <modelfile> <yamlfile>
          convert model to yaml (for debugging)
  api     <modelfile>
          start the stdio api
  inspect <modelfile>
          get modelfile information
  help
  version
```

### training a model

models are trained from raw text files. honestly they can be any files but for demo lets use text.

lets say text files are in the `./data/` directory as plaintext files.

you can use the command:

```bash
grall train ./model.gril 8 ./data/* # your shell should autocomplete this
```

to train the model with `8` depth.

`depth` -> refers the the _"size of the ngram"_ the markov chain uses. keep this low for creativity but too
low can create incomprehensible sentences.

this should create a `model.gril` file with the model serialized. you can now [run it](#running-a-model).

### running a model

> im currently playing around with different performance optimizations so theres gonna be useless memory bloat in some places ill remove them later

after [training](#training-a-model), you can run the serialized model with this command

```bash
grall run ./model.gril
```

### api

> note: the stdio api will change a bit in the future, i dont like it much how it is now.
> i will probably use unix sockets the next api rewrite.

you can alternatively use the stdio api if you wanna programmatically interact with a grall model.

```bash
grall api ./model.gril
```

the engine can run multiple generations at once. note that we do not use multiple threads,
instead its a simple task queue with polling
for commands.

commands are newline delimited and have `:` separator for arguments.
here `[]` denotes optional argument and `<>` is mandatory argument.

optional arguments can be omitted and will use zero value defaults.

#### available api commands

**1. `new:<name>:[limit]:[seed]`**

creates a new task with its own markov state with `name` and generates upto `limit` bytes.
uses the seed state `seed`.

```
new:user1:0:strawberry
```

here only the last `depth` bytes of seed is used. `0` limit indicates no limit.
generation can stop before reaching limit.

**2. `end:<name>`**

ends a task. no-op if task does not exist.

**3. `delay:<delay>`**

changes delay ms to `delay`. default is `0`. `0` delay indicates no delay.

**4. `quit`**

quits

**5. `flush`**

flushes stdout, note that this is not required because we already have an internal timer for flushing but this exists.

**6. `setflush:<count>`**

sets flush timer to flush every `count` iterations. includes empty iterations with no jobs.
using `0` disables buffering. default is `20`.

#### api output

output is newline delimited with `:` separator for arguments.
commands are also echoed after success.

**1. generation output**

```
g:<name>:<byte>
```

**2. errors**

mostly errors with command input, printed to stdout

```
error: <msg>
```

**3. system messages**

```
msg: <msg>
```

also there are other model info messages on startup

```
info:<depth>:<node_count>
```

#### keep in mind

dont use funky characters for task name etc. keep it simple a-z or A-Z or 1-9.
newlines will cause some issues.

## todo

- [ ] training optimization (move away from sorted arrays to probably a tree-like structure? but thats probably memory bloat)
- [ ] chunked trainings and model merging (allows distributed training, cool)
- [ ] better stdio api
- [ ] better cli
- [ ] make it faster (goal: 10MB/sec)
- [ ] upgrade to [zig 0.15.1](https://ziglang.org/download/0.15.1/release-notes.html)

i plan to make an openai-like api for this but that will be a different repo,
ill probably call it [opengrall](https://github.com/dragsbruh/opengrall).
this repo is purely for the zig implementation of the engine.

## license

grall has an [MIT license](LICENSE.md).
