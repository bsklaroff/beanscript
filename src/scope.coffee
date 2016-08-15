Symbol = require('./symbol')

class Scope
  @fnCount: 0
  @genFnScope: (fnName, parentScope) ->
    name = "#{Scope.fnCount}_#{fnName}"
    Scope.fnCount += 1
    return new Scope(name, parentScope)

  constructor: (@name, @parentScope) ->
    @argNames = []
    @locals = {}
    @_constCount = 0
    return

  getVarSymbol: (varName) ->
    # Hack to find top-level function defs
    # TODO: fix this
    rootScope = @
    while rootScope.parentScope?
      rootScope = rootScope.parentScope
    if rootScope.locals["$#{varName}"]?.type?.isFn()
      return rootScope.locals["$#{varName}"]
    return @locals["$#{varName}"]

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

  addSubsymbol: (nodeName, parentSymbol, propSymbols) ->
    nameSuffix = parentSymbol.shortName
    for propSymbol in propSymbols
      nameSuffix += "_#{propSymbol.shortName}"
    symbol = @addAnonSymbol(nodeName, nameSuffix)
    parentSymbol.addSubsymbol(propSymbols, symbol)
    symbol.setParentSymbols([parentSymbol].concat(propSymbols))
    return symbol

  addArgs: (fnSymbol, args) ->
    if @argNames.length > 0
      throw new Error('Cannot add args to scope twice')
    argSymbols = []
    for arg in args
      @argNames.push(arg.symbol.name)
      argSymbols.push(arg.symbol)
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
