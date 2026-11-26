;; guile-dokgen --- test: veritas/unit/commands-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What the three commands write: the API chapter, the report a `check' makes,
and the statistics chapter.  Every case runs the command it names into a
destination of its own under /tmp, so a case that fails leaves the others
untouched and the tree never holds a build artefact.

A renderer is a command line, so a case that wants a diagram drawn passes a
shell script from test/ instead of installing mermaid-cli or gnuplot. |#

(define-module (veritas unit commands-spec)
  #:use-module (dokgen commands)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:use-module (veritas all))

;; Two libraries: one with gaps in it, and one a check has nothing to say
;; about.  Each is a directory whose modules are named after it, which is how
;; a project lays its own tree out.
(define LIBRARY "test/examplelib")
(define CLEAN_LIBRARY "test/cleanlib")
(define PLOT_LIBRARY "test/plotlib")

(define FAKE_MERMAID "sh test/fake-mermaid %i %o")
(define FAKE_GNUPLOT "sh test/fake-gnuplot %i %o")

;; Every destination of this run, so one sweep removes all of them.
(define TEST_ROOT (format #f "/tmp/dokgen-commands-~a" (getpid)))

(define* (chapter-into name
                       #:key (library LIBRARY)
                       (mermaid FAKE_MERMAID)
                       (gnuplot ""))
  "Write the API chapter of LIBRARY into a destination of its own.

@var{name} tells this destination apart from the ones the other cases write,
so no case depends on the order the suite runs in.  The destination is
returned."
  (let ((where (format #f "~a/~a" TEST_ROOT name)))
    (api (list library) where mermaid gnuplot)
    where))

(define* (stats-into name #:key (library LIBRARY))
  "Write the statistics chapter of LIBRARY into a destination of its own."
  (let ((where (format #f "~a/~a" TEST_ROOT name)))
    (stats (list library) where)
    where))

(define (text-of file)
  "Return the whole of FILE, which a command just wrote."
  (call-with-input-file file get-string-all))

(define (chapter-of destination)
  "Return the API chapter written to DESTINATION."
  (text-of (format #f "~a/index.texi" destination)))

(define (stats-of destination)
  "Return the statistics chapter written to DESTINATION."
  (text-of (format #f "~a/stats.texi" destination)))

(define (holds-file-of-type? directory suffix)
  "Return @code{#t} when DIRECTORY holds a file whose name ends in SUFFIX."
  (pair? (scandir directory
                  (lambda (name) (string-suffix? suffix name)))))

(define check-suite
  (suite "The check command counts the gaps in a documented API"
         (test "a library with two undocumented procedures counts two"
               (assert-equal #:expect 2
                             #:got (check (list LIBRARY))))
         (test "a library with no gap counts none"
               (assert-equal #:expect 0
                             #:got (check (list CLEAN_LIBRARY))))
         (test "the report names the module and the name, so it can be fixed"
               (assert-contains #:expect
                                (with-output-to-string
                                  (lambda () (check (list LIBRARY))))
                                #:got
                                "undocumented: (examplelib mixed) blank-docstring"))))

(define api-suite
  (suite "The api command writes the chapter a manual includes"
         (test "the chapter is written where the command was told"
               (let ((where (chapter-into "written")))
                 (assert-true (file-exists?
                               (format #f "~a/index.texi" where)))))
         (test "the module has a node of its own, so a reader can find it"
               (assert-contains #:expect (chapter-of (chapter-into "named"))
                                #:got "@node examplelib_diagrammed"))
         (test "a definition carries the source behind it, behind a marker"
               (let ((chapter (chapter-of (chapter-into "source"))))
                 (assert-contains
                  #:expect chapter
                  #:got
                  "@anchor{dk_source_examplelib_mixed_documented}"
                  #:name "the panel is marked with an anchor")
                 (assert-contains
                  #:expect chapter
                  #:got
                  "(define (documented)\n  \"This procedure says what it does.\""
                  #:name "the form the module writes is in it")))
         (test "a diagram is referenced as an image the build drew"
               (assert-contains
                #:expect (chapter-of (chapter-into "drawn"))
                #:got "@image{diagrams/examplelib_diagrammed-"))
         (test "the image of a diagram is written beside the chapter"
               (assert-true (holds-file-of-type?
                             (format #f "~a/diagrams" (chapter-into "rendered"))
                             ".png")))
         (test "the stylesheet and the scripts go beside the chapter"
               (let ((where (chapter-into "assets")))
                 (assert-true (file-exists? (format #f "~a/dokgen.css" where))
                              #:name "the stylesheet")
                 (assert-true (file-exists? (format #f "~a/dokgen.js" where))
                              #:name "the script")
                 (assert-true
                  (file-exists? (format #f "~a/dokgen-mermaid.js" where))
                  #:name "the bundled renderer")))
         (test "an image already written is kept when nothing redraws it"
               (let ((where (chapter-into "kept")))
                 ;; The same destination twice: the second run is told to
                 ;; draw nothing, and the image the first one drew stays.
                 (api (list LIBRARY) where "" "")
                 (assert-contains #:expect (chapter-of where)
                                  #:got "@image{diagrams/examplelib_diagrammed-")))
         (test "a diagram with no image and no renderer is kept as source"
               (let ((chapter (chapter-of (chapter-into "bare" #:mermaid ""))))
                 (assert-contains #:expect chapter #:got "@example"
                                  #:name "the source is an example block")
                 (assert-contains #:expect chapter #:got "%% dokgen-mermaid"
                                  #:name "the page can tell it from a sample")))
         (test "a gnuplot diagram is drawn with the command it was given"
               (let ((where (chapter-into "plot"
                                          #:library PLOT_LIBRARY
                                          #:mermaid ""
                                          #:gnuplot FAKE_GNUPLOT)))
                 (assert-contains #:expect (chapter-of where)
                                  #:got "@image{diagrams/plotlib_plot-"
                                  #:name "the plot is an image")
                 (assert-true (holds-file-of-type?
                               (format #f "~a/diagrams" where) ".svg")
                              #:name "the plot is drawn as SVG")))
         (test "a plot with no renderer stays readable as source"
               (assert-contains
                #:expect (chapter-of (chapter-into "plot-bare"
                                                   #:library PLOT_LIBRARY
                                                   #:mermaid ""
                                                   #:gnuplot ""))
                #:got "Gnuplot diagram, as source:"))))

(define stats-suite
  (suite "The stats command measures the tree it was pointed at"
         (test "the chapter is written beside the API chapter"
               (assert-true
                (file-exists?
                 (format #f "~a/stats.texi" (stats-into "measured")))))
         (test "the chapter is titled the way a manual includes it"
               (assert-contains #:expect (stats-of (stats-into "titled"))
                                #:got "@chapter Statistics"))
         (test "the chapter is read with the same stylesheet and script"
               (let ((where (stats-into "readable")))
                 (assert-true (file-exists? (format #f "~a/dokgen.css" where))
                              #:name "the stylesheet")
                 (assert-true (file-exists? (format #f "~a/dokgen.js" where))
                              #:name "the script")))
         (test "the size of what was measured is reported"
               (assert-contains #:expect (stats-of (stats-into "sized"))
                                #:got "lines of code"))
         (test "how much of the API is documented is reported"
               (assert-contains #:expect (stats-of (stats-into "coverage"))
                                #:got "2 of the 4 exported"))))

(define (forget-destinations . _context)
  "Remove every destination this run wrote.

The suite's after-all hook hands the run context over, which a sweep of a
directory has no use for."
  ;; `rm -rf' and not a recursive delete from a library: the suite takes no
  ;; dependency it does not test.
  (false-if-exception (system* "rm" "-rf" TEST_ROOT)))

(define (spec)
  (veritas-run
   (suite "The dokgen commands"
          ;; One sweep after the last case, however the cases were ordered.
          #:after-all forget-destinations
          check-suite
          api-suite
          stats-suite)))
