fs = require('fs')
utils = require('./utils')

PRIMITIVES =
  I32: 'i32'
  I64: 'i64'
  BOOL: 'bool'
  VOID: 'void'

FORMS =
  CONCRETE: 'concrete'
  VARIABLE: 'variable'
  FUNCTION: 'function'

TYPE_INDICES =
  function: 0
  void: 1
  i32: 2
  i64: 3
  bool: 4

symbolTable = null
typeEnv = null
typeclassEnv = null

genWast = (rootNode, _symbolTable, typeInfo) ->
  symbolTable = _symbolTable
  {typeEnv, typeclassEnv} = typeInfo
  # Parse typeinsts to map typeclass fns to fn defs
  fnDefs = []
  typeclassFns = _getTypeclassFns(rootNode)
  typeinstFnDefs = {}
  for symbol, insts of typeclassFns
    fnDefs.push({symbol: symbol, insts: insts})
    for typevar, instSymbol of insts
      typeinstFnDefs[instSymbol] = true
  # Traverse tree and pull all fnDef nodes out
  statements = rootNode.children.statements
  fnDefs = fnDefs.concat(_getFnDefs(statements))
  nonTypeinstFnDefs = []
  for fnDef in fnDefs
    if fnDef.symbol not of typeinstFnDefs
      nonTypeinstFnDefs.push(fnDef)
  # Find each unique number of arguments among our fn defs
  fnSigs = {}
  for fnDef in nonTypeinstFnDefs
    fnType = typeEnv[fnDef.symbol].type
    returnsVoid = _isVoid(fnType.arr[fnType.arr.length - 1])
    fnSigs[fnType.contextTypevars.length + fnType.arr.length] ?= {}
    fnSigs[fnType.contextTypevars.length + fnType.arr.length][returnsVoid] = true
  # Generate wast
  sexprs = []
  # Generate fnsig type definitions
  for argCount, returnOpts of fnSigs
    for returnsVoid of returnOpts
      returnsVoid = if returnsVoid == 'true' then true else false
      sigSymbol = _genSigSymbol(argCount, returnsVoid)
      sigType = _genSigType(argCount, returnsVoid)
      sexprs.push(['type', sigSymbol, sigType])
  # Generate function table and fn def globals
  tableSexpr = ['elem']
  for fnDef in nonTypeinstFnDefs
    tableSexpr.push(fnDef.symbol)
  sexprs.push(['table', 'anyfunc', tableSexpr])
  for fnDef, i in nonTypeinstFnDefs
    sexprs.push(['global', fnDef.symbol, 'i32', ['i32.const', i]])
  for symbol of _getNonTypeclassGlobals(rootNode, typeclassFns)
    sexprs.push(['global', symbol, ['mut', 'i32'], ['i32.const', '-1']])
  # Generate function definitions
  for fnDef, i in fnDefs
    if 'astNode' of fnDef
      {args, body} = fnDef.astNode.children
      fnSexpr = _genFn(fnDef.symbol, args, body, fnDef.astNode.scopeId)
    else
      fnSexpr = _genTypeclassFn(fnDef)
    sexprs.push(fnSexpr)
  # Generate main function
  mainName = ['export', '"main"']
  mainFn = _genFn(mainName, [], statements, rootNode.scopeId)
  sexprs.push(mainFn)
  # Generate wast string, get rid of extra parentheses
  wast = _wastToString(sexprs)[1...-1]
  runtime = fs.readFileSync("#{__dirname}/runtime.wast").toString()
  wast = runtime.replace('GENERATED_CODE_HERE', wast)
  return wast

_getTypeclassFns = (rootNode) ->
  typeclassFns = {}
  for astNode in rootNode.children.statements
    if not astNode.isTypeinst()
      continue
    instType = astNode.children.type.literal
    for fnDefPropNode in astNode.children.fnDefs
      symbol = symbolTable.getNodeSymbol(fnDefPropNode)
      fnDefSymbol = symbolTable.getNodeSymbol(fnDefPropNode.children.fnDef)
      typeclassFns[symbol] ?= {}
      typeclassFns[symbol][instType] = fnDefSymbol
  return typeclassFns

_getFnDefs = (astNode) ->
  fnDefs = []
  if astNode.length?
    for child in astNode
      fnDefs = fnDefs.concat(_getFnDefs(child))
    return fnDefs
  if astNode.isFunctionDef()
    symbol = symbolTable.getNodeSymbol(astNode)
    fnDefs.push({symbol: symbol, astNode: astNode})
  for name, child of astNode.children
    fnDefs = fnDefs.concat(_getFnDefs(child))
  return fnDefs

