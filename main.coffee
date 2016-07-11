Parser = require('./src/parser')
CodeGen = require('./src/code_gen')

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

parser = new Parser(inputStr)

parser.parse()
codeGen = new CodeGen()
console.log(codeGen.genWast(parser.astTree))
