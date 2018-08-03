utils = require('./utils')

PRIMITIVES =
  I32: 'I32'
  I64: 'I64'
  BOOL: 'Bool'
  CHAR: 'Char'
  VOID: 'Void'

CONSTRUCTORS =
  ARR: 'Arr'

FORMS =
  CONCRETE: 'concrete'
  VARIABLE: 'variable'
  OBJECT: 'object'
  CONSTRUCTED: 'constructed'
  FUNCTION: 'function'

symbolTable = null
typeCount = null
newTypes = null
typeConstructors = null
fnTypeclasses = null
superclasses = null
typeclassEnv = null
objclassEnv = null
typeEnv = null

inferTypes = (rootNode, _symbolTable) ->
  symbolTable = _symbolTable
  typeCount = -1
  newTypes = {}
  typeConstructors = {}
  fnTypeclasses = {}
  superclasses = {}
  typeclassEnv = {}
  objclassEnv = {}
  typeEnv = {}
  _parseNewTypes(rootNode)
  _parseSupertypes(rootNode)
  _parseTypeDefs(rootNode)
  _parseTypes(rootNode)
  _addContextTypevars()
  return {newTypes, superclasses, typeclassEnv, objclassEnv, typeEnv}

###
Type object generation functions
###

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

_genVariableType = ->
  typeCount++
  return {
    form: FORMS.VARIABLE
    var: "$t#{typeCount}"
  }

_genObjectType = (props) ->
  return {
    form: FORMS.OBJECT
    keys: Object.keys(props).sort()
    props: props
  }

_genConstructedType = (name, params) ->
  return {
    form: FORMS.CONSTRUCTED
    name: name
    params: params
  }

_genFunctionType = (arr) ->
  return {
    form: FORMS.FUNCTION
    arr: arr
  }

###
Parse all explicitly defined types
###

_parseNewTypes = (rootNode) ->
  for astNode in rootNode.children.statements
    if astNode.isType()
      typeName = astNode.children.name.literal
      typeParams = utils.map(astNode.children.params, (p) -> p.literal)
      newTypes[typeName] = {
        params: typeParams
        constructors: []
      }
      for optNode in astNode.children.options
        constructor = optNode.children.constructor.literal
        if constructor of typeConstructors
          console.error("Type constructor #{constructor} defined multiple times")
          process.exit(1)
        dataTypeNode = optNode.children.dataType
        typevarMap = null
        dataScheme = null
        if not dataTypeNode.isEmpty()
          typevarMap = {}
          dataType = _parseTypeNode(dataTypeNode, typevarMap)
          dataScheme = _generalizeType(dataType, 0)
          for k of typevarMap
            if k not in typeParams
              console.error("Typevar #{k} in constructor #{constructor} not found in declaration for type #{typeName}")
              process.exit(1)
        typeConstructors[constructor] = {
          type: typeName
          typevar_map: typevarMap
          data_scheme: dataScheme
        }
        newTypes[typeName].constructors.push(constructor)
  return

###
Parse type hierarchy from typeclass and typeinst headers
###

_parseSupertypes = (rootNode) ->
  for astNode in rootNode.children.statements
    if astNode.isTypeclassDef()
      typeclass = astNode.children.typeclass.children.class.literal
      if typeclass of superclasses
        console.error("Typeclass #{typeclass} defined multiple times")
        process.exit(1)
      superclasses[typeclass] = {}
      for superclass in astNode.children.superclasses
        superclasses[typeclass][superclass.literal] = true
    else if astNode.isTypeinst()
      typeclass = astNode.children.class.literal
      type = astNode.children.type.literal
      superclasses[type] ?= {}
      superclasses[type][typeclass] = true
  return

###
Parse explicit type definitions, in typeclasses or otherwise
###

