ASTNode = require('../ast_node')

amendTypeclasses = (rootNode) ->
  # All typeclasses and typeinsts must be defined in global scope
  for astNode in rootNode.children.statements
    # If astNode is a typeclass, add typeclass context to all typedefs
    if astNode.isTypeclassDef()
      typeclass = astNode.children.typeclass
      className = typeclass.children.class.literal
      anonType = typeclass.children.anonType.literal
      for typeDefNode in astNode.children.body
        # Add context to node
        newTypeclassNode = ASTNode.make('_Typeclass_')
        newTypeclassNode.children.class = ASTNode.make('_ID_', className)
        newTypeclassNode.children.anonType = ASTNode.make('_ID_', anonType)
        context = typeDefNode.children.type.children.context
        context.push(newTypeclassNode)

  return rootNode

module.exports = amendTypeclasses
