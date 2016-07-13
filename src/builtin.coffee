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
      wast = ";;print(#{x.name})\n"
      if x.type == Symbol.TYPES.I32
        wast += "(call_import $print_i32 (i32.const 32))\n"
        wast += "(call_import $print_i32 (get_local #{x.name}))\n"
        return wast
      else if x.type == Symbol.TYPES.I64
        wast += "(call_import $print_i32 (i32.const 64))\n"
        wast += "(call_import $print_i32 (get_local #{x.lowWord}))\n"
        wast += "(call_import $print_i32 (get_local #{x.highWord}))\n"
        return wast
      throw new Error("Fn print not defined for type #{x.type}")
      return wast

    assign: (target, source) ->
      wast = ";;#{target.name} = #{source.name}\n"
      if target.type == Symbol.TYPES.I32 and source.type == Symbol.TYPES.I32
        wast += "(set_local #{target.name} (get_local #{source.name}))\n"
        return wast
      else if target.type == Symbol.TYPES.I64 and source.type == Symbol.TYPES.I64
        wast += "(set_local #{target.lowWord} (get_local #{source.lowWord}))\n"
        wast += "(set_local #{target.highWord} (get_local #{source.highWord}))\n"
        return wast
      throw new Error("Fn assign not defined for types #{target.type}, #{source.type}")
      return

    add: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} + #{b.name}\n"
      if res.type == Symbol.TYPES.I32 and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.I64 and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast += "(set_local #{res.lowWord} (i32.add (get_local #{a.lowWord}) (get_local #{b.lowWord})))\n"
        wast += "(set_local #{res.highWord} (i32.add (get_local #{a.highWord}) (get_local #{b.highWord})))\n"
        # Check for overflow of low word
        wast += "(if (i32.lt_u (get_local #{res.lowWord}) (get_local #{a.lowWord}))\n"
        wast += "  (then (set_local #{res.highWord} (i32.add (get_local #{res.highWord}) (i32.const 1))))\n"
        wast += ")\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

module.exports = builtin