_parseTypeDefs = (astNode, typeclassInfo = null) ->
  if astNode.length?
    for child in astNode
      _parseTypeDefs(child, typeclassInfo)
  else if astNode.isTypeclassDef()
    typeclass = astNode.children.typeclass
    className = typeclass.children.class.literal
    anonType = typeclass.children.anonType.literal
    _parseTypeDefs(astNode.children.body, {className: className, anonType: anonType})
  else if astNode.isTypeDef()
    symbol = symbolTable.getNodeSymbol(astNode)
    if symbol of typeEnv
      console.error("Multiple type annotations for symbol #{symbol}")
      process.exit(1)
    {type, anonTypevarMap, anonContext} = _parseTypeAnnotation(astNode.children.type)
    _assignSymbolType(symbol, type)
    # The following code deals with typeclasses
    # First, map typevars -> context using maps of anon -> typevar and anon -> context
    for anonType, typevar of anonTypevarMap
      if anonType of anonContext
        typeclassEnv[typevar.var] = anonContext[anonType]
    # Also, if we're inside a typeclass, map the fn name to its typeclassInfo
    if typeclassInfo?
      typeclassAnon = typeclassInfo.anonType
      if typeclassAnon not of anonTypevarMap or typeclassAnon not of anonContext
        console.error("Typeclass anonType #{typeclassAnon} not found in context of type def: #{JSON.stringify(astNode)}")
        process.exit(1)
      variableType = anonTypevarMap[typeclassAnon]
      newInfo = {className: typeclassInfo.className, typevar: variableType.var}
      fnTypeclasses[symbol] = newInfo
  else
    for name, child of astNode.children
      _parseTypeDefs(child, typeclassInfo)
  return

_parseTypeAnnotation = (typeWithContext, typeclassInfo) ->
  anonTypevarMap = {}
  type = _parseTypeNode(typeWithContext.children.type, anonTypevarMap)
  anonContext = _parseTypeContext(typeWithContext.children.context)
  return {type, anonTypevarMap, anonContext}

_parseTypeContext = (contextNodes) ->
  contextMap = {}
  for node in contextNodes
    anonType = node.children.anonType.literal
    typeclass = node.children.class.literal
    contextMap[anonType] ?= {}
    contextMap[anonType][typeclass] = true
  return contextMap

_parseTypeNode = (typeNode, typevarMap) ->
  if typeNode.isId()
    return _parseIdType(typeNode, typevarMap)
  if typeNode.isObjectType()
    return _parseObjectType(typeNode, typevarMap)
  if typeNode.isConstructedType()
    return _parseConstructedType(typeNode, typevarMap)
  if typeNode.isFunctionType()
    return _parseFunctionType(typeNode, typevarMap)
  console.error("Unknown type node #{JSON.stringify(typeNode)}")
  process.exit(1)
  return

_parseIdType = (idTypeNode, typevarMap) ->
  typeId = idTypeNode.literal
  if typeId in utils.values(PRIMITIVES)
    return _genConcreteType(typeId)
  if typeId of typevarMap
    return typevarMap[typeId]
  newType = _genVariableType()
  typevarMap[typeId] = newType
  return newType

_parseObjectType = (objectTypeNode, typevarMap) ->
  props = {}
  for propNode in objectTypeNode.children.props
    key = propNode.children.key.literal
    typeNode = propNode.children.val
    props[key] = _parseTypeNode(typeNode, typevarMap)
  return _genObjectType(props)

_parseConstructedType = (constructedTypeNode, typevarMap) ->
  typeId = constructedTypeNode.children.constructor.literal
  paramTypes = []
  for param in constructedTypeNode.children.params
    paramTypes.push(_parseTypeNode(param, typevarMap))
  return _genConstructedType(typeId, paramTypes)

_parseFunctionType = (functionTypeNode, typevarMap) ->
  argTypes = functionTypeNode.children.argTypes
  # Check for fn type with no arguments
  if argTypes[0].isEmpty()
    argTypes = argTypes[1..]
  resTypes = []
  for argType in argTypes
    resTypes.push(_parseTypeNode(argType, typevarMap))
  return _genFunctionType(resTypes)

