ASTNode = require('../ast_node')
errors = require('../errors')

addOnelineFnReturns = (astNode) ->
  # If astNode is an array, check each of its elements for oneline fns
  if astNode.length?
    for child in astNode
      addOnelineFnReturns(child)
  # If astNode is a function def, check for the dummy 'newline' node at the
  # beginning of its body. If the node is empty, this is a oneline function
  # and we should wrap the body in a return node.
  # In either case, remove the dummy 'newline' node.
  else if astNode.isFunctionDef()
    if astNode.children.body[0].isEmpty()
      if astNode.children.body.length != 2
        errors.panic("Expected one-line fn body to have exactly two statements")
      else if astNode.children.body[1].isReturn()
        errors.panic("One-line fn should not use return keyword")
      returnNode = ASTNode.make('_Return_')
      returnNode.children = {returnVal: astNode.children.body[1]}
      astNode.children.body = [returnNode]
    else
      astNode.children.body = astNode.children.body[1..]
  # Otherwise, check each its children for oneline fns
  else
    for name, child of astNode.children
      addOnelineFnReturns(child)
  return astNode

module.exports = addOnelineFnReturns
