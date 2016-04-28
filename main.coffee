Parser = require('./src/parser')

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

parser = new Parser(inputStr)

parser.parse()
console.log(JSON.stringify(parser.astTree, null, 2))
