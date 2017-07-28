# beanscript

## How to run
First, for wasm support, install [Node v8.x](https://nodejs.org)

Second, install [CoffeeScript](http://coffeescript.org/)

Then, to compile a beanscript file to WebAssembly s-expressions:
```
coffee main.coffee input.bs > output.wast
```

To convert the .wast file to .wasm, install [wabt](https://github.com/WebAssembly/wabt)
```
git clone --recursive https://github.com/WebAssembly/wabt/
cd wabt
make gcc-release
# Put the following in your .bashrc
export PATH=/path/to/wabt/out/gcc/Release:$PATH
```

Then, you can run:
```
wast2wasm output.wast -o output.wasm
```

Finally, to execute the wasm file:
```
node ./runwasm.js output.wasm
```

## Convenient shortcuts

I have the following in my `~/.bashrc`:
```
# Add wast2wasm to PATH
export PATH=/path/to/wabt/out/gcc/Release:$PATH
alias bsc='coffee /path/to/beanscript/main.coffee'
alias runwasm='node /path/to/beanscript/run_wasm.js'
function bs {
  TEMP=$(mktemp)
  bsc $1 > $TEMP
  runwast $TEMP
  rm $TEMP
}
function runwast {
  TEMP2=$(mktemp)
  wast2wasm $1 -o $TEMP2
  runwasm $TEMP2
  rm $TEMP2
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
