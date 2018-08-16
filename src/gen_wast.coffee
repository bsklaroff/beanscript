fs = require('fs')
errors = require('./errors')
utils = require('./utils')

PRIMITIVES =
  I32: 'I32'
  I64: 'I64'
  BOOL: 'Bool'
  CHAR: 'Char'
  VOID: 'Void'

CONSTRUCTORS =
  ARR: 'Arr'
  FN: 'Fn'

FORMS =
  CONCRETE: 'concrete'
  VARIABLE: 'variable'
  OBJECT: 'object'
  CONSTRUCTED: 'constructed'

TYPE_INDICES =
  function: 0
  Void: 1
  I32: 2
  I64: 3
  Bool: 4
  Char: 5

symbolTable = null
newTypes = null
typeEnv = null

genWast = (rootNode, _symbolTable, typeInfo) ->
  symbolTable = _symbolTable
  {newTypes, typeEnv} = typeInfo
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
    returnsVoid = _isVoid(fnType.params[fnType.params.length - 1])
    fnSigs[fnType.contextTypevars.length + fnType.params.length] ?= {}
    fnSigs[fnType.contextTypevars.length + fnType.params.length][returnsVoid] = true
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
      errors.panic("Cannot redefine global symbol #{targetSymbol}")
    if targetSymbol of typeclassFns
      errors.panic("Cannot redefine typeclass fn #{targetSymbol}")
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
    if not _isVoid(fnType.params[fnType.params.length - 1])
      sexpr.push(['result', 'i32'])
  sexpr = sexpr.concat(_genLocals(symbol, args, scopeId))
  sexpr = sexpr.concat(_genArgDestructions(args))
  sexpr = sexpr.concat(_genSexprs(statements))
  return sexpr

_genTypeclassFn = (fnDef) ->
  {symbol, insts} = fnDef
  fnType = typeEnv[symbol].type
  argSymbols = []
  # For polymorphic fns, include context typevars as args
  for contextTypevar in fnType.contextTypevars
    argSymbols.push(contextTypevar)
  for argType, i in fnType.params[...fnType.params.length - 1]
    argSymbols.push("$arg#{i}")
  # Generate sexpr
  sexpr = ['func', symbol]
  sexpr = sexpr.concat(_genArgs(argSymbols))
  returnsVoid = _isVoid(fnType.params[fnType.params.length - 1])
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

_genLocals = (fnNameSymbol, argNodes, scopeId) ->
  sexprs = []
  dataSymbols = []
  # Gen (local ...) var declerations for unboxed data in args
  for argNode in argNodes
    if argNode.isConstructed()
      dataNode = argNode.children.data
      if dataNode.isVariable() and dataNode.children.id.literal != '_'
        dataSymbol = symbolTable.getNodeSymbol(dataNode)
        sexprs.push(['local', dataSymbol, 'i32'])
        dataSymbols.push(dataSymbol)
  # Gen (local ...) var declerations
  argSymbols = utils.map(argNodes, (arg) -> symbolTable.getNodeSymbol(arg))
  for symbol, scheme of typeEnv
    if symbolTable.getScope(symbol) == scopeId and
       not symbolTable.isGlobal(symbol) and
       not symbolTable.isReturn(symbol) and
       symbol not in argSymbols and
       symbol not in dataSymbols and
       symbol != fnNameSymbol
      sexprs.push(['local', symbol, 'i32'])
  return sexprs

