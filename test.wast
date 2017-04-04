(module
  (memory 100)
  (import $print_i32 "stdio" "print" (param i32))
  (import $print_i64 "stdio" "print" (param i64))
  (func
    (call_import $print_i32 (i32.wrap/i64 (i64.const 9999999999999999)))
  )
  (export "main" 0)
)
