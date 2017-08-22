fs = require('fs')
path = require('path')
bs = require('./main')
utils = require('./src/utils')

baseDir = "#{__dirname}/test/infer_types"
for fname in fs.readdirSync(baseDir)
  if path.extname(fname) != '.bs'
    continue
  types = bs.main(["#{baseDir}/#{fname}",  '-t'])
  outputFname = "#{fname[...-3]}.json"
  if not fs.existsSync("#{baseDir}/#{outputFname}")
    console.log(JSON.stringify(types, null, 2))
    console.error("No output file found for #{fname}")
    process.exit(1)
  expected = JSON.parse(fs.readFileSync("#{baseDir}/#{outputFname}"))
  if utils.equals(types, expected)
    console.log("PASSED: #{fname}")
  else
    console.log("FAILED: #{fname}")
    console.log("OUTPUT: #{JSON.stringify(types)}")
    console.log("EXPECTED: #{JSON.stringify(expected)}")
