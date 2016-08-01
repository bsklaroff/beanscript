builtin = require('./builtin')
Symbol = require('./symbol')
Scope = require('./scope')

class ASTNode
  #TODO: unhardcode this, and give them types
  @NUM_TEMPS = 0

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

  # Generate a wast that lists all local variables of a scope
  @genLocals: (scope) ->
    wast = ''
    for name, symbol of scope.locals
      for [wastVar, type] in symbol.wastVars()
        wast += "(local #{wastVar} #{type})\n"
    for i in [0...ASTNode.NUM_TEMPS]
      wast += "(local $$t#{i} i32)\n"
    return wast

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
      niceType = type[1...-1]
      # For ALLCAPS node names, only uppercase the first letter
      if niceType == niceType.toUpperCase()
        niceType = "#{niceType[0]}#{niceType[1..].toLowerCase()}"
      fnName = "is#{niceType}"
      if type == @name
        @[fnName] = -> true
      else
        @[fnName] = -> false
    return

  isNestedVariable: -> @isVariable() and not @children.prop.isEmpty()
  isComparisonOp: -> @isOpExpression() and @children.op.name in ASTNode.COMPARISON_OPS

  traverseChildren: (traverseFn) ->
    fnDefs = []
    for name, child of @children
      if child.length > 0
        for subchild in child
          traverseFn(subchild)
      else
        traverseFn(child)
    return

  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    return

  genWast: -> ''

  genFunctionDefWast: ->
    wast = ''
    @traverseChildren((child) => wast += child.genFunctionDefWast(@scope))
    return wast


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

    wast = '(module\n'
    wast += '  (memory 0)\n'
    wast += '  (import $print_i32 "stdio" "print" (param i32))\n'
    wast += '  (import $print_i64 "stdio" "print" (param i64))\n'
    # Generate main function
    wast += '  (func\n'
    localsWast = ASTNode.genLocals(@scope)
    if localsWast.length > 0
      wast += ASTNode.addIndent(localsWast, 2)
    for statement in @children.statements
      wast += ASTNode.addIndent(statement.genWast(), 2)
    wast += '  )\n'
    # Generate user-defined functions
    wast += ASTNode.addIndent(@genFunctionDefWast())
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
  genWast: ->
    wast = @children.returnVal.genWast()
    wast += "(return (get_local #{@children.returnVal.symbol.name}))\n"
    return wast


class WhileNode extends ASTNode
  genWast: ->
    wast = @children.condition.genWast()
    wast += "(loop $done $loop\n"
    wast += "  (if (get_local #{@children.condition.symbol.name})\n"
    wast += "    (then\n"
    for statement in @children.body
      wast += ASTNode.addIndent(statement.genWast(), 3)
    wast += ASTNode.addIndent(@children.condition.genWast(), 3)
    wast += '      (br $loop)\n'
    wast += '    )\n'
    wast += '    (else (br $done))\n'
    wast += '  )\n'
    wast += ')\n'
    return wast


class AssignmentNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    # If this is a function assignment, make the target variable's symbol point
    # to the original function definition's symbol
    @children.target.symbol.unifyType(@children.source.symbol)
    if @children.source.symbol.type == Symbol.TYPES.FN
      @children.target.symbol.fnSymbol = @children.source.symbol
      return
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
    @traverseChildren((child) => child.genSymbols(@scope))
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
    @traverseChildren((child) => child.genSymbols(@scope))
    opExprSymbol = @children.opExpr.symbol
    @symbol = @scope.addAnonSymbol(@name, opExprSymbol.shortName)
    # Unify parenGroup type with inner opExpr
    @symbol.unifyType(opExprSymbol)
    return

  genWast: -> 'unimplemented'


class FunctionCallNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
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
    # First, make sure any expressions inside the args have been evaluated
    args = []
    for arg in @children.argList
      wast += arg.genWast()
      args.push(arg.symbol)
    fnNameSymbol = @children.fnName.symbol
    # Generate function call comment
    wast += ";;#{fnNameSymbol.name}("
    for arg in args
      wast += "#{arg.name}, "
    wast = "#{wast[...-2]})\n"
    # If function is builtin, inline it
    if fnNameSymbol.name of builtin.FN_CALL_MAP
      wast += builtin.fns[builtin.FN_CALL_MAP[fnNameSymbol.name]](@symbol, args)
      return wast
    # Otherwise, call user-defined function with arguments
    wast += "(set_local #{@symbol.name} (call #{fnNameSymbol.fnSymbol.name}"
    for arg in args
      wast += " (get_local #{arg.name})"
    wast += '))\n'
    return wast


class FunctionDefNode extends ASTNode
  genSymbols: (@scope) ->
    @symbol = @scope.addAnonSymbol(@name, '')
    @symbol.setType(Symbol.TYPES.FN)
    @fnScope = Scope.genFnScope(@symbol.name, @scope)
    @symbol.setChildScopeName(@fnScope.name)
    @traverseChildren((child) => child.genSymbols(@fnScope))
    @fnScope.addArgs(@symbol, @children.args)
    for statement in @children.body
      if statement.isReturn()
        @symbol.unifyReturnType(statement.children.returnVal.symbol)
    return

  genFunctionDefWast: ->
    wast = "(func #{@symbol.name}"
    for arg in @children.args
      wast += " (param #{arg.symbol.name} #{arg.symbol.type})"
    wast += " (result #{@symbol.returnSymbol.type})\n"
    localsWast = ASTNode.genLocals(@fnScope)
    if localsWast.length > 0
      wast += ASTNode.addIndent(localsWast)
    for statement in @children.body
      wast += ASTNode.addIndent(statement.genWast())
    wast += ')\n'
    @traverseChildren((child) => wast += child.genFunctionDefWast(@scope))
    return wast


class FunctionDefArgNode extends ASTNode
  genSymbols: (@scope) ->
    @symbol = @scope.addNamedSymbol(@children.id.literal)
    @symbol.setType(@children.type.literal)
    return


class NumberNode extends ASTNode
  genSymbols: (@scope) ->
    @symbol = @scope.addAnonSymbol(@name, @literal)
    return

  genWast: ->
    if @symbol.type == Symbol.TYPES.I32
      return "(set_local #{@symbol.name} (i32.const #{@literal}))\n"
    else if @symbol.type == Symbol.TYPES.I64
      return "(set_local #{@symbol.name} (i64.const #{@literal}))\n"
    throw new Error("Number constant does not exist for type #{@symbol.type}")
    return


TYPES =
  _Program_: ProgramNode
  _Return_: ReturnNode
  _While_: WhileNode
  _Assignment_: AssignmentNode
  _TypedVariable_: TypedVariableNode
  _Variable_: VariableNode
  _OpExpression_: OpExpressionNode
  _OpParenGroup_: OpParenGroupNode
  _FunctionCall_: FunctionCallNode
  _FunctionDef_: FunctionDefNode
  _FunctionDefArg_: FunctionDefArgNode
  _NUMBER_: NumberNode
  _EMPTY_: ASTNode

module.exports = ASTNode
