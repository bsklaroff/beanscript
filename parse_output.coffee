stdin = process.openStdin()

stdin.on('data', (input) ->
  for line in input.toString().split('\n')
    line = line.trim()
    if line.length > 0
      typedPrint(parseInt(line))
  return
)

curPrintType = null
tmpArr = null
arrType = null
arrLength = null
tmpLow = null

typedPrint = (x) ->
  if not curPrintType?
    curPrintType = x
  # Arr
  else if curPrintType == 23
    if not arrType?
      tmpArr = []
      arrType = x
    else if not arrLength?
      arrLength = x
      # Special case 0 length arrays
      if arrLength == 0
        console.log('[]')
        curPrintType = null
        tmpArr = null
        arrType = null
        arrLength = null
    else
      if arrType == 32
        tmpArr.push(x)
        arrLength--
      else if arrType == 64
        if not tmpLow?
          tmpLow = x
        else
          tmpArr.push(getI64(tmpLow, x))
          tmpLow = null
          arrLength--
      if arrLength == 0
        outputStr = '[ '
        for item in tmpArr
          outputStr += "#{item}, "
        outputStr = outputStr[...-2]
        outputStr += ' ]'
        console.log(outputStr)
        tmpArr = null
        arrType = null
        arrLength = null
        curPrintType = null
  # I32
  else if curPrintType == 32
    console.log(x)
    curPrintType = null
  # I64
  else if curPrintType == 64
    if not tmpLow?
      tmpLow = x
    else
      console.log(getI64(tmpLow, x))
      tmpLow = null
      curPrintType = null

getI64 = (tmpLow, x) ->
  highStr = (x >>> 0).toString(2)
  lowStr = (tmpLow >>> 0).toString(2)
  # Check for negative number
  if highStr.length == 32 && highStr[0] == '1'
    return '-' + sumHighLowStrs(highStr.slice(1), lowStr)
  return sumHighLowStrs(highStr, lowStr)

sumHighLowStrs = (highBinaryStr, lowBinaryStr) ->
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
