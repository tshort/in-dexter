#import "../in-dexter.typ": *
#set page("a6", flipped: true, numbering: "1")

_A test for the `merge-ranges` parameter of `make-index`. It merges
consecutive pages, and overlapping or adjacent ranges, into one range._

#let index-start = index.with(index-type: indextype.Start)
#let index-end = index.with(index-type: indextype.End)

#index[Consecutive]#index[Gap]#index[Mixed]
#index-main[Main]
Page 1.
#pagebreak()

#index[Consecutive]#index[Mixed]#index-start[Overlap]
#index-main[Main]
Page 2.
#pagebreak()

#index[Consecutive]#index[Gap]#index-main[Mixed]
#index[Main]
Page 3.
#pagebreak()

#index[Consecutive]#index[Overlap]
Page 4.
#index-end[Overlap]
#pagebreak()

#index[Overlap]
Page 5.
#pagebreak()

#index[Consecutive]
Page 6.
#pagebreak()

== Index without `merge-ranges`

Expected: Consecutive, 1, 2, 3, 4, 6; Gap, 1, 3; Main, *1*, *2*, 3;
Mixed, 1, 2, *3*; Overlap, 2--4, 4, 5

#make-index(spc: none)

#pagebreak()

== Index with `merge-ranges: true`

Expected: Consecutive, 1--4, 6; Gap, 1, 3; Main, *1--2*, 3;
Mixed, 1--2, *3*; Overlap, 2--5

#make-index(spc: none, merge-ranges: true)