###
Parse and infer all types
###

_parseTypes = (astNode, insideMatch = false) ->
  # If astNode is an array, gen types for each element
  if astNode.length?
    for child in astNode
      _parseTypes(child, insideMatch)
    return

  # Typedefs and new types have already been parsed
  if astNode.isTypeclassDef() or astNode.isTypeDef() or astNode.isType()
    return

  if astNode.isNumber()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genConcreteType(PRIMITIVES.I32)
    _setSymbolType(symbol, type)
    return type

  if astNode.isBoolean()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genConcreteType(PRIMITIVES.BOOL)
    _setSymbolType(symbol, type)
    return type

  if astNode.isChar()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genConcreteType(PRIMITIVES.CHAR)
    _setSymbolType(symbol, type)
    return type

  if astNode.isVariable()
    symbol = symbolTable.getNodeSymbol(astNode)
    if insideMatch
      if symbol of typeEnv
        console.error("Symbol #{symbol} assigned before destruction")
        process.exit(1)
      type = _genVariableType()
      _setSymbolType(symbol, type)
      return type
    scheme = typeEnv[symbol]
    if not scheme?
      console.error("Symbol #{symbol} referenced before assignment")
      process.exit(1)
    return _instantiateScheme(scheme)

  if astNode.isConstructed()
    constructor = astNode.children.constructor.literal
    dataNode = astNode.children.data
    if constructor not of typeConstructors
      console.error("Undeclared constructor: #{constructor}")
      process.exit(1)
    _parseTypes(dataNode, insideMatch)
    typeInfo = typeConstructors[constructor]
    [typeName, typevarMap, dataScheme] = [typeInfo.type, typeInfo.typevar_map, typeInfo.data_scheme]
    paramNames = newTypes[typeName].params
    # Generalize dataScheme and keep track of the subst
    subst = {}
    if not dataNode.isEmpty()
      for typevar in dataScheme.forall
        newTypevar = _genVariableType()
        subst[typevar] = newTypevar
    # Construct this node's type
    params = []
    for paramName in paramNames
      if not dataNode.isEmpty() and paramName of typevarMap
        params.push(subst[typevarMap[paramName].var])
      else
        params.push(_genVariableType())
    type = _genConstructedType(typeName, params)
    symbol = symbolTable.getNodeSymbol(astNode)
    _setSymbolType(symbol, type)
    # None of dataType's typevars will generalize below because they are ftvs
    # of this node's type we just set above
    if dataNode.isEmpty()
      if dataScheme?
        console.error("Constructor #{constructor} missing data node")
        process.exit(1)
    else
      dataType = _applySubstType(dataScheme.type, subst)
      dataSymbol = symbolTable.getNodeSymbol(dataNode)
      _assignSymbolType(dataSymbol, dataType)
    return typeEnv[symbol].type

  if astNode.isDestruction()
    boxed = astNode.children.boxed
    unboxed = astNode.children.unboxed
    if unboxed.isVariable()
      console.error("No data constructor found called #{unboxed.children.id.literal}")
      process.exit(1)
    boxedType = _parseTypes(boxed)
    unboxedType = _parseTypes(unboxed, true)
    subst = _unifyTypes(boxedType, unboxedType)
    _applySubstEnv(subst)
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genConcreteType(PRIMITIVES.BOOL)
    _setSymbolType(symbol, type)
    return type

  if astNode.isArray()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genConstructedType(CONSTRUCTORS.ARR, [_genVariableType()])
    for itemNode in astNode.children.items
      itemType = _parseTypes(itemNode, insideMatch)
      subst = _unifyTypes(type.params[0], itemType)
      _applySubstEnv(subst)
      type = _applySubstType(type, subst)
    _setSymbolType(symbol, type)
    return type

  # TODO
  if astNode.isArrayRange()
    return

  if astNode.isObject()
    symbol = symbolTable.getNodeSymbol(astNode)
    props = {}
    for propNode in astNode.children.props
      key = propNode.children.key.literal
      propType = _parseTypes(propNode.children.val, insideMatch)
      if key of props
        console.error("Key #{key} redefined in object #{JSON.stringify(astNode)}")
        process.exit(1)
      props[key] = propType
    type = _genObjectType(props)
    _setSymbolType(symbol, type)
    return type

  if astNode.isObjectRef()
    # Generate dummy newProps with ref mapped to a new vartype
    ref = astNode.children.ref.literal
    newProps = {}
    newProps[ref] = _genVariableType()
    newType = _genVariableType()
    objclassEnv[newType.var] = newProps
    # Unify newType with objType to transfer newType's objclass to objType.
    # This also unifies newType with any previous type or typeclass constraint
    # defined for objType[ref]
    obj = astNode.children.obj
    objType = _parseTypes(astNode.children.obj)
    subst = _unifyTypes(newType, objType)
    delete objclassEnv[newType.var]
    _applySubstEnv(subst)
    newProps[ref] = _applySubstType(newProps[ref], subst)
    symbol = symbolTable.getNodeSymbol(astNode)
    _setSymbolType(symbol, newProps[ref])
    return newProps[ref]

  if astNode.isAssignment()
    target = astNode.children.target
    targetSymbol = symbolTable.getNodeSymbol(target)
    if targetSymbol of fnTypeclasses
      console.error("Typeclass fn #{targetSymbol} defined outside a typeinst")
      process.exit(1)
    if not target.isVariable()
      _parseTypes(target)
    # If function def assignment, deal with recursion by assigning a dummy
    # typevar to the target
    #if astNode.children.source.isFunctionDef()
    #  _assignSymbolType(targetSymbol, _genVariableType())
    type = _parseTypes(astNode.children.source)
    if not type?
      console.error("No type found for node: #{JSON.stringify(astNode.children.source)}")
      process.exit(1)
    _assignSymbolType(targetSymbol, type)
    return

  if astNode.isTypeinst()
    instType = astNode.children.type.literal
    for fnDefPropNode in astNode.children.fnDefs
      fnDefNode = fnDefPropNode.children.fnDef
      fnDefType = _parseTypes(fnDefNode)
      # Grab typedef from typeclass
      targetSymbol = symbolTable.getNodeSymbol(fnDefPropNode)
      if targetSymbol not of typeEnv or targetSymbol not of fnTypeclasses
        console.error("Typeinst fn #{targetSymbol} is not defined in any typeclass")
        process.exit(1)
      typeclassFnScheme = typeEnv[targetSymbol]
      typeclassInfo = fnTypeclasses[targetSymbol]
      # Substitute typeinst type into typeclass typedef
      typeinstFnType = _instantiateSubstScheme(typeclassFnScheme, typeclassInfo.typevar, instType)
      # Unify calculated fn type with type parsed from the fn def
      subst = _unifyTypes(typeinstFnType, fnDefType)
      _applySubstEnv(subst)
    return

  if astNode.isFunctionDef()
    for argNode in astNode.children.args
      if argNode.isConstructed()
        _parseTypes(argNode, true)
      else
        symbol = symbolTable.getNodeSymbol(argNode)
        _setSymbolType(symbol, _genVariableType())
    _parseTypes(astNode.children.body)
    # Generate function def type from args and return symbol
    typeArr = []
    for argNode in astNode.children.args
      symbol = symbolTable.getNodeSymbol(argNode)
      typeArr.push(_instantiateScheme(typeEnv[symbol]))
    # Any return node inside the function will have unified with returnSymbol
    returnSymbol = symbolTable.scopeReturnSymbol(astNode.scopeId)
    if not typeEnv[returnSymbol]?
      _setSymbolType(returnSymbol, _genConcreteType(PRIMITIVES.VOID))
    typeArr.push(_instantiateScheme(typeEnv[returnSymbol]))
    # Set function def symbol type
    functionDefType = _genFunctionType(typeArr)
    functionDefSymbol = symbolTable.getNodeSymbol(astNode)
    _setSymbolType(functionDefSymbol, functionDefType)
    return functionDefType

  if astNode.isReturn()
    returnSymbol = symbolTable.scopeReturnSymbol(astNode.scopeId)
    if astNode.children.returnVal.isEmpty()
      childType = _genConcreteType(PRIMITIVES.VOID)
    else
      childType = _parseTypes(astNode.children.returnVal)
      if not childType?
        console.error("No type found for node: #{JSON.stringify(astNode.children.returnVal)}")
        process.exit(1)
    _assignSymbolType(returnSymbol, childType)
    return

  if astNode.isReturnPtr()
    childType = _parseTypes(astNode.children.returnVal)
    if not childType?
      console.error("No type found for node: #{JSON.stringify(astNode.children.returnVal)}")
      process.exit(1)
    childSymbol = symbolTable.getNodeSymbol(astNode.children.returnVal)
    _assignSymbolType(childSymbol, _genConcreteType(PRIMITIVES.I32))
    returnSymbol = symbolTable.scopeReturnSymbol(astNode.scopeId)
    _assignSymbolType(returnSymbol, _genVariableType())
    return

  if astNode.isFunctionCall()
    _parseTypes(astNode.children.args)
    # Assemble function type from args and dummy return
    typeArr = []
    for argNode in astNode.children.args
      symbol = symbolTable.getNodeSymbol(argNode)
      typeArr.push(_instantiateScheme(typeEnv[symbol]))
    returnType = _genVariableType()
    typeArr.push(returnType)
    # Unify function type with type pulled from function definition
    fnDefType = _parseTypes(astNode.children.fn)
    subst = _unifyTypes(fnDefType, _genFunctionType(typeArr))
    _applySubstEnv(subst)
    # Function call type is unified return type
    fnCallType = _applySubstType(returnType, subst)
    symbol = symbolTable.getNodeSymbol(astNode)
    _setSymbolType(symbol, fnCallType)
    return fnCallType

  if astNode.isIf()
    condition = astNode.children.condition
    _parseTypes(condition)
    conditionSymbol = symbolTable.getNodeSymbol(condition)
    _assignSymbolType(conditionSymbol, _genConcreteType(PRIMITIVES.BOOL))
    _parseTypes(astNode.children.body)
    _parseTypes(astNode.children.else)
    return

  if astNode.isWhile()
    condition = astNode.children.condition
    _parseTypes(condition)
    conditionSymbol = symbolTable.getNodeSymbol(condition)
    _assignSymbolType(conditionSymbol, _genConcreteType(PRIMITIVES.BOOL))
    _parseTypes(astNode.children.body)
    return

  if astNode.isAndExpression() or astNode.isOrExpression()
    _parseTypes(astNode.children.lhs)
    _parseTypes(astNode.children.rhs)
    symbol = symbolTable.getNodeSymbol(astNode)
    lhsSymbol = symbolTable.getNodeSymbol(astNode.children.lhs)
    rhsSymbol = symbolTable.getNodeSymbol(astNode.children.rhs)
    _setSymbolType(symbol, _genConcreteType(PRIMITIVES.BOOL))
    _assignSymbolType(lhsSymbol, _genConcreteType(PRIMITIVES.BOOL))
    _assignSymbolType(rhsSymbol, _genConcreteType(PRIMITIVES.BOOL))
    return

  if astNode.isWast()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genVariableType()
    _setSymbolType(symbol, type)
    return type

  for name, child of astNode.children
    _parseTypes(child, insideMatch)

  return

