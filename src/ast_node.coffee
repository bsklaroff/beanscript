class ASTNode
  @isEmpty: (node) -> node.name == '_EMPTY_'
  @isAssignment: (node) -> node.name == '_Assignment_'
  @isFunctionAssignment: (node) -> node.name == '_FunctionAssignment_'
  @isFunctionDef: (node) -> node.name == '_FunctionDef_'
  @isVariable: (node) -> node.name == '_Variable_'
  @isNestedVariable: (node) -> node.name == '_Variable_' and not ASTNode.isEmpty(node.children.prop)
  @isTypedVariable: (node) -> node.name == '_TypedVariable_'

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
    return

module.exports = ASTNode
