exports.empty = empty = {}
empty.program = ""
empty.ast =
  _Program_:
    statements: []

exports.newline = newline = {}
newline.program = '\n'
newline.ast =
  _Program_:
    statements: []

exports.manyNewline = manyNewline = {}
manyNewline.program = '\n\n\n\n\n'
manyNewline.ast =
  _Program_:
    statements: []
