class SymbolTable

  constructor: ->
    @_astIdToSymbol = {}
    @_scopeAnonCount = {}

  setNamedSymbol: (astNode, varName) ->
    name = @getSymbolName(varName, astNode.scopeId)
    @_astIdToSymbol[astNode.astId] = name
    return name

  setAnonSymbol: (astNode, nameSuffix = '') ->
    @_scopeAnonCount[astNode.scopeId] ?= 0
    anonId = @_scopeAnonCount[astNode.scopeId]
    varName = "#{anonId}#{astNode.name}#{nameSuffix}"
    name = @getSymbolName(varName, astNode.scopeId)
    @_scopeAnonCount[astNode.scopeId]++
    @_astIdToSymbol[astNode.astId] = name
    return name

  getSymbolName: (varName, scopeId) -> "$#{scopeId}~#{varName}"

  scopeReturnSymbol: (scopeId) -> "$#{scopeId}~return"

  getNodeSymbol: (astNode) -> @_astIdToSymbol[astNode.astId]

  getScope: (symbol) -> symbol.split('~')[0][1..]

  isGlobal: (symbol) -> symbol.split('~')[1][0] == '@'

  isFunctionDef: (symbol) -> symbol.split('_')[1] == 'FunctionDef'

  isReturn: (symbol) -> symbol.split('~')[1] == 'return'

module.exports = SymbolTable