_genArgDestructions = (argNodes) ->
  sexprs = []
  for argNode in argNodes
    if argNode.isConstructed()
      argSymbol = symbolTable.getNodeSymbol(argNode)
      dataNode = argNode.children.data
      if not dataNode.isEmpty()
        if dataNode.isVariable()
          varName = dataNode.children.id.literal
          if varName != '_'
            dataSymbol = symbolTable.getNodeSymbol(dataNode)
            heapLoc = ['i32.add', _get(argSymbol), ['i32.const', 4]]
            sexprs.push(_set(dataSymbol, ['i32.load', heapLoc]))
        else
          errors.panic('Nested destruction unimplemented')
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
    sexprs = sexprs.concat(_genSexprs(source))
    target = astNode.children.target
    if target.isVariable()
      targetSymbol = symbolTable.getNodeSymbol(target)
      sexprs.push(_set(targetSymbol, _get(sourceSymbol)))
    else if target.isObjectRef()
      obj = target.children.obj
      sexprs = sexprs.concat(_genSexprs(obj))
      objSymbol = symbolTable.getNodeSymbol(obj)
      objType = typeEnv[objSymbol].type
      idx = objType.keys.indexOf(target.children.ref.literal)
      heapOffset = ['i32.mul', ['i32.const', idx], _getTypeSize(_genConcreteType(PRIMITIVES.I32))]
      heapLoc = ['i32.add', _get(objSymbol), heapOffset]
      sexprs.push(['i32.store', heapLoc, _get(sourceSymbol)])
    else
      errors.panic("Assignment target must be variable or array ref, found #{JSON.stringify(target)}")

  else if astNode.isConstructed()
    dataNode = astNode.children.data
    sexprs = sexprs.concat(_genSexprs(dataNode))
    constructor = astNode.children.constructor.literal
    symbol = symbolTable.getNodeSymbol(astNode)
    type = typeEnv[symbol].type
    idx = newTypes[type.name].constructors.indexOf(constructor)
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', idx]))
    if not dataNode.isEmpty()
      dataSymbol = symbolTable.getNodeSymbol(dataNode)
      sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), _get(dataSymbol)))

  else if astNode.isDestruction()
    symbol = symbolTable.getNodeSymbol(astNode)
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', 0]))
    unboxed = astNode.children.unboxed
    unboxedSymbol = symbolTable.getNodeSymbol(unboxed)
    constructor = unboxed.children.constructor.literal
    unboxedType = typeEnv[unboxedSymbol].type
    idx = newTypes[unboxedType.name].constructors.indexOf(constructor)
    boxed = astNode.children.boxed
    boxedSymbol = symbolTable.getNodeSymbol(boxed)
    sexprs = sexprs.concat(_genSexprs(boxed))
    ifSexpr = ['if', ['i32.eq', _unbox(boxedSymbol), ['i32.const', idx]]]
    thenSexpr = ['then']
    thenSexpr = thenSexpr.concat(_setHeapVar(symbol, ['i32.const', 1]))
    dataNode = unboxed.children.data
    if not dataNode.isEmpty()
      if dataNode.isVariable()
        varName = dataNode.children.id.literal
        if varName != '_'
          dataSymbol = symbolTable.getNodeSymbol(dataNode)
          heapLoc = ['i32.add', _get(boxedSymbol), ['i32.const', 4]]
          symbol = symbolTable.getNodeSymbol(astNode)
          thenSexpr.push(_set(dataSymbol, ['i32.load', heapLoc]))
      else
        errors.panic('Nested destruction unimplemented')
    ifSexpr.push(thenSexpr)
    sexprs.push(ifSexpr)

  else if astNode.isOpParenGroup()
    opParenSymbol = symbolTable.getNodeSymbol(astNode)
    child = astNode.children.opExpr
    childSymbol = symbolTable.getNodeSymbol(child)
    sexprs = sexprs.concat(_genSexprs(child))
    sexprs.push(_set(opParenSymbol, _get(childSymbol)))

  else if astNode.isIf()
    conditionNode = astNode.children.condition
    conditionSymbol = symbolTable.getNodeSymbol(conditionNode)
    bodyNode = astNode.children.body
    elseNode = astNode.children.else
    sexprs = sexprs.concat(_genSexprs(conditionNode))
    ifSexpr = ['if', _unbox(conditionSymbol)]
    ifSexpr.push(['then'].concat(_genSexprs(bodyNode)))
    if not elseNode.isEmpty()
      ifSexpr.push(['else'].concat(_genSexprs(elseNode)))
    sexprs.push(ifSexpr)

  else if astNode.isElse()
    sexprs = sexprs.concat(_genSexprs(astNode.children.body))

  else if astNode.isWhile()
    cond = astNode.children.condition
    condSymbol = symbolTable.getNodeSymbol(cond)
    body = astNode.children.body
    loopSexpr = ['loop'].concat(_genSexprs(cond))
    loopSexpr.push(['br_if', 1, ['i32.eq', ['i32.const', 0], _unbox(condSymbol)]])
    loopSexpr = loopSexpr.concat(_genSexprs(body))
    loopSexpr.push(['br', 0])
    sexprs.push(['block', loopSexpr])

  else if astNode.isAndExpression()
    lhs = astNode.children.lhs
    rhs = astNode.children.rhs
    symbol = symbolTable.getNodeSymbol(astNode)
    lhsSymbol = symbolTable.getNodeSymbol(lhs)
    rhsSymbol = symbolTable.getNodeSymbol(rhs)
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', 0]))
    sexprs = sexprs.concat(_genSexprs(lhs))
    ifSexpr = ['if', _unbox(lhsSymbol)]
    thenSexpr = ['then'].concat(_genSexprs(rhs))
    innerIfSexpr = ['if', _unbox(rhsSymbol)]
    innerThenSexpr = ['then'].concat(_setHeapVar(symbol, ['i32.const', 1]))
    innerIfSexpr.push(innerThenSexpr)
    thenSexpr.push(innerIfSexpr)
    ifSexpr.push(thenSexpr)
    sexprs.push(ifSexpr)

  else if astNode.isOrExpression()
    lhs = astNode.children.lhs
    rhs = astNode.children.rhs
    symbol = symbolTable.getNodeSymbol(astNode)
    lhsSymbol = symbolTable.getNodeSymbol(lhs)
    rhsSymbol = symbolTable.getNodeSymbol(rhs)
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', 0]))
    sexprs = sexprs.concat(_genSexprs(lhs))
    ifSexpr = ['if', _unbox(lhsSymbol)]
    thenSexpr = ['then'].concat(_setHeapVar(symbol, ['i32.const', 1]))
    elseSexpr = ['else'].concat(_genSexprs(rhs))
    innerIfSexpr = ['if', _unbox(rhsSymbol)]
    innerThenSexpr = ['then'].concat(_setHeapVar(symbol, ['i32.const', 1]))
    innerIfSexpr.push(innerThenSexpr)
    elseSexpr.push(innerIfSexpr)
    ifSexpr.push(thenSexpr)
    ifSexpr.push(elseSexpr)
    sexprs.push(ifSexpr)

  else if astNode.isArray()
    itemNodes = astNode.children.items
    sexprs = sexprs.concat(_genSexprs(itemNodes))
    arrSymbol = symbolTable.getNodeSymbol(astNode)
    sexprs.push(_set(arrSymbol, ['get_global', '$hp']))
    # Add num elements in array
    sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), ['i32.const', itemNodes.length]))
    # Add allocation size
    sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), ['i32.const', itemNodes.length]))
    # Add pointer to start of array
    sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), ['i32.add', ['get_global', '$hp'], ['i32.const', 4]]))
    # Push array elements onto heap
    for itemNode in itemNodes
      itemSymbol = symbolTable.getNodeSymbol(itemNode)
      sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), _get(itemSymbol)))

  #TODO: astNode.isArrayRange

  else if astNode.isObject()
    propNodes = astNode.children.props
    sexprs = sexprs.concat(_genSexprs(propNodes))
    objSymbol = symbolTable.getNodeSymbol(astNode)
    sexprs.push(_set(objSymbol, ['get_global', '$hp']))
    for propNode in propNodes.sort((a, b) -> a.children.key.literal.localeCompare(b.children.key.literal))
      valSymbol = symbolTable.getNodeSymbol(propNode.children.val)
      sexprs = sexprs.concat(_addToHeap(_genConcreteType(PRIMITIVES.I32), _get(valSymbol)))

  else if astNode.isObjectProp()
    sexprs = sexprs.concat(_genSexprs(astNode.children.val))

  else if astNode.isObjectRef()
    obj = astNode.children.obj
    sexprs = sexprs.concat(_genSexprs(obj))
    objSymbol = symbolTable.getNodeSymbol(obj)
    objType = typeEnv[objSymbol].type
    idx = objType.keys.indexOf(astNode.children.ref.literal)
    heapOffset = ['i32.mul', ['i32.const', idx], _getTypeSize(_genConcreteType(PRIMITIVES.I32))]
    heapLoc = ['i32.add', _get(objSymbol), heapOffset]
    symbol = symbolTable.getNodeSymbol(astNode)
    sexprs.push(_set(symbol, ['i32.load', heapLoc]))

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
    returnsVoid = _isVoid(fnType.params[fnType.params.length - 1])
    fnCallSexpr.push(_genSigSymbol(fnType.params.length + fnType.contextTypevars.length, returnsVoid))
    # Pull out concrete symbols to use in contextTypevar search
    argSymbols = utils.map(args, (arg) -> symbolTable.getNodeSymbol(arg))
    fnCallSymbol = symbolTable.getNodeSymbol(astNode)
    # For polymorphic fns, pass context typevar types
    # Find each typevar by recursive searching the fnType
    for contextTypevar in fnType.contextTypevars
      argSchemes = utils.map(argSymbols.concat(fnCallSymbol), (symbol) -> typeEnv[symbol])
      contextType = _findContextTypevar(contextTypevar, fnType.params, argSchemes)
      if not contextType?
        errors.panic("Failed to find context typevar #{contextTypevar} for #{fnCallSymbol}")
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

  # TODO: fix number defaulting instead of hardcoding i32
  else if astNode.isNumber()
    symbol = symbolTable.getNodeSymbol(astNode)
    #type = typeEnv[symbol].type
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', astNode.literal]))

  else if astNode.isBoolean()
    symbol = symbolTable.getNodeSymbol(astNode)
    literal = if astNode.literal == 'True' then 1 else 0
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', literal]))

  else if astNode.isChar()
    symbol = symbolTable.getNodeSymbol(astNode)
    charCode = astNode.literal.charCodeAt()
    sexprs = sexprs.concat(_setHeapVar(symbol, ['i32.const', charCode]))

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
    if returnVal.isEmpty()
      sexprs.push(['return'])
    else
      returnValSymbol = symbolTable.getNodeSymbol(returnVal)
      sexprs = sexprs.concat(_genSexprs(returnVal))
      sexprs.push(['return', _get(returnValSymbol)])

  else if astNode.isReturnPtr()
    returnVal = astNode.children.returnVal
    returnValSymbol = symbolTable.getNodeSymbol(returnVal)
    sexprs = sexprs.concat(_genSexprs(returnVal))
    sexprs.push(['return', _unbox(returnValSymbol)])

  return sexprs

