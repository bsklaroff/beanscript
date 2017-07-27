utils = require('./utils')

genSymbols = (rootNode, symbolTable) ->
  parseSymbols(rootNode, symbolTable)
  symbolTable.assignAllTypes()
  return symbolTable

parseSymbols = (astNode, symbolTable, returnType = null) ->
  # If astNode is an array, gen symbols for each element
  if astNode.length?
    for child in astNode
      parseSymbols(child, symbolTable, returnType)
    return

  # Otherwise, gen children symbols, and then treat astNode based on its type
  if astNode.isAssignment()
    source = astNode.children.source
    parseSymbols(source, symbolTable, returnType)
    sourceSymbol = symbolTable.getASTNodeSymbol(source)
    target = astNode.children.target
    targetName = target.children.var.children.id.literal
    targetType = target.children.type
    targetSymbol = symbolTable.getOrAddSymbol(target, targetName)
    if not targetType.isEmpty()
      symbolTable.addTypeConstraint(targetSymbol, targetType.children.primitive.literal)
    symbolTable.unifyTypes(sourceSymbol, targetSymbol)

  else if astNode.isOpParenGroup()
    child = astNode.children.opExpr
    parseSymbols(child, symbolTable, returnType)
    childSymbol = symbolTable.getASTNodeSymbol(child)
    opParenSymbol = symbolTable.addAnonSymbol(astNode)
    symbolTable.unifyTypes(childSymbol, opParenSymbol)

  else if astNode.isReturn()
    child = astNode.children.returnVal
    parseSymbols(child, symbolTable, returnType)
    childSymbol = symbolTable.getASTNodeSymbol(child)
    #TODO: Remove the temporary ? 'i32' to allow returns from files
    symbolTable.addTypeConstraint(childSymbol, returnType ? 'i32')

  else if astNode.isFunctionCall()
    args = astNode.children.args
    parseSymbols(args, symbolTable, returnType)
    fnName = astNode.children.fnName.children.id.literal
    fnCallSymbol = symbolTable.addAnonSymbol(astNode, fnName)
    argSymbols = utils.map(args, (arg) -> symbolTable.getASTNodeSymbol(arg))
    symbolTable.addFnCallConstraints(fnName, fnCallSymbol, argSymbols)

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    symbolTable.getOrAddSymbol(astNode, varName)

  else if astNode.isNumber()
    numSymbol = symbolTable.addAnonSymbol(astNode, astNode.literal)
    symbolTable.addTypeConstraint(numSymbol, 'num')

  else if astNode.isTypeDef()
    #console.log('typedef unimplemented')

  else if astNode.isWast()
    symbolTable.addAnonSymbol(astNode, astNode.literal)

  # TODO: make this work for more complex typeclasses
  else if astNode.isTypeInst()
    classinst = astNode.children.inst
    instType = classinst.children.type.literal
    for fnDefProp in astNode.children.fnDefs
      fnName = fnDefProp.children.fnName.literal
      fnDef = fnDefProp.children.fnDef
      fnTypeInfo = symbolTable.typeInfo.fnTypes[fnName]
      if not fnTypeInfo?
        console.log("ERROR: type inst fn #{fnName} has no typeclass info")
        process.exit(1)
      # Create concrete fn type from anon fn type and type inst type
      concreteFnType = []
      for type in fnTypeInfo.fnType
        if type of fnTypeInfo.anonTypes
          concreteFnType.push(instType)
        else
          concreteFnType.push(type)
      # Assign symbols for all function def args
      fnDefArgs = fnDef.children.args
      for arg, i in fnDefArgs
        if not arg.children.type.isEmpty()
          console.log("ERROR: all typeinst fn args must be untyped")
          process.exit(1)
        argName = arg.children.id.literal
        argSymbol = symbolTable.getOrAddSymbol(arg, argName)
        symbolTable.addTypeConstraint(argSymbol, concreteFnType[i])
      # Assign symbols for function def body, passing in return type
      bodyReturnType = concreteFnType[concreteFnType.length - 1]
      parseSymbols(fnDef.children.body, symbolTable, bodyReturnType)

  else
    for name, child of astNode.children
      parseSymbols(child, symbolTable, returnType)
  return

module.exports = genSymbols
