ASTNode = require('./ast_node')

class Symbol
  @TYPES:
    FN: 'fn'
    OBJ: 'obj'
    ARR: 'arr'
    I64: 'i64'
    I32: 'i32'
    BOOL: 'bool'

  constructor: (@name, @scopeName, @namedVar) ->
    @type = null
    @_eqTypeSymbols = {}
    return

  getShortName: -> if @namedVar then @name else @name.split('_')[0]
  getScopedName: -> "#{@scopeName}:#{@name}"

  addProperty: (varNode, type) ->
    if @type != Symbol.TYPES.OBJ
      throw new Error("Cannot add property to non-obj symbol: #{@name}")
    if not ASTNode.isTypedVariable(typedVarNode)
      throw new Error("Expected node to be a typed variable: #{typedVarNode}")
    @props ?= {}
    varName = varNode.children.id.literal
    if ASTNode.isNestedVariable(varNode)
      if varName not of @props
        throw new Error("Expected property #{varName} in symbol #{@name}")
      @props[varName].addProperty(varNode.children.prop, type)
    else
      if varName not of @props
        @props[varName] = new Symbol(varName, type)
      else if type != '' and @props[varName].type != type
        throw new Error("Expected type #{@props[varName]} for node #{varNode}")
    return

  setChildScopeName: (name) ->
    if @type != Symbol.TYPES.FN
      throw new Error("Cannot set child scope of non-fn symbol: #{@name}")
    @childScopeName = name
    return

  setType: (type) ->
    if @type? and @type != type
      throw new Error("Cannot overwrite type #{type} for symbol #{@name} with type #{@type}")
    if not @type?
      @type = type
      for name, symbol of @_eqTypeSymbols
        symbol.setType(@type)
      @_eqTypeSymbols = null
    return

  unifyType: (otherSymbol) ->
    if otherSymbol.type?
      @setType(otherSymbol.type)
    else if not @type?
      @_eqTypeSymbols[otherSymbol.getScopedName()] = otherSymbol
    return

  unifyReturnType: (returnSymbol) ->
    if @type != Symbol.TYPES.FN
      throw new Error("Cannot unify return type for non-fn symbol: #{@name}")
    @returnSymbol ?= new Symbol("#{@name}:return", @scopeName, false)
    @returnSymbol.unifyType(returnSymbol)
    returnSymbol.unifyType(@returnSymbol)
    return

  unifyArgTypes: (argSymbols) ->
    if @type != Symbol.TYPES.FN
      throw new Error("Cannot unify arg types for non-fn symbol: #{@name}")
    if not @argSymbols
      @argSymbols = []
      for arg, i in argSymbols
        @argSymbols.push(new Symbol("#{@name}:arg#{i}", @scopeName, false))
    for argSymbol, i in argSymbols
      @argSymbols[i].unifyType(argSymbol)
      argSymbol.unifyType(@argSymbols[i])
    return

class Scope
  constructor: (@name, @parentScope) ->
    @argNames = null
    @locals = {}
    @_constCount = 0
    return

  addVarSymbol: (varName) ->
    @locals[varName] = new Symbol(varName, @name, true)
    return @locals[varName]

  addConstSymbol: (nodeName, nameSuffix) ->
    name = "#{@_constCount}#{nodeName}#{nameSuffix}"
    @locals[name] = new Symbol(name, @name, false)
    @_constCount += 1
    return @locals[name]

  getSymbol: (name) ->
    if name of @locals
      return @locals[name]
    # If not found in local scope, check for variable in parent scope
    if @parentScope?
      return @parentScope.getSymbol(name)
    return null

  getShortName: (name) -> @getSymbol(name)?.getShortName()

  addArgs: (fnSymbol, args) ->
    @argNames = []
    argSymbols = []
    for arg in args
      argName = arg.children.id.literal
      argType = arg.children.type.literal
      if argName of @locals
        throw new Error("Duplicate function argument: #{arg}")
      @locals[argName] = new Symbol(argName, @name, true)
      @locals[argName].setType(argType)
      @argNames.push(argName)
      argSymbols.push(@locals[argName])
    fnSymbol.unifyArgTypes(argSymbols)
    return

  unifyTypes: (name0, name1) ->
    s0 = @getSymbol(name0)
    s1 = @getSymbol(name1)
    s0.unifyType(s1)
    s1.unifyType(s0)
    return

  unifyFnCallTypes: (fnName, returnName, argNames) ->
    fnSymbol = @getSymbol(fnName)
    returnSymbol = @getSymbol(returnName)
    argSymbols = []
    for argName in argNames
      argSymbols.push(@getSymbol(argName))
    fnSymbol.unifyReturnType(returnSymbol)
    fnSymbol.unifyArgTypes(argSymbols)
    return

