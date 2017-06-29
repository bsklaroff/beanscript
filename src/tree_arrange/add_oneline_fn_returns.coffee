ASTNode = require('../ast_node')

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
        console.log("ERROR: expected one-line fn body to have exactly two statements")
        process.exit(1)
      else if astNode.children.body[1].isReturn()
        console.log("ERROR: one-line fn should not use return keyword")
        process.exit(1)
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