_generalizeType = (type, scopeId) ->
  typeFtv = _ftvOfType(type)
  envFtv = _ftvOfEnv(scopeId)
  forall = []
  for k of typeFtv
    if k not of envFtv
      forall.push(k)
  return {
    forall: forall
    type: type
  }

_ftvOfEnv = (scopeId) ->
  ftv = {}
  for symbol, scheme of typeEnv
    if symbolTable.getScope(symbol) == scopeId
      schemeFtv = _ftvOfScheme(scheme)
      for k of schemeFtv
        ftv[k] = true
  return ftv

_ftvOfScheme = (scheme) ->
  ftv = {}
  typeFtv = _ftvOfType(scheme.type)
  for k of typeFtv
    if k not in scheme.forall
      ftv[k] = true
  return ftv

_ftvOfType = (type) ->
  ftv = {}
  if type.form == FORMS.VARIABLE
    ftv[type.var] = true
  else if type.form == FORMS.OBJECT
    for key in type.keys
      subFtv = _ftvOfType(type.props[key])
      for k of subFtv
        ftv[k] = true
  else if type.form == FORMS.CONSTRUCTED
    for subtype in type.params
      subFtv = _ftvOfType(subtype)
      for k of subFtv
        ftv[k] = true
  else if type.form == FORMS.FUNCTION
    for subtype in type.arr
      subFtv = _ftvOfType(subtype)
      for k of subFtv
        ftv[k] = true
  return ftv

