utils = require('./utils')

class Type
  @FORM:
    PRIMITIVE: 'primitive'
    CONSTRUCTED: 'constructed'
    OBJECT: 'object'
    FUNCTION: 'function'

  constructor: (@form, @data, @context = {}) ->
    if @form not in utils.values(Type.FORM)
      console.log("ERROR: unknown type form #{@form}")
      process.exit(1)
    if @form == Type.FORM.PRIMITIVE and not @data.typeName?
      console.log("ERROR: primitive type requires valid data.typeName")
      process.exit(1)
    if @form == Type.FORM.FUNCTION and not Array.isArray(@data.typeArr)
      console.log("ERROR: function type requires valid data.typeArr")
      process.exit(1)
    return

  toString: ->
    str = ''
    if @form == Type.FORM.PRIMITIVE
      str += 'P_'
      str += @data.typeName
      if utils.keys(@context).length > 0
        str += '|'
        str += JSON.stringify(@context)
    else if @form == Type.FORM.FUNCTION
      str += 'F_'
      for type in @data.typeArr
        if type.form == Type.FORM.FUNCTION
          str += "(#{type.toString})"
        else
          str += type.toString
    return str

  @makePrimitive: (typeName = null, context = {}) ->
    return new Type(Type.FORM.PRIMITIVE, {typeName}, context)

  @fromTypeWithContext: (typeWithContextNode) ->
    typeNode = typeWithContextNode.children.type
    contextNodes = typeWithContextNode.children.context
    return Type.parseTypeAndContext(typeNode, contextNodes)

  @parseTypeAndContext: (typeNode, contextNodes) ->
    context = Type.parseContext(contextNodes)
    typeArr = typeNode.children.typeArr
    # Check for primitive type
    if typeArr.length == 1
      data =
        typeName: typeArr[0].children.primitive.literal
        params: Type.parseParams(typeArr[0].children.params)
      return new Type(Type.FORM.PRIMITIVE, data, context)
    # Check for fn type with no arguments
    if typeArr[0].isEmpty()
      typeArr = typeArr[1..]
    # Parse fn type
    argTypes = []
    for argTypeNode in typeArr
      argTypes.push(Type.parseTypeAndContext(argTypeNode, []))
    return new Type(Type.FORM.FUNCTION, {typeArr: argTypes}, context)

  @parseContext: (contextNodes) ->
    context = {}
    for typeclassNode in contextNodes
      anonType = typeclassNode.children.anonType.literal
      typeclass = typeclassNode.children.class.literal
      context[anonType] ?= []
      context[anonType].push(typeclass)
    return context

  @parseParams: (paramNodes) ->
    params = []
    for paramNode in paramNodes
      params.push(Type.parseTypeAndContext(paramNode, []))
    return params

  # TODO: everything
  @mergeTypes: (t0, t1) ->
    if not t0? or not t1?
      return t0 ? t1
    if t0.form != t1.form
      console.log('ERROR: cannot merge two types of different forms')
      process.exit(1)
    if t0.form == Type.FORM.PRIMITIVE
      return Type.mergePrimitiveTypes(t0, t1)
    return
  ###
      if Type.isSubTypeclass(
        console.log("ERROR: cannot merge types #{t0}, #{t1}")
        process.exit(1)
      if t0.data.primitive? or t1.data.primitive?
        newType.data.primitive = t0.data.primitive ? t1.data.primitive
      else
        for constraint of t0.constraints[t0.data.name]
          newType.constraints[constraint] = true
        for constraint of t1.constraints[t1.data.name]
          Type._handleNewConstraint(t0, constraint)
          newType.constraints[constraint] = true
  ###

  @mergePrimitiveTypes: (t0, t1) ->
    newType = utils.cloneDeep(t0)

  @addTypeConstraint: (t0, t1) ->
    for constraint of symbol.typeConstraints
      # If an existing constraint is more specific than the new constraint,
      # it's already covered
      if @_isSubConstraint(constraint, newConstraint)
        return
      # If the new constraint is more specific than an existing constraint,
      # replace the existing
      else if @_isSubConstraint(newConstraint, constraint)
        delete symbol.typeConstraints[constraint]
        symbol.typeConstraints[newConstraint] = true
        return
      # Otherwise, if either constraint is a literal type, throw an error
      # because it is incompatible
      else if @_isConcreteType(constraint) or @_isConcreteType(newConstraint)
        console.log("ERROR: Incompatible type constraints #{constraint}, " +
                    "#{newConstraint} for symbol:\n" +
                    "#{JSON.stringify(symbol, null, 2)}")
        process.exit(1)
    # If we found no conflicting or redundant constraints, simply add the new one
    symbol.typeConstraints[newConstraint] = true
    return

module.exports = Type
