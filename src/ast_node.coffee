class ASTNode
  @COMPARISON_OPS = [
    '_EQUALS_EQUALS_'
    '_NOT_EQUALS_'
    '_LTE_'
    '_LT_'
    '_GTE_'
    '_GT_'
  ]
  @isEmpty: (node) -> node.name == '_EMPTY_'
  @isFunctionAssignment: (node) -> node.name == '_FunctionAssignment_'
  @isReturn: (node) -> node.name == '_Return_'
  @isAssignment: (node) -> node.name == '_Assignment_'
  @isTypedVariable: (node) -> node.name == '_TypedVariable_'
  @isVariable: (node) -> node.name == '_Variable_'
  @isNestedVariable: (node) -> ASTNode.isVariable(node) and not ASTNode.isEmpty(node.children.prop)
  @isOpExpression: (node) -> node.name == '_OpExpression_'
  @isComparisonOp: (node) -> ASTNode.isOpExpression(node) and node.children.op.name in ASTNode.COMPARISON_OPS
  @isOpParenGroup: (node) -> node.name == '_OpParenGroup_'
  @isFunctionCall: (node) -> node.name == '_FunctionCall_'
  @isArray: (node) -> node.name == '_Array_'
  @isArrayRange: (node) -> node.name == '_ArrayRange_'
  @isString: (node) -> node.name == '_String_'
  @isNumber: (node) -> node.name == '_NUMBER_'

  # For generating the symbol table, we want to traverse function assignments
  # last so that the entire outer scope is defined before any inner scopes
  @traverseChildren: (node, traverseFn, fnAssignmentsLast = false) ->
    fnAssignments = []
    for name, child of node.children
      if child.length > 0
        for subchild in child
          if fnAssignmentsLast and ASTNode.isFunctionAssignment(subchild)
            fnAssignments.push(subchild)
          else
            traverseFn(subchild)
      else if fnAssignmentsLast and ASTNode.isFunctionAssignment(child)
        fnAssignments.push(child)
      else
        traverseFn(child)
    for fnAssignment in fnAssignments
      traverseFn(fnAssignment)
    return

  constructor: (@name, @literal = null) ->
    @children = null
    @scopeName = null
    @symbolName = null
    return

module.exports = ASTNode
