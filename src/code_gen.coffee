ASTNode = require('./ast_node')
SymbolTable = require('./symbol_table')
Symbol = require('./symbol')
builtin = require('./builtin')

class CodeGen
  @WAST_GEN_FNS:
    _Program_: 'genProgram'
    _While_: 'genWhile'
    _FunctionAssignment_: 'genFunctionAssignment'
    _Assignment_: 'genAssignment'
    _FunctionCall_: 'genFunctionCall'
    _OpExpression_: 'genOpExpression'
    _OpParenGroup_: 'genOpParenGroup'
    _FunctionDef_: 'genFunctionDef'
    _TypedId_: 'genTypedId'
    _Return_: 'genReturn'
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
    @scope = @symbolTable.scopes.global
    return

  _addIndent: (wast, n = 1) ->
    wastSplit = wast.split('\n')
    # Don't indent the trailing newline
    for i in [0...wastSplit.length - 1]
      for j in [0...n]
        wastSplit[i] = "  #{wastSplit[i]}"
    return wastSplit.join('\n')

  _genLocals: (scope, numTemps) ->
    wast = ''
    for name, symbol of scope.locals
      for wastVar in symbol.wastVars()
        wast += "(local #{wastVar} i32)\n"
    for i in [0...numTemps]
      wast += "(local $$t#{i} i32)\n"
    return wast

  genWast: (node) ->
    if node.name not of CodeGen.WAST_GEN_FNS
      return ''
    return @[CodeGen.WAST_GEN_FNS[node.name]](node)

  genProgram: (node) ->
    @symbolTable.genNodeSymbols(node)

    ###
    #console.log(JSON.stringify(node, null, 2))
    seen = []
    console.log(JSON.stringify(@symbolTable, (a, value) ->
      if typeof value == 'object'
        if not value?
          return null
        if seen.indexOf(value) != -1
          return value.name
        else
          seen.push(value)
      return value
    , 2))
    ###

    mainWast = ''
    fnsWast = ''
    for statement in node.children.statements
      if ASTNode.isFunctionAssignment(statement)
        fnsWast += @_addIndent(@genWast(statement))
      else
        mainWast += @_addIndent(@genWast(statement), 2)

    wast = '(module\n'
    wast += '  (import $print_i32 "stdio" "print" (param i32))\n'
    wast += '  (func\n'
    localsWast = @_genLocals(@scope, 3)
    if localsWast.length > 0
      wast += @_addIndent(localsWast, 2)
    wast += mainWast
    wast += '  )\n'
    wast += fnsWast
    ###
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
    ###
    wast += '  (export "main" 0)\n'
    wast += ')\n'
    return wast

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
    wast = @genWast(node.children.source)
    targetSymbol = @scope.getSymbol(node.children.target.symbolName)
    sourceSymbol = @scope.getSymbol(node.children.source.symbolName)
    wast += builtin.fns.assign(targetSymbol, sourceSymbol)
    return wast

  genFunctionCall: (node) ->
    wast = ''
    args = []
    for arg in node.children.argList
      wast += @genWast(arg)
      args.push(@scope.getSymbol(arg.symbolName))
    fnNameSymbol = @scope.getSymbol(node.children.fnName.symbolName)
    resSymbol = @scope.getSymbol(node.symbolName)
    if fnNameSymbol.name of builtin.FN_CALL_MAP
      wast += builtin.fns[builtin.FN_CALL_MAP[fnNameSymbol.name]](resSymbol, args)
      return wast
    return 'unimplemented'

  genOpExpression: (node) ->
    wast = @genWast(node.children.lhs)
    wast += @genWast(node.children.rhs)
    fnName = builtin.OP_MAP[node.children.op.name]
    resSymbol = @scope.getSymbol(node.symbolName)
    lhsSymbol = @scope.getSymbol(node.children.lhs.symbolName)
    rhsSymbol = @scope.getSymbol(node.children.rhs.symbolName)
    if lhsSymbol?
      wast += builtin.fns[fnName](resSymbol, lhsSymbol, rhsSymbol)
      return wast
    wast += builtin.fns[fnName](resSymbol, rhsSymbol)
    return wast

  genOpParenGroup: (node) -> @genWast(node.children.opExpr)

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

  genNumber: (node) ->
    symbol = @scope.getSymbol(node.symbolName)
    if symbol.type == Symbol.TYPES.I32
      return "(set_local #{symbol.name} (i32.const #{node.literal}))\n"
    else if symbol.type == Symbol.TYPES.I64
      wast = "(set_local #{symbol.lowWord} (i32.const #{node.literal}))\n"
      wast += "(set_local #{symbol.highWord} (i32.const 0))\n"
      return wast
    throw new Error("Number constant does not exist for type #{symbol.type}")
    return

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
