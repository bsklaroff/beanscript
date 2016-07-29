stdin = process.openStdin()

stdin.on('data', (input) ->
  for line in input.toString().split('\n')
    line = line.trim()
    if line.length > 0
      typedPrint(parseInt(line))
  return
)

curPrintType = null
tmpLow = null

typedPrint = (x) ->
  if not curPrintType?
    curPrintType = x
  else if curPrintType == 32
    console.log(x)
    curPrintType = null
  else if curPrintType == 64
    if not tmpLow?
      tmpLow = x
    else
      highStr = (x >>> 0).toString(2)
      lowStr = (tmpLow >>> 0).toString(2)
      # Check for negative number
      if highStr.length == 32 && highStr[0] == '1'
        console.log('-' + getI64(highStr.slice(1), lowStr))
      else
        console.log(getI64(highStr, lowStr))
      tmpLow = null
      curPrintType = null

getI64 = (highBinaryStr, lowBinaryStr) ->
  lowNum = parseInt(lowBinaryStr, 2)
  highNum = parseInt(highBinaryStr, 2)
  lowStr = lowNum.toString()
  highStr = highNum.toString()
  for j in [0...32]
    highStr = sumStr(highStr, highStr)
  return sumStr(highStr, lowStr)

sumStr = (a, b) ->
  aRev = a.split('').reverse().join('')
  bRev = b.split('').reverse().join('')
  carry = 0
  res = ''
  i = 0
  while i < aRev.length or i < bRev.length or carry != 0
    aDigit = parseInt(aRev.charAt(i))
    if aRev.charAt(i) == ''
      aDigit = 0
    bDigit = parseInt(bRev.charAt(i))
    if bRev.charAt(i) == ''
      bDigit = 0
    digitSum = aDigit + bDigit + carry
    nextDigit = digitSum % 10
    if digitSum > nextDigit
      carry = (digitSum - nextDigit) / 10
    else
      carry = 0
    res = nextDigit.toString() + res
    i++
  return res
