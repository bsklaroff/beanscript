class ASTNode
  @findLocalVars: (children) ->
    varNames = []
    for name, child of children
      if child.length > 0
        for subchild in child
          if subchild.name == '_Assignment_'
            varNames.push(subchild.children.target.literal)
          else if subchild.name != '_FunctionAssignment_'
            varNames = varNames.concat(ASTNode.findLocalVars(subchild.children))
      else
        if child.name == '_Assignment_'
          varNames.push(child.children.target.literal)
        else if child.name != '_FunctionAssignment_'
          varNames = varNames.concat(ASTNode.findLocalVars(child.children))
    return varNames

  @findFnAssignments: (children) ->
    fnAssignments = []
    for name, child of children
      if child.length > 0
        for subchild in child
          if subchild.name == '_FunctionAssignment_'
            fnAssignments.push(subchild)
          fnAssignments = fnAssignments.concat(ASTNode.findFnAssignments(subchild.children))
      else
        if child.name == '_FunctionAssignment_'
          fnAssignments.push(child)
        fnAssignments = fnAssignments.concat(ASTNode.findFnAssignments(child.children))
    return fnAssignments

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
    for varName in ASTNode.findLocalVars(@children)
      wast += "    (local $#{varName} i64)\n"
    for statement in @children.statements
      if statement.name != '_FunctionAssignment_'
        wast += "    #{statement.genWast()}\n"
    wast += '  )\n'
    for fnAssignment in ASTNode.findFnAssignments(@children)
      wast += "    #{fnAssignment.genWast()}\n"
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

class FunctionAssignmentNode extends ASTNode
  genWast: ->
    fnName = @children.target.genWast()
    fnDef = @children.source.genWast()
    return "(func #{fnName}#{fnDef})"

class AssignmentNode extends ASTNode
  genWast: ->
    targetWast = @children.target.genWast()
    sourceWast = @children.source.genWast()
    return "(set_local #{targetWast} #{sourceWast})"

class FunctionCallNode extends ASTNode
  genWast: ->
    nameWast = @children.fnName.genWast()
    argWasts = []
    for arg in @children.argList
      argWasts.push(arg.genWast())
    call = 'call'
    if nameWast == '$print_i64'
      call += '_import'
    wast = "(#{call} #{nameWast}"
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

class OpParenGroupNode extends ASTNode
  genWast: -> @children.opExpr.genWast()

class VariableNode extends ASTNode
  genWast: ->
    idWast = @children.id.genWast()
    return "(get_local #{idWast})"

class FunctionDefNode extends ASTNode
  genWast: ->
    wast = ''
    for arg in @children.args
      wast += "  (param #{arg.genWast()} i64)"
    wast += ' (result i64)\n'
    for varName in ASTNode.findLocalVars(@children.body)
      wast += "    (local $#{varName} i64)\n"
    for statement in @children.body
      wast += "  #{statement.genWast()}\n"
    return wast

class ReturnNode extends ASTNode
  genWast: -> "(return #{@children.returnVal.genWast()})"

class IdNode extends ASTNode
  genWast: -> "$#{@literal}"

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
  _FunctionAssignment_: FunctionAssignmentNode
  _Assignment_: AssignmentNode
  _FunctionCall_: FunctionCallNode
  _OpExpression_: OpExpressionNode
  _OpParenGroup_: OpParenGroupNode
  _Variable_: VariableNode
  _FunctionDef_: FunctionDefNode
  _Return_: ReturnNode
  _ID_: IdNode
  _NUMBER_: NumberNode
  _EXPONENT_: ExponentNode
  _TIMES_: TimesNode
  _DIVIDED_BY_: DividedByNode
  _PLUS_: PlusNode
  _MINUS_: MinusNode

module.exports = ASTNode
