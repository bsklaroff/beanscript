{execSync} = require('child_process')
fs = require('fs')
path = require('path')
bs = require('./main')
utils = require('./src/utils')

testDir = "#{__dirname}/test"
for fname in fs.readdirSync(testDir)
  if path.extname(fname) != '.bs'
    continue
  temp = execSync('mktemp').toString().trim()
  temp2 = execSync('mktemp').toString().trim()
  execSync("coffee #{__dirname}/main.coffee #{testDir}/#{fname} > #{temp}")
  execSync("wast2wasm #{temp} -o #{temp2}")
  stdout = execSync("node #{__dirname}/runwasm.js #{temp2}").toString()
  execSync("rm #{temp}")
  execSync("rm #{temp2}")
  outputFname = "#{fname[...-3]}.stdout"
  if not fs.existsSync("#{testDir}/#{outputFname}")
    console.log("FAILED: #{fname} (no stdout file found)")
    continue
  expected = fs.readFileSync("#{testDir}/#{outputFname}").toString()
  if stdout == expected
    console.log("PASSED: #{fname}")
  else
    console.log("FAILED: #{fname}")
    console.log("OUTPUT:\n#{stdout}")
    console.log("EXPECTED:\n#{expected}")
