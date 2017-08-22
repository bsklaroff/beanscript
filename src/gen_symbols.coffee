SymbolTable = require('./symbol_table')
symbolTable = null

genSymbols = (rootNode) ->
  symbolTable = new SymbolTable()
  _parseSymbols(rootNode)
  return symbolTable

_parseSymbols = (astNode) ->
  # If astNode is an array, gen symbols for each element
  if astNode.length?
    for child in astNode
      _parseSymbols(child)
    return

  if astNode.isAssignment()
    _parseSymbols(astNode.children.source)
    target = astNode.children.target
    targetName = target.children.id.literal
    symbolTable.setNamedSymbol(target, targetName)

  else if astNode.isOpParenGroup()
    _parseSymbols(astNode.children.opExpr)
    symbolTable.setAnonSymbol(astNode)

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    symbolTable.setNamedSymbol(astNode, varName)

  else if astNode.isNumber()
    symbolTable.setAnonSymbol(astNode, astNode.literal)

  else if astNode.isBoolean()
    symbolTable.setAnonSymbol(astNode, astNode.literal)

  else if astNode.isWast()
    symbolTable.setAnonSymbol(astNode, astNode.literal)

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

    ###
  else if astNode.isTypeclassDef()
    typeclass = astNode.children.typeclass
    className = typeclass.children.class.literal
    anonType = typeclass.children.anonType.literal
    superclasses = utils.map(astNode.children.superclasses, (a) -> a.literal)
    defaultType = null
    if not astNode.children.default.isEmpty()
      defaultType = Type.fromTypeWithContext(astNode.children.default)
    fns = []
    for typeDef in astNode.children.body
      fnName = typeDef.children.name.literal
      fnType = Type.fromTypeWithContext(typeDef.children.type)
      fnDefSymbol = symbolTable.getOrAddSymbol(typeDef, fnName)
      symbolTable.setTypeclass(fnDefSymbol, className, anonType, fnType)
      fns.push(fnDefSymbol.name)
    symbolTable.typeclasses[className] =
      supers: superclasses
      fns: fns
      default: defaultType

  else if astNode.isTypeInst()
    instClass = astNode.children.class.literal
    instType = astNode.children.type.literal
    fnDefProps = astNode.children.fnDefs
    _parseSymbols(fnDefProps, parentFnDefSymbol)
    for fnDefProp in fnDefProps
      fnDef = fnDefProp.children.fnDef
      fnDefSymbol = symbolTable.getASTNodeSymbol(fnDef)
      target = fnDefProp.children.fnName
      targetSymbol = symbolTable.getOrAddSymbol(target, target.literal)
      symbolTable.addTypeInst(targetSymbol, instType, fnDefSymbol.name)
    ###

  else
    for name, child of astNode.children
      _parseSymbols(child)
  return


module.exports = genSymbols
