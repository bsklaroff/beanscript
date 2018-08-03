ASTNode = require('../ast_node')
utils = require('../utils')

replaceStringsWithCharArrays = (astNode) ->

  # Check if astNode is an array
  if astNode.length?
    for child, i in astNode
      astNode[i] = replaceStringsWithCharArrays(child)
    return astNode

  # Rewrite all children
  for name, child of astNode.children
    astNode.children[name] = replaceStringsWithCharArrays(child)

  if astNode.isString()
    strLiteral = ''
    for fragment in astNode.children.fragments
      if fragment.isEscapedSingleQuote() or fragment.isEscapedDoubleQuote()
        strLiteral += fragment.literal[1]
      else if fragment.isStringNoSingleQuote() or fragment.isStringNoDoubleQuote()
        strLiteral += fragment.literal
      else
        console.error('Unexpected string fragment')
        process.exit(1)
    charNodes = utils.map(strLiteral, (char) -> ASTNode.make('_CHAR_', char))
    arrNode = ASTNode.make('_Array_')
    arrNode.children = {items: charNodes}
    return arrNode

  return astNode


module.exports = replaceStringsWithCharArrays
