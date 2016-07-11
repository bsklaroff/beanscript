class ASTNode
  @isFunctionAssignment: (node) -> node.name == '_FunctionAssignment_'
  @isAssignment: (node) -> node.name == '_Assignment_'
  @isVariable: (node) -> node.name == '_Variable_'
  @isOpExpression: (node) -> node.name == '_OpExpression_'
  @isOpParenGroup: (node) -> node.name == '_OpParenGroup_'
  @isFunctionCall: (node) -> node.name == '_FunctionCall_'
  @isArray: (node) -> node.name == '_Array_'
  @isArrayRange: (node) -> node.name == '_ArrayRange_'
  @isString: (node) -> node.name == '_String_'
  @isNumber: (node) -> node.name == '_NUMBER_'

  @isNestedVariable: (node) -> node.name == '_Variable_' and not ASTNode.isEmpty(node.children.prop)
  @isTypedVariable: (node) -> node.name == '_TypedVariable_'
  @isEmpty: (node) -> node.name == '_EMPTY_'

  @traverseChildren: (node, traverseFn) ->
    for name, child of node.children
      if child.length > 0
        for subchild in child
          traverseFn(subchild)
      else
        traverseFn(child)
    return

  constructor: (@name, @literal = null) ->
    @children = null
    @scopeName = null
    @symbolName = null
    return

module.exports = ASTNode
