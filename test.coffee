{execSync} = require('child_process')
fs = require('fs')
path = require('path')
bs = require('./main')
utils = require('./src/utils')


findFiles = (baseDir) ->
  res = []
  for fname in fs.readdirSync(baseDir)
    fpath = "#{baseDir}/#{fname}"
    if fs.statSync(fpath).isDirectory()
      res = res.concat(findFiles(fpath))
    else if path.extname(fpath) == '.bs'
      res.push(fpath)
  return res


filterFiles = (files, filter) ->
  res = []
  for fpath in files
    if fpath.match(filter)
      res.push(fpath)
  return res


testDir = "#{__dirname}/test"
testFiles = findFiles(testDir)
if process.argv.length >= 3
  testFiles = filterFiles(testFiles, process.argv[2])

for fpath in testFiles
  stderrFile = execSync('mktemp').toString().trim()
  wastFile = execSync('mktemp').toString().trim()
  wasmFile = execSync('mktemp').toString().trim()

  try
    execSync("coffee #{__dirname}/main.coffee #{fpath} > #{wastFile} 2> #{stderrFile}")
  stderr = execSync("cat #{stderrFile}").toString()
  stdout = ''
  outputExists = execSync("if [[ -s #{wastFile} ]]; then echo 'yes'; fi").toString()
  if outputExists.trim() == 'yes'
    execSync("wast2wasm #{wastFile} -o #{wasmFile}")
    stdout = execSync("node #{__dirname}/runwasm.js #{wasmFile}").toString()

  execSync("rm #{stderrFile}")
  execSync("rm #{wastFile}")
  execSync("rm #{wasmFile}")

  expectedOut = ''
  expectedErr = ''
  outFpath = "#{fpath[...-3]}.stdout"
  if fs.existsSync(outFpath)
    expectedOut = fs.readFileSync(outFpath).toString()
  errFpath = "#{fpath[...-3]}.stderr"
  if fs.existsSync(errFpath)
    expectedErr = fs.readFileSync(errFpath).toString()

  fname = fpath[testDir.length+1..]
  if stdout != expectedOut
    console.log("FAILED: #{fname}")
    console.log("STDOUT:\n#{stdout}")
    console.log("EXPECTED:\n#{expectedOut}")
  else if stderr != expectedErr
    console.log("FAILED: #{fname}")
    console.log("STDERR:\n#{stderr}")
    console.log("EXPECTED:\n#{expectedErr}")
  else
    console.log("PASSED: #{fname}")
