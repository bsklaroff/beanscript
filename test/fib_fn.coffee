exports.expFn = expFn = {}
expFn.program = '''
fib = (n) ->
  if n == 0 or n == 1
    return 1
  return fib(n - 1) + fib(n - 2)
console.log(fib(5))
'''
expFn.ast =
  _Program_:
    statements: [
      _Assignment_:
        target:
          _Variable_:
            varNames: [
              _ID_: 'fib'
            ]
        source:
          _FunctionDef_:
            args: [
              _ID_: 'n'
            ]
            body: [
              _If_:
                condition:
                  _OpExpression_:
                    lhs:
                      _OpExpression_:
                        lhs:
                          _Variable_:
                            varNames: [
                              _ID_: 'n'
                            ]
                        op:
                          _EQUALS_EQUALS_: '=='
                        rhs:
                          _NUMBER_: '0'
                    op:
                      _OR_: 'or'
                    rhs:
                      _OpExpression_:
                        lhs:
                          _Variable_:
                            varNames: [
                              _ID_: 'n'
                            ]
                        op:
                          _EQUALS_EQUALS_: '=='
                        rhs:
                          _NUMBER_: '1'
                body: [
                  _Return_:
                    returnVal:
                      _NUMBER_: '1'
                ]
                else:
                  _EMPTY_: ''
            ,
              _Return_:
                returnVal:
                  _OpExpression_:
                    lhs:
                      _FunctionCall_:
                        fnName:
                          _Variable_:
                            varNames: [
                              _ID_: 'fib'
                            ]
                        argList: [
                          _OpExpression_:
                            lhs:
                              _Variable_:
                                varNames: [
                                  _ID_: 'n'
                                ]
                            op:
                              _MINUS_: '-'
                            rhs:
                              _NUMBER_: '1'
                        ]
                    op:
                      _PLUS_: '+'
                    rhs:
                      _FunctionCall_:
                        fnName:
                          _Variable_:
                            varNames: [
                              _ID_: 'fib'
                            ]
                        argList: [
                          _OpExpression_:
                            lhs:
                              _Variable_:
                                varNames: [
                                  _ID_: 'n'
                                ]
                            op:
                              _MINUS_: '-'
                            rhs:
                              _NUMBER_: '2'
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
                  _ID_: 'fib'
                ]
            argList: [
              _NUMBER_: '5'
            ]
        ]
    ]
