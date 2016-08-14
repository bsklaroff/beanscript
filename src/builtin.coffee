Symbol = require('./symbol')

SHOW_COMMENTS = false

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
        wast += "(call_import $print_i32 (i32.const 64))\n"
        wast += "(call_import $print_i64 (get_local #{x.name}))\n"
        wast += "(call_import $print_i64 (i64.shr_u (get_local #{x.name}) (i64.const 32)))\n"
        return wast
      else if x.type.isArr()
        wast += "(call_import $print_i32 (i32.const 23))\n"
        if x.type.elemType.isI32()
          wast += "(call_import $print_i32 (i32.const 32))\n"
          wast += "(set_local $$t0 (i32.load (i32.add (get_local #{x.name}) (i32.const 4))))\n"
          wast += "(set_local $$t1 (i32.const 0))\n"
          wast += "(call_import $print_i32 (get_local $$t0))\n"
          wast += "(loop $done $loop\n"
          wast += "  (if (i32.eq (get_local $$t0) (get_local $$t1))\n"
          wast += '    (then (br $done))\n'
          wast += "    (else\n"
          offsetStart = "(i32.add (get_local #{x.name}) (i32.const #{Symbol.ARRAY_OFFSET * 4}))"
          offset = "(i32.mul (get_local $$t1) (i32.const 4))"
          wast += "      (call_import $print_i32 (i32.load (i32.add #{offsetStart} #{offset})))\n"
          wast += "      (set_local $$t1 (i32.add (get_local $$t1) (i32.const 1)))\n"
          wast += '      (br $loop)\n'
          wast += '    )\n'
          wast += '  )\n'
          wast += ')\n'
        else if x.type.elemType.isI64()
          wast += "(call_import $print_i32 (i32.const 64))\n"
          wast += "(set_local $$t0 (i32.load (i32.add (get_local #{x.name}) (i32.const 4))))\n"
          wast += "(set_local $$t1 (i32.const 0))\n"
          wast += "(loop $done $loop\n"
          wast += "  (if (i32.eq $$t0 $$t1)\n"
          wast += "    (then\n"
          offsetStart = "(i32.add (get_local #{x.name}) (i32.const #{Symbol.ARRAY_OFFSET * 4}))"
          offset = "(i32.mul (get_local $$t1) (i32.const 8))"
          wast += "      (call_import $print_i64 (i64.load (i32.add #{offsetStart} #{offset})))\n"
          wast += "      (call_import $print_i64 (i64.shr_u (i64.load (i32.add #{offsetStart} #{offset})) (i64.const 32)))\n"
          wast += "      (set_local $$t1 (i32.add (get_local $$t1) (i32.const 1)))\n"
          wast += '      (br $loop)\n'
          wast += '    )\n'
          wast += '    (else (br $done))\n'
          wast += '  )\n'
          wast += ')\n'
          wast += "(call_import $print_i32 (i32.const 64))\n"
          wast += "(call_import $print_i32 (i32.const #{x.type.length}))\n"
        else
          throw new Error("Fn print not defined for array with elements of type #{x.type.elemType.primitive}")
        return wast
      throw new Error("Fn print not defined for type #{x.type.primitive}")
      return wast

    assign: (target, source) ->
      if target.type.isFn() and source.type.isFn()
        return ''
      wast = if SHOW_COMMENTS then ";;#{target.name} = #{source.name}\n" else ''
      if (target.type.isI32() and source.type.isI32()) or
         (target.type.isI64() and source.type.isI64()) or
         (target.type.isArr() and source.type.isArr())
        if target.parentSymbols?
          wast += "(set_local #{target.name} #{target.genMemptr()})\n"
          wast += "(#{target.type.primitive}.store (get_local #{target.name}) (get_local #{source.name}))\n"
          # Set user-facing array length to the max of its current value and this index
          wast += "(set_local $$t0 (i32.add (get_local #{target.parentSymbols[target.parentSymbols.length - 2].name}) (i32.const 4)))\n"
          elemIdx = "(i32.add (get_local #{target.parentSymbols[target.parentSymbols.length - 1].name}) (i32.const 1))"
          wast += "(if (i32.gt_s #{elemIdx} (i32.load (get_local $$t0)))\n"
          wast += "  (i32.store (get_local $$t0) #{elemIdx})\n"
          wast += ")\n"
        else
          wast += "(set_local #{target.name} (get_local #{source.name}))\n"
        return wast
      throw new Error("Fn assign not defined for types #{target.type.primitive}, #{source.type.primitive}")
      return

    add: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} + #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    sub: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} - #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.sub (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.sub (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn sub not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    mul: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} * #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.mul (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn times not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    lte: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.le_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn lte not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    lt: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.lt_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.lt_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn lt not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    gte: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} => #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.ge_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.ge_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn gte not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    gt: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.gt_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.gt_s (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn gt not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    neg: (res, a) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = -#{a.name}" else ''
      if res.type.isI32() and a.type.isI32()
        wast +=  "(set_local #{res.name} (i32.sub (i32.const 0) (get_local #{a.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64()
        wast +=  "(set_local #{res.name} (i64.sub (i64.const 0) (get_local #{a.name})))\n"
        return wast
      throw new Error("Fn neg not defined for types #{res.type.primitive}, #{a.type.primitive}")
      return

    exp: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} ** #{b.name}" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast += "(set_local #{res.name} (i32.const 1))\n"
        wast += "(set_local $$t0 (get_local #{b.name}))\n"
        wast += '(loop $done $loop\n'
        wast += "  (br_if $done (i32.eq (get_local $$t0) (i32.const 0)))\n"
        wast += "  (set_local #{res.name} (i32.mul (get_local #{res.name}) (get_local #{a.name})))\n"
        wast += '  (set_local $$t0 (i32.sub (get_local $$t0) (i32.const 1)))\n'
        wast += '  (br $loop)\n'
        wast += ')\n'
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast += "(set_local #{res.name} (i64.const 1))\n"
        wast += "(set_local $$t0 (get_local #{b.name}))\n"
        wast += '(loop $done $loop\n'
        wast += "  (br_if $done (i64.eq (get_local $$t0) (i64.const 0)))\n"
        wast += "  (set_local #{res.name} (i64.mul (get_local #{res.name}) (get_local #{a.name})))\n"
        wast += '  (set_local $$t0 (i64.sub (get_local $$t0) (i64.const 1)))\n'
        wast += '  (br $loop)\n'
        wast += ')\n'
        return wast
      throw new Error("Fn exp not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    max: (res, a, b) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = max(#{a.name}, #{b.name})\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.add (get_local #{a.name}) (get_local #{b.name})))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return


module.exports = builtin