_genScheme = (forall, type) ->
  return {
    forall: forall
    type: type
  }

_genConcreteType = (name) ->
  return {
    form: FORMS.CONCRETE
    name: name
  }

_isVoid = (type) -> type.form == FORMS.CONCRETE and type.name == PRIMITIVES.VOID

_set = (symbol, source) ->
  if _isVoid(typeEnv[symbol].type)
    return source
  if symbolTable.isGlobal(symbol) or symbolTable.isFunctionDef(symbol)
    return ['set_global', symbol, source]
  return ['set_local', symbol, source]

_get = (symbol) ->
  if _isVoid(typeEnv[symbol].type)
    errors.panic("Void type found for #{symbol}: #{JSON.stringify(typeEnv[symbol])}")
  if symbolTable.isGlobal(symbol) or symbolTable.isFunctionDef(symbol)
    return ['get_global', symbol]
  return ['get_local', symbol]

_findContextTypevar = (typevar, typeArr, argSchemes) ->
  for type, i in typeArr

    # If we found a symbol corresponding to our context typevar, try to return it
    if type.form == FORMS.VARIABLE and type.var == typevar
      targetScheme = argSchemes[i]
      targetType = targetScheme.type
      if targetType.form == FORMS.CONCRETE
        # We found a concrete type, return it
        return _getTypeIndex(targetType)
      else if targetType.form == FORMS.VARIABLE and targetType.var not in targetScheme.forall
        # We found a typevar arg from the enclosing function, return it
        return _getTypeIndex(targetType)
      else if targetType.form == FORMS.CONSTRUCTED
        # Constructed types cannot be typeclassed for now
        errors.panic('Constructed type cannot be passed as a context typevar')

    else if type.form == FORMS.CONSTRUCTED
      if argSchemes[i].type.form != FORMS.CONSTRUCTED
        errors.panic("Arg scheme #{JSON.stringify(argSchemes[i])} should be constructed form")
      if argSchemes[i].type.name != type.name
        errors.panic("Arg scheme #{JSON.stringify(argSchemes[i])} should have name #{type.name}")
      paramSchemes = utils.map(argSchemes[i].type.params, (p) -> _genScheme(argSchemes[i].forall, p))
      contextTypevar = _findContextTypevar(typevar, type.params, paramSchemes)
      if contextTypevar?
        return contextTypevar

  return

