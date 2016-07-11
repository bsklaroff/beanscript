ASTNode = require('./ast_node')

class Symbol
  constructor: (@name, @namedVar) ->
    @type = null
    return

  getShortName: -> if @namedVar then @name else @name.split('_')[0]

  addProperty: (varNode, type) ->
    if @type != 'obj'
      throw new Error("Cannot add property to non-obj symbol: #{@}")
    if not ASTNode.isTypedVariable(typedVarNode)
      throw new Error("Expected node to be a typed variable: #{typedVarNode}")
    @props ?= {}
    varName = varNode.children.id.literal
    if ASTNode.isNestedVariable(varNode)
      if varName not of @props
        throw new Error("Expected property #{varName} in symbol #{@}")
      @props[varName].addProperty(varNode.children.prop, type)
    else
      if varName not of @props
        @props[varName] = new Symbol(varName, type)
      else if type != '' and @props[varName].type != type
        throw new Error("Expected type #{@props[varName]} for node #{varNode}")
    return

  setScopeName: (name) ->
    if @type != 'fn'
      throw new Error("Cannot set scope of non-fn symbol: #{@}")
    @scopeName = name
    return

  setType: (type) ->
    if @type? and @type != type
      throw new Error("Cannot overwrite type #{type} for symbol #{@}")
    @type = type
    return

class Scope
  constructor: (@name, @parentScope) ->
    @argNames = null
    @locals = {}
    @_constCount = 0
    return

  addVarSymbol: (varName) ->
    @locals[varName] = new Symbol(varName, true)
    return @locals[varName]

  addConstSymbol: (nodeName, nameSuffix) ->
    name = "#{@_constCount}#{nodeName}#{nameSuffix}"
    @locals[name] = new Symbol(name, false)
    @_constCount += 1
    return @locals[name]

  getSymbol: (name) ->
    # Recursively check for variable in parent scope
    if @parentScope?
      symbol = @parentScope.getSymbol(name)
      if symbol?
        return symbol
    return @locals[name]

  addArgs: (args) ->
    @argNames = []
    for arg in args
      argName = arg.children.id.literal
      argType = arg.children.type.literal
      if argName of @locals
        throw new Error("Duplicate function argument: #{arg}")
      @locals[argName] = new Symbol(argName, true)
      @locals[argName].setType(argType)
      @argNames.push(argName)
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
    if ASTNode.isFunctionAssignment(node)
      target = node.children.target
      targetVar = target.children.var
      targetVarName = targetVar.children.id.literal
      if scope.getSymbol(targetVarName)?
        throw new Error("Cannot redefine function: #{target}")
      symbol = scope.addVarSymbol(targetVarName)
      fnScope = @_genFnScope(symbol.name, scope)
      symbol.setType(target.children.type.literal)
      symbol.setScopeName(fnScope.name)
      # Extract arg symbols from function definition into function scope
      fnDef = node.children.source
      fnScope.addArgs(fnDef.children.args)
      for statement in fnDef.children.body
        @genNodeSymbols(statement, fnScope)
    else if ASTNode.isAssignment(node)
      # TODO
      ###
      target = node.children.target
      targetVar = target.children.var
      if ASTNode.isNestedVariable(targetVar)
        objSymbol = scope.getVarSymbol(targetVar)
        if not objSymbol?
          throw new Error("Parent object does not exist: #{targetVar}")
        objSymbol.addProperty(targetVar, target.children.type.literal)
      else
        varSymbol = scope.getVarSymbol(targetVar)
        if not varSymbol?
          scope.addVarSymbol(target)
        else if varSymbol.type != target.children.type.literal
        else if varSymbol.type != target.children.type.literal
          throw new Error("Expected type #{varSymbol.type} for target #{target}")
      ###
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
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
      nameSuffix = ''
      if not ASTNode.isEmpty(node.children.lhs)
        nameSuffix += "#{scope.getSymbol(node.children.lhs.symbolName).getShortName()}_"
      nameSuffix += scope.getSymbol(node.children.rhs.symbolName).getShortName()
      symbol = scope.addConstSymbol(node.name, nameSuffix)
    else if ASTNode.isOpParenGroup(node)
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
      opExprName = scope.getSymbol(node.children.opExpr.symbolName).getShortName()
      symbol = scope.addConstSymbol(node.name, opExprName)
    else if ASTNode.isFunctionCall(node)
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
      functionName = scope.getSymbol(node.children.fnName.symbolName).getShortName()
      symbol = scope.addConstSymbol(node.name, functionName)
    else if ASTNode.isArray(node)
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
      symbol = scope.addConstSymbol(node.name)
    else if ASTNode.isArrayRange(node)
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
      symbol = scope.addConstSymbol(node.name)
    else if ASTNode.isString(node)
      symbol = scope.addConstSymbol(node.name, node.literal)
    else if ASTNode.isNumber(node)
      symbol = scope.addConstSymbol(node.name, node.literal)

    if symbol?
      node.symbolName = symbol.name
    else
      ASTNode.traverseChildren(node, (child) => @genNodeSymbols(child, scope))
    return

module.exports = SymbolTable
