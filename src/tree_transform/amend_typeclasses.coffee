ASTNode = require('../ast_node')

amendTypeclasses = (rootNode) ->
  # All typeclasses and typeinsts must be defined in global scope
  for astNode in rootNode.children.statements
    # If astNode is a typeclass, prepend all fn names with '@' and add typeclass
    # context to all typedefs
    if astNode.isTypeclassDef()
      typeclass = astNode.children.typeclass
      className = typeclass.children.class.literal
      anonType = typeclass.children.anonType.literal
      for typeDefNode in astNode.children.body
        # Prepend '@' to fn name
        fnName = typeDefNode.children.name.literal
        if fnName[0] == '@'
          console.error("Function name inside typeclass cannot begin with '@': #{fnName}")
          process.exit(1)
        typeDefNode.children.name.literal = "@#{fnName}"
        # Add context to node
        newTypeclassNode = ASTNode.make('_Typeclass_')
        newTypeclassNode.children.class = ASTNode.make('_ID_', className)
        newTypeclassNode.children.anonType = ASTNode.make('_ID_', anonType)
        context = typeDefNode.children.type.children.context
        context.push(newTypeclassNode)
    # If astNode is a typeinst, prepend all fn names with '@'
    else if astNode.isTypeinst()
      for fnDefPropNode in astNode.children.fnDefs
        fnName = fnDefPropNode.children.fnName.literal
        fnDefPropNode.children.fnName.literal = "@#{fnName}"

  return rootNode

module.exports = amendTypeclasses