_setHeapVar = (symbol, dataSexpr) ->
  sexprs = [_set(symbol, ['get_global', '$hp'])]
  sexprs = sexprs.concat(_addToHeap(typeEnv[symbol].type, dataSexpr))
  return sexprs

_addToHeap = (type, dataSexpr) ->
  return [
    [_getStoreFn(type), ['get_global', '$hp'], dataSexpr]
    ['set_global', '$hp', ['i32.add', ['get_global', '$hp'], _getTypeSize(type)]]
  ]

_getStoreFn = (type) ->
  if type.form not in [FORMS.CONCRETE, FORMS.CONSTRUCTED]
    errors.panic("Could not get store fn for non-concrete type: #{JSON.stringify(type)}")
  if type.form == FORMS.CONSTRUCTED or type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL, PRIMITIVES.CHAR]
    return 'i32.store'
  else if type.name == PRIMITIVES.I64
    return 'i64.store'
  errors.panic("Store fn unimplemented for type: #{JSON.stringify(type)}")
  return

_getTypeSize = (type) ->
  if type.form not in [FORMS.CONCRETE, FORMS.CONSTRUCTED]
    errors.panic("Could not get type size for non-concrete type: #{JSON.stringify(type)}")
  if type.form == FORMS.CONSTRUCTED or type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL, PRIMITIVES.CHAR]
    return ['i32.const', '4']
  else if type.name == PRIMITIVES.I64
    return ['i32.const', '8']
  errors.panic("Type size unimplemented for type: #{JSON.stringify(type)}")
  return

