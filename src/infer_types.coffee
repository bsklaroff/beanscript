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

symbolTable = null
typeCount = null
typeclassEnv = null
typeEnv = null

inferTypes = (rootNode, _symbolTable) ->
  symbolTable = _symbolTable
  typeCount = -1
  typeclassEnv = {}
  typeEnv = {}
  _parseTypeclasses(rootNode)
  _parseTypes(rootNode)
  return typeEnv

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
    var: "t#{typeCount}"
  }

_genFunctionType = (arr) ->
  return {
    form: FORMS.FUNCTION
    arr: arr
  }

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
  for symbol, schema of typeEnv
    if symbolTable.getSymbolScope(symbol) == scopeId
      schemaFtv = _ftvOfSchema(schema)
      for k of schemaFtv
        ftv[k] = true
  return ftv

_ftvOfSchema = (schema) ->
  ftv = {}
  typeFtv = _ftvOfType(schema.type)
  for k of typeFtv
    if k not in schema.forall
      ftv[k] = true
  return ftv

_ftvOfType = (type) ->
  ftv = {}
  if type.form == FORMS.VARIABLE
    ftv[type.var] = true
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
  return _applySubstType(scheme.type, subst)

_setSymbolType = (symbol, type) ->
  if typeEnv[symbol]?
    console.error("Cannot set type #{type} for symbol #{symbol} which already has scheme #{typeEnv[symbol]}")
    process.exit(1)
  typeEnv[symbol] = _genScheme([], type)
  return

_assignSymbolType = (symbol, type) ->
  prevScheme = typeEnv[symbol] ? _genScheme([], _genVariableType())
  scopeId = symbolTable.getSymbolScope(symbol)
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

_typeVarOccurs = (typeVar, type) ->
  if type.form == FORMS.CONCRETE
    return false
  if type.form == FORMS.VARIABLE
    return typeVar == type.var
  if type.form == FORMS.FUNCTION
    for subtype in type.arr
      if _typeVarOccurs(typeVar, subtype)
        return true
    return false
  console.error("Unknown form for type: #{JSON.stringify(type)}")
  process.exit(1)
  return

_bindVariableType = (typeVar, type) ->
  if type.form == FORMS.VARIABLE and type.var == typeVar
    return {}
  if _typeVarOccurs(typeVar, type)
    console.error("Type var #{typeVar} occurs in type #{type}, causing infinite type")
    process.eixt(1)
  res = {}
  res[typeVar] = type
  return res

_unifyTypes = (t0, t1) ->
  if t0.form == FORMS.CONCRETE and t1.form == FORMS.CONCRETE and t0.name == t1.name
    return {}
  if t0.form == FORMS.VARIABLE
    return _bindVariableType(t0.var, t1)
  if t1.form == FORMS.VARIABLE
    return _bindVariableType(t1.var, t0)
  if t0.form == FORMS.FUNCTION and t1.form == FORMS.FUNCTION and t0.arr.length == t1.arr.length
    if t0.arr.length == 0
      return {}
    subst = _unifyTypes(t0.arr[0], t1.arr[0])
    t0new = _applySubstType(t0, subst)
    t0new.arr = t0new.arr[1..]
    t1new = _applySubstType(t1, subst)
    t1new.arr = t1new.arr[1..]
    return _composeSubsts(_unifyTypes(t0new, t1new), subst)
  console.error("Failed to unify types: #{JSON.stringify(t0)}, #{JSON.stringify(t1)}")
  process.exit(1)
  return

# TODO: parse typeclass contexts here
_parseTypeAnnotation = (taNode) -> _parseTypeNode(taNode.children.type)

_parseTypeNode = (typeNode, typevarMap = {}) ->
  typeArr = typeNode.children.typeArr
  # Check for primitive / typevar
  if typeArr.length == 1
    return _parseSingleType(typeArr[0], typevarMap)
  # Check for fn type with no arguments
  if typeArr[0].isEmpty()
    typeArr = typeArr[1..]
  resArr = []
  for subtypeNode in typeArr
    resArr.push(_parseTypeNode(subtypeNode, typevarMap))
  return _genFunctionType(resArr)

# TODO: parse type params here
_parseSingleType = (nonFnTypeNode, typevarMap) ->
  typeId = nonFnTypeNode.children.primitive.literal
  if typeId in utils.values(PRIMITIVES)
    return _genConcreteType(typeId)
  if typeId of typevarMap
    return typevarMap[typeId]
  newType = _genVariableType()
  typevarMap[typeId] = newType
  return newType

_parseTypes = (astNode) ->
  # If astNode is an array, gen types for each element
  if astNode.length?
    for child in astNode
      _parseTypes(child)
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

  if astNode.isVariable()
    symbol = symbolTable.getNodeSymbol(astNode)
    scheme = typeEnv[symbol]
    if not scheme?
      console.error("Symbol #{symbol} referenced before assignment")
      process.exit(1)
    return _instantiateScheme(scheme)

  if astNode.isAssignment()
    targetSymbol = symbolTable.getNodeSymbol(astNode.children.target)
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

  if astNode.isFunctionDef()
    for argNode in astNode.children.args
      symbol = symbolTable.getNodeSymbol(argNode)
      _setSymbolType(symbol, _genVariableType())
    _parseTypes(astNode.children.body)
    # Generate function def type from args and return symbol
    typeArr = []
    for argNode in astNode.children.args
      symbol = symbolTable.getNodeSymbol(argNode)
      typeArr.push(_instantiateScheme(typeEnv[symbol]))
    # Any return node inside the function will have unified with returnSymbol
    returnSymbol = symbolTable.scopeReturnSymbol(astNode)
    if not typeEnv[returnSymbol]?
      _setSymbolType(returnSymbol, _genConcreteType(PRIMITIVES.VOID))
    typeArr.push(_instantiateScheme(typeEnv[returnSymbol]))
    # Set function def symbol type
    functionDefType = _genFunctionType(typeArr)
    functionDefSymbol = symbolTable.getNodeSymbol(astNode)
    _setSymbolType(functionDefSymbol, functionDefType)
    return functionDefType

  if astNode.isReturn()
    childType = _parseTypes(astNode.children.returnVal)
    if not childType?
      console.error("No type found for node: #{JSON.stringify(astNode.children.returnVal)}")
      process.exit(1)
    returnSymbol = symbolTable.scopeReturnSymbol(astNode)
    _assignSymbolType(returnSymbol, childType)
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

  if astNode.isTypeDef()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _parseTypeAnnotation(astNode.children.type)
    _assignSymbolType(symbol, type)
    return

  if astNode.isWast()
    symbol = symbolTable.getNodeSymbol(astNode)
    type = _genVariableType()
    _setSymbolType(symbol, type)
    return type

  for name, child of astNode.children
    _parseTypes(child)

  return


module.exports = inferTypes