_instantiateScheme = (scheme) ->
  subst = {}
  for typevar in scheme.forall
    newTypevar = _genVariableType()
    subst[typevar] = newTypevar
    if typevar of typeclassEnv
      typeclassEnv[newTypevar.var] = utils.cloneDeep(typeclassEnv[typevar])
    if typevar of objclassEnv
      objclassEnv[newTypevar.var] = utils.cloneDeep(objclassEnv[typevar])
  return _applySubstType(scheme.type, subst)

_instantiateSubstScheme = (scheme, substTypevar, substType) ->
  subst = {}
  found = false
  for typevar in scheme.forall
    if typevar == substTypevar
      found = true
      newType = _genConcreteType(substType)
    else
      newType = _genVariableType()
    subst[typevar] = newType
    if typevar of typeclassEnv and newType.form == FORMS.VARIABLE
      typeclassEnv[newType.var] = utils.cloneDeep(typeclassEnv[typevar])
  if not found
    console.error("Typevar #{substTypevar} failed to substitute into scheme #{scheme}")
    process.exit(1)
  return _applySubstType(scheme.type, subst)

_setSymbolType = (symbol, type) ->
  if typeEnv[symbol]?
    console.error("Cannot set type #{JSON.stringify(type)} for symbol #{symbol} which already has scheme #{JSON.stringify(typeEnv[symbol])}")
    console.trace()
    process.exit(1)
  typeEnv[symbol] = _genScheme([], type)
  return

