class Type
  @PRIMITIVES:
    FN: 'fn'
    OBJ: 'obj'
    ARR: 'arr'
    I64: 'i64'
    I32: 'i32'
    BOOL: 'bool'

  @fromTypeNode: (node) ->
    if not node.isType()
      throw new Error('Cannot parse type from non-TypedId node')
    primitive = node.children.primitive.literal
    subtypes = []
    for subtype in node.children.subtypes
      subtypes.push(Type.fromTypeNode(subtype))
    argSymbols = []
    for arg in node.children.args
      argSymbols.push(arg.symbol)
    return new Type(primitive, subtypes, argSymbols)

  constructor: (@primitive, @subtypes = [], @argSymbols = []) ->
    @elemType = null
    @lengthSymbol = null
    # Check if this is an array
    if @primitive == Type.PRIMITIVES.ARR
      if @subtypes.length != 1
        throw new Error('Expected arr type to have exactly one subtype')
      if @argSymbols.length != 1
        throw new Error('Expected arr type to have exactly one argument')
      @elemType = @subtypes[0]
      @lengthSymbol = @argSymbols[0]
    found = false
    for k, v of Type.PRIMITIVES
      if @primitive == v
        found = true
    if not found
      throw new Error("Invalid primitive type: #{@primitive}")
    # Set up isType functions on this object
    for k, v of Type.PRIMITIVES
      capitalV = "#{v[0].toUpperCase()}#{v[1..]}"
      if @primitive == v
        @["is#{capitalV}"] = -> true
      else
        @["is#{capitalV}"] = -> false
    return

  isEqual: (otherType) ->
    for subtype, i in @subtypes
      if not subtype.isEqual(otherType.subtypes[i])
        return false
    return @primitive == otherType.primitive and @subtypes.length == otherType.subtypes.length

module.exports = Type
