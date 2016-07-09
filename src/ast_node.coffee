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
    wast += '  (import $print_i64 "stdio" "print" (param i64))\n'
    wast += '  (func\n'
    for statement in @children.statements
      wast += "    #{statement.genWast()}\n"
    wast += '  )\n'
    wast += '''
(func $exp_i64 (param $base i64) (param $exp i64) (result i64)
  (local $res i64)
  (set_local $res (i64.const 1))
  (loop $done $loop
    (br_if $done (i64.eq (get_local $exp) (i64.const 0)))
    (set_local $res (i64.mul (get_local $res) (get_local $base)))
    (set_local $exp (i64.sub (get_local $exp) (i64.const 1)))
    (br $loop)
  )
  (return (get_local $res))
)\n'''
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

class ExponentNode extends ASTNode
  genWast: -> 'call $exp_i64'

class TimesNode extends ASTNode
  genWast: -> 'i64.mul'

class DividedByNode extends ASTNode
  genWast: -> 'i64.div'

class PlusNode extends ASTNode
  genWast: -> 'i64.add'

class MinusNode extends ASTNode
  genWast: -> 'i64.sub'

class NumberNode extends ASTNode
  genWast: -> "(i64.const #{@literal})"

TYPES =
  _Program_: ProgramNode
  _FunctionCall_: FunctionCallNode
  _OpExpression_: OpExpressionNode
  _Variable_: VariableNode
  _NUMBER_: NumberNode
  _EXPONENT_: ExponentNode
  _TIMES_: TimesNode
  _DIVIDED_BY_: DividedByNode
  _PLUS_: PlusNode
  _MINUS_: MinusNode

module.exports = ASTNode
