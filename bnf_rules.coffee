BNF = {
  _Program_: [
    'statements{statements[]}'
  ]
  statements: [
    '(statement NEWLINE)* statement'
  ]
  statement: [
    '_Assignment_'
    'expr'
    ''
  ]

  _Assignment_: [
    '_Variable_{target} EQUALS expr{source}'
    '_Variable_{target} EQUALS fnDef{source}'
  ]
  _Variable_: [
    '((_ID_ DOT)* _ID_){varNames[]}'
  ]

  expr: [
    'nonOpExpr'
    '_OpExpression_'
  ]

  nonOpExpr: [
    'LEFT_PAREN expr RIGHT_PAREN'
    '_FunctionCall_'
    '_Variable_'
    '_String_'
    '_NUMBER_'
  ]
  _OpExpression_: [
    'nonOpExpr{lhs} op{op} expr{rhs}'
  ]

  _FunctionCall_: [
    '_Variable_{fnName} argList{argList[]}'
  ]
  argList: [
    'LEFT_PAREN commaList RIGHT_PAREN'
  ]
  commaList: [
    'commaList0'
    ''
  ]
  commaList0: [
    '_ID_ COMMA NEWLINE* commaList0'
    '_ID_'
  ]

  op: [
    '_MOD_'
    '_EXPONENT_'
    '_TIMES_'
    '_DIVDED_BY_'
    '_PLUS_'
    '_MINUS_'
  ]

  _String_: [
    'SINGLE_QUOTE singleQuoteString{fragments[]} SINGLE_QUOTE',
    'DOUBLE_QUOTE doubleQuoteString{fragments[]} DOUBLE_QUOTE'
  ]
  singleQuoteString: [
    '_ESCAPED_SINGLE_QUOTES_ singleQuoteString'
    '_STRING_NO_SINGLE_QUOTE_ singleQuoteString'
    ''
  ]
  doubleQuoteString : [
    '_ESCAPED_DOUBLE_QUOTES_ doubleQuoteString'
    '_STRING_NO_DOUBLE_QUOTE_ doubleQuoteString'
    ''
  ]

  _FunctionDef_: [
    'argList{args[]} fnDef0{body[]}'
    '{args[]} fnDef0{body[]}'
  ]
  fnDef0: [
    'RIGHT_ARROW INDENT NEWLINE statements UNINDENT'
    'RIGHT_ARROW statement'
  ]

  NEWLINE: '\n'
  WHITESPACE: '[ \t\r]+'
  EQUALS: '='
  DOT: '\\.'
  _ID_: '[_a-zA-Z][_a-zA-Z0-9]*'
  _NUMBER_: '[1-9][0-9]+(\.[0-9]+)?'
  LEFT_PAREN: '\\('
  RIGHT_PAREN: '\\)'
  COMMA: ','
  _MOD_: '%'
  _EXPONENT_: '\\*\\*'
  _TIMES_: '\\*'
  _DIVIDED_BY_: '\''
  _PLUS_: '\\+'
  _MINUS_: '-'
  SINGLE_QUOTE: "'"
  DOUBLE_QUOTE: '"'
  _ESCAPED_SINGLE_QUOTES_: "\\'+"
  _STRING_NO_SINGLE_QUOTE_: "[^']+"
  _ESCAPED_DOUBLE_QUOTES_: '\\"+'
  _STRING_NO_DOUBLE_QUOTE_: '[^"]+'
  RIGHT_ARROW: '->'
}

