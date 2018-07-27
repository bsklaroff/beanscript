SymbolTable = require('./symbol_table')
symbolTable = null


genSymbols = (rootNode) ->
  symbolTable = new SymbolTable()
  _setGlobalFunctionDefs(rootNode)
  _parseSymbols(rootNode)
  return symbolTable


# Ensure all typeclassed functions and top-level function defs are marked as
# global symbols
_setGlobalFunctionDefs = (rootNode) ->
  for statement in rootNode.children.statements

    if statement.isAssignment() and statement.children.source.isFunctionDef()
      target = statement.children.target
      if target.isVariable()
        varName = target.children.id.literal
        symbolTable.setGlobal(varName)

    else if statement.isTypeclassDef()
      for typeDefNode in statement.children.body
        fnName = typeDefNode.children.name.literal
        symbolTable.setGlobal(fnName)


_parseSymbols = (astNode) ->
  # If astNode is an array, gen symbols for each element
  if astNode.length?
    for child in astNode
      _parseSymbols(child)
    return

  else if astNode.isFnDefProp()
    _parseSymbols(astNode.children.fnDef)
    fnName = astNode.children.fnName.literal
    symbolTable.setNamedSymbol(astNode, fnName)

  else if astNode.isArray()
    _parseSymbols(astNode.children.items)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isArrayRange()
    _parseSymbols(astNode.children.start)
    _parseSymbols(astNode.children.end)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isObject()
    _parseSymbols(astNode.children.props)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isArrayRef()
    _parseSymbols(astNode.children.arr)
    _parseSymbols(astNode.children.ref)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isObjectRef()
    _parseSymbols(astNode.children.obj)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    symbolTable.setNamedSymbol(astNode, varName)

  else if astNode.isNumber()
    symbolTable.setAnonSymbol(astNode, astNode.literal)

  else if astNode.isBoolean()
    symbolTable.setAnonSymbol(astNode, astNode.literal)

  else if astNode.isWast()
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isFunctionDef()
    _parseSymbols(astNode.children.args)
    _parseSymbols(astNode.children.body)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isFunctionDefArg()
    argName = astNode.children.id.literal
    symbolTable.setNamedSymbol(astNode, argName)

  else if astNode.isFunctionCall()
    _parseSymbols(astNode.children.fn)
    _parseSymbols(astNode.children.args)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isTypeDef()
    symbolName = astNode.children.name.literal
    symbolTable.setNamedSymbol(astNode, symbolName)

  else
    for name, child of astNode.children
      _parseSymbols(child)
  return


module.exports = genSymbols
