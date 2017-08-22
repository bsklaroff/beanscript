class SymbolTable

  constructor: ->
    @allSymbols = {}
    @_astIdToSymbol = {}
    @_scopeAnonCount = {}

  setNamedSymbol: (astNode, varName, isFunctionCall = false) ->
    name = "#{astNode.scopeId}~#{varName}"
    if isFunctionCall
      name = "0~#{varName}"
    @allSymbols[name] = true
    @_astIdToSymbol[astNode.astId] = name
    return name

  setAnonSymbol: (astNode, nameSuffix = '') ->
    @_scopeAnonCount[astNode.scopeId] ?= 0
    anonId = @_scopeAnonCount[astNode.scopeId]
    name = "#{astNode.scopeId}~#{anonId}#{astNode.name}#{nameSuffix}"
    @_scopeAnonCount[astNode.scopeId]++
    @allSymbols[name] = true
    @_astIdToSymbol[astNode.astId] = name
    return name

  scopeReturnSymbol: (astNode) -> "#{astNode.scopeId}~return"

  getNodeSymbol: (astNode) -> @_astIdToSymbol[astNode.astId]

  getSymbolScope: (symbol) -> symbol.split('~')[0]

module.exports = SymbolTable
