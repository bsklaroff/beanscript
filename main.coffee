fs = require('fs')
handleError = require('./src/handle_error')
utils = require('./src/utils')

usageMessage = '''
Usage: coffee main.coffee [OPTIONS] FILE
Options (cannot be combined):
  -a      Output astTree
  -s      Output symbol table
  -t      Output inferred types
'''

_execArgs = (args) ->
  if args.usageError?
    console.error("Usage Error: #{args.usageError}\n")
    console.error(usageMessage)
    process.exit(1)

  try
    Parser = require('./src/parser')
    addOnelineFnReturns = require('./src/tree_transform/add_oneline_fn_returns')
    fixOpPrecedence = require('./src/tree_transform/fix_op_precedence')
    replaceOpsWithFnCalls = require('./src/tree_transform/replace_ops_with_fn_calls')
    rewriteVarExts = require('./src/tree_transform/rewrite_var_exts')
    amendTypeclasses = require('./src/tree_transform/amend_typeclasses')
    assignASTIds = require('./src/tree_transform/assign_ast_ids')
    genSymbols = require('./src/gen_symbols')
    inferTypes = require('./src/infer_types')
    genWast = require('./src/gen_wast')

    prelude = fs.readFileSync("#{__dirname}/src/prelude.bs").toString()
    inputStr = fs.readFileSync(args.filename).toString()

    parser = new Parser()

    astTree = parser.parse(prelude + inputStr)
    astTree = addOnelineFnReturns(astTree)
    astTree = fixOpPrecedence(astTree)
    astTree = replaceOpsWithFnCalls(astTree)
    astTree = rewriteVarExts(astTree)
    astTree = amendTypeclasses(astTree)
    astTree = assignASTIds(astTree)
    if 'a' in args.flags
      return astTree

    symbolTable = genSymbols(astTree)
    if 's' in args.flags
      return symbolTable

    typeInfo = inferTypes(astTree, symbolTable)
    if 't' in args.flags
      return typeInfo

    wast = genWast(astTree, symbolTable, typeInfo)
    return wast

  catch e
    handleError(e, prelude, inputStr)
    process.exit(1)

_parseArgs = (argv) ->
  filename = null
  flags = []
  for arg in argv
    if arg[0] == '-'
      flags = flags.concat(char for char in arg[1..])
    else if filename?
      return {usageError: "Multiple FILE args #{filename}, #{arg}"}
    else
      filename = arg
  if not filename?
    return {usageError: "No FILE arg found"}
  outputFlags = utils.intersect(['a', 's'], flags)
  if outputFlags.length > 1
    return {usageError: "Multiple OPTIONS #{outputFlags.join(', ')}"}
  return {
    filename: filename
    flags: flags
  }

main = (argv) -> _execArgs(_parseArgs(argv))

module.exports = exports = {
  main: main
}

if require.main == module
  # JSON.stringify output unless it is a string already
  output = main(process.argv[2..])
  if typeof output == 'string'
    console.log(output)
  else
    console.log(JSON.stringify(output, null, 2))
