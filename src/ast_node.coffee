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
      # Also, replace underscores with capital letters
      if niceType == niceType.toUpperCase()
        splitType = niceType.split('_')
        for word, i in splitType
          splitType[i] = "#{word[0]}#{word[1..].toLowerCase()}"
        niceType = splitType.join('')
      fnName = "is#{niceType}"
      if type == @name
        @[fnName] = -> true
      else
        @[fnName] = -> false
    return

NODE_TYPES = [
  '_Program_'
  '_Return_'
  '_ReturnPtr_'
  '_If_'
  '_Else_'
  '_While_'
  '_Assignment_'
  '_TypeDef_'
  '_TypeclassDef_'
  '_Typeclass_'
  '_Typeinst_'
  '_Type_'
  '_ObjectType_'
  '_ConstructedType_'
  '_FunctionType_'
  '_Assignable_'
  '_VarOrFnCall_'
  '_ArgList_'
  '_Variable_'
  '_ArrayRef_'
  '_ObjectRef_'
  '_FunctionCall_'
  '_OpExpression_'
  '_OpParenGroup_'
  '_Array_'
  '_ArrayRange_'
  '_Object_'
  '_ObjectProp_'
  '_FunctionDef_'
  '_FunctionDefArg_'
  '_FnDefProp_'
  '_Wast_'
  '_Sexpr_'
  '_DoubleQuoteString_'
  '_NUMBER_'
  '_BOOLEAN_'
  '_ID_'
  '_ID_REF_'
  '_EMPTY_'
]

module.exports = ASTNode
