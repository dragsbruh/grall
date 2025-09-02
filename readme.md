# grall

a (hopefully) fast and memory efficient markov trainer/runner

## demo

> I must say also a few words. Leave me; I am inexorable.
> \- _Grall, trained on Frankenstein_

## installation

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
  run     <modelfile> [infinite] [delay]
  yaml    <modelfile> <yamlfile>
          convert model to (not-so-correct) yaml (for debugging)
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

`ending_style` -> generation ending style. only for plaintext inputs. `line` will make the runtime stop after
every new line, etc. see [termination style](./docs/termination.md).
`delay` -> sleeps `delay` ms per token generation

### api

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

#### available commands

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

#### output

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
