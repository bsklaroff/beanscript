Parser = require('./src/parser')
CodeGen = require('./src/code_gen')

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

parser = new Parser(inputStr)

parser.parse()
#console.log(JSON.stringify(parser.astTree, null, 2))
codeGen = new CodeGen()
console.log(codeGen.genWast(parser.astTree))
