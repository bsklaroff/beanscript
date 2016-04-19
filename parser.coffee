###
# Indent based
+
-
*
/
**
%
if
else if
else
# no switch
try
catch e
fn_call(a, b, c)
x = 3
fn = (a, b, c = 3) ->
fn = (a, b, c) =>
# closures
# first class functions
object.property
object['property']
[2, 3, 4]
{ property: value }
return
""
''
###

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
    '_Variable_'
    '_FunctionCall_'
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
    'SINGLE_QUOTE singleQuoteString{pieces[]} SINGLE_QUOTE',
    'DOUBLE_QUOTE doubleQuoteString{pieces[]} DOUBLE_QUOTE'
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
}

LITERALS = {
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
  _EXPONENT_: '\*\*'
  _TIMES_: '\*'
  _DIVIDED_BY_: '\''
  _PLUS_: '+'
  _MINUS_: '-'
  SINGLE_QUOTE: "'"
  DOUBLE_QUOTE: '"'
  _ESCAPED_SINGLE_QUOTES_: "\\'+"
  _STRING_NO_SINGLE_QUOTE_: "[^']+"
  _ESCAPED_DOUBLE_QUOTES_: '\\"+'
  _STRING_NO_DOUBLE_QUOTE_: '[^"]+'
  RIGHT_ARROW: '->'
}

class Phrase
  SYMBOLS:
    WHITESPACE: ' +'
    ID: '[_a-zA-Z0-9]+'
    LEFT_CURLY_BRACE: '{'
    RIGHT_CURLY_BRACE: '}'
    SQUARE_BRACKETS: '\\[\\]'
    LEFT_PAREN: '\\('
    RIGHT_PAREN: '\\)'
    STAR: '\\*'

  constructor: (@key, @bnfOptions) ->
    @options = []
    for bnfOption in @bnfOptions
      @options.push(@_parseBNF(bnfOption))
    @isASTNode = false
    # By convention, we denote an _ASTNode_ by surrounding it with underscores
    if @key[0] == '_' and @key[@key.length - 1] == '_'
      @isASTNode = true
      @_checkASTChildren()
    return

  # Make sure that all options have the same set of ast children
  _checkASTChildren: ->
    astChildren = null
    for option in @options
      optionASTChildren = {}
      for phraseToken in option
        if phraseToken.astChildKey?
          optionASTChildren[phraseToken.astChildKey] = true
      if astChildren?
        for key, t of astChildren
          if key not of optionASTChildren
            throw new Error("An option for #{@key} is missing ast child #{key}")
        for key, t of optionASTChildren
          if key not of astChildren
            throw new Error("An option for #{@key} is missing ast child #{key}")
      else
        astChildren = optionASTChildren
    return

  _parseBNF: (bnfOption) ->
    @bnfLineToParse = bnfOption
    @parenDepth = 0
    tokenizedOption = @_parsePhraseTokens()
    if @parenDepth != 0
      throw new Error("BNF option #{bnfOption} has mismatched parentheses")
    delete @bnfLineToParse
    delete @parenDepth
    return tokenizedOption

  _parsePhraseTokens: ->
    phraseTokens = []
    while @bnfLineToParse.length > 0
      foundRightParen = false
      wipPhraseToken =
        phraseKey: null
        isLiteral: false
        zeroOrMore: false
        astChildKey: null
        astChildIsArray: false
        astChildIsEmpty: false
        isGroup: false
        subphrases: null
      [symbolName, symbol] = @_getNextSymbol()
      if symbolName == 'WHITESPACE'
        continue
      else if symbolName == 'ID'
        wipPhraseToken.phraseKey = symbol
        wipPhraseToken.isLiteral = @_isLiteral(symbol)
        foundRightParen = @_parseSymbolSuffix(wipPhraseToken)
      else if symbolName == 'LEFT_CURLY_BRACE'
        wipPhraseToken.astChildIsEmpty = true
        @_parseASTChild(wipPhraseToken)
      else if symbolName == 'LEFT_PAREN'
        @parenDepth++
        wipPhraseToken.isGroup = true
        wipPhraseToken.subphrases = @_parsePhraseTokens()
        foundRightParen = @_parseSymbolSuffix(wipPhraseToken)
      else
        throw new Error("Symbol #{symbolName} (#{symbol}) cannot start a phrase")
      phraseTokens.push(wipPhraseToken)
      if foundRightParen
        break
    return phraseTokens

  # By convention, we denote a LITERAL by using all caps for it
  _isLiteral: (phraseKey) ->
    for char in phraseKey
      if /[a-z]/.test(char)
        return false
    return true

  _parseSymbolSuffix: (wipPhraseToken) ->
    while @bnfLineToParse.length > 0
      [symbolName, symbol] = @_getNextSymbol()
      if symbolName == 'WHITESPACE'
        break
      else if symbolName == 'STAR'
        wipPhraseToken.zeroOrMore = true
      else if symbolName == 'LEFT_CURLY_BRACE'
        @_parseASTChild(wipPhraseToken)
      else if symbolName == 'RIGHT_PAREN'
        if @parenDepth <= 0
          throw new Error("Extra right parenthesis while parsing: #{@bnfLineToParse}")
        @parenDepth--
        return true
      else
        throw new Error("Symbol #{symbolName} (#{symbol}) cannot be suffix")
    return false

  _parseASTChild: (wipPhraseToken) ->
    [symbolName, symbol] = @_getNextSymbol()
    if symbolName != 'ID'
      throw new Error("Symbol #{symbolName} (#{symbol}) cannot start AST child")
    wipPhraseToken.astChildKey = symbol
    [symbolName, symbol] = @_getNextSymbol()
    if symbolName == 'SQUARE_BRACKETS'
      wipPhraseToken.astChildIsArray = true
      [symbolName, symbol] = @_getNextSymbol()
    if symbolName != 'RIGHT_CURLY_BRACE'
      throw new Error("Symbol #{symbolName} (#{symbol}) cannot end AST child")
    return

  _getNextSymbol: ->
    for name, regex of @SYMBOLS
      symbolMatch = @bnfLineToParse.match(new RegExp("^#{regex}"))
      if symbolMatch?
        @bnfLineToParse = @bnfLineToParse[symbolMatch[0].length..]
        return [name, symbolMatch[0]]
    throw new Error("No valid symbol found while parsing: #{@bnfLineToParse}")

