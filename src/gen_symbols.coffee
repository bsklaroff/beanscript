ASTNode = require('./ast_node')
Scope = require('./new_scope')
utils = require('./utils')

genSymbols = (astNode, scope) ->
  _parseSymbols(astNode, scope)
  scope.assignAllTypes()
  return scope

_parseSymbols = (astNode, scope) ->
  # If astNode is an array, gen symbols for each element
  if astNode.length?
    for child in astNode
      _parseSymbols(child, scope)
    return

  # Otherwise, gen children symbols, and then treat astNode based on its type
  if astNode.isAssignment()
    source = astNode.children.source
    _parseSymbols(source, scope)
    sourceSymbol = scope.astIdToSymbol[source.astId]
    target = astNode.children.target
    targetName = target.children.var.children.id.literal
    targetType = target.children.type
    targetSymbol = scope.getOrAddSymbol(targetName)
    if not targetType.isEmpty()
      scope.addTypeConstraint(targetSymbol, targetType.children.primitive.literal)
    scope.unifyTypes(sourceSymbol, targetSymbol)

  else if astNode.isOpParenGroup()
    child = astNode.children.opExpr
    _parseSymbols(child, scope)
    childSymbol = scope.astIdToSymbol[child.astId]
    opParenSymbol = scope.addAnonSymbol(astNode.name)
    scope.astIdToSymbol[astNode.astId] = opParenSymbol
    scope.unifyTypes(childSymbol, opParenSymbol)

  else if astNode.isFunctionCall()
    args = astNode.children.args
    _parseSymbols(args, scope)
    fnName = astNode.children.fnName.children.id.literal
    fnCallSymbol = scope.addAnonSymbol(fnName)
    scope.astIdToSymbol[astNode.astId] = fnCallSymbol
    argSymbols = utils.map(args, (arg) -> scope.astIdToSymbol[arg.astId])
    scope.addFnCallConstraints(fnName, fnCallSymbol, argSymbols)

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    varSymbol = scope.getOrAddSymbol(varName)
    scope.astIdToSymbol[astNode.astId] = varSymbol

  else if astNode.isNumber()
    console.log('num unimplemented')

  else if astNode.isTypeDef()
    console.log('typedef unimplemented')

  # Temporary hack to prevent typeinst fns from being parsed
  else if astNode.isTypeInst()
    console.log('typeinst unimplemented')

  else
    for name, child of astNode.children
      _parseSymbols(child, scope)
  return

module.exports = genSymbols