_assignSymbolType = (symbol, type) ->
  prevScheme = typeEnv[symbol] ? _genScheme([], _genVariableType())
  scopeId = symbolTable.getScope(symbol)
  prevType = _instantiateScheme(prevScheme)
  subst = _unifyTypes(prevType, type)
  _applySubstEnv(subst)
  newType = _applySubstType(prevType, subst)
  typeEnv[symbol] = _generalizeType(newType, scopeId)
  return

# Modifies typeEnv in-place
_applySubstEnv = (subst) ->
  for k, v of typeEnv
    typeEnv[k] = _applySubstScheme(v, subst)
  for tv of objclassEnv
    for k, v of objclassEnv[tv]
      objclassEnv[tv][k] = _applySubstType(v, subst)
  return

_applySubstScheme = (scheme, subst) ->
  newSubst = {}
  for k, v of subst
    if k not in scheme.forall
      newSubst[k] = v
  newType = _applySubstType(scheme.type, newSubst)
  return _genScheme(scheme.forall, newType)

_applySubstType = (type, subst) ->
  newType = {form: type.form}
  if type.form == FORMS.CONCRETE
    newType.name = type.name
  else if type.form == FORMS.VARIABLE
    if type.var of subst
      return subst[type.var]
    newType.var = type.var
  else if type.form == FORMS.OBJECT
    newType.keys = []
    newType.props = {}
    for key in type.keys
      newType.keys.push(key)
      newType.props[key] = _applySubstType(type.props[key], subst)
  else if type.form == FORMS.CONSTRUCTED
    newType.name = type.name
    newType.params = []
    for param in type.params
      newType.params.push(_applySubstType(param, subst))
  else if type.form == FORMS.FUNCTION
    newType.arr = []
    for subtype in type.arr
      newType.arr.push(_applySubstType(subtype, subst))
  return newType

