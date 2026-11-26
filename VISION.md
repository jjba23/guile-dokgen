# Vision

guile-dokgen loads a Guile module, asks it what it exports, and writes the
exported procedures, macros, variables and parameter objects out as Texinfo,
with their docstrings in the place the reader of a manual expects them. The
documentation is extracted from the code that is running rather than from a
parse of its text, so what a manual says exists is what a program can call.
This document says what that premise should eventually buy and which refusals
are worth keeping.

## Where guile-dokgen is today

Seven modules under `src/dokgen/`, about nine hundred lines of Guile 3, MIT
licensed, with no build step. It is a hard fork of Guile Documentá by Luis
Felipe López Acevedo; the extraction and the stexi rendering are his, and the
fork's work so far is the project around them: a pinned Guix environment, a
Maak file, SPDX headers, and tests that fail the build when they fail.

What exists and is tested:

- **Two commands, `dokgen api` and `dokgen check`.** The first takes one or
  more Scheme files or directories, resolves each to a module name, loads it,
  and writes `index.texi`; a directory is read recursively. The second reports
  the exported procedures and macros that have no documentation string and
  exits non-zero when it found one, which is what lets a build hold a library
  to a documented API.
- **Extraction from the live module.** Exports are found through the module's
  public interface, so a name that is re-exported or a residual export with no
  binding is something the program sees, and reports, rather than something a
  text scan would miss.
- **Docstrings are Texinfo.** The documentation string is the source and the
  renderer passes it through stexi, so `@var`, `@code` and `@example` in a
  docstring become the same markup in the manual. A module's commentary is
  its description, either as `;;; Commentary:` lines or as a `#| … |#` block.
- **Diagrams in the documentation.** A fenced mermaid or gnuplot block in a
  docstring is drawn through a renderer command and shown as an image. Mermaid
  has a second path: with no image, the page draws the source from a bundled
  renderer, so reading the HTML never requires `mmdc`. Gnuplot is drawn as SVG
  when gnuplot is installed. With no renderer at all the diagram is written as
  source, so nothing silently disappears. Each diagram is named after a digest
  of its own text, which is what keeps a stale drawing from being shown as the
  current one.
- **Definitions that can be pointed at.** Every definition carries an anchor
  built from its module and its name, so a hand-written chapter can reference
  one procedure rather than a whole section.
- **A page built to be read.** Beside the Texinfo, dokgen writes a stylesheet
  and a script: one card per definition with its signature at the top, an
  index of the sections and definitions down the side with a filter, a button
  that copies a signature, a warm light and dark page, and diagrams that fit
  the column. They are progressive: a manual that ignores them gets the same
  chapter it would have had, and a page without JavaScript keeps its own table
  of contents.
- **Numbers about the tree.** `dokgen stats` measures the sources and the
  history and writes them as a chapter: lines of code and comment, the
  decision points the code branches through, how much of the exported API is
  documented, and the authors and churn git reports. It is a snapshot that
  names the commit it describes, which is what lets a manual include it
  without the numbers pretending to be live.
- **A manual that is generated and a manual that is written.** The API chapter
  is `manual/api/index.texi`, produced by `maak docs` from the project's own
  sources and included by `manual/main.texi`, which is written by hand. The
  tool documents itself.

What it does not do is stated as plainly. It documents Guile only. It writes
Texinfo only. The command line of a program is not extracted, so the CLI
chapter is rewritten by hand. A module it cannot load is an error, not a gap in
the output.

## The vision

1. **The manual cannot disagree with the code.** The API chapter is data
   derived from the modules, and a release should fail when the two could
   differ: an export with no docstring, a reference to a node that does not
   exist, an example that no longer evaluates.
2. **Documentation that reads the program it documents.** The command-line
   chapter is the next thing that is written twice. The configuration record
   already holds every argument, its synopsis and its example; the chapter
   should be rendered from it.
3. **A faithful Texinfo, then other formats on top of it.** Texinfo is the
   product because `texi2any` turns it into Info, HTML and PDF. Anything else
   should be a rendering of the same data, not a second extractor.

