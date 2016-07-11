SymbolTable = require('./symbol_table')

class CodeGen
  @WAST_GEN_FNS:
    _Program_: 'genProgram'
    _While_: 'genWhile'
    _FunctionAssignment_: 'genFunctionAssignment'
    _Assignment_: 'genAssignment'
    _FunctionCall_: 'genFunctionCall'
    _OpExpression_: 'genOpExpression'
    _OpParenGroup_: 'genOpParenGroup'
    _TypedVariable_: 'genTypedVariable'
    _Variable_: 'genVariable'
    _FunctionDef_: 'genFunctionDef'
    _Return_: 'genReturn'
    _ID_: 'genId'
    _NUMBER_: 'genNumber'
    _LT_: 'genLT'
    _LTE_: 'genLTE'
    _GT_: 'genGT'
    _GTE_: 'genGTE'
    _EXPONENT_: 'genExponent'
    _TIMES_: 'genTimes'
    _DIVIDED_BY_: 'genDividedBy'
    _PLUS_: 'genPlus'
    _MINUS_: 'genMinus'
    _NEG_: 'genNeg'

  constructor: ->
    @symbolTable = new SymbolTable()
    return

  genWast: (node) ->
    return @[CodeGen.WAST_GEN_FNS[node.name]](node)

  genProgram: (node) ->
    @symbolTable.extractNodeSymbols(node)
    console.log(JSON.stringify(@symbolTable, null, 2))
    return
    ###
    mainBody = ''
    for statement in node.children.statements
      if statement.name != '_FunctionAssignment_'
        mainBody += "    #{@genWast(statement)}\n"
    mainBody += '  )\n'
    for fnAssignment in CodeGen.findFnAssignments(node.children)
      mainBody += "    #{@genWast(fnAssignment)}\n"

    wast = '(module\n'
    wast += '  (import $print_i64 "stdio" "print" (param i64))\n'
    wast += '  (func\n'
    for varName of @symbols
      wast += "(local $#{varName} i32)"
    wast += mainBody
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
    ###

  genWhile: (node) ->
    wast = '(loop $done $loop\n'
    wast += "  (if #{@genWast(node.children.condition)}\n"
    wast += "  (then\n"
    for statement in node.children.body
      wast += "    #{@genWast(statement)}\n"
    wast += '''
      (br $loop)
    )
    (else (br $done))
  )
)'''
    return wast

  genFunctionAssignment: (node) ->
    fnSymbol = @_getSymbol(node)
    fnName = @genWast(node.children.target)
    fnDef = @genWast(node.children.source)
    return "(func #{fnName}#{fnDef})"

  genAssignment: (node) ->
    targetWast = @genWast(node.children.target)
    sourceWast = @genWast(node.children.source)
    return "(set_local #{targetWast} #{sourceWast})"

  genFunctionCall: (node) ->
    nameWast = @genWast(node.children.fnName)
    argWasts = []
    for arg in node.children.argList
      argWasts.push(@genWast(arg))
    call = 'call'
    if nameWast == '$print_i64'
      call += '_import'
    wast = "(#{call} #{nameWast}"
    for argWast in argWasts
      wast += " #{argWast}"
    wast += ')'
    return wast


  genOpExpression: (node) ->
    lhsWast = @genWast(node.children.lhs)
    rhsWast = @genWast(node.children.rhs)
    opWast = @genWast(node.children.op)
    wast = "(#{opWast} #{lhsWast} #{rhsWast})"

  genOpParenGroup: (node) -> @genWast(node.children.opExpr)

  genTypedVariable: (node) ->
    idWast = @genWast(node.children.var)
    return "(get_local #{idWast})"

  genVariable: (node) ->
    idWast = @genWast(node.children.obj)
    return "(get_local #{idWast})"

  genFunctionDef: (node) ->
    wast = ''
    argLiterals = {}
    for arg in node.children.args
      wast += "  (param #{@genWast(arg)} i64)"
      argLiterals[arg.literal] = 1
    wast += ' (result i64)\n'
    for varName in CodeGen.findLocalVars(node.children.body, argLiterals)
      wast += "    (local $#{varName} i64)\n"
    for statement in node.children.body
      wast += "  #{@genWast(statement)}\n"
    return wast

  genReturn: (node) -> "(return #{@genWast(node.children.returnVal)})"

  genId: (node) -> "$#{node.literal}"

  genNumber: (node) -> "(i64.const #{node.literal})"

  genLT: (node) -> 'i64.lt_s'

  genLTE: (node) -> 'i64.le_s'

  genGT: (node) -> 'i64.gt_s'

  genGTE: (node) -> 'i64.ge_s'

  genExponent: (node) -> 'call $exp_i64'

  genTimes: (node) -> 'i64.mul'

  genDividedBy: (node) -> 'i64.div'

  genPlus: (node) -> 'i64.add'

  genMinus: (node) -> 'i64.sub'

  genNeg: (node) -> 'i64.sub (i64.const 0)'

module.exports = CodeGen
