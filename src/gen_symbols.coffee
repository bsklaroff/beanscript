ASTNode = require('./ast_node')
Scope = require('./new_scope')

genSymbols = (astNode, scope = new Scope()) ->
  # If astNode is an array, gen symbols for each element
  if astNode.length?
    for child in astNode
      genSymbols(child, scope)
    return scope
  # Otherwise, gen children symbols, and then treat astNode based on its type
  if astNode.isAssignment()
    source = astNode.children.source
    genSymbols(astNode.children.source, scope)
    sourceSymbol = scope.astIdToSymbol[source.astId]
    target = astNode.children.target
    targetName = target.children.var.children.id
    targetType = target.children.type
    targetSymbol = scope.getOrAddSymbol(targetName)
    if not targetType.isEmpty()
      console.log('Set explicit type here')
    scope.unifyTypes(sourceSymbol, targetSymbol)
  else if astNode.isOpParenGroup()
    child = astNode.children.opExpr
    genSymbols(child, scope)
    childSymbol = scope.astIdToSymbol[child.astId]
    newSymbol = scope.addAnonSymbol(astNode.name)
    scope.astIdToSymbol[astNode.astId] = newSymbol
    scope.unifyTypes(childSymbol, newSymbol)
  else if astNode.isFunctionCall()
    console.log('fn')
  else if astNode.isVariable()
    varName = astNode.children.id
    # TODO
  else if astNode.isNumber()
    console.log('num')
  else
    for name, child of astNode.children
      genSymbols(child, symbols)
  return scope

module.exports = genSymbols
