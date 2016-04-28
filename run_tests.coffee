checkSameAST = (parsedAST, testAST) ->
  # Check if they're both null
  if parsedAST? and not testAST?
    console.log("Unexpected null value: #{JSON.stringify(parsedAST)}")
    return
  if not parsedAST? and testAST?
    console.log("Expecting null value: #{JSON.stringify(parsedAST)}")
    return
  if not parsedAST? and not testAST?
    return true

  # Check if they're both arrays
  if parsedAST.length? and not testAST.length?
    console.log("Unexpected array: #{JSON.stringify(parsedAST)}")
    return
  if not parsedAST.length? and testAST.length?
    console.log("Expecting array: #{JSON.stringify(parsedAST)}")
    return
  if parsedAST.length? and testAST.length?
    if parsedAST.length != testAST.length
      console.log("Expecting array of length #{testAST.length}, but got: #{JSON.stringify(parsedAST)}")
      return
    allSame = true
    for parsedNode, i in parsedAST
      allSame = allSame and checkSameAST(parsedNode, testAST[i])
    return allSame

  if Object.keys(testAST).length != 1
    console.log("Bad test AST for: #{testAST}")
    return

  testNodeName = Object.keys(testAST)[0]
  if testNodeName != parsedAST.name
    console.log("Expecting #{testNodeName} node, got #{JSON.stringify(parsedAST)}")
    return
  testNodeChildren = testAST[testNodeName]
  if parsedAST.literal?
    if parsedAST.children?
      console.log("Found both literal and children in node: #{JSON.stringify(parsedAST)}")
      return
    if parsedAST.literal != testNodeChildren
      console.log("Failed to match literal #{testNodeChildren}: #{JSON.stringify(parsedAST)}")
      return
  else if not parsedAST.children?
    console.log("Found neither literal nor children in node: #{JSON.stringify(parsedAST)}")
    return
  else
    if Object.keys(parsedAST.children).length != Object.keys(testNodeChildren).length
      console.log("Expecting children of length #{Object.keys(testNodeChildren).length}, but got #{JSON.stringify(parsedAST)}")
      return
    for name, child of parsedAST.children
      if not checkSameAST(child, testNodeChildren[name])
        console.log("Child #{name} failed to match: #{JSON.stringify(child)}")
        return
  return true


fs = require('fs')
Parser = require('./src/parser')

failedCount = 0
totalCount = 0
for fname in fs.readdirSync('test')
  if not fname.endsWith('.coffee')
    continue
  tests = require("./test/#{fname}")
  for testName, test of tests
    parser = new Parser(test.program)
    parser.parse()
    console.log("Testing #{fname[...-'.coffee'.length]}\##{testName}")
    if not checkSameAST(parser.astTree, test.ast)
      console.log('FAILED')
      failedCount++
    totalCount++

console.log("#{totalCount} tests ran")
if failedCount == 0
  console.log('All Passed!')
else
  console.log("#{failedCount} Failed")

