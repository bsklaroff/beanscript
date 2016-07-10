BNF = {
  _Program_: [
    'statements{statements[]}'
  ]
  statements: [
    '(statement NEWLINE)* statement'
  ]
  statement: [
    '_Return_'
    '_If_'
    '_While_'
    '_FunctionAssignment_'
    '_Assignment_'
    'expr'
    ''
  ]

  _Return_: [
    'RETURN expr{returnVal}'
  ]

  _If_: [
    'IF expr{condition} INDENT NEWLINE statements{body[]} UNINDENT maybeElse{else}'
  ]
  _ElseIf_: [
    'ELSE IF expr{condition} INDENT NEWLINE statements{body[]} UNINDENT maybeElse{else}'
  ]
  _Else_: [
    'ELSE INDENT NEWLINE statements{body[]} UNINDENT'
  ]
  maybeElse: [
    '_ElseIf_'
    '_Else_'
    '_EMPTY_'
  ]

  _While_: [
    'WHILE expr{condition} INDENT NEWLINE statements{body[]} UNINDENT'
  ]

  _FunctionAssignment_: [
    '_TypedVariable_{target} EQUALS _FunctionDef_{source}'
  ]
  _Assignment_: [
    '_TypedVariable_{target} EQUALS expr{source}'
  ]
  _TypedVariable_: [
    '_Variable_{var} LEFT_CURLY _ID_{type} RIGHT_CURLY'
    '_Variable_{var} _EMPTY_{type}'
  ]
  _Variable_: [
    '_ID_{obj} DOT _Variable_{prop}'
    '_ID_{obj} _EMPTY_{prop}'
  ]

  expr: [
    '_OpExpression_'
    'nonOpExpr'
  ]

  _OpExpression_: [
    'nonOpExpr{lhs} op{op} expr{rhs}'
    '_EMPTY_{lhs} _NOT_{op} expr{rhs}'
    '_EMPTY_{lhs} _NEG_{op} expr{rhs}'
  ]
  _OpParenGroup_: [
    'LEFT_PAREN _OpExpression_{opExpr} RIGHT_PAREN'
  ]
  nonOpExpr: [
    '_OpParenGroup_'
    '_FunctionCall_'
    '_Variable_'
    '_String_'
    '_NUMBER_'
  ]

  op: [
    '_EXPONENT_'
    '_MOD_'
    '_TIMES_'
    '_DIVIDED_BY_'
    '_PLUS_'
    '_MINUS_'
    '_EQUALS_EQUALS_'
    '_NOT_EQUALS_'
    '_LTE_'
    '_LT_'
    '_GTE_'
    '_GT_'
    '_AND_'
    '_OR_'
  ]

  _FunctionCall_: [
    '_Variable_{fnName} argList{argList[]}'
  ]
  argList: [
    'LEFT_PAREN argListInner RIGHT_PAREN'
  ]
  argListInner: [
    'argListInner0'
    ''
  ]
  argListInner0: [
    'expr COMMA argListInner0'
    'expr'
  ]

  _Array_: [
    'LEFT_SQUARE argListInner{items[]} RIGHT_SQUARE'
  ]
  _ArrayRange_: [
    'LEFT_SQUARE expr{start} DOT_DOT expr{end} RIGHT_SQUARE'
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
    'argDefList{args[]} fnDef0{body[]}'
    '_EMPTY_{args[]} fnDef0{body[]}'
  ]
  argDefList: [
    'LEFT_PAREN argDefListInner RIGHT_PAREN'
  ]
  argDefListInner: [
    'argDefListInner0'
    ''
  ]
  argDefListInner0: [
    '_TypedId_ COMMA argDefListInner0'
    '_TypedId_'
  ]
  _TypedId_: [
    '_ID_{id} LEFT_CURLY _ID_{type} RIGHT_CURLY'
    '_ID_{id} _EMPTY_{type}'
  ]

  fnDef0: [
    'RIGHT_ARROW INDENT NEWLINE statements UNINDENT'
    'RIGHT_ARROW statement'
  ]

  NEWLINE: '[ \t\n]*\n'
  WHITESPACE: '[ \t]*'
  RETURN: 'return'
  IF: 'if'
  WHILE: 'while'
  ELSE: 'else'
  EQUALS: '='
  DOT: '\\.'
  _ID_: '[_a-zA-Z][_a-zA-Z0-9]*'
  _NUMBER_: '[0-9]+(\\.[0-9]*)?'
  LEFT_PAREN: '\\('
  RIGHT_PAREN: '\\)'
  LEFT_SQUARE: '\\['
  RIGHT_SQUARE: '\\]'
  LEFT_CURLY: '{'
  RIGHT_CURLY: '}'
  DOT_DOT: '\\.\\.'
  COMMA: ','
  _MOD_: '%'
  _EXPONENT_: '\\*\\*'
  _TIMES_: '\\*'
  _DIVIDED_BY_: '/'
  _PLUS_: '\\+'
  _MINUS_: '-'
  _AND_: 'and'
  _OR_: 'or'
  _EQUALS_EQUALS_: '=='
  _NOT_EQUALS_: '!='
  _LT_: '<'
  _LTE_: '<='
  _GT_: '>'
  _GTE_: '>='
  _NOT_: 'not'
  _NEG_: '-'
  SINGLE_QUOTE: "'"
  DOUBLE_QUOTE: '"'
  _ESCAPED_SINGLE_QUOTES_: "\\\\'+"
  _STRING_NO_SINGLE_QUOTE_: "[^']+"
  _ESCAPED_DOUBLE_QUOTES_: '\\\\"+'
  _STRING_NO_DOUBLE_QUOTE_: '[^"]+'
  RIGHT_ARROW: '->'
  INDENT: ''
  UNINDENT: ''
  _EMPTY_: ''
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
        isGroup: false
        subsymbols: null
      [ruleTokenName, ruleTokenVal] = @_getNextRuleToken()
      if ruleTokenName == 'WHITESPACE'
        continue
      else if ruleTokenName == 'ID'
        wipSymbol.name = ruleTokenVal
        foundRightParen = @_parseSymbolSuffix(wipSymbol)
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

