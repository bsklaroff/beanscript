ASTNode = require('./ast_node')

OP_EXPRESSION_NAME = '_OpExpression_'

OP_PRECEDENCE_LEVELS = [
  ['_OR_']
  ['_AND_']
  ['_EQUALS_EQUALS_', '_NOT_EQUALS_']
  ['_LT_', '_LTE_', '_GT_', '_GTE_']
  ['_PLUS_', '_MINUS_']
  ['_EXPONENT_', '_MOD_', '_TIMES_', '_DIVIDED_BY_']
  ['_NOT_', '_NEG_']
]

fixOpPrecedence = (astNode) ->
  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = fixOpPrecedence(child)
    return astNode
  # Check if astNode is an non-op
  if not astNode.isOpExpression()
    for name, child of astNode.children
      astNode.children[name] = fixOpPrecedence(child)
    return astNode
  # Fix operator precedence for an op node
  [operators, operands] = getOpLists(astNode.children.rhs)
  operators.unshift(astNode.children.op)
  operands.unshift(astNode.children.lhs)
  return makeOpTree(operators, operands, 0)

getOpLists = (astNode) ->
  # Check if astNode was the last rhs in an op chain
  if not astNode.isOpExpression()
    return [[], [astNode]]
  [operators, operands] = getOpLists(astNode.children.rhs)
  operators.unshift(astNode.children.op)
  operands.unshift(astNode.children.lhs)
  return [operators, operands]

makeOpTree = (operators, operands, precedenceIdx) ->
  if operators.length == 0
    if operands.length != 1
      throw new Error("Expeced operands of length 1, found #{operands}")
    return operands[0]
  if precedenceIdx >= OP_PRECEDENCE_LEVELS.length
    throw new Error('Precedence index exceeds maximum')
  i = operators.length - 1
  while i >= 0
    if operators[i].name in OP_PRECEDENCE_LEVELS[precedenceIdx]
      lhs = makeOpTree(operators[...i], operands[..i], precedenceIdx)
      rhs = makeOpTree(operators[i + 1..], operands[i + 1..], precedenceIdx + 1)
      return makeOpNode(operators[i], lhs, rhs)
    i--
  return makeOpTree(operators, operands, precedenceIdx + 1)

makeOpNode = (operator, lhs, rhs) ->
  opNode = ASTNode.make(OP_EXPRESSION_NAME)
  opNode.children =
    lhs: lhs
    op: operator
    rhs: rhs
  return opNode

module.exports = fixOpPrecedence