_getNonTypeclassGlobals = (rootNode, typeclassFns) ->
  nonTypeclassGlobals = {}
  for astNode in rootNode.children.statements
    if not astNode.isAssignment()
      continue
    targetSymbol = symbolTable.getNodeSymbol(astNode.children.target)
    if not symbolTable.isGlobal(targetSymbol)
      continue
    if targetSymbol of nonTypeclassGlobals
      console.error("Cannot redefine global symbol #{targetSymbol}")
      process.exit(1)
    if targetSymbol of typeclassFns
      console.error("Cannot redefine typeclass fn #{targetSymbol}")
      process.exit(1)
    nonTypeclassGlobals[targetSymbol] = true
  return nonTypeclassGlobals

_genSigSymbol = (argCount, returnsVoid) ->
  voidStr = if returnsVoid then 'void' else ''
  return "$fnsig#{argCount - 1}#{voidStr}"

_genSigType = (argCount, returnsVoid) ->
  sexpr = ['func']
  for i in [0...argCount - 1]
    sexpr.push(['param', 'i32'])
  if not returnsVoid
    sexpr.push(['result', 'i32'])
  return sexpr

_genFn = (symbol, args, statements, scopeId) ->
  argSymbols = utils.map(args, (arg) -> symbolTable.getNodeSymbol(arg))
  sexpr = ['func', symbol]
  # Don't generate args for main fn
  if utils.isString(symbol)
    fnType = typeEnv[symbol].type
    argSymbols = fnType.contextTypevars.concat(argSymbols)
    sexpr = sexpr.concat(_genArgs(argSymbols))
    if not _isVoid(fnType.arr[fnType.arr.length - 1])
      sexpr.push(['result', 'i32'])
  sexpr = sexpr.concat(_genLocals(symbol, argSymbols, scopeId))
  sexpr = sexpr.concat(_genSexprs(statements))
  return sexpr

_genTypeclassFn = (fnDef) ->
  {symbol, insts} = fnDef
  fnType = typeEnv[symbol].type
  argSymbols = []
  # For polymorphic fns, include context typevars as args
  for contextTypevar in fnType.contextTypevars
    argSymbols.push(contextTypevar)
  for argType, i in fnType.arr[...fnType.arr.length - 1]
    argSymbols.push("$arg#{i}")
  # Generate sexpr
  sexpr = ['func', symbol]
  sexpr = sexpr.concat(_genArgs(argSymbols))
  returnsVoid = _isVoid(fnType.arr[fnType.arr.length - 1])
  if not returnsVoid
    sexpr.push(['result', 'i32'])
  # For each possible type of the typeclass typevar, add an if statement and
  # call the correct typeinst fn def
  for instType, fnDefSymbol of insts
    fnCallSexpr = ['call', fnDefSymbol]
    for argSymbol in argSymbols[1..]
      fnCallSexpr.push(['get_local', argSymbol])
    # TODO: ensure that typeclass typevar is always first amongst contextTypevars
    ifSexpr = ['if', ['i32.eq', ['get_local', argSymbols[0]], ['i32.const', TYPE_INDICES[instType]]]]
    if returnsVoid
      ifSexpr.push(['then', fnCallSexpr])
    else
      ifSexpr.push(['then', ['return', fnCallSexpr]])
    sexpr.push(ifSexpr)
  if not returnsVoid
    sexpr.push(['return', ['i32.const', '-1']])
  return sexpr

_genArgs = (argSymbols) ->
  sexprs = []
  for argSymbol in argSymbols
    sexprs.push(['param', argSymbol, 'i32'])
  return sexprs

_genLocals = (fnNameSymbol, argSymbols, scopeId) ->
  sexprs = []
  # Gen (local ...) var declerations
  for symbol, scheme of typeEnv
    if symbolTable.getScope(symbol) == scopeId and not symbolTable.isGlobal(symbol) and
       not symbolTable.isReturn(symbol) and symbol not in argSymbols and symbol != fnNameSymbol
      sexprs.push(['local', symbol, 'i32'])
  return sexprs

