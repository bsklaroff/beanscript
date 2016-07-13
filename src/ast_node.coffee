builtin = require('./builtin')
Symbol = require('./symbol')
Scope = require('./scope')

class ASTNode
  #TODO: unhardcode this
  @NUM_TEMPS = 3

  @COMPARISON_OPS = [
    '_EQUALS_EQUALS_'
    '_NOT_EQUALS_'
    '_LTE_'
    '_LT_'
    '_GTE_'
    '_GT_'
  ]

  @make: (name, literal) ->
    if name of TYPES
      return new TYPES[name](name, literal)
    return new ASTNode(name, literal)

  # List all scopes with their symbols (for debugging)
  @getScopes: (node) ->
    scopes = [node.scope]
    getScopesFn = (child) ->
      if child.scope not in scopes
        scopes.push(child.scope)
      child.traverseChildren(getScopesFn)
      return
    node.traverseChildren(getScopesFn)
    return scopes

  @addIndent: (wast, n = 1) ->
    wastSplit = wast.split('\n')
    # Don't indent the trailing newline
    for i in [0...wastSplit.length - 1]
      for j in [0...n]
        wastSplit[i] = "  #{wastSplit[i]}"
    return wastSplit.join('\n')

  constructor: (@name, @literal = null) ->
    @children = null
    @scope = null
    @symbol = null
    # Generate 'isNodeType' functions
    for type of TYPES
      # Strip underscores
      type = type[1...-1]
      # For ALLCAPS node names, only uppercase the first letter
      if type == type.toUpperCase()
        type = "#{type[0]}#{type[1..].toLowerCase()}"
      fnName = "is#{type}"
      if type == @name
        @[fnName] = -> true
      else
        @[fnName] = -> false
    return

  isNestedVariable: -> @isVariable() and not @children.prop.isEmpty()
  isComparisonOp: -> @isOpExpression() and @children.op.name in ASTNode.COMPARISON_OPS

  # For generating the symbol table, we want to traverse function assignments
  # last so that the entire outer scope is defined before any inner scopes
  traverseChildren: (traverseFn, fnAssignmentsLast = false) ->
    fnAssignments = []
    for name, child of @children
      if child.length > 0
        for subchild in child
          if fnAssignmentsLast and subchild.isFunctionAssignment()
            fnAssignments.push(subchild)
          else
            traverseFn(subchild)
      else if fnAssignmentsLast and child.isFunctionAssignment()
        fnAssignments.push(child)
      else
        traverseFn(child)
    for fnAssignment in fnAssignments
      traverseFn(fnAssignment)
    return

  _genLocals: ->
    wast = ''
    for name, symbol of @scope.locals
      for wastVar in symbol.wastVars()
        wast += "(local #{wastVar} i32)\n"
    for i in [0...ASTNode.NUM_TEMPS]
      wast += "(local $$t#{i} i32)\n"
    return wast

  genSymbols: (@scope) ->
    @traverseChildren(((child) => child.genSymbols(@scope)), true)
    return

  genWast: -> ''


class ProgramNode extends ASTNode
  genWast: ->
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
    for statement in @children.statements
      if statement.isFunctionAssignment()
        fnsWast += ASTNode.addIndent(statement.genWast())
      else
        mainWast += ASTNode.addIndent(statement.genWast(), 2)

    wast = '(module\n'
    wast += '  (import $print_i32 "stdio" "print" (param i32))\n'
    wast += '  (func\n'
    localsWast = @_genLocals()
    if localsWast.length > 0
      wast += ASTNode.addIndent(localsWast, 2)
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


class ReturnNode extends ASTNode
  genWast: -> 'unimplemented'


class WhileNode extends ASTNode
  genWast: ->
    wast = "(loop $done $loop\n"
    wast += "  (if #{@children.condition.genWast()}\n"
    wast += "    (then\n"
    for statement in @children.body
      next = ASTNode.addIndent(statement.genWast(), 3)
      wast += "#{next}\n"
    wast += '      (br $loop)\n'
    wast += '    )\n'
    wast += '    (else (br $done))\n'
    wast += '  )\n'
    wast += ')'
    return 'unimplemented'


class FunctionAssignmentNode extends ASTNode
  genSymbols: (@scope) ->
    targetVarName = @children.target.children.var.children.id.literal
    @symbol = @scope.getVarSymbol(targetVarName)
    if not @symbol?
      @symbol = @scope.addNamedSymbol(targetVarName)
      @symbol.setType(Symbol.TYPES.FN)
    if @symbol.childScopeName?
      throw new Error("Cannot redefine function: #{target}")
    fnScope = Scope.genFnScope(@symbol.name, @scope)
    @symbol.setChildScopeName(fnScope.name)
    # Extract arg symbols from function definition into function scope
    fnDef = @children.source
    fnScope.addArgs(@symbol, fnDef.children.args)
    for statement in fnDef.children.body
      statement.genSymbols(fnScope)
      if statement.isReturn()
        @symbol.unifyReturnType(statement.children.returnVal.symbol)
    return

  genWast: -> 'unimplemented'


class AssignmentNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren(((child) => child.genSymbols(@scope)), true)
    @children.target.symbol.unifyType(@children.source.symbol)
    return

  genWast: ->
    wast = @children.source.genWast()
    wast += builtin.fns.assign(@children.target.symbol, @children.source.symbol)
    return wast


class TypedVariableNode extends ASTNode
  genSymbols: (@scope) ->
    varName = @children.var.children.id.literal
    # This only works if we prevent starting a variable name with a number
    @symbol = @scope.getVarSymbol(varName)
    if not @symbol?
      @symbol = @scope.addNamedSymbol(varName)
    # Set variable type
    type = @children.type.literal
    if type.length > 0
      @symbol.setType(type)
    return


class VariableNode extends ASTNode
  genSymbols: (@scope) ->
    if @isNestedVariable()
      #TODO
      return
    varName = @children.id.literal
    # This only works if we prevent starting a variable name with a number
    @symbol = @scope.getVarSymbol(varName)
    if not @symbol?
      @symbol = @scope.addNamedSymbol(varName)
    return


class OpExpressionNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren(((child) => child.genSymbols(@scope)), true)
    nameSuffix = ''
    if not @children.lhs.isEmpty()
      nameSuffix += "#{@children.lhs.symbol.shortName}_"
    nameSuffix += @children.rhs.symbol.shortName
    @symbol = @scope.addAnonSymbol(@name, nameSuffix)
    # Unify types of result and operands
    if not @children.lhs.isEmpty()
      @children.lhs.symbol.unifyType(@children.rhs.symbol)
    if @isComparisonOp()
      @symbol.setType(Symbol.TYPES.BOOL)
    else
      @symbol.unifyType(@children.rhs.symbol)
    return

  genWast: ->
    wast = @children.lhs.genWast()
    wast += @children.rhs.genWast()
    fnName = builtin.OP_MAP[@children.op.name]
    if @children.lhs.symbol?
      wast += builtin.fns[fnName](@symbol, @children.lhs.symbol, @children.rhs.symbol)
      return wast
    wast += builtin.fns[fnName](@symbol, @children.rhs.symbol)
    return wast


class OpParenGroupNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren(((child) => child.genSymbols(@scope)), true)
    opExprSymbol = @children.opExpr.symbol
    @symbol = @scope.addAnonSymbol(@name, opExprSymbol.shortName)
    # Unify parenGroup type with inner opExpr
    @symbol.unifyType(opExprSymbol)
    return

  genWast: -> 'unimplemented'


class FunctionCallNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren(((child) => child.genSymbols(@scope)), true)
    fnSymbol = @children.fnName.symbol
    @symbol = @scope.addAnonSymbol(@name, fnSymbol.shortName)
    args = []
    for arg in @children.argList
      args.push(arg.symbol)
    fnSymbol.setType(Symbol.TYPES.FN)
    fnSymbol.unifyReturnType(@symbol)
    fnSymbol.unifyArgTypes(args)
    return

  genWast: ->
    wast = ''
    args = []
    for arg in @children.argList
      wast += arg.genWast()
      args.push(arg.symbol)
    fnNameSymbol = @children.fnName.symbol
    if fnNameSymbol.name of builtin.FN_CALL_MAP
      wast += builtin.fns[builtin.FN_CALL_MAP[fnNameSymbol.name]](@symbol, args)
      return wast
    return 'unimplemented'


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
    return 'unimplemented'


class NumberNode extends ASTNode
  genSymbols: (@scope) ->
    @symbol = @scope.addAnonSymbol(@name, @literal)
    return

  genWast: ->
    if @symbol.type == Symbol.TYPES.I32
      return "(set_local #{@symbol.name} (i32.const #{@literal}))\n"
    else if @symbol.type == Symbol.TYPES.I64
      wast = "(set_local #{@symbol.lowWord} (i32.const #{@literal}))\n"
      wast += "(set_local #{@symbol.highWord} (i32.const 0))\n"
      return wast
    throw new Error("Number constant does not exist for type #{@symbol.type}")
    return


TYPES =
  _Program_: ProgramNode
  _Return_: ReturnNode
  _While_: WhileNode
  _FunctionAssignment_: FunctionAssignmentNode
  _Assignment_: AssignmentNode
  _TypedVariable_: TypedVariableNode
  _Variable_: VariableNode
  _OpExpression_: OpExpressionNode
  _OpParenGroup_: OpParenGroupNode
  _FunctionCall_: FunctionCallNode
  _FunctionDef_: FunctionDefNode
  _NUMBER_: NumberNode
  _EMPTY_: ASTNode

module.exports = ASTNode
