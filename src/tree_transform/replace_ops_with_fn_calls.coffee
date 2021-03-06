ASTNode = require('../ast_node')

OP_MAP =
  _REMAINDER_: '__rem__'
  _EXPONENT_: '__exp__'
  _TIMES_: '__mul__'
  _DIVIDED_BY_: '__div__'
  _PLUS_: '__add__'
  _MINUS_: '__sub__'
  _EQUALS_EQUALS_: '__eq__'
  _NOT_EQUALS_: '__neq__'
  _LTE_: '__lte__'
  _LT_: '__lt__'
  _GTE_: '__gte__'
  _GT_: '__gt__'
  _NEG_: '__neg__'
  _NOT_: '__not__'
  _AND_: null
  _OR_: null

replaceOpsWithFnCalls = (astNode) ->
  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = replaceOpsWithFnCalls(child)
    return astNode
  # Replace ops with fns for all children
  for name, child of astNode.children
    astNode.children[name] = replaceOpsWithFnCalls(child)
  # If this node is an op, replace with a fn call.
  # Special case: replace _AND_ and _OR_ ops with _AndExpression_ and
  # _OrExpression_ nodes
  resNode = astNode
  if astNode.isOpExpression()
    if OP_MAP[astNode.children.op.name]?
      idNode = ASTNode.make('_ID_', OP_MAP[astNode.children.op.name])
      varNode = ASTNode.make('_Variable_')
      varNode.children = {id: idNode}
      resNode = ASTNode.make('_FunctionCall_')
      resNode.children = {fn: varNode, args: []}
      if not astNode.children.lhs.isEmpty()
        resNode.children.args.push(astNode.children.lhs)
      resNode.children.args.push(astNode.children.rhs)
    else if astNode.children.op.name == '_AND_'
      resNode = ASTNode.make('_AndExpression_')
      resNode.children = {lhs: astNode.children.lhs, rhs: astNode.children.rhs}
    else if astNode.children.op.name == '_OR_'
      resNode = ASTNode.make('_OrExpression_')
      resNode.children = {lhs: astNode.children.lhs, rhs: astNode.children.rhs}
  # If this node is an opParenGroup, replace it with its child
  else if astNode.isOpParenGroup()
    resNode = astNode.children.opExpr
  return resNode

module.exports = replaceOpsWithFnCalls
