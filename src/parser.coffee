ASTNode = require('./ast_node')
grammar = require('./grammar')

class Parser
  SPACES_PER_INDENT = 2

  _makeHistoryNode: (token, parent) ->
    rule = null
    if token.isGroup
      rule =
        isLiteral: false
        patterns: [token.subtokens]
    else
      rule = grammar[token.name]
    return {
      rule: rule
      patternNum: 0
      tokenNum: 0
      parseIdx: parent?.parseIdx ? 0
      indentLevel: @indentLevel
      parent: parent
      astChildKey: token.astChildKey
      astChildIsArray: token.astChildIsArray
      literal: null
      astNode: null
    }

  _copyHistoryNode: (node) ->
    return {
      rule: node.rule
      patternNum: 0
      tokenNum: 0
      parseIdx: node.parseIdx
      indentLevel: @indentLevel
      parent: node.parent
      literal: node.literalMatch
      astNode: null
    }

  # For debugging
  _printHistory: ->
    printHistory = "[ #{node.rule.name}:#{node.parseIdx}"
    for node, i in @history
      if i == 0
        continue
      printHistory += ", #{node.rule.name}:#{node.parseIdx}"
    printHistory += ' ]'
    console.log(printHistory)
    return

  # Take parsed nodes in order and make them into an ASTNode tree
  _astTreeFromHistory: ->
    for node in @history
      if node.astChildIsArray
        node.parent.astNode.children[node.astChildKey] ?= []
      if node.rule.isASTNode
        node.astNode = ASTNode.make(node.rule.name, node.literal)
        parentNode = node.parent
        if not parentNode?
          continue
        {astChildKey, astChildIsArray} = node
        while not parentNode.rule.isASTNode
          {astChildKey, astChildIsArray} = parentNode
          parentNode = parentNode.parent
        astParent = parentNode.astNode
        if astChildIsArray
          astParent.children[astChildKey].push(node.astNode)
        else
          astParent.children[astChildKey] = node.astNode
    return @history[0].astNode

  parse: (@inputStr) ->
    @indentLevel = 0
    @history = [@_makeHistoryNode({name: '_Program_'}, null)]
    while @history[0].parseIdx != @inputStr.length
      @_parseNextRule()
      if @history.length == 0
        return null
    return @_astTreeFromHistory()

  # Parses next rule in @history
  _parseNextRule: ->
    node = @history[@history.length - 1]
    {rule, parseIdx} = node
    if rule.isLiteral
      # Ignore whitespace
      parseIdx = @_parseWhitespace(parseIdx)
      literalMatch = @inputStr[parseIdx..].match(new RegExp("^#{rule.regex}"))
      if not literalMatch?
        @_tokenNoMatch(node.parent)
        return
      nextIdx = parseIdx + literalMatch[0].length
      if rule.isASTNode
        node.literal = literalMatch[0]
      else if rule.name == 'INDENT'
        @indentLevel++
      else if rule.name == 'UNINDENT'
        @indentLevel--
      else if rule.name == 'NEWLINE'
        # Parse next line's indentation with this line
        postIndentIdx = @_parseWhitespace(nextIdx)
        if postIndentIdx != nextIdx + @indentLevel * SPACES_PER_INDENT
          @_tokenNoMatch(node.parent)
          return
        nextIdx = postIndentIdx
      @_tokenMatch(node.parent, nextIdx)
    else
      nextToken = rule.patterns[node.patternNum][node.tokenNum]
      @history.push(@_makeHistoryNode(nextToken, node))
    return

  # Parses whitespace, returns parseIdx after any whitespace
  _parseWhitespace: (parseIdx) ->
    match = @inputStr[parseIdx..].match(new RegExp("^#{grammar.WHITESPACE.regex}"))
    if match?
      return parseIdx + match[0].length
    return parseIdx

  # Records that a token of the node's current pattern was matched
  _tokenMatch: (node, nextIdx) ->
    if not node?
      return
    node.parseIdx = nextIdx
    node.tokenNum++
    pattern = node.rule.patterns[node.patternNum]
    if node.tokenNum == pattern.length
      @_tokenMatch(node.parent, nextIdx)
    else
      nextToken = pattern[node.tokenNum]
      @history.push(@_makeHistoryNode(nextToken, node))
    return

  # Records that the latest token of the node's current pattern failed to match
  _tokenNoMatch: (node) ->
    @_removeSubnodesFromHistory(node)
    node.patternNum++
    if node.patternNum == node.rule.patterns.length
      # Check if this is the _Program_ node
      if not node.parent?
        @history = []
        return
      @_tokenNoMatch(node.parent)
    node.tokenNum = 0
    node.parseIdx = node.parent.parseIdx
    return

  # Remove any later nodes from history
  _removeSubnodesFromHistory: (node) ->
    while @history.length > 0
      if @history[@history.length - 1] == node
        break
      @history.pop()
    return

module.exports = Parser
