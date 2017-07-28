genTypeInfo = (rootNode) ->
  typeInfo =
    dataTypes:
      bool: []
      i32: []
      i64: []
      void: []
    fnTypes: {}
    typeclasses: {}
  # Make sure all dataTypes are listed before this call
  genTypeclasses(rootNode, typeInfo)
  genTypeInsts(rootNode, typeInfo)
  return typeInfo

genTypeclasses = (astNode, typeInfo) ->
  if astNode.length?
    for child in astNode
      genTypeclasses(child, typeInfo)
    return
  if not astNode.isTypeclassDef()
    for name, child of astNode.children
      genTypeclasses(child, typeInfo)
    return
  # If astNode is a _TypeclassDef_ node, process it
  typeclass = astNode.children.typeclass
  className = typeclass.children.class.literal
  anonType = typeclass.children.type.literal
  defaultType = null
  if not astNode.children.default.isEmpty()
    defaultType = astNode.children.default.children.primitive.literal
  reqs = parseTypeclassReqs(astNode.children.supertypes, anonType)
  if typeInfo.typeclasses[className]?
    console.log("ERROR: multiple definitions for typeclass #{className}")
    process.exit(1)
  typeInfo.typeclasses[className] =
    reqs: reqs
    fns: []
    default: defaultType
  parseFnTypeDefs(astNode.children.body, className, anonType, typeInfo)
  return

parseTypeclassReqs = (supertypes, anonType) ->
  reqs = []
  for typeclass in supertypes
    req = typeclass.children.class.literal
    reqAnon = typeclass.children.type.literal
    if reqAnon != anonType
      console.log("ERROR: typeclass req (#{req} #{reqAnon}) should have anonType #{anonType}")
      process.exit(1)
    if req in reqs
      console.log("ERROR: typeclass req (#{req} #{reqAnon}) defined multiple times")
      process.exit(1)
    reqs.push(req)
  return reqs

parseFnTypeDefs = (typeDefs, className, anonType, typeInfo) ->
  for typeDef in typeDefs
    typeName = typeDef.children.name.literal
    type = typeDef.children.type
    if typeInfo.fnTypes[typeName]
      console.log("ERROR: type #{typeName} required multiple times in typeclass defs")
      process.exit(1)
    typeInfo.typeclasses[className].fns.push(typeName)

    fnType = []
    for nonFnType in type.children.nonFnTypes
      fnType.push(nonFnType.children.primitive.literal)

    anonTypes = {}
    for argtype in fnType
      if argtype not of typeInfo.dataTypes
        anonTypes[argtype] = []
    if anonType not of anonTypes
      console.log("ERROR: fn type #{fnType} does not contain #{anonType}")
      process.exit(1)
    anonTypes[anonType].push(className)

    for anonConstraint in type.children.anonConstraints
      req = anonConstraint.children.class.literal
      reqAnon = anonConstraint.children.type.literal
      if not anonTypes[reqAnon]?
        console.log("ERROR: typeclass req (#{req} #{reqAnon}) matches no part of fn type #{fnType}")
        process.exit(1)
      if req in anonTypes[reqAnon]
        console.log("ERROR: typeclass req (#{req} #{reqAnon}) defined multiple times")
        process.exit(1)
      anonTypes[reqAnon].push(req)

    typeInfo.fnTypes[typeName] =
      fnType: fnType
      anonTypes: anonTypes

  return

genTypeInsts = (astNode, typeInfo) ->
  if astNode.length?
    for child in astNode
      genTypeInsts(child, typeInfo)
    return
  if not astNode.isTypeInst()
    for name, child of astNode.children
      genTypeInsts(child, typeInfo)
    return
  # If astNode is a _TypeInst_ node, process it
  inst = astNode.children.inst
  className = inst.children.class.literal
  typeName = inst.children.type.literal
  if typeName not of typeInfo.dataTypes
    console.log("ERROR: datatype #{typeName} not found")
    process.exit(1)
  if className not of typeInfo.typeclasses
    console.log("ERROR: no typeclass def found for #{className}")
    process.exit(1)
  if className in typeInfo.dataTypes[typeName]
    console.log("ERROR: multiple type instances found for (#{className} #{typeInfo})")
    process.exit(1)
  typeInfo.dataTypes[typeName].push(className)
  return

module.exports = genTypeInfo
