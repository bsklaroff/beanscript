fs = require('fs')
path = require('path')
bs = require('./main')
utils = require('./src/utils')

inputDir = "#{__dirname}/test/input"
typeOutputDir = "#{__dirname}/test/type_output"
for fname in fs.readdirSync(inputDir)
  if path.extname(fname) != '.bs'
    continue
  types = bs.main(["#{inputDir}/#{fname}",  '-t'])
  outputFname = "#{fname[...-3]}.json"
  if not fs.existsSync("#{typeOutputDir}/#{outputFname}")
    console.log(JSON.stringify(types, null, 2))
    console.error("No output file found for #{fname}")
    process.exit(1)
  expected = JSON.parse(fs.readFileSync("#{typeOutputDir}/#{outputFname}"))
  if utils.equals(types, expected)
    console.log("PASSED: #{fname}")
  else
    console.log("FAILED: #{fname}")
    console.log("OUTPUT: #{JSON.stringify(types)}")
    console.log("EXPECTED: #{JSON.stringify(expected)}")
