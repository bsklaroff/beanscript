class ASTNode
  constructor: (@name, @literal = null) ->
    @children = null
    return

module.exports = ASTNode
