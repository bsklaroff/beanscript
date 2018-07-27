GRAMMAR = {
  _Program_: [
    'statements{statements[]}'
  ]
  statements: [
    'statement (NEWLINE statement)*'
  ]
  statement: [
    '_Type_'
    '_Typealias_'
    '_TypeclassDef_'
    '_Typeinst_'
    '_ReturnPtr_'
    '_Return_'
    '_If_'
    '_While_'
    '_TypeDef_'
    '_Assignment_'
    'expr'
    'EMPTY'
  ]

  anytype: [
    '_FunctionType_'
    '_ConstructedType_'
    '_ObjectType_'
    '_ID_'
  ]

  _FunctionType_: [
    '(fnTypeInner RIGHT_ARROW fnTypeInner (RIGHT_ARROW fnTypeInner)*){argTypes[]}'
    '(_EMPTY_ RIGHT_ARROW fnTypeInner){argTypes[]}'
  ]
  fnTypeInner: [
    'LEFT_PAREN _FunctionType_ RIGHT_PAREN'
    '_ConstructedType_'
    '_ObjectType_'
    '_ID_'
  ]

  _ConstructedType_: [
    '_ID_{constructor} (constructedTypeInner constructedTypeInner*){params[]}'
  ]
  constructedTypeInner: [
    'LEFT_PAREN _FunctionType_ RIGHT_PAREN'
    'LEFT_PAREN _ConstructedType_ RIGHT_PAREN'
    '_ObjectType_'
    '_ID_'
  ]

  _ObjectType_: [
    'LEFT_CURLY objTypeBody{props[]}'
  ]
  objTypeBody: [
    '_ObjTypeProp_ (COMMA _ObjTypeProp_)* RIGHT_CURLY'
    'INDENT NEWLINE _ObjTypeProp_ (NEWLINE _ObjTypeProp_)* UNINDENT NEWLINE RIGHT_CURLY'
    'EMPTY RIGHT_CURLY'
  ]
  _ObjTypeProp_: [
    '_ID_{key} TWO_COLON anytype{val}'
  ]

  _Type_: [
    'TYPE _ID_{name} _ID_*{params} EQUALS (_TypeOpt_ (VBAR _TypeOpt_)*){options}'
  ]
  _TypeOpt_: [
    '_ID_{constructor} constructedTypeInner{param}'
    '_ID_{constructor} _EMPTY_{param}'
  ]

  _Typealias_: [
    'TYPEALIAS _ID_{name} _ID_*{params} EQUALS anytype{type}'
  ]

  _TypeclassDef_: [
    'TYPECLASS _Typeclass_{typeclass} maybeSuperclasses{superclasses[]} INDENT NEWLINE typeDefs{body[]} UNINDENT'
  ]
  maybeSuperclasses: [
    'LTE LEFT_PAREN _ID_ (COMMA _ID_)* RIGHT_PAREN'
    'EMPTY'
  ]
  typeDefs: [
    '_TypeDef_ (NEWLINE _TypeDef_)*'
  ]

  _Typeinst_: [
    'TYPEINST _ID_{class} _ID_{type} INDENT NEWLINE fnDefObj{fnDefs[]} UNINDENT'
  ]
  fnDefObj: [
    '_FnDefProp_ (NEWLINE _FnDefProp_)*'
  ]
  _FnDefProp_: [
    '_ID_{fnName} COLON _FunctionDef_{fnDef}'
  ]

  _ReturnPtr_: [
    'RETURN_PTR fnDefOrExpr{returnVal}'
  ]
  _Return_: [
    'RETURN fnDefOrExpr{returnVal}'
  ]

  _If_: [
    'IF expr{condition} INDENT NEWLINE statements{body[]} UNINDENT maybeElse{else}'
  ]
  _Else_: [
    'ELSE INDENT NEWLINE statements{body[]} UNINDENT'
  ]
  maybeElse: [
    'NEWLINE ELSE _If_'
    'NEWLINE _Else_'
    '_EMPTY_'
  ]

  _While_: [
    'WHILE expr{condition} INDENT NEWLINE statements{body[]} UNINDENT'
  ]

  _TypeDef_: [
    '_ID_{name} TWO_COLON _TypeWithContext_{type}'
  ]
  _TypeWithContext_: [
    'typeContext{context[]} anytype{type}'
  ]
  typeContext: [
    'LEFT_PAREN (_Typeclass_ (COMMA _Typeclass_)*) RIGHT_PAREN DOUBLE_RIGHT_ARROW'
    'EMPTY'
  ]
  _Typeclass_: [
    '_ID_{class} _ID_{anonType}'
  ]

  _Assignment_: [
    '_Assignable_{target} EQUALS fnDefOrExpr{source}'
  ]
  _Assignable_: [
    '_Variable_{base} varExt*{exts[]}'
  ]
  _Variable_: [
    '_ID_{id}'
  ]
  varExt: [
    'LEFT_SQUARE expr RIGHT_SQUARE'
    'DOT _ID_'
  ]

  fnDefOrExpr: [
    '_FunctionDef_'
    'expr'
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

  nonOpExpr: [
    '_OpParenGroup_'
    '_Array_'
    '_ArrayRange_'
    '_Object_'
    '_BOOLEAN_'
    '_Constructed_'
    '_Destruction_'
    '_VarOrFnCall_'
    '_String_'
    '_Wast_'
    '_NUMBER_'
  ]

  _OpParenGroup_: [
    'LEFT_PAREN _OpExpression_{opExpr} RIGHT_PAREN'
  ]

  _Array_: [
    'LEFT_SQUARE argListInner{items[]} RIGHT_SQUARE'
  ]
  _ArrayRange_: [
    'LEFT_SQUARE expr{start} TWO_DOT expr{end} RIGHT_SQUARE'
    'LEFT_SQUARE expr{start} TWO_DOT _EMPTY_{end} RIGHT_SQUARE'
    'LEFT_SQUARE _EMPTY_{start} TWO_DOT expr{end} RIGHT_SQUARE'
    'LEFT_SQUARE _EMPTY_{start} TWO_DOT _EMPTY_{end} RIGHT_SQUARE'
  ]

  _Object_: [
    'LEFT_CURLY objBody{props[]}'
  ]
  objBody: [
    '_ObjectProp_ (COMMA _ObjectProp_)* RIGHT_CURLY'
    'INDENT NEWLINE _ObjectProp_ (NEWLINE _ObjectProp_)* UNINDENT NEWLINE RIGHT_CURLY'
    'EMPTY RIGHT_CURLY'
  ]
  _ObjectProp_: [
    '_ID_{key} COLON expr{val}'
  ]

  _VarOrFnCall_: [
    '_Variable_{base} varExtOrArgList*{exts[]}'
    'LEFT_PAREN _FunctionDef_{base} RIGHT_PAREN (_ArgList_ varExtOrArgList*){exts[]}'
  ]
  varExtOrArgList: [
    'varExt'
    '_ArgList_'
  ]
  _ArgList_: [
    'LEFT_PAREN argListInner{args[]} RIGHT_PAREN'
  ]
  argListInner: [
    'fnDefOrExpr (COMMA fnDefOrExpr)*'
    'EMPTY'
  ]

  _Constructed_: [
    '_ID_{constructor} SPACE LEFT_PAREN _Constructed_{param} RIGHT_PAREN'
    '_ID_{constructor} SPACE nonOpExpr{param}'
  ]

  _Destruction_: [
    '_VarOrFnCall_{boxed} EQUALS_VBAR _Constructed_{unboxed}'
    '_VarOrFnCall_{boxed} EQUALS_VBAR _ID_{unboxed}'
  ]

  _String_: [
    'SINGLE_QUOTE singleQuoteString{fragments[]} SINGLE_QUOTE',
    'DOUBLE_QUOTE doubleQuoteString{fragments[]} DOUBLE_QUOTE'
  ]
  _DoubleQuoteString_: [
    'DOUBLE_QUOTE doubleQuoteString{fragments[]} DOUBLE_QUOTE'
  ]
  singleQuoteString: [
    '_ESCAPED_SINGLE_QUOTES_ singleQuoteString'
    '_STRING_NO_SINGLE_QUOTE_ singleQuoteString'
    'EMPTY'
  ]
  doubleQuoteString : [
    '_ESCAPED_DOUBLE_QUOTES_ doubleQuoteString'
    '_STRING_NO_DOUBLE_QUOTE_ doubleQuoteString'
    'EMPTY'
  ]

  _Wast_: [
    'LEFT_PAREN ANY_SPACE _Sexpr_{sexpr} ANY_SPACE RIGHT_PAREN'
  ]
  _Sexpr_: [
    'LEFT_PAREN ANY_SPACE sexprSymbols{symbols[]} ANY_SPACE RIGHT_PAREN'
  ]
  sexprSymbols: [
    'sexprSymbol ANY_SPACE sexprSymbols'
    'EMPTY'
  ]
  sexprSymbol: [
    '_Sexpr_'
    '_Assignable_'
    '_ID_REF_'
    '_DoubleQuoteString_'
    '_NUMBER_'
  ]

  _FunctionDef_: [
    'argDefList{args[]} fnDef0{body[]}'
    'EMPTY{args[]} fnDef0{body[]}'
  ]
  argDefList: [
    'LEFT_PAREN _FunctionDefArg_ (COMMA _FunctionDefArg_)* RIGHT_PAREN'
  ]
  _FunctionDefArg_: [
    '_ID_{id} EQUALS fnDefOrExpr{default}'
    '_ID_{id} _EMPTY_{default}'
  ]
  fnDef0: [
    'RIGHT_ARROW INDENT _NEWLINE_ statements UNINDENT'
    'RIGHT_ARROW _EMPTY_ statement'
  ]

  NEWLINE: '[ \t\n]*\n'
  _NEWLINE_: '[ \t\n]*\n'
  ANY_SPACE: '[ \t\n]*'
  TYPE: 'type '
  TYPEALIAS: 'typealias '
  TYPECLASS: 'typeclass '
  TYPEINST: 'typeinst '
  RETURN_PTR: 'return_ptr '
  RETURN: 'return '
  IF: 'if '
  WHILE: 'while '
  ELSE: 'else'
  EQUALS: '='
  EQUALS_VBAR: '=\\|'
  DOT: '\\.'
  COLON: ':'
  _ID_: '[@_$a-zA-Z][_$a-zA-Z0-9]*'
  _ID_REF_: '&[@_$a-zA-Z][_$a-zA-Z0-9]*'
  _NUMBER_: '[0-9]+(\\.[0-9]*)?'
  _BOOLEAN_: '(true|false)'
  LEFT_PAREN: '\\('
  RIGHT_PAREN: '\\)'
  LEFT_SQUARE: '\\['
  RIGHT_SQUARE: '\\]'
  LEFT_CURLY: '{'
  RIGHT_CURLY: '}'
  LEFT_ANGLE: '<'
  RIGHT_ANGLE: '>'
  VBAR: '\\|'
  TWO_COLON: '::'
  TWO_DOT: '\\.\\.'
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
  LTE: '<='
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
  DOUBLE_RIGHT_ARROW: '=>'
  INDENT: ''
  UNINDENT: ''
  SPACE: ''
  _EMPTY_: ''
  EMPTY: ''
}

class GrammarRule
  RULE_SEQS:
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
      for token in pattern
        if token.astChildKey?
          patternASTChildren[token.astChildKey] = true
      if astChildren?
        for key, t of astChildren
          if key not of patternASTChildren
            throw {
              userError: false
              msg: "A pattern for #{@name} is missing ast child #{key}"
            }
        for key, t of patternASTChildren
          if key not of astChildren
            throw {
              userError: false
              msg: "A pattern for #{@name} is missing ast child #{key}"
            }
      else
        astChildren = patternASTChildren
    return

  _parsePatternString: (patternString) ->
    @patternStringToParse = patternString
    @parenDepth = 0
    tokens = @_parseTokens()
    if @parenDepth != 0
      throw {
        userError: false
        msg: "Pattern #{patternString} has mismatched parentheses"
      }
    delete @patternStringToParse
    delete @parenDepth
    return tokens

  _createToken: (t = {}) ->
    return {
      name: t.name ? null
      astChildKey: t.astChildKey ? null
      astChildIsArray: t.astChildIsArray ? false
      isGroup: t.isGroup ? false
      subtokens: t.subtokens ? null
    }

  _parseTokens: ->
    tokens = []
    while @patternStringToParse.length > 0
      foundRightParen = false
      wipToken = @_createToken()
      [ruleSeqName, ruleSeqVal] = @_getNextRuleSeq()
      if ruleSeqName == 'WHITESPACE'
        continue
      else if ruleSeqName == 'ID'
        wipToken.name = ruleSeqVal
        foundRightParen = @_parseTokenSuffix(wipToken)
      else if ruleSeqName == 'LEFT_PAREN'
        @parenDepth++
        wipToken.isGroup = true
        wipToken.subtokens = @_parseTokens()
        foundRightParen = @_parseTokenSuffix(wipToken)
      else
        throw {
          userError: false
          msg: "Rule token #{ruleSeqName} (#{ruleSeqVal}) cannot start a pattern"
        }
      tokens.push(wipToken)
      if foundRightParen
        break
    return tokens

  _parseTokenSuffix: (wipToken) ->
    while @patternStringToParse.length > 0
      [ruleSeqName, ruleSeqVal] = @_getNextRuleSeq()
      if ruleSeqName == 'WHITESPACE'
        break
      else if ruleSeqName == 'STAR'
        @_createStarToken(wipToken)
      else if ruleSeqName == 'LEFT_CURLY_BRACE'
        @_parseASTChild(wipToken)
      else if ruleSeqName == 'RIGHT_PAREN'
        if @parenDepth <= 0
          throw {
            userError: false
            msg: "Extra right parenthesis while parsing: #{@patternStringToParse}"
          }
        @parenDepth--
        return true
      else
        throw {
          userError: false
          msg: "Rule token #{ruleSeqName} (#{ruleSeqVal}) cannot be suffix"
        }
    return false

  ###
    Make wipToken into a new token that translates to 'zero or more of the current wipToken'.
    To do this, we have to add an entirely new GrammarRule that has this new token's name.
    If the current token is a group, then the new rule will look like this:
    newRule.patterns = [
      [<oldToken.subtokens> <newRule token>]
      [<EMPTY token>]
    ]
    If the current token is not a group, then the new rule will look like this:
    newRule.patterns = [
      [<oldToken> <newRule token>]
      [<EMPTY token>]
    ]
  ###
  _createStarToken: (wipToken) ->
    # First, either grab the wipToken.subtokens or take a copy of wipToken itself as the
    # tokens for the subrule
    subrulePattern = if wipToken.isGroup then wipToken.subtokens else [@_createToken(wipToken)]
    # Make wipToken into essentially a new token by giving it a new name
    # Make sure name is unique using anonStartIdx
    ogName = if wipToken.isGroup then 'group' else wipToken.name
    wipToken.name = "star_#{ogName}_#{anonStarIdx}"
    wipToken.isGroup = false
    wipToken.subtokens = null
    anonStarIdx++
    # Add a recursive reference to this token to the end of the subrule
    subrulePattern = subrulePattern.concat(@_createToken(wipToken))
    # Make sure no subTokens think they have {astChild} modifiers
    for token in subrulePattern
      token.astChildKey = null
      token.astChildIsArray = false
    # Initialize the GrammarRule with no patterns
    subrule = new GrammarRule(wipToken.name, '')
    # Manually set the patterns as specified in the comment above this function
    subrule.patterns = [subrulePattern, [@_createToken({name: 'EMPTY'})]]
    # Add this GrammarRule to the global grammar object
    grammar[wipToken.name] = subrule
    return

  _parseASTChild: (wipToken) ->
    [ruleSeqName, ruleSeqVal] = @_getNextRuleSeq()
    if ruleSeqName != 'ID'
      throw {
        userError: false
        msg: "Rule token #{ruleSeqName} (#{ruleSeqVal}) cannot start AST child"
      }
    wipToken.astChildKey = ruleSeqVal
    [ruleSeqName, ruleSeqVal] = @_getNextRuleSeq()
    if ruleSeqName == 'SQUARE_BRACKETS'
      wipToken.astChildIsArray = true
      [ruleSeqName, ruleSeqVal] = @_getNextRuleSeq()
    if ruleSeqName != 'RIGHT_CURLY_BRACE'
      throw {
        userError: false
        msg: "Rule seq #{ruleSeqName} (#{ruleSeqVal}) cannot end AST child"
      }
    return

  _getNextRuleSeq: ->
    for name, regex of @RULE_SEQS
      match = @patternStringToParse.match(new RegExp("^#{regex}"))
      if match?
        @patternStringToParse = @patternStringToParse[match[0].length..]
        return [name, match[0]]
    throw {
      userError: false
      msg: "No valid rule token found while parsing: #{@patternStringToParse}"
    }

anonStarIdx = 0
grammar = {}
for name, patternStrings of GRAMMAR
  grammar[name] = new GrammarRule(name, patternStrings)

module.exports = grammar
