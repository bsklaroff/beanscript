(module
  (func $print (import "env" "print") (param i32))
  (memory (import "env" "memory") 0)
  (func (export "main")
    (i32.store (i32.const 0) (i32.const 23))
    (call $print (i32.const 0))
  )
)
