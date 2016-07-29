# beanscript

## How to Run
First, install [CoffeeScript](http://coffeescript.org/)

Then, to compile a beanscript file to WebAssembly s-expressions:
```
coffee main.coffee input.bs > output.wast
```

To run the WebAssembly text file output, install [wasm](https://github.com/proglodyte/wasm)

Then, to execute the wast output:
```
wast output.wast | coffee parse_output.coffee
```

`parse_output.coffee` is a script that allows us to print different types, for
example combining two printed 32-bit integers into a single 64-bit integer.

## Convenient shortcuts

I have the following in my `~/.bashrc`:
```
alias bsc='coffee /path/to/beanscript/main.coffee'
alias parse_bs_output='coffee /path/to/beanscript/parse_output.coffee'
function bs {
  TEMP=$(mktemp)
  bsc $1 > $TEMP
  wast $TEMP | parse_bs_output
  rm $TEMP
}
```

Then, I can simply:
```
bsc input.bs > output.wast
```
or
```
bs input.bs
```
