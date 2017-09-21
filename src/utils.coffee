exports.map = (arr, fn) ->
  res = []
  for x in arr
    res.push(fn(x))
  return res

exports.intersect = (a0, a1) ->
  res = []
  for x in a0
    if x in a1
      res.push(x)
  return res

module.exports = exports
