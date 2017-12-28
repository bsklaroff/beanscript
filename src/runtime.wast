(module
  (func $print (import "env" "print") (param i32))
  (memory (import "env" "memory") 0)
  (global $hp (mut i32) (i32.const 4))
  GENERATED_CODE_HERE)
