ASTNode = require('../ast_node')

OP_MAP =
  _EXPONENT_: '__exp__'
  _MOD_: '__mod__'
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
  _AND_: '__and__'
  _OR_: '__or__'
  _NEG_: '__neg__'

replaceOpsWithFns = (astNode) ->
  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = replaceOpsWithFns(child)
    return astNode
  # Replace ops with fns for all children
  for name, child of astNode.children
    astNode.children[name] = replaceOpsWithFns(child)
  # If this node is an op, replace with a fn call
  resNode = astNode
  if astNode.isOpExpression()
    idNode = ASTNode.make('_ID_', OP_MAP[astNode.children.op.name])
    varNode = ASTNode.make('_Variable_')
    varNode.children =
      id: idNode
      props: []
    resNode = ASTNode.make('_FunctionCall_')
    resNode.children =
      fnName: varNode
      args: []
    if not astNode.children.lhs.isEmpty()
      resNode.children.args.push(astNode.children.lhs)
    resNode.children.args.push(astNode.children.rhs)
  return resNode

module.exports = replaceOpsWithFns
