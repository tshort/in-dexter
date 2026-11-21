#import "../in-dexter.typ": *
#set page("a6", flipped: true, numbering: "1")

_A test for cross-references with the `see` and `see-also` parameters
of `index`. A cross-reference mark adds no page reference; repeated
targets are listed once._

#index[Faults]#index[Short circuits]
#index("Faults", "temporary")
#index(see: "Short circuits")[Shorts]
#index(see-also: "Short circuits")[Faults]
#index(see-also: "Short circuits")[Faults]
#index(see: "Faults", see-also: ("Lightning", [Surges]))[Arcs]
#index(see-also: "Lightning", "Faults", "temporary")
Page 1.

== Index

Expected:
- Arcs, _see_ Faults; _see also_ Lightning; Surges
- Faults, 1; _see also_ Short circuits
  - Temporary, 1; _see also_ Lightning
- Short circuits, 1
- Shorts, _see_ Short circuits

#make-index()

#pagebreak()

== Custom labels

Expected: as above, with "See" and "See also".

#make-index(see-label: emph[See], see-also-label: emph[See also])
