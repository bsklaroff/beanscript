types = {
  PARSER: 'parser'
}


userError = (type, loc) ->
  throw {
    userError: true
    type: type
    loc: loc
  }


panic = (msg) ->
  console.error("########################")
  console.error("###  COMPILER ERROR  ###")
  console.error("########################")
  throw new Error(msg)


handleError = (e, prelude, inputStr) ->
  if not e.userError
    console.error(e.stack ? JSON.stringify(e))
    return

  if e.type == types.PARSER
    [line, lineNum, charNum, inPrelude] = _findErrorPos(e.loc, prelude, inputStr)
    inputType = if inPrelude then 'prelude' else 'user input'
    console.error("Parse error, line #{lineNum + 1}:#{charNum + 1} of #{inputType}")
    console.error(line)
    pointerStr = ''
    for i in [0...charNum]
      pointerStr += ' '
    pointerStr += '^'
    console.error(pointerStr)


_findErrorPos = (loc, prelude, inputStr) ->
  for line, i in prelude.split('\n')
    if loc < line.length
      return [line, i, loc, true]
    loc -= line.length + 1
  for line, i in inputStr.split('\n')
    if loc < line.length
      return [line, i, loc, false]
    loc -= line.length + 1
  panic("Error position #{loc} out of bounds of input")


module.exports = {
  types: types
  userError: userError
  panic: panic
  handleError: handleError
}

