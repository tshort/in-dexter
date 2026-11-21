// Copyright 2023, 2024 Rolf Bremer, Jutta Klebe
// Use of this code is governed by the License in the LICENSE.txt file.
// For a 'how to use this package', see the accompanying .md, .pdf + .typ documents.

#let indextype = (
  Start: "Start",
  End: "End",
  Cardinal: "Cardinal",
)

// Adds a new entry to the index
// @param fmt: function: content -> content
// @param index-type: indextype.Cardinal, indextype.Start, indextype.End.
// @param initial: "letter" to sort entries under - otherwise first letter of entry is used,
//    useful for indexing umlauts or accented letters with their unaccented versions or
//    symbols under a common "Symbols" headline
// @param index: Name of the index to add the entry to. Default is "Default".
// @param display: If given, this will be the displayed content in the index page (instead of the key entry).
// @param apply-casing: If set to auto (default) the parameter from make-index is used.
//    Otherwise it overwrites the setting. Set to false for entries starting with a formula!
// @param see: Entry or entries (string or content, or an array of them) to refer to
//    instead of a page, like "see Faults". The mark adds no page reference.
// @param see-also: Like see, for "see also" references.
// @param ..entry, variable argument to nest index entries (left to right). Only the last, rightmost
// entry is the key for the entry. The others are used for grouping.
#let index(
  fmt: it => it,
  index-type: indextype.Cardinal,
  initial: none,
  index: "Default",
  display: auto,
  apply-casing: auto,
  see: (),
  see-also: (),
  ..entry,
) = (
  context {
    let loc = here()
    [#metadata((
        fmt: fmt,
        index-type: index-type,
        initial: initial,
        index-name: index,
        location: loc.position(),
        page-counter: counter(page).at(loc).at(0),
        page-counter-end: counter(page).at(loc).at(0),
        page-numbering: loc.page-numbering(),
        entry: entry,
        display: display,
        apply-casing: apply-casing,
        see: if type(see) == array { see } else { (see,) },
        see-also: if type(see-also) == array { see-also } else { (see-also,) },
      ))<jkrb_index>]
  }
)

// Default function to semantically mark main entries in the index
#let index-main = index.with(fmt: strong)

#let as-text(input) = {
  let t = type(input)
  if input == none or input == auto {
    ""
  } else if t == str {
    input
  } else if t == label {
    repr(input)
  } else if t == int {
    str(input)
  } else if t == content {
    if input.has("text") {
      input.text
    } else if input.has("children") {
      if input.children.len() == 0 {
        ""
      } else {
        input.children.map(child => as-text(child)).join("")
      }
    } else if input.has("body") {
      as-text(input.body)
    } else {
      " "
    }
  } else {
    panic("Unexpected entry type " + t + " of " + repr(input))
  }
}

