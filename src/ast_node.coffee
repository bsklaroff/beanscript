class ASTNode
  @make: (name, literal) ->
    if name of TYPES
      return new TYPES[name](name, literal)
    return new ASTNode(name, literal)

  constructor: (@name, @literal = null) ->
    @children = null
    return

  genWast: -> ''

class ProgramNode extends ASTNode
  genWast: ->
    wast = '(module\n'
    wast += '  (import $print_i32 "stdio" "print" (param i32))\n'
    wast += '  (func\n'
    for statement in @children.statements
      wast += "    #{statement.genWast()}\n"
    wast += '  )\n'
    wast += '  (export "main" 0))'
    return wast

class FunctionCallNode extends ASTNode
  genWast: ->
    nameWast = @children.fnName.genWast()
    argWasts = []
    for arg in @children.argList
      argWasts.push(arg.genWast())
    wast = "(call_import $#{nameWast}"
    for argWast in argWasts
      wast += " #{argWast}"
    wast += ')'
    return wast

class OpExpressionNode extends ASTNode
  genWast: ->
    lhsWast = @children.lhs.genWast()
    rhsWast = @children.rhs.genWast()
    opWast = @children.op.genWast()
    wast = "(#{opWast} #{lhsWast} #{rhsWast})"

# TODO: handle dot object accesses
class VariableNode extends ASTNode
  genWast: -> @children.varNames[0].literal

class PlusNode extends ASTNode
  genWast: -> 'i32.add'

class NumberNode extends ASTNode
  genWast: -> "(i32.const #{@literal})"

TYPES =
  _Program_: ProgramNode
  _FunctionCall_: FunctionCallNode
  _OpExpression_: OpExpressionNode
  _Variable_: VariableNode
  _NUMBER_: NumberNode
  _PLUS_: PlusNode

module.exports = ASTNode
