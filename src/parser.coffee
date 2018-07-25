ASTNode = require('./ast_node')
grammar = require('./grammar')

class Parser
  PARSE_DEBUG = false
  SPACES_PER_INDENT = 2

  _makeHistoryNode: (token, parent) ->
    rule = null
    if token.isGroup
      rule =
        isLiteral: false
        patterns: [token.subtokens]
    else
      rule = grammar[token.name]
      if not rule?
        throw {
          userError: false
          msg: "ERROR: no rule found for token #{token.name}"
        }
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
    printHistory = "[ #{@history[0].rule.name}:#{@history[0].parseIdx}"
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
    @maxParseIdx = 0
    @history = [@_makeHistoryNode({name: '_Program_'}, null)]
    while @history[0].parseIdx != @inputStr.length
      @_parseNextRule()
      if @history.length == 0
        throw {
          userError: true
          type: 'parser'
          loc: @maxParseIdx + 1
        }
    return @_astTreeFromHistory()

  # Parses next rule in @history
  _parseNextRule: ->
    node = @history[@history.length - 1]
    {rule, parseIdx} = node
    if rule.isLiteral
      # Ignore whitespace and comments
      parseIdx = @_parseWhitespaceAndComments(parseIdx)
      literalMatch = @inputStr[parseIdx..].match(new RegExp("^#{rule.regex}"))
      if not literalMatch?
        @_tokenNoMatch(node.parent, rule.name)
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
          @_tokenNoMatch(node.parent, rule.name)
          return
        nextIdx = postIndentIdx
      valid = @_tokenMatch(node.parent, nextIdx)
      # If we matched the whole pattern but did not consume the whole input str,
      # roll back this match
      if not valid
        @_tokenNoMatch(node.parent, rule.name)
      else if PARSE_DEBUG
        pattern = node.parent.rule.patterns[node.parent.patternNum]
        patternStr = ''
        for token in pattern
          patternStr += token.name + ' '
        console.log("matched #{rule.name} in #{node.parent.rule.name}:#{patternStr}")
        console.log(@inputStr[...@history[@history.length - 1].parseIdx])
    else
      nextToken = rule.patterns[node.patternNum][node.tokenNum]
      @history.push(@_makeHistoryNode(nextToken, node))
    return

  # Parses any whitespace and comments
  _parseWhitespaceAndComments: (parseIdx) ->
    origIdx = null
    while origIdx != parseIdx
      origIdx = parseIdx
      parseIdx = @_parseWhitespace(parseIdx)
      parseIdx = @_parseMultiLineComment(parseIdx)
    parseIdx = @_parseSingleLineComment(parseIdx)
    return parseIdx

  # Parses whitespace, returns parseIdx after any whitespace
  _parseWhitespace: (parseIdx) ->
    match = @inputStr[parseIdx..].match(new RegExp('^[ \t]*'))
    if match?
      return parseIdx + match[0].length
    return parseIdx

  # Parses single line comment
  _parseSingleLineComment: (parseIdx) ->
    match = @inputStr[parseIdx..].match(new RegExp('^#[^\n]*'))
    if match?
      return parseIdx + match[0].length
    return parseIdx

  # Parses multi line comment
  _parseMultiLineComment: (parseIdx) ->
    match = @inputStr[parseIdx..].match(new RegExp('^###[\\s\\S]*?(?=###)###'))
    if match?
      return parseIdx + match[0].length
    return parseIdx

  # Records that a token of the node's current pattern was matched
  _tokenMatch: (node, nextIdx) ->
    @maxParseIdx = Math.max(@maxParseIdx, nextIdx)
    # If we matched the whole pattern, make sure we matched the whole input str
    if not node?
      return nextIdx == @inputStr.length
    oldParseIdx = node.parseIdx
    node.parseIdx = nextIdx
    node.tokenNum++
    pattern = node.rule.patterns[node.patternNum]
    if node.tokenNum == pattern.length
      valid = @_tokenMatch(node.parent, nextIdx)
      # If we matched the whole pattern but did not consume the whole input str,
      # roll back this match
      if not valid
        node.parseIdx = oldParseIdx
        node.tokenNum--
        return false
    else
      nextToken = pattern[node.tokenNum]
      if not nextToken?
        throw {
          userError: false
          msg: "ERROR: no token found at position #{node.tokenNum} in pattern #{JSON.stringify(pattern)}"
        }
      @history.push(@_makeHistoryNode(nextToken, node))
    return true

  # Records that the latest token of the node's current pattern failed to match
  _tokenNoMatch: (node, ruleName) ->
    if PARSE_DEBUG
      pattern = node.rule.patterns[node.patternNum]
      patternStr = ''
      for token in pattern
        patternStr += token.name + ' '
      console.log("failed to match #{ruleName} in #{node.rule.name}:#{patternStr}")
      console.log(@inputStr[...@history[@history.length - 1].parseIdx])
    @_removeSubnodesFromHistory(node)
    node.patternNum++
    if node.patternNum == node.rule.patterns.length
      # Check if this is the _Program_ node
      if not node.parent?
        @history = []
        return
      @_tokenNoMatch(node.parent, node.rule.name)
    node.tokenNum = 0
    node.parseIdx = node.parent.parseIdx
    return

  # Remove any later nodes from history
  _removeSubnodesFromHistory: (node) ->
    while @history.length > 0
      if @history[@history.length - 1] == node
        break
      poppedNode = @history.pop()
      if poppedNode.rule.name == 'INDENT'
        @indentLevel--
      if poppedNode.rule.name == 'UNINDENT'
        @indentLevel++
    return

module.exports = Parser
