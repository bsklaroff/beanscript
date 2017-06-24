exports.map = (arr, fn) ->
  res = []
  for x in arr
    res.push(fn(x))
  return res

module.exports = exports
