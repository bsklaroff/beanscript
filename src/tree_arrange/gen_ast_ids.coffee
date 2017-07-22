unusedScopeId = 1

genASTIds = (astNode, next = {id: 0, scopeId: 0}) ->
  # If astNode is a function def, create a new scope for it and its children
  prevScopeId = next.scopeId
  if not astNode.length? and astNode.isFunctionDef()
    next.scopeId = unusedScopeId
    unusedScopeId++
  # Assign id to current node and track that we've assigned it
  astNode.astId = next.id
  astNode.scopeId = next.scopeId
  next.id++
  # If astNode is an array, gen node ids for each of its elements
  if astNode.length?
    for child in astNode
      genASTIds(child, next)
    return astNode
  # Otherwise, gen node ids for each of its children
  for name, child of astNode.children
    genASTIds(child, next)
  # If astNode is a function def, unset children scope
  if astNode.isFunctionDef()
    next.scopeId = prevScopeId
  return astNode

module.exports = genASTIds
