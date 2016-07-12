ASTNode = require('./ast_node')
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
    _TypedId_: 'genTypedId'
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
    @scope = @symbolTable.globalScope
    return

  _addIndent: (wast, n = 1) ->
    wastSplit = wast.split('\n')
    for i in [0...wastSplit.length]
      for j in [0...n]
        wastSplit[i] = "  #{wastSplit[i]}"
    return wastSplit.join('\n')

  genWast: (node) ->
    #console.log(node)
    return @[CodeGen.WAST_GEN_FNS[node.name]](node)

  genProgram: (node) ->
    @symbolTable.genNodeSymbols(node)
    #console.log(JSON.stringify(node, null, 2))
    seen = []
    console.log(JSON.stringify(@symbolTable, (a, value) ->
      if typeof value == 'object'
        if seen.indexOf(value) != -1
          return value?.name
        else
          seen.push(value)
      return value
    , 2))
    ###
    mainWast = ''
    fnsWast = ''
    for statement in node.children.statements
      if ASTNode.isFunctionAssignment(statement)
        next = @_addIndent(@genWast(statement))
        fnsWast += "#{next}\n"
      else
        next = @_addIndent(@genWast(statement), 2)
        mainWast += "#{next}\n"

    wast = '(module\n'
    wast += '  (import $print_i64 "stdio" "print" (param i64))\n'
    wast += '  (func\n'
    for varName of @scope.locals
      wast += "    (local $#{varName} i32)\n"
    wast += mainWast
    wast += '  )\n'
    wast += fnsWast
    wast += '  (func $exp_i64 (param $base i64) (param $exp i64) (result i64)\n'
    wast += '    (local $res i64)\n'
    wast += '    (set_local $res (i64.const 1))\n'
    wast += '    (loop $done $loop\n'
    wast += '      (br_if $done (i64.eq (get_local $exp) (i64.const 0)))\n'
    wast += '      (set_local $res (i64.mul (get_local $res) (get_local $base)))\n'
    wast += '      (set_local $exp (i64.sub (get_local $exp) (i64.const 1)))\n'
    wast += '      (br $loop)\n'
    wast += '    )\n'
    wast += '    (return (get_local $res))\n'
    wast += '  )\n'
    wast += '  (export "main" 0)\n'
    wast += ')\n'
    return wast
    ###

  genWhile: (node) ->
    wast = "(loop $done $loop\n"
    wast += "  (if #{@genWast(node.children.condition)}\n"
    wast += "    (then\n"
    for statement in node.children.body
      next = @_addIndent(@genWast(statement), 3)
      wast += "#{next}\n"
    wast += '      (br $loop)\n'
    wast += '    )\n'
    wast += '    (else (br $done))\n'
    wast += '  )\n'
    wast += ')'
    return wast

  genFunctionAssignment: (node) ->
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
    idWast = @genWast(node.children.id)
    return "(get_local #{idWast})"

  genTypedId: (node) ->
    idWast = @genWast(node.children.id)
    return "(get_local #{idWast})"

  genFunctionDef: (node) ->
    wast = ''
    argLiterals = {}
    for arg in node.children.args
      wast += " (param #{@genWast(arg)} i64)"
      argLiterals[arg.literal] = 1
    wast += ' (result i64)\n'
    ###
    for varName in CodeGen.findLocalVars(node.children.body, argLiterals)
      wast += "    (local $#{varName} i64)\n"
    ###
    for statement in node.children.body
      next = @_addIndent(@genWast(statement))
      wast += "#{next}\n"
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