## Features that are in scope and not built yet

- **Sources without quotes.** `dokgen api "mylib.scm mylib"` takes its sources
  as one space-separated string because of how the argument is declared.
  Accepting `dokgen api mylib.scm mylib` is a change to the argument, and a
  test for a path that contains a space comes with it.
- **CLI documentation from the specification.** Rendering the `api` chapter's
  sibling from the guile-config record. The hard part is keeping the narrative
  a hand-written chapter carries, which a generated one does not.
- **Checks that run in `maak docs`.** A dangling `@ref` and a malformed stexi
  fragment are both knowable at extraction time. The hard part is the policy:
  which of them stop the build and which are reported.  A missing docstring is
  the one of them that `dokgen check` now answers.
- **Documenting more than procedures.** Record types and class definitions each
  need a decision about what counts as their documentation and where it is
  read from.

## New features that would be worth having

- **A `dokgen check` command** that exits non-zero when an exported name has no
  documentation, so a pipeline can hold a library to a documented API without
  writing the manual.  *(Built in 0.7.0.)*
- **Incremental output**, one file per module, so a change to one module
  changes one file in a diff and the reviewer reads that file.
- **A listing of what was skipped and why**, on standard output, so a name that
  is missing from the manual is a line in a report and not a puzzle.
  *(The undocumented half of this is `dokgen check`, built in 0.7.0.)*

## Contributions that would move the needle

1. **A test.** Each spec under `test/veritas/unit/` documents one module; a new
   case for a shape of export the tool mishandles is both the bug report and
   the fix.
2. **A docstring shape.** A construct Texinfo can say and the renderer
   flattens: a table, a nested list, a `@defun` in a docstring.
3. **A sentence in the manual** that removes a hesitation. The manual is read
   by people deciding whether to point the tool at their library.
4. **Unquoted sources**, because every first use runs into it.

## Compared to related projects

| Project | What it is | Where guile-dokgen differs |
| --- | --- | --- |
| `(texinfo reflection)` in guile-lib | A library that reflects on modules and produces stexi for their bindings | The building block this uses; it is a library, not a command, and it leaves the choice of files, the chapter and the output file to the caller |
| Geiser, `help` in the REPL | Interactive documentation of a loaded module | Answers one name at a time to a person at a prompt; there is no document to review, ship or diff |
| Doxygen, Sphinx autodoc | Extraction of documentation from C-family and Python sources | Their own markup and their own build; the output here is Texinfo, which Guile's manual and the GNU toolchain already use |
| Codox, rustdoc, godoc | Extraction tools that ship with a language's ecosystem | One language each and the language's own format; the same idea, for a language that had a reflection library and no command |
| Writing the reference by hand | The usual state of a Guile library's manual | Drifts from the code on the first rename, and nothing says when |

The others do two things guile-dokgen should reach for: a documentation check
that fails the build (rustdoc, godoc) and output people actually read in a
browser without a toolchain of their own.  The first of those is now
`dokgen check`; the second is still `texi2any`'s job.  None of them reads a
running Guile module.

Where guile-dokgen is ahead, and should stay ahead: the documentation is the
docstring, in the markup the manual already speaks, with no second syntax to
learn; and the program is under a thousand lines that a maintainer reads in an
afternoon.

## In the long run

- **The docstring is the artefact.** If the docstrings are good enough, the
  renderer is replaceable, and the manual follows from the code instead of
  from the habits of whoever last edited it.
- **One extraction, several outputs.** Texinfo first; anything else is a
  rendering of the same data, which is what keeps a new format an afternoon's
  work.
- **Small on purpose.** The tool is useful because it can be read and trusted.
  A feature that doubles it needs an argument first.

## Closing

The in-scope items are ordered by what a stranger can land first: a test, a
docstring shape, a sentence, a quoted argument. The vision items change what
the tool guarantees rather than what it prints, and deserve an argument before
a patch.

*This document describes intent, not commitments.*
