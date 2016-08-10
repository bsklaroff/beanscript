ASTNode = require('./src/ast_node')
fixOpPrecedence = require('./src/fix_op_precedence')
Parser = require('./src/parser')
Scope = require('./src/scope')

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

parser = new Parser()

astTree = parser.parse(inputStr)
astTree = fixOpPrecedence(astTree)
#console.log(JSON.stringify(astTree, null, 2))
astTree.genSymbols(new Scope('global', null))
#console.log(JSON.stringify(ASTNode.getScopes(astTree), null, 2))
console.log(astTree.genWast())
