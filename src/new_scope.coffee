class Scope

  constructor: ->
    @locals = {}
    @astIdToSymbol = {}
    @typeEqGraph = {}
    @_constCount = 0
    return

  getOrAddSymbol: (varName) ->
    if not @locals[varName]?
      @locals[varName] =
        name: varName
        typeConstraints: null
    return @locals[varName]

  addAnonSymbol: (nodeName, nameSuffix = '') ->
    name = "#{@_constCount}#{nodeName}#{nameSuffix}"
    @locals[name] =
      name: name
      typeConstraints: null
    @_constCount++
    return @locals[name]

  # Stub for now
  unifyTypes: (s0, s1) ->
    console.log("Unifying #{s0.name}, #{s1.name}")
    return

module.exports = Scope