_genSexprs = (astNode) ->
  sexprs = []

  if astNode.length?
    for child in astNode
      sexprs = sexprs.concat(_genSexprs(child))
    return sexprs

  if astNode.isAssignment()
    source = astNode.children.source
    sourceSymbol = symbolTable.getNodeSymbol(source)
    target = astNode.children.target
    targetSymbol = symbolTable.getNodeSymbol(target)
    sexprs = sexprs.concat(_genSexprs(source))
    sexprs.push(_set(targetSymbol, _get(sourceSymbol)))

  else if astNode.isOpParenGroup()
    opParenSymbol = symbolTable.getNodeSymbol(astNode)
    child = astNode.children.opExpr
    childSymbol = symbolTable.getNodeSymbol(child)
    sexprs = sexprs.concat(_genSexprs(child))
    sexprs.push(_set(opParenSymbol, _get(childSymbol)))

  else if astNode.isWhile()
    cond = astNode.children.condition
    condSymbol = symbolTable.getNodeSymbol(cond)
    body = astNode.children.body
    loopSexpr = ['loop'].concat(_genSexprs(cond))
    loopSexpr.push(['br_if', 1, ['i32.eq', ['i32.const', 0], _unbox(condSymbol)]])
    loopSexpr = loopSexpr.concat(_genSexprs(body))
    loopSexpr.push(['br', 0])
    sexprs.push(['block', loopSexpr])

  else if astNode.isFunctionCall()
    # TODO: account for anonymous / nested fns
    # Generate code for arguments
    args = astNode.children.args
    sexprs = sexprs.concat(_genSexprs(args))
    # Call function from function table
    fnCallSexpr = ['call_indirect']
    # Get type signature from fn def type
    fnName = symbolTable.getNodeSymbol(astNode.children.fn)
    fnType = typeEnv[fnName].type
    returnsVoid = _isVoid(fnType.arr[fnType.arr.length - 1])
    fnCallSexpr.push(_genSigSymbol(fnType.arr.length + fnType.contextTypevars.length, returnsVoid))
    # Pull out concrete symbols to use in contextTypevar search
    argSymbols = utils.map(args, (arg) -> symbolTable.getNodeSymbol(arg))
    fnCallSymbol = symbolTable.getNodeSymbol(astNode)
    # For polymorphic fns, pass context typevar types
    # Find each typevar by recursive searching the fnType
    for contextTypevar in fnType.contextTypevars
      contextType = _findContextTypevar(contextTypevar, fnType.arr, argSymbols.concat(fnCallSymbol))
      fnCallSexpr.push(contextType)
    # Pass actual arguments
    for argSymbol in argSymbols
      fnCallSexpr.push(_get(argSymbol))
    # Generate the function def index
    fnCallSexpr.push(_get(fnName))
    # Assign return value to function call symbol
    # Set return value if function is not void
    if not _isVoid(typeEnv[fnCallSymbol].type)
      fnCallSexpr = _set(fnCallSymbol, fnCallSexpr)
    sexprs.push(fnCallSexpr)

  else if astNode.isNumber()
    symbol = symbolTable.getNodeSymbol(astNode)
    #type = typeEnv[symbol].type
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', astNode.literal]))

  else if astNode.isBoolean()
    symbol = symbolTable.getNodeSymbol(astNode)
    literal = if astNode.literal == 'true' then 1 else 0
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', literal]))

  else if astNode.isWast()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = typeEnv[symbol].type
    wastSexpr = _parseBSWast(astNode.children.sexpr)
    if type.form != FORMS.CONCRETE
      sexprs.push(wastSexpr)
    else
      sexprs = sexprs.concat(_setHeapVar(symbol, wastSexpr))

  else if astNode.isReturn()
    returnVal = astNode.children.returnVal
    returnValSymbol = symbolTable.getNodeSymbol(returnVal)
    sexprs = sexprs.concat(_genSexprs(returnVal))
    sexprs.push(['return', _get(returnValSymbol)])

  return sexprs

_isVoid = (type) -> type.form == FORMS.CONCRETE and type.name == PRIMITIVES.VOID

_set = (symbol, source) ->
  if _isVoid(typeEnv[symbol].type)
    return source
  if symbolTable.isGlobal(symbol) or symbolTable.isFunctionDef(symbol)
    return ['set_global', symbol, source]
  return ['set_local', symbol, source]

_get = (symbol) ->
  if _isVoid(typeEnv[symbol].type)
    console.error("Void type found for #{symbol}: #{JSON.stringify(typeEnv[symbol])}")
    process.exit(1)
  if symbolTable.isGlobal(symbol) or symbolTable.isFunctionDef(symbol)
    return ['get_global', symbol]
  return ['get_local', symbol]