class BNFRule
  RULE_TOKENS:
    WHITESPACE: ' +'
    ID: '[_a-zA-Z0-9]+'
    LEFT_CURLY_BRACE: '{'
    RIGHT_CURLY_BRACE: '}'
    SQUARE_BRACKETS: '\\[\\]'
    LEFT_PAREN: '\\('
    RIGHT_PAREN: '\\)'
    STAR: '\\*'

  constructor: (@name, expression) ->
    # We denote a LITERAL by using all caps for it
    @isLiteral = not /[a-z]/.test(@name)
    # We denote an _ASTNode_ by surrounding it with underscores
    @isASTNode = @name[0] == '_' and @name[@name.length - 1] == '_'
    if @isLiteral
      @regex = expression
      return
    @patterns = []
    for patternString in expression
      @patterns.push(@_parsePatternString(patternString))
    if @isASTNode
      @_checkASTChildren()
    return

  # Make sure that all patterns have the same set of ast children
  _checkASTChildren: ->
    astChildren = null
    for pattern in @patterns
      patternASTChildren = {}
      for symbol in pattern
        if symbol.astChildKey?
          patternASTChildren[symbol.astChildKey] = true
      if astChildren?
        for key, t of astChildren
          if key not of patternASTChildren
            throw new Error("A pattern for #{@name} is missing ast child #{key}")
        for key, t of patternASTChildren
          if key not of astChildren
            throw new Error("A pattern for #{@name} is missing ast child #{key}")
      else
        astChildren = patternASTChildren
    return

  _parsePatternString: (patternString) ->
    @patternStringToParse = patternString
    @parenDepth = 0
    symbols = @_parseSymbols()
    if @parenDepth != 0
      throw new Error("Pattern #{patternString} has mismatched parentheses")
    delete @patternStringToParse
    delete @parenDepth
    return symbols

  _parseSymbols: ->
    symbols = []
    while @patternStringToParse.length > 0
      foundRightParen = false
      wipSymbol =
        name: null
        zeroOrMore: false
        astChildKey: null
        astChildIsArray: false
        astChildIsEmpty: false
        isGroup: false
        subsymbols: null
      [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
      if ruleTokenName == 'WHITESPACE'
        continue
      else if ruleTokenName == 'ID'
        wipSymbol.name = ruleTokenVal
        foundRightParen = @_parseSymbolSuffix(wipSymbol)
      else if ruleTokenName == 'LEFT_CURLY_BRACE'
        wipSymbol.astChildIsEmpty = true
        @_parseASTChild(wipSymbol)
      else if ruleTokenName == 'LEFT_PAREN'
        @parenDepth++
        wipSymbol.isGroup = true
        wipSymbol.subsymbols = @_parseSymbols()
        foundRightParen = @_parseSymbolSuffix(wipSymbol)
      else
        throw new Error("Rule token #{ruleTokenName} (#{ruleTokenVal}) cannot start a pattern")
      symbols.push(wipSymbol)
      if foundRightParen
        break
    return symbols

  _parseSymbolSuffix: (wipSymbol) ->
    while @patternStringToParse.length > 0
      [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
      if ruleTokenName == 'WHITESPACE'
        break
      else if ruleTokenName == 'STAR'
        wipSymbol.zeroOrMore = true
      else if ruleTokenName == 'LEFT_CURLY_BRACE'
        @_parseASTChild(wipSymbol)
      else if ruleTokenName == 'RIGHT_PAREN'
        if @parenDepth <= 0
          throw new Error("Extra right parenthesis while parsing: #{@patternStringToParse}")
        @parenDepth--
        return true
      else
        throw new Error("Rule token #{ruleTokenName} (#{ruleTokenVal}) cannot be suffix")
    return false

  _parseASTChild: (wipSymbol) ->
    [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
    if ruleTokenName != 'ID'
      throw new Error("Rule token #{ruleTokenName} (#{ruleTokenVal}) cannot start AST child")
    wipSymbol.astChildKey = ruleTokenVal
    [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
    if ruleTokenName == 'SQUARE_BRACKETS'
      wipSymbol.astChildIsArray = true
      [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
    if ruleTokenName != 'RIGHT_CURLY_BRACE'
      throw new Error("Rule token #{ruleTokenName} (#{ruleTokenVal}) cannot end AST child")
    return

  _getNextRuleToken: ->
    for tokenName, regex of @RULE_TOKENS
      tokenMatch = @patternStringToParse.match(new RegExp("^#{regex}"))
      if tokenMatch?
        @patternStringToParse = @patternStringToParse[tokenMatch[0].length..]
        return [tokenName, tokenMatch[0]]
    throw new Error("No valid rule token found while parsing: #{@patternStringToParse}")

bnfRules = {}
for name, patternStrings of BNF
  bnfRules[name] = new BNFRule(name, patternStrings)

module.exports = bnfRules

