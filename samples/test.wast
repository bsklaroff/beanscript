(module
  (func $print (import "env" "print") (param i32))
  (memory (import "env" "memory") 0)
  (type $t (func (param i32) (result i32)))
  (table anyfunc (elem $fn))
  (func (export "main")
    (local $x i32)
    (set_local $x (call_indirect $t (i32.const 46) (i32.const 0)))
    (i32.store (i32.const 0) (get_local $x))
    (call $print (i32.const 0))
  )
  (func $fn (param $a i32) (result i32)
    (return (i32.add (get_local $a) (i32.const 1)))
  )
)
