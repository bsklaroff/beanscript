class Symbol
  #TODO: unhardcode this, and make it dynamic
  @ARRAY_LENGTH = 100
  #TODO: put this somewhere else
  @ARRAY_OFFSET = 2

  constructor: (@name, @scopeName, @namedVar) ->
    @shortName = if @namedVar then @name else @name.split('_')[0]
    @uniqName = "#{@scopeName}:#{@name}"
    @type = null
    @ref = "(get_local #{@name})"
    @parentSymbols = null
    @_eqTypeSymbols = {}
    return

  getSubsymbol: (propSymbols) ->
    if not @type.isArr() and not @type.isObj()
      throw new Error("Cannot get subsymbols of non-obj, non-arr symbol: #{@name}")
    curSymbol = @
    for propSymbol in propSymbols
      curSymbol = curSymbol.subsymbols[propSymbol.name]
      if not curSymbol?
        break
    return curSymbol

  addSubsymbol: (propSymbols, newSymbol) ->
    if not @type.isArr() and not @type.isObj()
      throw new Error("Cannot get subsymbols of non-obj, non-arr symbol: #{@name}")
    curSymbol = @
    for propSymbol, i in propSymbols
      # First, traverse the nested subsymbols
      if i < propSymbols.length - 1
        curSymbol = curSymbol.subsymbols[propSymbol.name]
        if not curSymbol?
          throw new Error("Nested symbol not found: #{propSymbol.name}")
      # Finally, add the new symbol at the end of the chain
      else
        if curSymbol.subsymbols[propSymbol.name]?
          throw new Error("Nested symbol already defined: #{propSymbol.name}")
        curSymbol.subsymbols[propSymbol.name] = newSymbol
        if curSymbol.type.isArr()
          newSymbol.setType(curSymbol.type.elemType)
    return

  setChildScopeName: (name) ->
    if not @type.isFn()
      throw new Error("Cannot unify arg types for non-fn symbol: #{@name}")
    @childScopeName = name
    return

  setType: (type) ->
    if @type? and not @type.isEqual(type)
      throw new Error("Cannot overwrite type #{@type.primitive} for symbol #{@name} with type #{type.primitive}")
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
    else if @type.isObj() or @type.isArr()
      @subsymbols = {}
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

  setParentSymbols: (@parentSymbols) ->
    if @type.isI64()
      @ref = "(i64.load #{@genMemptr()})"
    else if @type.isI32() or @type.isArr()
      @ref = "(i32.load #{@genMemptr()})"
    return

  # TODO: make this work for more than single-dimensional array accesses
  genMemptr: ->
    if not @parentSymbols?
      throw new Error("Cannot genMemptr for symbol with no parentSymbols: #{@name}")
    elemSize = if @type.isI64() then 8 else 4
    offsetStart = "(i32.add (get_local #{@parentSymbols[0].name}) (i32.const #{Symbol.ARRAY_OFFSET * 4}))"
    offsetLen = "(get_local #{@parentSymbols[1].name})"
    if @parentSymbols[1].type.isI64()
      offsetLen = "(i32.wrap/i64 #{offsetLen})"
    return "(i32.add #{offsetStart} (i32.mul #{offsetLen} (i32.const #{elemSize})))"

  wastVars: ->
    if @type?.isI32() or @type?.isArr() or @parentSymbols?
      return [[@name, 'i32']]
    if @type?.isI64()
      return [[@name, 'i64']]
    if @type?.isBool()
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