# grall

a (hopefully) fast and memory efficient markov trainer/runner

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
  run     <modelfile> [infinite]
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
grall train ./model.gril 8 none ./data/* # your shell should autocomplete this
```

to train the model with `8` depth.

`depth` -> refers the the _"size of the ngram"_ the markov chain uses. keep this low for creativity but too
low can create incomprehensible sentences.

this should create a `model.gril` file with the model serialized. you can now [run it](#running-a-model).

### running a model

after [training](#training-a-model), you can run the serialized model with this command

```
grall run true ./model.gril none
```

`ending_style` -> generation ending style. only for plaintext inputs. `line` will make the runtime stop after
every new line, etc. see [termination style](./docs/termination.md).
