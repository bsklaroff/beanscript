ASTNode = require('./ast_node')

class Symbol
  constructor: (@name, @type) ->
    return

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

class Scope
  constructor: (@name, @parentScope) ->
    @argNames = null
    @locals = {}
    return

  getVarSymbol: (varNode) ->
    if not ASTNode.isVariable(varNode)
      throw new Error("Expected node to be a variable: #{varNode}")
    # Recursively check for variable in parent scope
    if @parentScope?
      symbol = @parentScope.getVarSymbol(varNode)
      if symbol?
        return symbol
    return @locals[varNode.children.id.literal]

  addVarSymbol: (typedVarNode) ->
    if not ASTNode.isTypedVariable(typedVarNode)
      throw new Error("Expected node to be a typed variable: #{typedVarNode}")
    varName = typedVarNode.children.var.children.id.literal
    varType = typedVarNode.children.type.literal
    @locals[varName] = new Symbol(varName, varType)
    return @locals[varName]

  addArgs: (args) ->
    @argNames = []
    for arg in args
      argName = arg.children.id.literal
      argType = arg.children.type.literal
      if argName of @locals
        throw new Error("Duplicate function argument: #{arg}")
      @locals[argName] = new Symbol(argName, argType)
      @argNames.push(argName)
    return

class SymbolTable
  constructor: ->
    @globalScope = new Scope('global', null)
    @fnScopes = {}
    @_fnCount = 0
    return

  _genFnScope: (fnName, parentScope) ->
    name = "#{@_fnCount}_#{fnName}"
    @_fnCount += 1
    @fnScopes[name] = new Scope(name, parentScope)
    return @fnScopes[name]

  extractNodeSymbols: (node, scope = @globalScope) ->
    if ASTNode.isAssignment(node)
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
        else if target.children.type.literal != '' and varSymbol.type != target.children.type.literal
          throw new Error("Expected type #{varSymbol.type} for target #{target}")
    else if ASTNode.isFunctionAssignment(node)
      target = node.children.target
      targetVar = target.children.var
      if scope.getVarSymbol(targetVar)?
        throw new Error("Cannot redefine function: #{target}")
      fnSymbol = scope.addVarSymbol(target)
      fnScope = @_genFnScope(fnSymbol.name, scope)
      fnSymbol.setScopeName(fnScope.name)
      # Extract symbols from function definition into function scope
      fnDef = node.children.source
      fnScope.addArgs(fnDef.children.args)
      for statement in fnDef.children.body
        @extractNodeSymbols(statement, fnScope)
    else
      ASTNode.traverseChildren(node, (child) => @extractNodeSymbols(child, scope))
    return

module.exports = SymbolTable
