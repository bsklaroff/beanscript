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
WebAssembly.compile(buffer)
.then(module => {
  imports = {
    env: {
      memoryBase: 0,
      tableBase: 0,
      memory: new WebAssembly.Memory({initial: 256}),
      table: new WebAssembly.Table({initial: 0, element: 'anyfunc'})
    }
  }
  return new WebAssembly.Instance(module, imports)
}).then(instance => {
  var exports = instance.exports
  console.log(exports.main())
}).catch(res => {
  console.log(res)
})