// Internal function to set plain and nested entries
#let make-entries(
  entries,
  page-link,
  reg-entry,
  use-bang-grouping,
  apply-casing,
) = {
  // Handling LaTeX nested entry syntax (only if it is the last entry)

  if use-bang-grouping and entries.len() == 1 {
    let entry = entries.at(0)
    if type(entry.key) == str and entry.key.len() > 0 {
      let display = entry.display
      entries = entry.key.split("!").map(e => {
        let d = if type(display) == str and display.contains(regex("!\w+")) {
          e
        } else {
          display
        }
        (display: d, key: e)
      })

      if entries.last().key == "" {
        let emptyKeyIndex = entries.position(e => e.key == "")
        let bangCount = 0
        if emptyKeyIndex != none {
          bangCount = entries.len() - emptyKeyIndex
        }
        entries = entries.filter(e => e.key != "")
        entries.last() = (display: entries.last().display + "!" * bangCount, key: entries.last().key)
      }
    }
  }

  let (entry, ..rest) = entries

  if rest.len() > 0 {
    let nested-entries = reg-entry.at(entry.key, default: (:))
    let ref = make-entries(
      rest,
      page-link,
      nested-entries.at("nested", default: (:)),
      use-bang-grouping,
      apply-casing,
    )
    nested-entries.insert("nested", ref)
    reg-entry.insert(entry.key, nested-entries)
  } else {
    let key = if type(entry.key) == str {
      entry.key
    } else {
      as-text(entry.key)
    }
    if type(key) == content {
      panic("Entry must be string compatible. Consider specifying as display parameter.")
    }
    let current-entry = reg-entry.at(
      key,
      default: (
        display: entry.display,
        pages: (),
        apply-casing: apply-casing,
      ),
    )
    // A cross-reference mark adds its targets instead of a page.
    if page-link.see.len() > 0 or page-link.see-also.len() > 0 {
      for kind in ("see", "see-also") {
        let targets = current-entry.at(kind, default: ())
        for t in page-link.at(kind) {
          if t not in targets { targets.push(t) }
        }
        current-entry.insert(kind, targets)
      }
      reg-entry.insert(key, current-entry)
      return reg-entry
    }
    let pages = current-entry.at("pages", default: ())
    let pageRanges = pages.map(p => {
      if p.index-type == indextype.Start and page-link.index-type == indextype.End {
        p.index-type = "Range"
        p.rangeEnd = page-link.page
        p.page-counter-end = page-link.page-counter
      }
      return p
    })
    let searchFunc = p => {
      p.index-type == "Range" and p.rangeEnd == page-link.page or p.index-type == indextype.Cardinal and p.page == page-link.page and p.fmt == page-link.fmt
    }
    let foundRange = pageRanges.find(searchFunc)
    if foundRange == none {
      pageRanges.push(page-link)
    }
    current-entry.insert("pages", pageRanges)
    reg-entry.insert(key, current-entry)
  }
  reg-entry
}

// Internal function to collect plain and nested entries into the index
#let references(indexes, use-bang-grouping, sort-order) = {
  let register = (:)
  let initials = (:)

  for indexed in query(<jkrb_index>) {
    let (
      fmt,
      index-type,
      initial,
      index-name,
      location,
      page-counter,
      page-counter-end,
      page-numbering,
      entry,
      display,
      apply-casing,
      see,
      see-also,
    ) = indexed.value

    if (indexes != auto) and (not indexes.contains(index-name)) {
      continue
    }

    // Handle tuple as (display, key)
    let entries = entry.pos().map(e => {
      if type(e) == content {
        e = as-text(e)
      }
      let disp = if display == auto {
        e
      } else {
        display
      }

      let k = none
      if type(e) == array {
        if e.len() == 2 {
          disp = e.at(0)
          k = e.at(1)
        }
      } else {
        k = as-text(e)
      }
      (display: disp, key: k)
    })

    if entries.len() == 0 {
      panic("expected entry to have at least one entry to add to the index")
    } else {
      let initial-letter = if initial == none {
        let fe = sort-order(entries.first().at("key", default: "?"))
        let fe2 = if type(fe) == str {
          fe
        } else {
          as-text(fe)
        }
        if type(fe2) != str {
          panic("Content cannot be converted to string. Use `initial` or `display` parameter for the entry.")
        }
        let first-letter = fe2.first()
        initials.insert(first-letter, first-letter)
        first-letter
      } else {
        if (type(initial) == dictionary) {
          let letter = sort-order(initial.at("letter"))
          let sort-by = initial.at("sort-by", default: letter)
          initials.insert(sort-by, letter)
          letter
        } else if (type(initial) == str) {
          let first-letter = sort-order(initial.first())
          initials.insert(first-letter, first-letter)
          first-letter
        } else {
          panic("Expected initial to be either a 'string' or '(letter: <string>, sort-by: <none|string>)'")
        }

      }
      let reg-entry = register.at(initial-letter, default: (:))
      register.insert(
        initial-letter,
        make-entries(
          entries,
          (
            page: location.page,
            rangeEnd: location.page,
            fmt: fmt,
            index-type: index-type,
            page-counter: page-counter,
            page-counter-end: page-counter-end,
            page-numbering: page-numbering,
            see: see,
            see-also: see-also,
          ),
          reg-entry,
          use-bang-grouping,
          apply-casing,
        ),
      )
    }
  }
  (register: register, initials: initials)
}


