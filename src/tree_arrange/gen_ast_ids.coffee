genASTIds = (astNode, next = {id: 0}) ->
  # Assign id to current node and track that we've assigned it
  astNode.astId = next.id
  next.id++
  # If astNode is an array, gen node ids for each of its elements
  if astNode.length?
    for child in astNode
      genASTIds(child, next)
    return astNode
  # Otherwise, gen node ids for each of its children
  for name, child of astNode.children
    genASTIds(child, next)
  return astNode

module.exports = genASTIds