_getTypeIndex = (type) ->
  if type.form == FORMS.CONSTRUCTED and type.name == CONSTRUCTORS.FN
    return ['i32.const', TYPE_INDICES[type.form]]
  else if type.form == FORMS.CONCRETE
    return ['i32.const', TYPE_INDICES[type.name]]
  else if type.form == FORMS.VARIABLE
    return ['get_local', type.var]
  return

_unbox = (symbol) ->
  type = typeEnv[symbol].type
  if type.form not in [FORMS.CONCRETE, FORMS.CONSTRUCTED]
    errors.panic("Could not unbox non-concrete type: #{JSON.stringify(type)}")
  if type.form == FORMS.CONSTRUCTED or type.name in [PRIMITIVES.I32, PRIMITIVES.BOOL, PRIMITIVES.CHAR]
    return ['i32.load', _get(symbol)]
  else if type.name == PRIMITIVES.I64
    return ['i64.load', _get(symbol)]
  errors.panic("Unbox unimplemented for type: #{JSON.stringify(type)}")
  return

_parseBSWast = (astNode) ->

  if astNode.isSexpr()
    sexpr = []
    for child, i in astNode.children.symbols
      sexpr.push(_parseBSWast(child))
    return sexpr

  # TODO: handle ArrayRefs

  # TODO: handle more than single level of nesting
  # TODO: check typeEnv for symbol instead of just passing through string
  else if astNode.isObjectRef()
    varName = astNode.children.obj.children.id.literal
    refStr = astNode.children.ref.literal
    return "#{varName}.#{refStr}"

  else if astNode.isIdRef()
    varName = astNode.literal[1..]
    symbol = symbolTable.getSymbolName(varName, astNode.scopeId)
    if symbol not of typeEnv
      errors.panic("Ref id #{astNode.literal} not found in type env")
    return _get(symbol)

  else if astNode.isVariable()
    varName = astNode.children.id.literal
    symbol = symbolTable.getSymbolName(varName, astNode.scopeId)
    if symbol of typeEnv
      return _unbox(symbol)
    return varName

  else if astNode.isNumber()
    return astNode.literal

  # TODO: handle double quoted string here

  errors.panic("Unhandled node during bs wast parsing: #{JSON.stringify(astNode)}")
  return

_shouldAddNewline = (arr, i) ->
  if utils.isArray(arr[0])
    return true
  if arr[0] in ['loop', 'func', 'if', 'then', 'else']
    # Add newline at end only if we added a newline for the last element in arr
    if i == -1
      i = arr.length - 2
    if not utils.isArray(arr[i + 1])
      return false
    if arr[0] == 'if' and i == 0
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