phrases = {}
for key, bnfOptions of BNF
  phrases[key] = new Phrase(key, bnfOptions)

fs = require('fs')
inputStr = fs.readFileSync(process.argv[2]).toString()

tryLiteral = (key, idx) ->
  literalMatch = inputStr[idx..].match(new RegExp("^#{LITERALS[key]}"))
  if literalMatch?
    return literalMatch[0]
  return null

tryOption = (option, idx) ->
  phraseTokenIdx = 0
  while phraseTokenIdx < option.length
    phraseToken = option[phraseTokenIdx]
    # Ignore whitespace
    whitespace = tryLiteral('WHITESPACE', idx)
    if whitespace?
      idx += whitespace.length
    # Attempt to match the next phrase token
    if phraseToken.isLiteral
      literal = tryLiteral(phraseToken.phraseKey, idx)
      if literal?
        nextIdx = idx + literal.length
      else
        nextIdx = -1
    else if phraseToken.isGroup
      nextIdx = tryOption(phraseToken.subphrases, idx)
    else
      nextIdx = tryPhrase(phraseToken.phraseKey, idx)
    # If this phraseToken has a STAR, only move forward if we didn't match
    if phraseToken.zeroOrMore
      if nextIdx == -1
        phraseTokenIdx++
      else
        idx = nextIdx
    # If this phraseToken has no STAR, return -1 if we didn't match
    else if nextIdx == -1
      return -1
    else
      idx = nextIdx
      phraseTokenIdx++
  return idx

tryPhrase = (key, idx) ->
  phrase = phrases[key]
  for option in phrase.options
    nextIdx = tryOption(option, idx)
    if nextIdx != -1
      return nextIdx
  return -1

# TODO: match as much as possible

console.log(tryPhrase('_Program_', 0))
