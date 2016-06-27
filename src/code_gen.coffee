class CodeGen
  constructor: (@astTree) ->
    return

  genWast: -> @astTree.genWast()

module.exports = CodeGen
