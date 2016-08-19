Symbol = require('./symbol')
Type = require('./type')

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
    print: (scope, res, [x]) ->
      wast = ''
      if x.type.isI32()
        wast += "(call_import $print_i32 (i32.const 32))\n"
        wast += "(call_import $print_i32 #{x.ref})\n"
        return wast
      else if x.type.isI64()
        wast += "(call_import $print_i32 (i32.const 64))\n"
        wast += "(call_import $print_i64 #{x.ref})\n"
        wast += "(call_import $print_i64 (i64.shr_u #{x.ref} (i64.const 32)))\n"
        return wast
      else if x.type.isArr()
        wast += "(call_import $print_i32 (i32.const 23))\n"
        if x.type.elemType.isI32()
          t0 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
          t1 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
          wast += "(call_import $print_i32 (i32.const 32))\n"
          wast += "(set_local #{t0} (i32.load (i32.add #{x.ref} (i32.const 4))))\n"
          wast += "(set_local #{t1} (i32.const 0))\n"
          wast += "(call_import $print_i32 (get_local #{t0}))\n"
          wast += "(loop $done $loop\n"
          wast += "  (if (i32.eq (get_local #{t0}) (get_local #{t1}))\n"
          wast += '    (then (br $done))\n'
          wast += "    (else\n"
          offsetStart = "(i32.add #{x.ref} (i32.const #{Symbol.ARRAY_OFFSET * 4}))"
          offset = "(i32.mul (get_local #{t1}) (i32.const 4))"
          wast += "      (call_import $print_i32 (i32.load (i32.add #{offsetStart} #{offset})))\n"
          wast += "      (set_local #{t1} (i32.add (get_local #{t1}) (i32.const 1)))\n"
          wast += '      (br $loop)\n'
          wast += '    )\n'
          wast += '  )\n'
          wast += ')\n'
        else if x.type.elemType.isI64()
          t0 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
          t1 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
          t2 = scope.addTemp(new Type(Type.PRIMITIVES.I64))
          wast += "(call_import $print_i32 (i32.const 64))\n"
          wast += "(set_local #{t0} (i32.load (i32.add #{x.ref} (i32.const 4))))\n"
          wast += "(set_local #{t1} (i32.const 0))\n"
          wast += "(call_import $print_i32 (get_local #{t0}))\n"
          wast += "(loop $done $loop\n"
          wast += "  (if (i32.eq (get_local #{t0}) (get_local #{t1}))\n"
          wast += '    (then (br $done))\n'
          wast += "    (else\n"
          offsetStart = "(i32.add #{x.ref} (i32.const #{Symbol.ARRAY_OFFSET * 4}))"
          offset = "(i32.mul (get_local #{t1}) (i32.const 8))"
          wast += "      (set_local #{t2} (i64.load (i32.add #{offsetStart} #{offset})))\n"
          wast += "      (call_import $print_i64 (get_local #{t2}))\n"
          wast += "      (call_import $print_i64 (i64.shr_u (get_local #{t2}) (i64.const 32)))\n"
          wast += "      (set_local #{t1} (i32.add (get_local #{t1}) (i32.const 1)))\n"
          wast += '      (br $loop)\n'
          wast += '    )\n'
          wast += '  )\n'
          wast += ')\n'
        else
          throw new Error("Fn print not defined for array with elements of type #{x.type.elemType.primitive}")
        return wast
      throw new Error("Fn print not defined for type #{x.type.primitive}")
      return wast

    assign: (scope, target, source) ->
      if target.type.isFn() and source.type.isFn()
        return ''
      wast = if SHOW_COMMENTS then ";;#{target.name} = #{source.name}\n" else ''
      if (target.type.isI32() and source.type.isI32()) or
         (target.type.isI64() and source.type.isI64()) or
         (target.type.isArr() and source.type.isArr())
        if target.parentSymbols?
          t0 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
          typePrimitive = if target.type.isArr() then 'i32' else target.type.primitive
          wast += "(#{typePrimitive}.store #{target.genMemptr()} #{source.ref})\n"
          # Set user-facing array length to the max of its current value and this index
          wast += "(set_local #{t0} (i32.add (get_local #{target.parentSymbols[target.parentSymbols.length - 2].name}) (i32.const 4)))\n"
          idxNode = target.parentSymbols[target.parentSymbols.length - 1]
          if idxNode.type.isI64()
            elemIdx = "(i32.add (i32.wrap/i64 #{idxNode.ref}) (i32.const 1))"
          else
            elemIdx = "(i32.add #{idxNode.ref} (i32.const 1))"
          wast += "(if (i32.gt_s #{elemIdx} (i32.load (get_local #{t0})))\n"
          wast += "  (i32.store (get_local #{t0}) #{elemIdx})\n"
          wast += ")\n"
        else
          wast += "(set_local #{target.name} #{source.ref})\n"
        return wast
      throw new Error("Fn assign not defined for types #{target.type.primitive}, #{source.type.primitive}")
      return

    add: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} + #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.add #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.add #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn add not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    sub: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} - #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.sub #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.sub #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn sub not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    mul: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} * #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.mul #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.mul #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn times not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    div: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} / #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.div_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.div_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn div not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    eq: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} == #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.eq #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.eq #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn eq not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    neq: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} != #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.ne #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.ne #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn neq not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    lte: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.le_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.le_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn lte not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    lt: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.lt_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.lt_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn lt not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    gte: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} => #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.ge_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.ge_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn gte not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    gt: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} <= #{b.name}\n" else ''
      if res.type.isBool() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.gt_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isBool() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.gt_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn gt not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    neg: (scope, res, [a]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = -#{a.name}" else ''
      if res.type.isI32() and a.type.isI32()
        wast +=  "(set_local #{res.name} (i32.sub (i32.const 0) #{a.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64()
        wast +=  "(set_local #{res.name} (i64.sub (i64.const 0) #{a.ref}))\n"
        return wast
      throw new Error("Fn neg not defined for types #{res.type.primitive}, #{a.type.primitive}")
      return

    exp: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} ** #{b.name}" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        t0 = scope.addTemp(new Type(Type.PRIMITIVES.I32))
        wast += "(set_local #{res.name} (i32.const 1))\n"
        wast += "(set_local #{t0} #{b.ref})\n"
        wast += '(loop $done $loop\n'
        wast += "  (br_if $done (i32.eq (get_local #{t0}) (i32.const 0)))\n"
        wast += "  (set_local #{res.name} (i32.mul #{res.ref} #{a.ref}))\n"
        wast += "  (set_local #{t0} (i32.sub (get_local #{t0}) (i32.const 1)))\n"
        wast += '  (br $loop)\n'
        wast += ')\n'
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        t0 = scope.addTemp(new Type(Type.PRIMITIVES.I64))
        wast += "(set_local #{res.name} (i64.const 1))\n"
        wast += "(set_local #{t0} #{b.ref})\n"
        wast += '(loop $done $loop\n'
        wast += "  (br_if $done (i64.eq (get_local #{t0}) (i64.const 0)))\n"
        wast += "  (set_local #{res.name} (i64.mul #{res.ref} #{a.ref}))\n"
        wast += "  (set_local #{t0} (i64.sub (get_local #{t0}) (i64.const 1)))\n"
        wast += '  (br $loop)\n'
        wast += ')\n'
        return wast
      throw new Error("Fn exp not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return

    mod: (scope, res, [a, b]) ->
      wast = if SHOW_COMMENTS then ";;#{res.name} = #{a.name} % #{b.name}\n" else ''
      if res.type.isI32() and a.type.isI32() and b.type.isI32()
        wast +=  "(set_local #{res.name} (i32.rem_s #{a.ref} #{b.ref}))\n"
        return wast
      else if res.type.isI64() and a.type.isI64() and b.type.isI64()
        wast +=  "(set_local #{res.name} (i64.rem_s #{a.ref} #{b.ref}))\n"
        return wast
      throw new Error("Fn mod not defined for types #{res.type.primitive}, #{a.type.primitive}, #{b.type.primitive}")
      return


module.exports = builtin