# TODO: recursively search function arguments for context typevar
_findContextTypevar = (typevar, typeArr, argAndReturnSymbols) ->
  for type, i in typeArr
    # If we found a symbol corresponding to our context typevar, try to return it
    if type.form == FORMS.VARIABLE and type.var == typevar
      targetScheme = typeEnv[argAndReturnSymbols[i]]
      targetType = targetScheme.type
      if targetType.form == FORMS.CONCRETE
        # We found a concrete type, return it
        return _getTypeIndex(targetType)
      else if targetType.form == FORMS.VARIABLE and targetType.var not in targetScheme.forall
        # We found a typevar arg from the enclosing function, return it
        return _getTypeIndex(targetType)
      else if targetType.form == FORMS.FUNCTION
        # Function types cannot be typeclassed for now
        console.error('Function type cannot be passed as a context typevar')
        process.exit(1)
  return

_setHeapVar = (symbol, dataSexpr) ->
  type = typeEnv[symbol].type
  sexprs = []
  sexprs.push(_set(symbol, ['get_global', '$hp']))
  sexprs.push([_getStoreFn(type), ['get_global', '$hp'], dataSexpr])
  sexprs.push(['set_global', '$hp', ['i32.add', ['get_global', '$hp'], _getTypeSize(type)]])
  return sexprs

_getTypeIndex = (type) ->
  if type.form == FORMS.FUNCTION
    return ['i32.const', TYPE_INDICES[type.form]]
  else if type.form == FORMS.CONCRETE
    return ['i32.const', TYPE_INDICES[type.name]]
  else if type.form == FORMS.VARIABLE
    return ['get_local', type.var]
  return

_unbox = (symbol) ->
  type = typeEnv[symbol].type
  if type.form != FORMS.CONCRETE
    console.error("Could not unbox non-concrete type: #{JSON.stringify(type)}")
    process.exit(1)
  if type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL]
    return ['i32.load', _get(symbol)]
  else if type.name == PRIMITIVES.I64
    return ['i64.load', _get(symbol)]
  console.error("Unbox unimplemented for type: #{JSON.stringify(type)}")
  process.exit(1)
  return

_getStoreFn = (type) ->
  if type.form != FORMS.CONCRETE
    console.error("Could not get store fn for non-concrete type: #{JSON.stringify(type)}")
    process.exit(1)
  if type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL]
    return 'i32.store'
  else if type.name == PRIMITIVES.I64
    return 'i64.store'
  console.error("Store fn unimplemented for type: #{JSON.stringify(type)}")
  process.exit(1)
  return

_getTypeSize = (type) ->
  if type.form != FORMS.CONCRETE
    console.error("Could not get type size for non-concrete type: #{JSON.stringify(type)}")
    process.exit(1)
  if type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL]
    return ['i32.const', '4']
  else if type.name == PRIMITIVES.I64
    return ['i32.const', '8']
  console.error("Type size unimplemented for type: #{JSON.stringify(type)}")
  process.exit(1)
  return

_parseBSWast = (astNode) ->

  if astNode.isSexpr()
    sexpr = []
    for child, i in astNode.children.symbols
      sexpr.push(_parseBSWast(child))
    return sexpr

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    props = astNode.children.props
    symbol = symbolTable.getSymbolName(varName, astNode.scopeId)
    # If variable exists in outer scope, replace it with a proper wast reference
    if props.length == 0 and symbol of typeEnv
      return _unbox(symbol)
    # Otherwise, pass the string through
    str = varName
    for prop in props
      str += ".#{prop.literal}"
    return str

  else if astNode.isNumber()
    return astNode.literal

  # TODO: handle double quoted string here

  console.error("Unhandled node during bs wast parsing: #{JSON.stringify(astNode)}")
  process.exit(1)
  return

_shouldAddNewline = (arr, i) ->
  if utils.isArray(arr[0])
    return true
  if arr[0] in ['loop', 'func']
    # Add newline at end only if we added a newline for the last element in arr
    if i == -1
      i = arr.length - 2
    if not utils.isArray(arr[i + 1])
      return false
    if arr[i + 1][0] in ['import', 'export', 'param', 'result']
      return false
    return true
  return false

_wastToString = (arr, indent = '  ') ->
  wast = '('
  for val, i in arr
    if utils.isArray(val)
      wast += _wastToString(val, indent + '  ')
    else
      wast += val
    if i != arr.length - 1
      if _shouldAddNewline(arr, i)
        wast += "\n#{indent}"
      else
        wast += ' '
  if _shouldAddNewline(arr, -1)
    endIndent = indent[...-2]
    wast += "\n#{endIndent}"
  wast += ')'
  return wast


module.exports = genWast
