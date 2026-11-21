#import "../in-dexter.typ": *
#set page("a6", flipped: true, numbering: "1")

_A test for the `run-in` and `level-indent` parameters of `make-index`.
With `run-in: true`, the pages follow the entry instead of being aligned
on the right._

#index[Faults]#index("Faults", "temporary")#index("Faults", "temporary", "arcing")
#index(see: "Faults")[Shorts]
#index(see-also: "Shorts")[Faults]
#index[A long entry that wraps onto a second line in a narrow column]
Page 1.
#pagebreak()
#index[Faults]#index[A long entry that wraps onto a second line in a narrow column]
Page 2.
#pagebreak()

== Default layout

#columns(2, make-index())

#pagebreak()

== Run-in layout

Expected:
- A long entry ... column, 1, 2 (wrapped lines indented by 3em)
- Faults, 1, 2; _see also_ Shorts
  - Temporary, 1 (indented 1.5em)
    - Arcing, 1 (indented 3em)
- Shorts, _see_ Faults

#columns(2, make-index(
  run-in: true,
  level-indent: 1.5em,
  surround: body => {
    set par(first-line-indent: 0pt, spacing: 0.65em, hanging-indent: 3em, justify: false)
    body
  },
))
