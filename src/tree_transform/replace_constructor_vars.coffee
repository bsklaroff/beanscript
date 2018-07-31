ASTNode = require('../ast_node')

constructors = null


replaceConstructorVars = (astNode) ->
  constructors = {}
  _parseConstructors(astNode)
  astNode = _replaceConstructorVars(astNode)
  return astNode


# Pull out all constructor names as special symbols
_parseConstructors = (rootNode) ->
  for statement in rootNode.children.statements
    if statement.isType()
      for optionNode in statement.children.options
        constructor = optionNode.children.constructor.literal
        constructors[constructor] = true


###
Replace all _Variable_ nodes whose varName is a constructor with _Constructed_
nodes
###
_replaceConstructorVars = (astNode) ->

  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = _replaceConstructorVars(child)
    return astNode

  # Rewrite all children
  for name, child of astNode.children
    astNode.children[name] = _replaceConstructorVars(child)

  if astNode.isVariable()
    varName = astNode.children.id.literal
    if varName of constructors
      newNode = ASTNode.make('_Constructed_')
      newNode.children = {
        constructor: ASTNode.make('_ID_', varName)
        data: ASTNode.make('_EMPTY_')
      }
      return newNode

  return astNode


module.exports = replaceConstructorVars
