Symbol = require('./symbol')

class Scope
  @fnCount: 0
  @genFnScope: (fnName, parentScope) ->
    name = "#{Scope.fnCount}_#{fnName}"
    Scope.fnCount += 1
    return new Scope(name, parentScope)

  constructor: (@name, @parentScope) ->
    @argNames = null
    @locals = {}
    @_constCount = 0
    return

  getVarSymbol: (varName) -> @locals["$#{varName}"]
  ### No closures for now
    if not name?
      return null
    if name of @locals
      return @locals[name]
    # If not found in local scope, check for variable in parent scope
    if @parentScope?
      return @parentScope.getSymbol(name)
    return null
  ###

  addNamedSymbol: (varName) ->
    varName = "$#{varName}"
    @locals[varName] = new Symbol(varName, @name, true)
    return @locals[varName]

  addAnonSymbol: (nodeName, nameSuffix) ->
    name = "$#{@_constCount}#{nodeName}#{nameSuffix}"
    @locals[name] = new Symbol(name, @name, false)
    @_constCount += 1
    return @locals[name]

  addArgs: (fnSymbol, args) ->
    @argNames = []
    argSymbols = []
    for arg in args
      argName = "$#{arg.children.id.literal}"
      argType = arg.children.type.literal
      if argName of @locals
        throw new Error("Duplicate function argument: #{arg}")
      @locals[argName] = new Symbol(argName, @name, true)
      @locals[argName].setType(argType)
      @argNames.push(argName)
      argSymbols.push(@locals[argName])
    fnSymbol.unifyArgTypes(argSymbols)
    return

  toJSON: -> {
    name: @name
    parentScope: "&#{@parentScope?.name}"
    argNames: @argNames
    locals: @locals
    _constCount: @_constCount
  }

module.exports = Scope
