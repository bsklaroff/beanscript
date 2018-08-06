handleError = (e, prelude, inputStr) ->
  if e.userError
    if e.type == 'parser'
      [line, lineNum, charNum, inPrelude] = findErrorPos(e.loc, prelude, inputStr)
      inputType = if inPrelude then 'prelude' else 'user input'
      console.error("Parse error, line #{lineNum + 1}:#{charNum + 1} of #{inputType}")
      console.error(line)
      pointerStr = ''
      for i in [0...charNum]
        pointerStr += ' '
      pointerStr += '^'
      console.error(pointerStr)
  else
    console.error(e.stack ? JSON.stringify(e))

findErrorPos = (loc, prelude, inputStr) ->
  for line, i in prelude.split('\n')
    if loc < line.length
      return [line, i, loc, true]
    loc -= line.length + 1
  for line, i in inputStr.split('\n')
    if loc < line.length
      return [line, i, loc, false]
    loc -= line.length + 1
  throw new Error("Error postition #{loc} out of bounds of input")

module.exports = handleError

