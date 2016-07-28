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
wast output.wast
```

I have the following in my `~/.bashrc`:
```
alias bsc='coffee /path/to/beanscript/main.coffee'
function bs {
  TEMP=$(mktemp)
  bsc $1 > $TEMP
  wast $TEMP
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
