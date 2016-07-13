ASTNode = require('./src/ast_node')
Parser = require('./src/parser')
Scope = require('./src/scope')

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

parser = new Parser(inputStr)

parser.parse()
parser.astTree.genSymbols(new Scope('global', null))
#console.log(JSON.stringify(ASTNode.getScopes(parser.astTree), null, 2))
console.log(parser.astTree.genWast())
