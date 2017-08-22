unusedScopeId = null

assignASTIds = (rootNode) ->
  unusedScopeId = 1
  return _assignASTIds(rootNode, {id: 0, scopeId: 0})

_assignASTIds = (astNode, next) ->
  # Assign id to current node and track that we've assigned it
  astNode.astId = "#{next.id}"
  astNode.scopeId = "#{next.scopeId}"
  # Variable names prefaced by '@' symbol are global
  if not astNode.length? and astNode.isVariable() and astNode.children.id.literal[0] == '@'
    astNode.scopeId = "0"
  next.id++
  # If astNode is a function def, create a new scope for it and its children
  prevScopeId = next.scopeId
  if not astNode.length? and astNode.isFunctionDef()
    next.scopeId = unusedScopeId
    astNode.scopeId = "#{next.scopeId}"
    unusedScopeId++
  # If astNode is an array, gen node ids for each of its elements
  if astNode.length?
    for child in astNode
      _assignASTIds(child, next)
    return astNode
  # Otherwise, gen node ids for each of its children
  for name, child of astNode.children
    _assignASTIds(child, next)
  # If astNode is a function def, unset children scope
  if astNode.isFunctionDef()
    next.scopeId = prevScopeId
  return astNode

module.exports = assignASTIds
