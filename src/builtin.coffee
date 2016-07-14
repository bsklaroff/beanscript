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

    mul: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} * #{b.name}\n"
      if res.type == Symbol.TYPES.I32 and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.I64 and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast += "(set_local $$t0 (i32.and (get_local #{a.lowWord}) (i32.const 65535)))\n"
        wast += "(set_local $$t1 (i32.shr_u (get_local #{a.lowWord}) (i32.const 16)))\n"
        wast += "(set_local $$t2 (i32.and (get_local #{a.highWord}) (i32.const 65535)))\n"
        wast += "(set_local $$t3 (i32.shr_u (get_local #{a.highWord}) (i32.const 16)))\n"
        wast += "(set_local $$t4 (i32.and (get_local #{b.lowWord}) (i32.const 65535)))\n"
        wast += "(set_local $$t5 (i32.shr_u (get_local #{b.lowWord}) (i32.const 16)))\n"
        wast += "(set_local $$t6 (i32.and (get_local #{b.highWord}) (i32.const 65535)))\n"
        wast += "(set_local $$t7 (i32.shr_u (get_local #{b.highWord}) (i32.const 16)))\n"
        # Calculate 0*4=>res.lowWord; 1*4=>8; 0*5=>9; 8+9=>10
        wast += "(set_local #{res.lowWord} (i32.mul (get_local $$t0) (get_local $$t4)))\n"
        wast += "(set_local $$t8 (i32.mul (get_local $$t1) (get_local $$t4)))\n"
        wast += "(set_local $$t9 (i32.mul (get_local $$t0) (get_local $$t5)))\n"
        wast += "(set_local $$t10 (i32.add (get_local $$t8) (get_local $$t9)))\n"
        # Check for overflow of 8 + 9
        wast += "(if (i32.lt_u (get_local $$t10) (get_local $$t8))\n"
        wast += "  (then (set_local #{res.highWord} (i32.const 65536)))\n"
        wast += "  (else (set_local #{res.highWord} (i32.const 0)))\n"
        wast += ")\n"
        # Reuse 8 as low half of 10 shifted into high position, then res.lowWord += 8
        wast += "(set_local $$t8 (i32.shl (get_local $$t10) (i32.const 16)))\n"
        wast += "(set_local #{res.lowWord} (i32.add (get_local #{res.lowWord}) (get_local $$t8)))\n"
        # Check for overflow of res.lowWord + t8
        wast += "(if (i32.lt_u (get_local #{res.lowWord}) (get_local $$t8))\n"
        wast += "  (then (set_local #{res.highWord} (i32.add (get_local #{res.highWord}) (i32.const 1))))\n"
        wast += ")\n"
        # From now on we don't have to worry about overflow because we're dealing with res.highWord
        # Reuse 8 as high half of 10 shifted into low position, then res.highWord += 8
        wast += "(set_local $$t8 (i32.shr_u (get_local $$t10) (i32.const 16)))\n"
        wast += "(set_local #{res.highWord} (i32.add (get_local #{res.highWord}) (get_local $$t8)))\n"
        # Calculate 2*4=>8; 1*5=>9; 8+9=>10
        wast += "(set_local $$t8 (i32.mul (get_local $$t2) (get_local $$t4)))\n"
        wast += "(set_local $$t9 (i32.mul (get_local $$t1) (get_local $$t5)))\n"
        wast += "(set_local $$t10 (i32.add (get_local $$t8) (get_local $$t9)))\n"
        # Calculate 0*6=>8; 8+10=>9, res.highWord += 9
        wast += "(set_local $$t8 (i32.mul (get_local $$t0) (get_local $$t6)))\n"
        wast += "(set_local $$t9 (i32.add (get_local $$t8) (get_local $$t10)))\n"
        wast += "(set_local #{res.highWord} (i32.add (get_local #{res.highWord}) (get_local $$t9)))\n"
        # Calculate 3*4=>8; 2*5=>9, 8+9=>10
        wast += "(set_local $$t8 (i32.mul (get_local $$t3) (get_local $$t4)))\n"
        wast += "(set_local $$t9 (i32.mul (get_local $$t2) (get_local $$t5)))\n"
        wast += "(set_local $$t10 (i32.add (get_local $$t8) (get_local $$t9)))\n"
        # Calculate 1*6=>8; 0*7=>9, 8+9=>0, 0+10=>1
        wast += "(set_local $$t8 (i32.mul (get_local $$t1) (get_local $$t6)))\n"
        wast += "(set_local $$t9 (i32.mul (get_local $$t0) (get_local $$t7)))\n"
        wast += "(set_local $$t0 (i32.add (get_local $$t8) (get_local $$t9)))\n"
        wast += "(set_local $$t1 (i32.add (get_local $$t0) (get_local $$t10)))\n"
        # Reuse 2 as low have of 1 shifted into high position, then res.highWord += 2
        wast += "(set_local $$t2 (i32.shl (get_local $$t1) (i32.const 16)))\n"
        wast += "(set_local #{res.highWord} (i32.add (get_local #{res.highWord}) (get_local $$t2)))\n"
        return wast
      throw new Error("Fn times not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

    lte: (res, a, b) ->
      wast = ";;#{res.name} = #{a.name} <= #{b.name}\n"
      if res.type == Symbol.TYPES.BOOL and a.type == Symbol.TYPES.I32 and b.type == Symbol.TYPES.I32
        wast +=  "(set_local #{res.name} (i32.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type == Symbol.TYPES.BOOL and a.type == Symbol.TYPES.I64 and b.type == Symbol.TYPES.I64
        wast += "(set_local #{res.lowWord} (i32.or\n"
        wast += "  (i32.lt_s (get_local #{a.highWord}) (get_local #{b.highWord}))\n"
        wast += "  (i32.and\n"
        wast += "    (i32.eq (get_local #{a.highWord}) (get_local #{b.highWord}))\n"
        wast += "    (i32.le_u (get_local #{a.lowWord}) (get_local #{b.lowWord}))\n"
        wast += "  )\n"
        wast += ")\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type}, #{a.type}, #{b.type}")
      return

module.exports = builtin
