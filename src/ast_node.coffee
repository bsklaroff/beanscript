class ASTNode

  @make: (name, literal) ->
    return new ASTNode(name, literal)

  constructor: (@name, @literal = null) ->
    @children = if @literal? then null else {}
    # Generate 'isNodeType' functions
    for type in NODE_TYPES
      # Strip underscores
      niceType = type[1...-1]
      # For ALLCAPS node names, only uppercase the first letter
      if niceType == niceType.toUpperCase()
        niceType = "#{niceType[0]}#{niceType[1..].toLowerCase()}"
      fnName = "is#{niceType}"
      if type == @name
        @[fnName] = -> true
      else
        @[fnName] = -> false
    return

NODE_TYPES = [
  '_Program_'
  '_Return_'
  '_If_'
  '_Else_'
  '_While_'
  '_Assignment_'
  '_TypeDef_'
  '_TypeclassDef_'
  '_Typeclass_'
  '_TypeInst_'
  '_Type_'
  '_Variable_'
  '_OpExpression_'
  '_OpParenGroup_'
  '_FunctionCall_'
  '_Array_'
  '_FunctionDef_'
  '_FunctionDefArg_'
  '_FnDefProp_'
  '_Wast_'
  '_Sexpr_'
  '_DoubleQuoteString_'
  '_NUMBER_'
  '_BOOLEAN_'
  '_EMPTY_'
]

module.exports = ASTNode
