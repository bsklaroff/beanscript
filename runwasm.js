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
var exports = null

function printMemory(length) {
  memory = new UInt8Array(exports.memory)
  var bytes = Array.prototype.slice.call(memory, 0, length)
  var msg = bytes.map(function(byte) {
    return String.fromCharCode(byte)
  }).join('')
  console.log(msg)
}

WebAssembly.compile(buffer)
.then(module => {
  imports = {
    env: {
      memoryBase: 0,
      tableBase: 0,
      table: new WebAssembly.Table({initial: 0, element: 'anyfunc'})
      print: printMemory
    }
  }
  return new WebAssembly.Instance(module, imports)
}).then(instance => {
  exports = instance.exports
  console.log(exports.main())
}).catch(res => {
  console.log(res)
})
