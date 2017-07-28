const fs = require('fs')

function toUint8Array(buf) {
  var u = new Uint8Array(buf.length)
  for (var i = 0; i < buf.length; ++i) {
    u[i] = buf[i]
  }
  return u
}

filename = process.argv[2]
const buffer = toUint8Array(fs.readFileSync(filename))
var memoryImport = new WebAssembly.Memory({initial: 1})

TYPES = {
  0: 'i32',
  1: 'i64',
  2: 'bool'
}

function printMemory(type) {
  if (TYPES[type] == 'i32') {
    memory = new Int32Array(memoryImport.buffer)
    console.log(memory[0])
  } else if (TYPES[type] == 'i64') {
    //TODO: implement this
    memory = new Int32Array(memoryImport.buffer)
    console.log(memory[0])
  } else if (TYPES[type] == 'bool') {
    memory = new Uint8Array(memoryImport.buffer)
    if (memory[0] == 1) {
      console.log('true')
    } else {
      console.log('false')
    }
  }
}

WebAssembly.compile(buffer)
.then(module => {
  imports = {
    env: {
      memoryBase: 0,
      tableBase: 0,
      memory: memoryImport,
      table: new WebAssembly.Table({initial: 0, element: 'anyfunc'}),
      print: printMemory
    }
  }
  return new WebAssembly.Instance(module, imports)
}).then(instance => {
  instance.exports.main()
}).catch(res => {
  console.log(res)
})