class SymbolTable
  constructor: ->
    @scopes = {global: new Scope('global', null)}
    @_fnCount = 0
    return

  _genFnScope: (fnName, parentScope) ->
    name = "#{@_fnCount}_#{fnName}"
    @_fnCount += 1
    @scopes[name] = new Scope(name, parentScope)
    return @scopes[name]

  genNodeSymbols: (node, scope = @scopes.global) ->
    node.scopeName = scope.name
    symbol = null
    traversed = false
    if ASTNode.isFunctionAssignment(node)
      target = node.children.target
      targetVar = target.children.var
      targetVarName = targetVar.children.id.literal
      symbol = scope.getSymbol(targetVarName)
      if not symbol?
        symbol = scope.addVarSymbol(targetVarName)
        symbol.setType(Symbol.TYPES.FN)
      if symbol.childScopeName?
        throw new Error("Cannot redefine function: #{target}")
      fnScope = @_genFnScope(symbol.name, scope)
      symbol.setChildScopeName(fnScope.name)
      # Extract arg symbols from function definition into function scope
      fnDef = node.children.source
      fnScope.addArgs(symbol, fnDef.children.args)
      for statement in fnDef.children.body
        @genNodeSymbols(statement, fnScope)
        if ASTNode.isReturn(statement)
          symbol.unifyReturnType(fnScope.getSymbol(statement.children.returnVal.symbolName))
    else if ASTNode.isAssignment(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      traversed = true
      # Unify source and dest types
      scope.unifyTypes(node.children.target.symbolName, node.children.source.symbolName)
    else if ASTNode.isTypedVariable(node)
      varNode = node.children.var
      varName = varNode.children.id.literal
      # This only works if we prevent starting a variable name with a number
      symbol = scope.getSymbol(varName)
      if not symbol?
        symbol = scope.addVarSymbol(varName)
      # Set variable type
      type = node.children.type.literal
      if type.length > 0
        symbol.setType(type)
    else if ASTNode.isNestedVariable(node)
      #TODO
    else if ASTNode.isVariable(node)
      varName = node.children.id.literal
      # This only works if we prevent starting a variable name with a number
      symbol = scope.getSymbol(varName)
      if not symbol?
        symbol = scope.addVarSymbol(varName)
    else if ASTNode.isOpExpression(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      nameSuffix = ''
      if not ASTNode.isEmpty(node.children.lhs)
        nameSuffix += "#{scope.getShortName(node.children.lhs.symbolName)}_"
      nameSuffix += scope.getShortName(node.children.rhs.symbolName)
      symbol = scope.addConstSymbol(node.name, nameSuffix)
      # Unify types of result and operands
      if not ASTNode.isEmpty(node.children.lhs)
        scope.unifyTypes(node.children.lhs.symbolName, node.children.rhs.symbolName)
      if ASTNode.isComparisonOp(node)
        symbol.setType(Symbol.TYPES.BOOL)
      else
        scope.unifyTypes(symbol.name, node.children.rhs.symbolName)
    else if ASTNode.isOpParenGroup(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      opExprName = node.children.opExpr.symbolName
      symbol = scope.addConstSymbol(node.name, scope.getShortName(opExprName))
      # Unify parenGroup type with inner opExpr
      scope.unifyTypes(symbol.name, opExprName)
    else if ASTNode.isFunctionCall(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      functionName = node.children.fnName.symbolName
      symbol = scope.addConstSymbol(node.name, scope.getShortName(functionName))
      argNames = []
      for arg in node.children.argList
        argNames.push(arg.symbolName)
      scope.getSymbol(functionName).setType(Symbol.TYPES.FN)
      scope.unifyFnCallTypes(functionName, symbol.name, argNames)
    else if ASTNode.isArray(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      symbol = scope.addConstSymbol(node.name)
    else if ASTNode.isArrayRange(node)
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
      symbol = scope.addConstSymbol(node.name)
    else if ASTNode.isString(node)
      symbol = scope.addConstSymbol(node.name, node.literal)
    else if ASTNode.isNumber(node)
      symbol = scope.addConstSymbol(node.name, node.literal)

    # Assume we've already traversed children if we have a node symbol
    if symbol?
      node.symbolName = symbol.name
    else if not traversed
      ASTNode.traverseChildren(node, ((child) => @genNodeSymbols(child, scope)), true)
    return

module.exports = SymbolTable
