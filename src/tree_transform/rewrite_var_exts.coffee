ASTNode = require('../ast_node')


rewriteVarExts = (astNode) ->
  astNode = replaceVarExtsWithRefs(astNode)
  astNode = replaceArrRefsWithFnCalls(astNode)
  return astNode


###
Replace all _Assignable_ and _VarOrFnCall_ nodes with a properly nested tree
of _Variable_, _ObjectRef_, _ArrayRef_, and _FunctionCall_ nodes
###
replaceVarExtsWithRefs = (astNode) ->

  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = replaceVarExtsWithRefs(child)
    return astNode

  # Rewrite all children
  for name, child of astNode.children
    astNode.children[name] = replaceVarExtsWithRefs(child)

  if astNode.isAssignable() or astNode.isVarOrFnCall()
    lastNode = astNode.children.base
    for extNode in astNode.children.exts
      if extNode.isArgList()
        functionCallNode = ASTNode.make('_FunctionCall_')
        functionCallNode.children = {fn: lastNode, args: extNode.children.args}
        lastNode = functionCallNode
      else if extNode.isId()
        objectRefNode = ASTNode.make('_ObjectRef_')
        objectRefNode.children = {obj: lastNode, ref: extNode}
        lastNode = objectRefNode
      else
        arrayRefNode = ASTNode.make('_ArrayRef_')
        arrayRefNode.children = {arr: lastNode, ref: extNode}
        lastNode = arrayRefNode
    return lastNode

  return astNode


###
Replace all _ArrayRef_ nodes with @__arr_get__ nodes, unless they are the
target of an _Assignment_, in which case we replace the entire _Assignment_
with @__arr_set__
###
replaceArrRefsWithFnCalls = (astNode) ->

  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = replaceArrRefsWithFnCalls(child)
    return astNode

  if astNode.isAssignment()
    lhs = astNode.children.target
    if lhs.isArrayRef()
      idNode = ASTNode.make('_ID_', '@__arr_set__')
      varNode = ASTNode.make('_Variable_')
      varNode.children = {id: idNode}
      fnCallNode = ASTNode.make('_FunctionCall_')
      fnCallNode.children = {fn: varNode, args: [lhs.children.arr, lhs.children.ref, astNode.children.source]}
      astNode = fnCallNode

  else if astNode.isArrayRef()
    idNode = ASTNode.make('_ID_', '@__arr_get__')
    varNode = ASTNode.make('_Variable_')
    varNode.children = {id: idNode}
    fnCallNode = ASTNode.make('_FunctionCall_')
    fnCallNode.children = {fn: varNode, args: [astNode.children.arr, astNode.children.ref]}
    astNode = fnCallNode

  # Rewrite all children
  for name, child of astNode.children
    astNode.children[name] = replaceArrRefsWithFnCalls(child)

  return astNode


module.exports = rewriteVarExts
