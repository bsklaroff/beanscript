exports.map = (arr, fn) ->
  res = []
  for x in arr
    res.push(fn(x))
  return res

exports.keys = (obj) ->
  return Object.keys(obj)

exports.values = (obj) ->
  return exports.map(exports.keys(obj), (k) -> obj[k])

exports.cloneDeep = (obj) ->
  return JSON.parse(JSON.stringify(obj))

exports.intersect = (a0, a1) ->
  res = []
  for x in a0
    if x in a1
      res.push(x)
  return res

exports.isString = (x) -> typeof x == 'string' or x instanceof String

exports.isArray = (x) -> Object.prototype.toString.call(x) == '[object Array]'

exports.isObject = (x) -> Object.prototype.toString.call(x) == '[object Object]' and x == Object(x)

exports.equals = (a0, a1) ->
  if isNaN(a0) and isNaN(a1) && typeof a0 == 'number' && typeof a1 == 'number'
    return true

  if a0 == a1
    return true

  if exports.isArray(a0) and exports.isArray(a1) and a0.length == a1.length
    for x, i in a0
      if not exports.equals(x, a1[i])
        return false
    return true

  if exports.isObject(a0) and exports.isObject(a1)
    if not exports.equals(Object.keys(a0), Object.keys(a1))
      return false
    for k, v of a0
      if not exports.equals(v, a1[k])
        return false
    return true

  return false

module.exports = exports