_composeSubsts = (s0, s1) ->
  newSubst = {}
  for k, v of s0
    newSubst[k] = v
  for k, v of s1
    newSubst[k] = _applySubstType(v, s0)
  return newSubst

_typevarOccurs = (typevar, type) ->
  if type.form == FORMS.CONCRETE
    return false
  if type.form == FORMS.VARIABLE
    return typevar == type.var
  if type.form == FORMS.OBJECT
    for key in type.keys
      if _typevarOccurs(typevar, type.props[key])
        return true
    return false
  if type.form == FORMS.CONSTRUCTED
    for param in type.params
      if _typevarOccurs(typevar, param)
        return true
    return false
  if type.form == FORMS.FUNCTION
    for subtype in type.arr
      if _typevarOccurs(typevar, subtype)
        return true
    return false
  console.error("Unknown form for type: #{JSON.stringify(type)}")
  process.exit(1)
  return

_bindVariableType = (typevar, type) ->
  if type.form == FORMS.VARIABLE and type.var == typevar
    return {}
  if _typevarOccurs(typevar, type)
    console.error("Typevar #{typevar} occurs in type #{type}, causing infinite type")
    process.eixt(1)
  res = {}
  res[typevar] = type
  tcRes = _bindTypeclasses(typevar, type)
  return _composeSubsts(res, tcRes)

_bindTypeclasses = (typevar, type) ->
  if typevar not of typeclassEnv and typevar not of objclassEnv
    return {}
  if typevar of typeclassEnv and typevar of objclassEnv
    console.error("Typevar #{typevar} cannot exist in both typeclassEnv and objclassEnv")
    process.exit(1)
  if type.form == FORMS.CONSTRUCTED
    # Constructed typeclasses unimplemented for now
    console.error("Cannot bind typeclasses of #{typevar} with constructed type #{JSON.stringify(type)}")
    process.exit(1)
  else if type.form == FORMS.FUNCTION
    # Higher-kinded typeclasses unimplemented for now
    console.error("Cannot bind typeclasses of #{typevar} with function type #{JSON.stringify(type)}")
    process.exit(1)
  else if type.form == FORMS.OBJECT
    if typevar of typeclassEnv
      console.error("Object type #{type.name} cannot have typeclasses: #{typeclassEnv[typevar]}")
      process.exit(1)
    res = {}
    for k, v of objclassEnv[typevar]
      if k not of type.props
        console.error("Objclass key #{k} not found in object type #{JSON.stringify(type)}")
        process.exit(1)
      res = _composeSubsts(_unifyTypes(v, type.props[k]), res)
    return res
  else if type.form == FORMS.CONCRETE
    if typevar of objclassEnv
      console.error("Type #{type.name} cannot have objclasses: #{objclassEnv[typevar]}")
      process.exit(1)
    for typeclass of typeclassEnv[typevar]
      if not _isSuperclass(typeclass, type.name)
        console.error("Type #{type.name} is not an instance of #{typeclass}")
        process.exit(1)
  else if type.form == FORMS.VARIABLE
    if typevar of objclassEnv
      return _unifyObjclasses(typevar, type.var)
    _unifyTypeclasses(typevar, type.var)
  return {}

