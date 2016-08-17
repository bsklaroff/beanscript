builtin = require('./builtin')
Symbol = require('./symbol')
Scope = require('./scope')
Type = require('./type')

SHOW_COMMENTS = false

class ASTNode
  #TODO: unhardcode this, and give them types
  @NUM_TEMPS = 2

  @COMPARISON_OPS = [
    '_EQUALS_EQUALS_'
    '_NOT_EQUALS_'
    '_LTE_'
    '_LT_'
    '_GTE_'
    '_GT_'
  ]

  @make: (name, literal) ->
    if name of NODE_TYPES
      return new NODE_TYPES[name](name, literal)
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
      if symbol.name not in scope.argNames
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

  # 1. $$t0 = *global_mem[0]
  # 2. name = $$t0
  # 3. *global_mem[0] += len
  @malloc: (name, len) ->
    wast = "(set_local $$t0 (i32.load (i32.const 0)))\n"
    wast += "(set_local #{name} (get_local $$t0))\n"
    wast += "(i32.store (i32.const 0) (i32.add (get_local $$t0) (i32.const #{len})))\n"
    return wast

  constructor: (@name, @literal = null) ->
    @children = if @literal? then null else {}
    @scope = null
    @symbol = null
    # Generate 'isNodeType' functions
    for type of NODE_TYPES
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

  isNestedVariable: -> @isVariable() and @children.props.length > 0
  isComparisonOp: -> @isOpExpression() and @children.op.name in ASTNode.COMPARISON_OPS

  traverseChildren: (traverseFn) ->
    fnDefs = []
    for name, child of @children
      if Object.prototype.toString.call(child) == '[object Array]'
        for subchild in child
          traverseFn(subchild)
      else
        traverseFn(child)
    return

  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    return

  genFunctionDefSymbols: (@scope) ->
    @traverseChildren((child) => child.genFunctionDefSymbols(@scope))
    return

  genWast: -> ''

  genFunctionDefWast: ->
    wast = ''
    @traverseChildren((child) => wast += child.genFunctionDefWast(@scope))
    return wast


class ProgramNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    @traverseChildren((child) => child.genFunctionDefSymbols(@scope))
    return

  genWast: ->
    ###
    #console.log(JSON.stringify(node, null, 2))
    seen = []
    console.log(JSON.stringify(@scope, (a, value) ->
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
    wast += '  (memory 10000)\n'
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
    wast += '  (export "main" 0)\n'
    wast += ')\n'
    return wast


class ReturnNode extends ASTNode
  genWast: ->
    wast = @children.returnVal.genWast()
    wast += "(return (get_local #{@children.returnVal.symbol.name}))\n"
    return wast


class IfNode extends ASTNode
  genWast: ->
    wast = @children.condition.genWast()
    wast += "(if #{@children.condition.symbol.ref}\n"
    wast += '  (then\n'
    for statement in @children.body
      wast += ASTNode.addIndent(statement.genWast(), 2)
    wast += '  )\n'
    if not @children.else.isEmpty()
      wast += '  (else\n'
      wast += ASTNode.addIndent(@children.else.genWast(), 2)
      wast += '  )\n'
    wast += ')\n'
    return wast


class ElseNode extends ASTNode
  genWast: ->
    wast = ''
    for statement in @children.body
      wast += statement.genWast()
    return wast


class WhileNode extends ASTNode
  genWast: ->
    wast = @children.condition.genWast()
    wast += "(loop $done $loop\n"
    wast += "  (if #{@children.condition.symbol.ref}\n"
    wast += '    (then\n'
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
    # If source is a FunctionDef, it will not yet be defined
    if @children.source.symbol?
      @children.target.symbol.unifyType(@children.source.symbol)
    return

  genFunctionDefSymbols: (@scope) ->
    @traverseChildren((child) => child.genFunctionDefSymbols(@scope))
    @children.target.symbol.unifyType(@children.source.symbol)
    if @children.source.symbol.type?.isFn()
      @children.target.symbol.fnSymbol = @children.source.symbol
    return

  genWast: ->
    wast = @children.source.genWast()
    wast += @children.target.genWast()
    wast += builtin.fns.assign(@children.target.symbol, @children.source.symbol)
    return wast


class MaybeTypedVarNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    @symbol = @children.var.symbol
    # Set variable type if it exists
    if not @children.type.isEmpty()
      @symbol.setType(Type.fromTypeNode(@children.type))
    return

  genWast: -> @children.var.genWast()


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
      @symbol.setType(new Type(Type.PRIMITIVES.BOOL))
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

  genWast: ->
    wast = @children.opExpr.genWast()
    wast += "(set_local #{@symbol.name} (get_local #{@children.opExpr.symbol.name}))\n"
    return wast


class FunctionCallNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    fnSymbol = @children.fnName.symbol
    @symbol = @scope.addAnonSymbol(@name, fnSymbol.shortName)
    args = []
    for arg in @children.args
      args.push(arg.symbol)
    fnSymbol.setType(new Type(Type.PRIMITIVES.FN))
    fnSymbol.unifyReturnType(@symbol)
    fnSymbol.unifyArgTypes(args)
    return

  genWast: ->
    wast = ''
    # First, make sure any expressions inside the args have been evaluated
    args = []
    for arg in @children.args
      wast += arg.genWast()
      args.push(arg.symbol)
    fnNameSymbol = @children.fnName.symbol
    # Generate function call comment
    if SHOW_COMMENTS
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
      wast += " #{arg.ref}"
    wast += '))\n'
    return wast


class ArrayNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    @symbol = @scope.addAnonSymbol(@name, '')
    return

  genWast: ->
    elemLength = if @symbol.type.elemType.isI64() then 8 else 4
    wast = ASTNode.malloc(@symbol.name, Symbol.ARRAY_OFFSET * 4 + Symbol.ARRAY_LENGTH * elemLength)
    # First array offset item is allocated length
    wast += "(i32.store #{@symbol.ref} (i32.const #{Symbol.ARRAY_LENGTH}))\n"
    # Second array offset item is user-facing array length
    wast += "(i32.store (i32.add #{@symbol.ref} (i32.const 4)) (i32.const 0))\n"
    return wast


class VariableNode extends ASTNode
  genSymbols: (@scope) ->
    @traverseChildren((child) => child.genSymbols(@scope))
    varName = @children.id.literal
    @symbol = null
    if @isNestedVariable()
      parentSymbol = @scope.getVarSymbol(varName)
      if not parentSymbol?
        throw new Error("No parent symbol found with name: #{nodeName}")
      propSymbols = []
      for prop in @children.props
        prop.symbol.setType(new Type(Type.PRIMITIVES.I32))
        propSymbols.push(prop.symbol)
      @symbol = parentSymbol.getSubsymbol(propSymbols)
      if not @symbol?
        @symbol = @scope.addSubsymbol(@name, parentSymbol, propSymbols)
    else
      # This only works if we prevent starting a variable name with a number
      @symbol = @scope.getVarSymbol(varName)
      if not @symbol?
        @symbol = @scope.addNamedSymbol(varName)
    return

  genWast: ->
    wast = ''
    if @isNestedVariable()
      for prop in @children.props
        wast += prop.genWast()
    return wast


class FunctionDefNode extends ASTNode
  genFunctionDefSymbols: (@scope) ->
    @symbol = @scope.addAnonSymbol(@name, '')
    @symbol.setType(new Type(Type.PRIMITIVES.FN))
    @fnScope = Scope.genFnScope(@symbol.name, @scope)
    @symbol.setChildScopeName(@fnScope.name)
    @traverseChildren((child) => child.genSymbols(@fnScope))
    @traverseChildren((child) => child.genFunctionDefSymbols(@fnScope))
    @fnScope.addArgs(@symbol, @children.args)
    for statement in @children.body
      if statement.isReturn()
        @symbol.unifyReturnType(statement.children.returnVal.symbol)
    return

  genFunctionDefWast: ->
    wast = "(func #{@symbol.name}"
    for arg in @children.args
      argType = if arg.symbol.type.isArr() then 'i32' else arg.symbol.type.primitive
      wast += " (param #{arg.symbol.name} #{argType})"
    returnType = if @symbol.returnSymbol.type.isArr() then 'i32' else @symbol.returnSymbol.type.primitive
    wast += " (result #{returnType})\n"
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
    if not @children.type.isEmpty()
      @symbol.setType(Type.fromTypeNode(@children.type))
    return


class MaybeTypedIdNode extends ASTNode
  genSymbols: (@scope) ->
    varName = @children.id.literal
    # This only works if we prevent starting a variable name with a number
    @symbol = @scope.getVarSymbol(varName)
    if not @symbol?
      @symbol = @scope.addNamedSymbol(varName)
    # Set variable type if it exists
    if not @children.type.isEmpty()
      @symbol.setType(Type.fromTypeNode(@children.type))
    return


class NumberNode extends ASTNode
  genSymbols: (@scope) ->
    @symbol = @scope.addAnonSymbol(@name, @literal)
    return

  genWast: ->
    if @symbol.type.isI32()
      return "(set_local #{@symbol.name} (i32.const #{@literal}))\n"
    else if @symbol.type.isI64()
      return "(set_local #{@symbol.name} (i64.const #{@literal}))\n"
    throw new Error("Number constant does not exist for type #{@symbol.type}")
    return


NODE_TYPES =
  _Program_: ProgramNode
  _Return_: ReturnNode
  _If_: IfNode
  _Else_: ElseNode
  _While_: WhileNode
  _Assignment_: AssignmentNode
  _MaybeTypedVar_: MaybeTypedVarNode
  _Type_: ASTNode
  _Variable_: VariableNode
  _OpExpression_: OpExpressionNode
  _OpParenGroup_: OpParenGroupNode
  _FunctionCall_: FunctionCallNode
  _Array_: ArrayNode
  _FunctionDef_: FunctionDefNode
  _FunctionDefArg_: FunctionDefArgNode
  _MaybeTypedId_: MaybeTypedIdNode
  _NUMBER_: NumberNode
  _EMPTY_: ASTNode

module.exports = ASTNode
