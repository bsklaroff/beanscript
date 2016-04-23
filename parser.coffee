ASTNode = require('./ast_node')
bnfRules = require('./bnf_rules')

class Parser
  constructor: (@inputString) ->
    @astTree = null
    return

  parse: -> @astTree = @tryRule(bnfRules._Program_, 0, true)[0]

  tryRule: (rule, idx, end = false) ->
    if rule.isLiteral
      literalMatch = @inputString[idx..].match(new RegExp("^#{rule.regex}"))
      if literalMatch?
        nextIdx = idx + literalMatch[0].length
        if rule.isASTNode
          return [new ASTNode(rule.name, literalMatch[0]), nextIdx]
        return [null, nextIdx]
    else if rule.isASTNode
      for pattern in rule.patterns
        newNode = new ASTNode(rule.name)
        # If we're parsing an ast node pattern, we know @tryPattern will return an object
        [newNode.children, nextIdx] = @tryPattern(pattern, idx, end)
        if (nextIdx > -1 and not end) or nextIdx == @inputString.length
          return [newNode, nextIdx]
    else
      for pattern in rule.patterns
        # If we're parsing a non-ast node pattern, we know @tryPattern will return an array
        [newNodes, nextIdx] = @tryPattern(pattern, idx, end)
        if (nextIdx > -1 and not end) or nextIdx == @inputString.length
          return [newNodes, nextIdx]
    return [null, -1]

  tryPattern: (pattern, idx, end = false) ->
    symbolIdx = 0
    childrenObj = null
    childrenArr = []
    while symbolIdx < pattern.length
      lastToken = end and symbolIdx == pattern.length - 1
      symbol = pattern[symbolIdx]
      # Initialize children object if we are parsing an ast node rule
      if symbol.astChildKey?
        childrenObj ?= {}
      # Ignore whitespace
      [whitespace, nextIdx] = @tryRule(bnfRules.WHITESPACE, idx)
      if nextIdx != -1
        idx = nextIdx
      # Attempt to match parenthesized subgroup
      if symbol.isGroup
        # We know this will return an array because symbol.subsymbols is not an ast node pattern
        [patternResult, nextIdx] = @tryPattern(symbol.subsymbols, idx, lastToken)
        @updateChildren(patternResult, symbol, childrenObj, childrenArr)
      # TODO: match an empty ast child
      # Attempt to match rule token
      else
        [ruleResult, nextIdx] = @tryRule(bnfRules[symbol.name], idx, lastToken)
        @updateChildren(ruleResult, symbol, childrenObj, childrenArr)
      # If this symbol has a STAR, only move forward if we didn't match
      if symbol.zeroOrMore
        if nextIdx == -1
          symbolIdx++
        else
          idx = nextIdx
      # If this symbol has no STAR and we didn't match, return -1
      else if nextIdx == -1
        return [null, -1]
      # If this symbol has no STAR and we matched, move forward one symbol
      else
        idx = nextIdx
        symbolIdx++
    # Return children object if we were parsing an ast node pattern
    if childrenObj?
      if childrenArr.length > 0
        throw new Error("Found a mix of ast children and non-ast children while parsing #{pattern}")
      return [childrenObj, idx]
    # Otherwise, return array of subnodes
    return [childrenArr, idx]

  updateChildren: (res, symbol, childrenObj, childrenArr) ->
    # Do nothing if we found no result
    if not res?
      return
    # Case 1: res is an ast node
    if res.name?
      # Case a: we are parsing the pattern for an ast node
      if symbol.astChildKey?
        childrenObj[symbol.astChildKey] = res
      # Case b: we are parsing the pattern for a non-ast node
      else
        childrenArr.push(res)
    # Case 2: res is an array of ast nodes
    else if res.length?
      # Case a: we are parsing the pattern for an ast node
      if symbol.astChildKey?
        childrenObj[symbol.astChildKey] ?= []
        for subNode in res
          childrenObj[symbol.astChildKey].push(subNode)
      # Case b: we are parsing the pattern for a non-ast node
      else
        for subNode in res
          childrenArr.push(subNode)
    else
      throw new Error("Result #{res} is neither an ast node nor an array of nodes")
    return

module.exports = Parser