_unifyObjclasses = (source, target) ->
  objclassEnv[target] ?= {}
  res = {}
  for k, v of objclassEnv[source]
    if k not of objclassEnv[target]
      objclassEnv[target][k] = v
    else
      res = _composeSubsts(_unifyTypes(v, objclassEnv[target][k]), res)
  return res

_unifyTypeclasses = (source, target) ->
  typeclassEnv[target] ?= {}
  # For each new typeclass of the source typevar:
  # 1. If it is a superclass of an existing typeclass of the target typevar,
  #    ignore it
  # 2. If it is a subclass of an existing typeclass of the target typevar,
  #    replace the existing typeclass with the new typeclass
  # 3. Otherwise, add the new typeclass to the target typevar
  for newTypeclass of typeclassEnv[source]
    found = false
    for oldTypeclass of typeclassEnv[target]
      if newTypeclass == oldTypeclass or _isSuperclass(newTypeclass, oldTypeclass)
        found = true
        break
      if _isSuperclass(oldTypeclass, newTypeclass)
        delete typeclassEnv[target][oldTypeclass]
        typeclassEnv[target][newTypeclass] = true
        found = true
        break
    if not found
      typeclassEnv[target][newTypeclass] = true
  return

_isSuperclass = (t0, t1) ->
  if t1 not of superclasses
    return false
  if t0 of superclasses[t1]
    return true
  for superclass of superclasses[t1]
    if _isSuperclass(t0, superclass)
      return true
  return false

_unifyTypes = (t0, t1) ->
  if t0.form == FORMS.CONCRETE and t1.form == FORMS.CONCRETE and t0.name == t1.name
    return {}
  if t0.form == FORMS.VARIABLE
    return _bindVariableType(t0.var, t1)
  if t1.form == FORMS.VARIABLE
    return _bindVariableType(t1.var, t0)
  if t0.form == FORMS.OBJECT and t1.form == FORMS.OBJECT and utils.equals(t0.keys, t1.keys)
    if t0.keys.length == 0
      return {}
    key = t0.keys[0]
    subst = _unifyTypes(t0.props[key], t1.props[key])
    t0new = _applySubstType(t0, subst)
    t1new = _applySubstType(t1, subst)
    delete t0new.props[key]
    delete t1new.props[key]
    t0new.keys = t0new.keys[1..]
    t1new.keys = t1new.keys[1..]
    return _composeSubsts(_unifyTypes(t0new, t1new), subst)
  if t0.form == FORMS.CONSTRUCTED and t1.form == FORMS.CONSTRUCTED and t0.params.length == t1.params.length
    if t0.params.length == 0
      return {}
    subst = _unifyTypes(t0.params[0], t1.params[0])
    t0new = _applySubstType(t0, subst)
    t1new = _applySubstType(t1, subst)
    t0new.params = t0new.params[1..]
    t1new.params = t1new.params[1..]
    return _composeSubsts(_unifyTypes(t0new, t1new), subst)
  if t0.form == FORMS.FUNCTION and t1.form == FORMS.FUNCTION and t0.arr.length == t1.arr.length
    if t0.arr.length == 0
      return {}
    subst = _unifyTypes(t0.arr[0], t1.arr[0])
    t0new = _applySubstType(t0, subst)
    t1new = _applySubstType(t1, subst)
    t0new.arr = t0new.arr[1..]
    t1new.arr = t1new.arr[1..]
    return _composeSubsts(_unifyTypes(t0new, t1new), subst)
  console.error("Failed to unify types: #{JSON.stringify(t0)}, #{JSON.stringify(t1)}")
  console.trace()
  process.exit(1)
  return

###
For each polymorphic function, specify list of typevars that must be supplied as arguments
###

_addContextTypevars = ->
  for symbol, scheme of typeEnv
    if scheme.type.form == FORMS.FUNCTION
      scheme.type.contextTypevars = []
      for typevar of _ftvOfType(scheme.type)
        if typevar of typeclassEnv
          scheme.type.contextTypevars.push(typevar)
  return

module.exports = inferTypes
