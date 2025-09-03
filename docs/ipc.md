# grall ipc unix socket

```bash
grall ipc ./model.gril /tmp/grall-model.sock
```

this command will serve a unix socket with its own super simple [binary protocol](#the-protocol).

## basics

each grall process serves a single model and accepts multiple connections over a unix socket.
each connection runs in its own thread and can run multiple concurrent generations.

note that they these generations on a connection are concurrent, not parallel.

each generation has a name associated with it that is simply a string.
it is recommended to use a short but unique string. for each generation.

these names expire once the task is completed.

each generation can be seeded with a certain string. here seed simply is the initial state of the
markov chain sequence. i.e it will try to continue that seed. so probably dont use a jargon seed.

each generation iteration will yield atmost `4` bytes per token unless it ends mid generation.

## the protocol

general command outputs (if any) are immediately responded to. the server first starts with a `pong` opcode.
commands are not echoed.

### data types

theres a few super simple data types in the protocol.

- every number is always a 32-bit big-endian unsigned integer (like lengths, etc)
- every [opcode](#opcodes) is a single byte
- every sequence (strings, tokens) is a combination of its length `n` (u32) and `n` bytes after it.

thats it. every command will use a combination of these data types.

note that in the ipc socket, a single token will be atmost 4 bytes. but it is recommended to consider the
length provided in the token sequence in case there generation stops mid token. also because the token size
may be changed/configurable later. 

### opcodes

all opcodes are single byte and can be continued by other data types (arguments) or be standalone.
starting an opcode sequence will cause all generations for that connection pause.
so make sure you send once the entire thing is ready.

here, constants are showed as-is and arguments are wrapped with `<>`.
for example, `[1:opcode]` is a constant `1` of `opcode` type. but `[<name>:sequence]`
is a variable valued `name` which is a `sequence`. `[...bytes]` refers to raw bytes of the sequence.

sequence refers to `[<length>:u32][...bytes]` where `length` is the length of bytes.
all arguments are necessary, there are no optionals.

it is not recommended to concurrently write opcodes, so use a mutex or something.

#### command opcodes

these are the actual opcodes that _you_ send to the socket.

**1. ping**

value: `1`

```js
[1:opcode]
```

this is a standalone opcode. server responds with the pong opcode (see [response opcodes](#response-opcodes)).

**2. new**

value: `2`

```js
[2:opcode][<name>:sequence][<seed>:sequence][<limit>:u32][<delay>:u32]
```

this will start a new generation named `name`  with `seed`.
it will generate atmost `limit` bytes. use `0` if you do not want a limit.
the task will cause the whole connection to sleep `delay` milliseconds after running this task.
`0` delay skips sleeping.

note that how `delay` works will be changed in the future to something more reasonable.

**3. end**

value: `3`

```js
[3:opcode][<name>:sequence]
```

this will end the generation `name`. no-op if the generation does not exist.

**4. delay**

value: `4`

```js
[4:opcode][<name>:sequence][<delay>:u32]
```

sets the delay of generation `name` to `delay`

**5. close**

value: `5`

```js
[5:opcode]
```

immediately stops all generations on that connection and closes it.

#### response opcodes

these are the opcodes that the _socket_ gives you.

these opcodes happen only after you provide a command that the socket responds with,
except, `gen` and `end` opcodes they may happen at any time.

`pong` is always first sent when the connection is ready.

**1. pong**

value: `1`

```js
[1:opcode]
```

sent on server start and as a response to `ping` opcode

**2. gen**

value: `2`

```js
[2:opcode][<name>:sequence][<token>:sequence]
```

sent as generation output. `name` is generation name, `token` is atmost 4-byte long
(token length might be changed in future, so always consider the sequence length preix).

**3. end**

value: `3`

```js
[3:opcode][<name>:sequence]
```

sent when a generation ends naturally, i.e, cannot produce tokens or limit is reached.
not sent when you artificially stop generation.

**4. err**

value: `4`

```js
[4:opcode][<message>:sequence]
```

error messages when an opcode fails, currently only when you provide incorrect opcodes,
so you can just skip this (remember to actually read/skip the bytes)
