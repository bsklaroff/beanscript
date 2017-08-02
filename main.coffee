handleError = require('./src/handle_error')

try
  Parser = require('./src/parser')
  addOnelineFnReturns = require('./src/tree_transform/add_oneline_fn_returns')
  fixOpPrecedence = require('./src/tree_transform/fix_op_precedence')
  replaceOpsWithFns = require('./src/tree_transform/replace_ops_with_fns')
  genASTIds = require('./src/tree_transform/gen_ast_ids')
  genTypeInfo = require('./src/gen_type_info')
  SymbolTable = require('./src/symbol_table')
  genSymbols = require('./src/gen_symbols')
  genWast = require('./src/gen_wast')

  fs = require('fs')
  prelude = fs.readFileSync("#{__dirname}/src/prelude.bs").toString()
  inputStr = fs.readFileSync(process.argv[2]).toString()

  parser = new Parser()

  astTree = parser.parse(prelude + inputStr)
  astTree = addOnelineFnReturns(astTree)
  astTree = fixOpPrecedence(astTree)
  astTree = replaceOpsWithFns(astTree)
  astTree = genASTIds(astTree)
  #console.log(JSON.stringify(astTree, null, 2))
  typeInfo = genTypeInfo(astTree)
  #console.log(JSON.stringify(typeInfo, null, 2))
  symbolTable = genSymbols(astTree, new SymbolTable(typeInfo))
  #console.log(JSON.stringify(symbols, null, 2))
  wast = genWast(astTree, symbolTable)
  console.log(wast)

catch e
  handleError(e, prelude, inputStr)
  process.exit(1)
