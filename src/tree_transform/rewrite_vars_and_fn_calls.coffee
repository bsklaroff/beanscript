ASTNode = require('../ast_node')

###
Replace all _Assignable_ and _VarOrFnCall_ nodes with a properly nested tree
of _Variable_, _ObjectRef_, _ArrayRef_, and _FunctionCall_ nodes
###

rewriteVarsAndFnCalls = (astNode) ->

  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = rewriteVarsAndFnCalls(child)
    return astNode

  if astNode.isAssignable() or astNode.isVarOrFnCall()
    lastNode = astNode.children.base
    for extNode in astNode.children.exts
      if extNode.isArgList()
        functionCallNode = ASTNode.make('_FunctionCall_')
        args = rewriteVarsAndFnCalls(extNode.children.args)
        functionCallNode.children = {fn: lastNode, args: args}
        lastNode = functionCallNode
      else if extNode.isId()
        objectRefNode = ASTNode.make('_ObjectRef_')
        objectRefNode.children = {obj: lastNode, ref: extNode}
        lastNode = objectRefNode
      else
        arrayRefNode = ASTNode.make('_ArrayRef_')
        ref = rewriteVarsAndFnCalls(extNode)
        arrayRefNode.children = {arr: lastNode, ref: ref}
        lastNode = arrayRefNode
    return lastNode

  # Rewrite all children
  for name, child of astNode.children
    astNode.children[name] = rewriteVarsAndFnCalls(child)

  return astNode

module.exports = rewriteVarsAndFnCalls
