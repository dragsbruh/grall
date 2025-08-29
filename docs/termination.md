# termination styles

termination styles control when the generation will end.

note that the generation will always end if the model has never seen a sequence.

## available termination styles

**1. none**

this is the simplest and should be used when you arent dealing with text files.

this will cause the chain to generate text until it literally cannot.

**2. never**

this will cause the chain to generate theoretically infinite text.

note that it requires you to have a fair amount of text that covers a decent number of cases.
a few hundred kilobytes should be fine i think.

if you wonder how it works, its [pretty simple](#never).

**3. line**

also pretty simple, runtime will terminate at every newline.

note that if you are using windows or files that use CRLF (`\r\n`) line endings, convert them to `\n` style
line endings before training, otherwise the runtime will render a `\r` and you wont be able to see the text output.

**4. word**

runtime will terminate at every whitespace or a few other characters.

### never

due to the nature of how grall works, we sort the markov ngrams (sequences as we call them) in
reverse as a sorted array, so the a quick representation is (example):

```
aaaaaaaa
aaaaaaab
aaaaaaac
aaaaaaba
aaaaaabb
aaaaaabc
aaaabdas
aaabasas
aaacadsd
aaacdads
...
hsadusad
hzjsadds
...
```

this should in theory be slightly more reasonable at no performance cost with the comparision implementation.
basically equal cost for actual comparision, possibly faster overall because its more accurate and reasonable
to compare from the end, and also allows the [never style](#never)!!!

but how does this allow the never style, you may ask?

also pretty simple, since we use binary sort to find matching n-gram, we come to something like this:

lets say we have never seen the sequence "blackberry" in our training data, but somehow we arrived to "strawberry".
binary sort will fail to find it but it will eventually arrive at the insertion index of "blackberry".

example sequences:

```
...
e dont cry
e you very
e a cherry
strawberry <- insertion index points here because this was the closest match
...
```

we return whatever character "blackberry" points to next here.

so if training data was

```
strawberry is red in color
```

and we had the sequence "blackberry", grall would (in `never` mode) complete it as

```
blackberry is red in color
```

i agree its incorrect but hey youre dealing with a markov chain here

ofcourse this is just silly and i only intended to use this where user types "blackberry" and i dont think
this would actually make it go infinite but whatever, its always possible.