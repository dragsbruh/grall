# grall

> **note:** this does give random-ish answers, that is intended behavior. it is a markov chain after all!

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
  ipc     <modelfile> <socket_path>
          start the unix socket
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

grall also has a multi-threaded ipc protocol (over unix sockets). each grall process serves a single mdoel and accepts connections
and spawns a single runner thread for each connection. you can still run multiple concurrent generations over the same connection
but it will not spawn a separate thread for that.

see the api usage and additional info at [its own docs file](docs/ipc.md).

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
- [ ] better cli
- [ ] make it faster (goal: 10MB/sec)
- [ ] upgrade to [zig 0.15.1](https://ziglang.org/download/0.15.1/release-notes.html)
- [x] better ipc socket

i plan to make an openai-like api for this but that will be a different repo,
ill probably call it [opengrall](https://github.com/dragsbruh/opengrall).
this repo is purely for the zig implementation of the engine.

## license

grall has an [MIT license](LICENSE.md).
