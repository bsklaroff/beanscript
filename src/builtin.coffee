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

  FN_CALL_MAP:
    $print: 'print'

  fns:
    print: (res, [x]) ->
      wast = ''
      if x.type == Symbol.TYPES.I32
        wast += "(call_import $print_i32 (i32.const 32))\n"
        wast += "(call_import $print_i32 (get_local #{x.name}))\n"
        return wast
      else if x.type == Symbol.TYPES.I64
        wast += "(call_import $print_i64 (i64.const 64))\n"
        wast += "(call_import $print_i64 (get_local #{x.name}))\n"
        wast += "(call_import $print_i64 (i64.shr_u (get_local #{x.name}) (i64.const 32)))\n"
        return wast
      throw new Error("Fn print not defined for type #{x.type}")
      return wast

    assign: (target, source) ->
      if target.type == Symbol.TYPES.FN and source.type == Symbol.TYPES.FN
        return ''
      wast = ";;#{target.name} = #{source.name}\n"
      if (target.type == Symbol.TYPES.I32 and source.type == Symbol.TYPES.I32) or
         (target.type == Symbol.TYPES.I64 and source.type == Symbol.TYPES.I64)
        wast += "(set_local #{target.name} (get_local #{source.name}))\n"
        return wast
      throw new Error("Fn assign not defined for types #{target.type}, #{source.type}")
      return

    add: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} + #{b.name}\n"
      if res.type == Symbol.TYPES.I32 and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.I64 and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast +=  "(set_local #{res.name} (i64.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    mul: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} * #{b.name}\n"
      if res.type == Symbol.TYPES.I32 and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.I64 and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast +=  "(set_local #{res.name} (i64.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn times not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    lte: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} <= #{b.name}\n"
      if res.type == Symbol.TYPES.BOOL and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.BOOL and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast +=  "(set_local #{res.name} (i64.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

module.exports = builtin
