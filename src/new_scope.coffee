class Scope

  constructor: (@typeInfo) ->
    @locals = {}
    @astIdToSymbol = {}
    @typeEqGraph = {}
    @_constCount = 0
    return

  getOrAddSymbol: (varName) ->
    if not @locals[varName]?
      @locals[varName] =
        name: varName
        typeConstraints: {}
        type: null
    return @locals[varName]

  addAnonSymbol: (nodeName, nameSuffix = '') ->
    name = "#{@_constCount}#{nodeName}#{nameSuffix}"
    @locals[name] =
      name: name
      typeConstraints: {}
      type: null
    @_constCount++
    return @locals[name]

  unifyTypes: (s0, s1) ->
    @typeEqGraph[s0.name] ?= {}
    @typeEqGraph[s1.name] ?= {}
    @typeEqGraph[s0.name][s1.name] = true
    @typeEqGraph[s1.name][s0.name] = true
    return

  _isConcreteType: (type) -> type of @typeInfo.dataTypes

  _isSubConstraint: (t0, t1) ->
    if t0 == t1
      return true
    if @_isConcreteType(t0)
      for typeclass in @typeInfo.dataTypes[t0]
        if @_isSubConstraint(typeclass, t1)
          return true
    else
      for typeclass in @typeInfo.typeclasses[t0].reqs
        if @_isSubConstraint(typeclass, t1)
          return true
    return false

  addTypeConstraint: (symbol, newConstraint) ->
    for constraint of symbol.typeConstraints
      # If an existing constraint is more specific than the new constraint,
      # it's already covered
      if @_isSubConstraint(constraint, newConstraint)
        return
      # If the new constraint is more specific than an existing constraint,
      # replace the existing
      else if @_isSubConstraint(newConstraint, constraint)
        delete symbol.typeConstraints[constraint]
        symbol.typeConstraints[newConstraint] = true
        return
      # Otherwise, if either constraint is a literal type, throw an error
      # because it is incompatible
      else if @_isConcreteType(constraint) or @_isConcreteType(newConstraint)
        console.log("ERROR: Incompatible type constraints #{constraint}, " +
                    "#{newConstraint} for symbol:\n" +
                    "#{JSON.stringify(symbol, null, 2)}")
        process.exit(1)
    # If we found no conflicting or redundant constraints, simply add the new one
    symbol.typeConstraints[newConstraint] = true
    return

  addFnCallConstraints: (fnName, fnCallSymbol, argSymbols) ->
    fnDef = @typeInfo.fnTypes[fnName]

    if not fnDef?
      console.log("ERROR: no def found for fn #{fnName}")
      process.exit(1)
    if argSymbols.length != fnDef.fnType.length - 1
      console.log("ERROR: found #{argSymbols.length} args for #{fnName}, " +
                  "expected #{fnDef.fnType.length - 1}")
      process.exit(1)

    tempSymbolGroups = {}
    allSymbols = argSymbols.concat([fnCallSymbol])
    for symbol, i in allSymbols
      type = fnDef.fnType[i]
      # If type is a literal type, just add it to the symbol_constraints
      if @_isConcreteType(type)
        @addTypeConstraint(symbol, type)
      # If type_constraint is anonymous, add its typeclass constraint to
      # symbol_constraints. Also, mark in the symbol_graph that it must be the
      # same type as all other symbols with the same anonymous type.
      else
        # Add typeclass constraint
        if not fnDef.anonTypes?[type]?
          console.log("ERROR: no typeclass found for anon type #{type} in def " +
                      "for fn #{fnName}")
        typeclasses = fnDef.anonTypes[type]
        for typeclass in typeclasses
          @addTypeConstraint(symbol, typeclass)
        # Update symbol graph
        tempSymbolGroups[type] ?= []
        for otherSymbol in tempSymbolGroups[type]
          @unifyTypes(symbol, otherSymbol)
        tempSymbolGroups[type].push(symbol)
    return

  _setType: (symbol, type) ->
    if symbol.type? and symbol.type != type
      console.log("ERROR: Cannot set conflicting type #{type} for symbol:\n" +
                  "#{JSON.stringify(symbol, null, 2)}")
      process.exit(1)
    symbol.type = type
    return

  assignAllTypes: ->
    symbolGroups = @_genSymbolGroups()
    # Assign concrete types to all symbolGroups
    for symbolGroup in symbolGroups
      for constraint of symbolGroup.typeConstraints
        if @_isConcreteType(constraint)
          @_setType(symbolGroup, constraint)
        else if @typeInfo.typeclasses[constraint].default?
          @_setType(symbolGroup, @typeInfo.typeclasses[constraint].default)
      if not symbolGroup.type?
        console.log("ERROR: No concrete type found for symbolGroup:\n" +
                    "#{JSON.stringify(symbolGroup, null, 2)}")
        process.exit(1)
      # Assign concrete types to all symbols in the symbolGroup
      for symbolName in symbolGroup.symbols
        @locals[symbolName].type = symbolGroup.type
    # Make sure every local got assigned a type
    for symbolName, symbol of @locals
      if not symbol.type?
        console.log("ERROR: No concrete type found for symbol #{symbol.name}")
        process.exit(1)
    return

  ###
  Traverse typeEqGraph to assign symbols groups and constraints.
  Any symbol reachable in a DFS is unified together in the same symbol group.
  We also keep track of type constraints (literal types or typeclasses) we can
  determine for each anonymous type type symbol (e.g. if we unify with a '5'
  node we know this is of the 'num' typeclass)
  ###
  _genSymbolGroups: ->
    symbolGroups = []
    seenSymbols = {}
    while Object.keys(seenSymbols).length != Object.keys(@typeEqGraph).length
      for symbolName of @typeEqGraph
        if not seenSymbols[symbolName]
          symbolGroup = {symbols: [], typeConstraints: {}, type: null}
          symbolGroups.push(symbolGroup)
          @_addToSymbolGroup(symbolGroup, symbolName, seenSymbols)
    return symbolGroups

  _addToSymbolGroup: (symbolGroup, symbolName, seenSymbols) ->
    if seenSymbols[symbolName]
      return
    symbol = @locals[symbolName]
    seenSymbols[symbol.name] = true
    symbolGroup.symbols.push(symbol.name)
    # Add all symbol constraints to the anon type's pre-existing constraints
    for typeConstraint of symbol.typeConstraints
      @addTypeConstraint(symbolGroup, typeConstraint)
    for otherSymbolName of @typeEqGraph[symbol.name]
      @_addToSymbolGroup(symbolGroup, otherSymbolName, seenSymbols)
    return


module.exports = Scope