// Internal function to format a page link
#let render-link(
  use-page-counter,
  range-delimiter,
  spc,
  mpc,
  (page, rangeEnd, index-type, fmt, page-counter, page-counter-end, page-numbering),
) = {
  if page-numbering == none {
    page-numbering = "1"
  }
  let resPage = if use-page-counter {
    numbering(page-numbering, page-counter)
  } else {
    str(page)
  }
  let resEndPage = if use-page-counter {
    numbering(page-numbering, page-counter-end)
  } else {
    str(rangeEnd)
  }
  let t = if index-type == "Range" {
    if rangeEnd - page == 1 {
      if spc != none {
        resPage + spc
      } else {
        resPage + range-delimiter + resEndPage
      }
    } else if rangeEnd == page {
      resPage
    } else {
      resPage + range-delimiter + resEndPage
    }
  } else if index-type == indextype.Start {
    resPage + mpc
  } else {
    resPage
  }
  link((page: page, x: 0pt, y: 0pt), fmt[#t])
}


// First letter casing
#let first-letter-up(entry) = {
  if type(entry) == str and entry.len() > 0 {
    upper(entry.first()) + entry.clusters().slice(1).join()
  }
}

#let apply-entry-casing(display, entry-casing, apply-casing) = {
  let applied = state("applied", false)
  applied.update(false)
  show text: it => (
    context {
      let t = it.text
      let transformed = entry-casing(t)
      if t == transformed or applied.get() == true {
        it
      } else {
        if apply-casing == false {
          it
        } else {
          let t2 = entry-casing(transformed)
          if t2 != transformed {
            panic("entry-casing not idempotent:" + repr(t) + "~>" + repr(transformed) + "~>" + repr(t2))
          }
          applied.update(true)
          transformed
        }
      }
    }
  )
  display
}

// Internal function to merge consecutive pages, and overlapping or adjacent
// ranges, into one range: 71, 72, 73 -> 71--73. Expects pages sorted by page.
// Only pages with the same format and numbering are merged.
#let merge-consecutive(pages) = {
  let merged = ()
  for p in pages {
    let q = merged.at(-1, default: none)
    let mergeable = (
      q != none
        and q.index-type in (indextype.Cardinal, "Range")
        and p.index-type in (indextype.Cardinal, "Range")
        and q.fmt == p.fmt
        and q.page-numbering == p.page-numbering
        and p.page <= q.rangeEnd + 1
        and p.page-counter <= q.page-counter-end + 1
    )
    if mergeable {
      if p.rangeEnd > q.rangeEnd {
        q.rangeEnd = p.rangeEnd
        q.page-counter-end = p.page-counter-end
      }
      if q.rangeEnd > q.page { q.index-type = "Range" }
      merged.at(-1) = q
    } else {
      merged.push(p)
    }
  }
  merged
}

// Internal function to format a plain or nested entry
#let render-entry(idx, entry, lvl, use-page-counter, sort-order, entry-casing, range-delimiter, spc, mpc, merge-ranges, see-label, see-also-label) = {
  // Pages are collected in source order, which is not always page order:
  // a mark in a floating figure can land on a later page than the marks
  // after it.
  let pages = entry.at("pages", default: ()).sorted(key: p => p.page)
  if merge-ranges { pages = merge-consecutive(pages) }
  let display = entry.at("display", default: idx)
  let render-function = render-link.with(use-page-counter, range-delimiter, spc, mpc)

