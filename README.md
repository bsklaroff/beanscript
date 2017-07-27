# beanscript

## How to run
First, install [CoffeeScript](http://coffeescript.org/)

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

To execute the .wasm file, install [Node v8.x](https://nodejs.org)

Then:
```
node ./runwasm.js output.wasm
```

`parse_output.coffee` is a script that allows us to print different types, for
example combining two printed 32-bit integers into a single 64-bit integer.

## Convenient shortcuts

I have the following in my `~/.bashrc`:
```
export PATH=/path/to/wabt/out/gcc/Release:$PATH
alias bsc='coffee /path/to/beanscript/main.coffee'
alias parse_bs_output='coffee /path/to/beanscript/parse_output.coffee'
alias runwasm='node /path/to/beanscript/run_wasm.js'
function bs {
  TEMP=$(mktemp)
  TEMP2=$(mktemp)
  bsc $1 > $TEMP
  wast2wasm $TEMP -o $TEMP2
  runwasm $TEMP2
  rm $TEMP $TEMP2
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
