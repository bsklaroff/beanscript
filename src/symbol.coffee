class Symbol
  constructor: (@name, @scopeName, @namedVar) ->
    @shortName = if @namedVar then @name else @name.split('_')[0]
    @uniqName = "#{@scopeName}:#{@name}"
    @type = null
    @_eqTypeSymbols = {}
    return

  ###
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
  ###

  setChildScopeName: (name) ->
    if not @type.isFn()
      throw new Error("Cannot unify arg types for non-fn symbol: #{@name}")
    @childScopeName = name
    return

  setType: (type) ->
    if @type? and not @type.isEqual(type)
      throw new Error("Cannot overwrite type #{type} for symbol #{@name} with type #{@type}")
    if not @type?
      @type = type
      @_initType()
      for name, symbol of @_eqTypeSymbols
        symbol.setType(@type)
      @_eqTypeSymbols = null
    return

  _initType: ->
    if @type.isFn()
      @fnSymbol = @
      @returnSymbol = new Symbol("#{@name}:return", @scopeName, false)
      @argSymbols = []
    return

  addEqTypeSymbol: (otherSymbol) ->
    @_eqTypeSymbols[otherSymbol.uniqName] = otherSymbol
    return

  unifyType: (otherSymbol) ->
    if otherSymbol.type?
      @setType(otherSymbol.type)
    else if @type?
      otherSymbol.setType(@type)
    else
      @addEqTypeSymbol(otherSymbol)
      otherSymbol.addEqTypeSymbol(@)
    # If we found a function, unify arg and return types as well
    if @type?.isFn()
      @fnSymbol = otherSymbol
      @unifyReturnType(otherSymbol.returnSymbol)
      @unifyArgTypes(otherSymbol.argSymbols)
    return

  unifyReturnType: (returnSymbol) ->
    if not @type.isFn()
      throw new Error("Cannot unify return type for non-fn symbol: #{@name}")
    @returnSymbol.unifyType(returnSymbol)
    returnSymbol.unifyType(@returnSymbol)
    return

  unifyArgTypes: (argSymbols) ->
    if not @type.isFn()
      throw new Error("Cannot unify arg types for non-fn symbol: #{@name}")
    for argSymbol, i in argSymbols
      @argSymbols[i] ?= new Symbol("#{@name}:arg#{i}", @scopeName, false)
      @argSymbols[i].unifyType(argSymbol)
      argSymbol.unifyType(@argSymbols[i])
    return

  wastVars: ->
    if @type?.isI32()
      return [[@name, 'i32']]
    else if @type?.isI64()
      return [[@name, 'i64']]
    else if @type?.isBool()
      return [[@name, 'i32']]
    return []

  toJSON: ->
    eqTypeSymbols = []
    for name of @_eqTypeSymbols
      eqTypeSymbols.push(name)
    res = {
      name: @name
      scopeName: @scopeName
      namedVar: @namedVar
      type: @type
      _eqTypeSymbols: eqTypeSymbols
    }
    if @type?.isFn()
      res.returnSymbol = @returnSymbol
      res.argSymbols = @argSymbols
    return res

module.exports = Symbol