let rendered-pages = {
    let p = pages.map(render-function)
    box(width: lvl * 1em)
    apply-entry-casing(
      display,
      entry-casing,
      entry.at("apply-casing", default: auto),
    )
    // Cross-references follow the pages ("12; see also Faults"), or the
    // entry itself when it has no pages ("Faults, see Short circuits").
    let refs = ()
    let see = entry.at("see", default: ())
    let see-also = entry.at("see-also", default: ())
    if see.len() > 0 { refs.push(see-label + [ ] + see.join("; ")) }
    if see-also.len() > 0 { refs.push(see-also-label + [ ] + see-also.join("; ")) }
    let parts = if p.len() > 0 { (p.join(", "),) } else { () } + refs
    if parts.len() > 0 {
      if p.len() > 0 { box(width: 1fr) } else [, ]
      parts.join("; ")
    }
    parbreak()
  }

  let sub-entries = entry.at("nested", default: (:))

  let rendered-entries = if sub-entries.keys().len() > 0 [
    #for key in sub-entries.keys().sorted(key: sort-order) [
      #render-entry(key, sub-entries.at(key), lvl + 1, use-page-counter, sort-order, entry-casing, range-delimiter, spc, mpc, merge-ranges, see-label, see-also-label)
    ]
  ]
  [
    #rendered-pages
    #rendered-entries
  ]
}


// Inserts the index into the document
// @param title (default: none) sets the title of the index to use.
// @param outlined (default: false) if index is shown in outline (table of contents).
// @param use-page-counter (default: false) use the value of the page counter for page number text.
// @param use-bang-grouping (default: false) support the LaTeX bang grouping syntax.
// @param sort-order (default: upper) a function to control how the entry is sorted.
// @param entry-casing (default: first-letter-up) a function to control how the
//        entry key is displayed (when no display parameter is provided).
// @param range-delimiter (default: [--]) the delimiter to use in ranges, like the
//        em-dash in "1--42".
// @param spc (default: "f.") Symbol(s) to mark a Single-Page-Continuation.
//        If set to none, a numeric range is used instead, like "42-43".
// @param mpc (default: "ff.") Symbol(s) to mark a Multi-Page-Continuation.
// @param merge-ranges (default: false) merge consecutive pages into a range,
//        like "71, 72, 73" into "71--73".
// @param see-label (default: emph[see]) text before "see" cross-references.
// @param see-also-label (default: emph[see also]) text before "see also" cross-references.
// @param indexes (default: auto) optional name(s) of the index(es) to use. Auto uses all indexes.
// @param surround (default: body) a function to surround the index body with additional content/settings.
// @param section-container (default: section) a function to wrap the whole section in a container.
// @param section-title (default: heading(level: 2, numbering: none, outlined: false, letter))
// @param section-body (default: body) a function to render the body of the section.
#let make-index(
  title: none,
  outlined: false,
  use-page-counter: false,
  use-bang-grouping: false,
  sort-order: k => upper(k),
  entry-casing: k => first-letter-up(k),
  spc: "f.",
  mpc: "ff.",
  range-delimiter: [--],
  merge-ranges: false,
  see-label: emph[see],
  see-also-label: emph[see also],
  indexes: auto,
  surround: (body) => {
      set par(first-line-indent: 0pt, spacing: 0.65em, hanging-indent: 1em)
      body
  },
  section-container: (section) => {section},
  section-title: (letter, counter) => heading(level: 2, numbering: none, outlined: false, letter),
  section-body: (letter, counter, body) => {body}
) = (
  context {
    surround({
      let (register, initials) = references(indexes, use-bang-grouping, sort-order)

      if title != none {
        heading(
          outlined: outlined,
          numbering: none,
          title,
        )
      }

      let lastPage = counter(page).get().last()
      let effective-mpc = if mpc == none {
        range-delimiter + str(lastPage)
      } else {
        mpc
      }

      let counter = 0
      for initial in initials.keys().sorted() {
        let letter = initials.at(initial)
        section-container({
          section-title(letter, counter)
          section-body(letter, counter, {
            counter += 1
            let entry = register.at(letter)
            // sort and render entries
            for idx in entry.keys().sorted(key: sort-order) {
              render-entry(idx, entry.at(idx), 0, use-page-counter, sort-order, entry-casing, range-delimiter, spc, effective-mpc, merge-ranges, see-label, see-also-label)
            }
          })
        })
      }
    })
  }
)