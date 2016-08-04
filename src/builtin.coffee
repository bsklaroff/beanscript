Symbol = require('./symbol')

builtin =
  OP_MAP:
    _EXPONENT_: 'exp'
    _MOD_: 'mod'
    _TIMES_: 'mul'
    _DIVIDED_BY_: 'div'
    _PLUS_: 'add'
    _MINUS_: 'sub'
    _EQUALS_EQUALS_: 'eq'
    _NOT_EQUALS_: 'neq'
    _LTE_: 'lte'
    _LT_: 'lt'
    _GTE_: 'gte'
    _GT_: 'gt'
    _AND_: 'and'
    _OR_: 'or'
    _NEG_: 'neg'

  FN_CALL_MAP:
    $print: 'print'

  fns:
    print: (res, [x]) ->
      wast = ''
      if x.type.isI32()
        wast += "(call_import $print_i32 (i32.const 32))\n"
        wast += "(call_import $print_i32 (get_local #{x.name}))\n"
        return wast
      else if x.type.isI64()
        wast += "(call_import $print_i64 (i64.const 64))\n"
        wast += "(call_import $print_i64 (get_local #{x.name}))\n"
        wast += "(call_import $print_i64 (i64.shr_u (get_local #{x.name}) (i64.const 32)))\n"
        return wast
      throw new Error("Fn print not defined for type #{x.type}")
      return wast

    assign: (target, source) ->
      if target.type.isFn() and source.type.isFn()
        return ''
      wast = ";;#{target.name} = #{source.name}\n"
      if (target.type.isI32() and source.type.isI32()) or
         (target.type.isI64() and source.type.isI64())
        wast += "(set_local #{target.name} (get_local #{source.name}))\n"
        return wast
      throw new Error("Fn assign not defined for types #{target.type}, #{source.type}")
      return

    add: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} + #{b.name}\n"
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    sub: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} - #{b.name}\n"
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.sub (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.sub (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn sub not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    mul: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} * #{b.name}\n"
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn times not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    lte: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} <= #{b.name}\n"
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn lte not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    gte: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} => #{b.name}\n"
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.ge_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.ge_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn gte not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

module.exports = builtin
