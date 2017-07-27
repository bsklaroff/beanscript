utils = require('./utils')

genWast = (rootNode, symbolTable) ->
  wast = '''
(module
  (memory 10000)
  (func (export "main") (result i32)

'''
  statements = rootNode.children.statements
  mainFunc = genFuncBody(statements, symbolTable, [], rootNode.scopeId)
  wast += addIndent(mainFunc, 2)
  wast += '  )\n'
  otherFuncs = genFuncDefs(statements, symbolTable)
  wast += addIndent(otherFuncs)
  wast += ')\n'
  return wast

addIndent = (wast, n = 1) ->
  wastSplit = wast.split('\n')
  # Don't indent the trailing newline
  for i in [0...wastSplit.length - 1]
    for j in [0...n]
      wastSplit[i] = "  #{wastSplit[i]}"
  return wastSplit.join('\n')

wastType = (bsType) ->
  if bsType == 'bool'
    return 'i32'
  return bsType

getScope = (symbol) -> symbol.name.split('~')[0]

getName = (symbol) -> "$#{symbol.name.split('~')[1]}"

getTypedFnName = (fnName, argSymbols) ->
  name = "$#{fnName}::"
  for argSymbol, i in argSymbols
    if i > 0
      name += '|'
    name += argSymbol.type
  return name

genFuncBody = (statements, symbolTable, argNames, scopeId) ->
  wast = ''
  wast += genLocals(symbolTable, argNames, scopeId)
  wast += genWastExprs(statements, symbolTable)
  return wast

genLocals = (symbolTable, argNames, scopeId) ->
  locals = ''
  for symbolName, symbol of symbolTable.symbols
    if getScope(symbol) == "#{scopeId}" and getName(symbol) not in argNames
      locals += "(local #{getName(symbol)} #{wastType(symbol.type)})\n"
  return locals

genWastExprs = (astNode, symbolTable) ->
  wast = ''

  if astNode.length?
    for child in astNode
      wast += genWastExprs(child, symbolTable)
    return wast

  if astNode.isAssignment()
    source = astNode.children.source
    # Don't parse function def assignments here
    if source.isFunctionDef()
      return wast
    sourceSymbol = symbolTable.getASTNodeSymbol(source)
    sourceName = getName(sourceSymbol)
    target = astNode.children.target
    targetSymbol = symbolTable.getASTNodeSymbol(target)
    targetName = getName(targetSymbol)
    wast += genWastExprs(source, symbolTable)
    wast += "(set_local #{targetName} (get_local #{sourceName}))\n"

  else if astNode.isOpParenGroup()
    opParenSymbol = symbolTable.getASTNodeSymbol(astNode)
    opParenName = getName(opParenSymbol)
    child = astNode.children.opExpr
    childSymbol = symbolTable.getASTNodeSymbol(child)
    childName = getName(childSymbol)
    wast += genWastExprs(child, symbolTable)
    wast += "(set_local #{opParenName} (get_local #{childName}))\n"

  else if astNode.isFunctionCall()
    fnCallSymbol = symbolTable.getASTNodeSymbol(astNode)
    fnCallName = getName(fnCallSymbol)
    fnName = astNode.children.fnName.children.id.literal
    args = astNode.children.args
    argSymbols = utils.map(args, (arg) -> symbolTable.getASTNodeSymbol(arg))
    typedFnName = getTypedFnName(fnName, argSymbols)
    for arg in args
      wast += genWastExprs(arg, symbolTable)
    wast += "(set_local #{fnCallName} (call #{typedFnName}"
    for argSymbol in argSymbols
      argName = getName(argSymbol)
      wast += " (get_local #{argName})"
    wast += '))\n'

  else if astNode.isNumber()
    symbol = symbolTable.getASTNodeSymbol(astNode)
    name = getName(symbol)
    type = wastType(symbol.type)
    wast += "(set_local #{name} (#{type}.const #{astNode.literal}))\n"

  else if astNode.isWast()
    symbol = symbolTable.getASTNodeSymbol(astNode)
    name = getName(symbol)
    bsWast = parseBSWast(astNode.children.sexpr, symbolTable)
    wast += "(set_local #{name} #{bsWast})\n"

  else if astNode.isReturn()
    returnVal = astNode.children.returnVal
    returnValSymbol = symbolTable.getASTNodeSymbol(returnVal)
    returnValName = getName(returnValSymbol)
    wast += genWastExprs(returnVal, symbolTable)
    wast += "(return (get_local #{returnValName}))\n"

  return wast

parseBSWast = (astNode, symbolTable) ->
  wast = ''

  if astNode.isSexpr()
    wast += '('
    for child, i in astNode.children.symbols
      if i > 0
        wast += ' '
      wast += parseBSWast(child, symbolTable)
    wast += ')'

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    props = astNode.children.props
    symbolName = "#{astNode.scopeId}~#{varName}"
    # If variable exists in outer scope, replace it with a proper wast reference
    if props.length == 0 and symbolTable.symbols[symbolName]?
      wast += "(get_local $#{varName})"
    else
      wast += varName
      for prop in props
        wast += ".#{prop.literal}"

  else if astNode.isNumber()
    wast += astNode.literal

  # TODO: handle double quoted string here

  return wast

genFuncDefs = (astNode, symbolTable) ->
  wast = ''

  if astNode.length?
    for child in astNode
      wast += genFuncDefs(child, symbolTable)
    return wast

  if astNode.isTypeInst()
    classinst = astNode.children.inst
    instType = classinst.children.type.literal
    for fnDefProp in astNode.children.fnDefs
      fnName = fnDefProp.children.fnName.literal
      fnDef = fnDefProp.children.fnDef
      # Determine concrete return type
      fnTypeInfo = symbolTable.typeInfo.fnTypes[fnName]
      returnType = fnTypeInfo.fnType[fnTypeInfo.fnType.length - 1]
      if returnType of fnTypeInfo.anonTypes
        returnType = instType
      # Determine typed fn name from fn name and arg symbols
      args = fnDef.children.args
      argSymbols = utils.map(args, (arg) -> symbolTable.getASTNodeSymbol(arg))
      typedFnName = getTypedFnName(fnName, argSymbols)
      # Generate wast
      wast += "(func #{typedFnName}"
      for argSymbol in argSymbols
        argName = getName(argSymbol)
        argType = wastType(argSymbol.type)
        wast += " (param #{argName} #{argType})"
      wast += " (result #{wastType(returnType)})\n"
      argNames = utils.map(argSymbols, getName)
      funcBody = genFuncBody(fnDef.children.body, symbolTable, argNames, fnDef.scopeId)
      wast += addIndent(funcBody)
      wast += ')\n'

  return wast

module.exports = genWast
