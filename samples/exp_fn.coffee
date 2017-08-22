exports.expFn = expFn = {}
expFn.program = '''
console.log('start')
b = (n) ->
  return n ** n
console.log(b(23))
'''
expFn.ast =
  _Program_:
    statements: [
      _FunctionCall_:
        fnName:
          _Variable_:
            varNames: [
              _ID_: 'console'
            ,
              _ID_: 'log'
            ]
        argList: [
          _String_:
            fragments: [
              _STRING_NO_SINGLE_QUOTE_: 'start'
            ]
        ]
    ,
      _Assignment_:
        target:
          _Variable_:
            varNames: [
              _ID_: 'b'
            ]
        source:
          _FunctionDef_:
            args: [
              _ID_: 'n'
            ]
            body: [
              _Return_:
                returnVal:
                  _OpExpression_:
                    lhs:
                      _Variable_:
                        varNames: [
                          _ID_: 'n'
                        ]
                    op:
                      _EXPONENT_: '**'
                    rhs:
                      _Variable_:
                        varNames: [
                          _ID_: 'n'
                        ]
            ]
    ,
      _FunctionCall_:
        fnName:
          _Variable_:
            varNames: [
              _ID_: 'console'
            ,
              _ID_: 'log'
            ]
        argList: [
          _FunctionCall_:
            fnName:
              _Variable_:
                varNames: [
                  _ID_: 'b'
                ]
            argList: [
              _NUMBER_: '23'
            ]
        ]
    ]
