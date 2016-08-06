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
    isArray = not node.children.length.isEmpty()
    length = if isArray then parseInt(node.children.length.literal) else null
    return new Type(primitive, length)

  constructor: (@primitive, @length = null) ->
    @elemType = null
    # Check if this is an array
    if @length?
      @elemType = @primitive
      @primitive = Type.PRIMITIVES.ARR
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
    return @primitive == otherType.primitive and
           @elemType == otherType.elemType and
           @length == otherType.length

module.exports = Type
