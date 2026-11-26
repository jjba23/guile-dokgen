;; guile-dokgen --- test: veritas/unit/diagrams-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What (dokgen diagrams) makes of the diagrams a docstring holds: the blocks a
docstring is split into, the name a diagram's files are written under, and the
Texinfo nodes that show the image, or the source when nothing drew it.

A diagram is drawn by a program outside dokgen, so the docstring, the files
written beside the chapter and the node that references them have to agree on a
name: disagree, and the manual shows an image of a diagram the reader changed
weeks ago. The renderers here are the scripts at the top of the test tree,
spawned the way dokgen spawns a real one, so the spawn itself is checked too. |#

(define-module (veritas unit diagrams-spec)
  #:use-module (dokgen diagrams)
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (veritas all))


;;; CONSTANTS

;; A directory of its own, so that what a rendered diagram writes never lands
;; in the tree and goes away with the suite.
(define TEST_DIR (format #f "/tmp/dokgen-test-~a" (getpid)))

;; The renderers sit at the top of the test tree, and a spec runs from the
;; repository root.  They are spawned as the program under test spawns a real
;; renderer, because `sh' is found on PATH the same way `mmdc' would be.
(define RENDERERS "test")

(define FAKE_MERMAID (format #f "sh ~a/fake-mermaid %i %o" RENDERERS))
(define FAKE_GNUPLOT (format #f "sh ~a/fake-gnuplot %i %o" RENDERERS))

(define EXAMPLE "graph TD\n  source --> manual")
(define PLOT "plot sin(x)")


;;; HELPERS

(define (render language source owner command)
  "Return the nodes that show SOURCE, with COMMAND drawing it into TEST_DIR.

  Only the command of the diagram's own language is read, so both parameters
  are set from the one argument: an empty COMMAND draws nothing, which is how a
  diagram is left as source."
  (parameterize ((*diagram-destination* TEST_DIR)
                 (*mermaid-command* command)
                 (*gnuplot-command* command))
    (diagram-stexi language source owner)))

(define (diagram-file owner extension)
  "Return the path of the file OWNER's diagram is written with EXTENSION under."
  (format #f "~a/diagrams/~a.~a" TEST_DIR owner extension))


;;; SUITES

(define diagram-blocks-suite
  (suite "A docstring split into the prose and the diagrams it holds"
         (test "a docstring with no fence is one block of prose"
               (assert-equal #:expect (list (cons 'text "Just prose."))
                             #:got (diagram-blocks "Just prose.")))
         (test "a fenced diagram is split out of the prose around it"
               (assert-equal
                #:expect (list (cons 'text "Before.")
                               (list 'diagram "mermaid" EXAMPLE)
                               (cons 'text "After."))
                #:got (diagram-blocks
                       (format #f "Before.~%```mermaid~%~a~%```~%After." EXAMPLE))))
         (test "a fence that stands on an indented line is still read"
               (assert-equal
                #:expect (list (list 'diagram "mermaid" EXAMPLE))
                #:got (diagram-blocks
                       (format #f "  ```mermaid~%~a~%  ```" EXAMPLE))))
         (test "a gnuplot fence is read as a gnuplot diagram"
               (assert-equal
                #:expect (list (list 'diagram "gnuplot" PLOT))
                #:got (diagram-blocks
                       (format #f "```gnuplot~%~a~%```" PLOT))))
         (test "a fence in a language dokgen does not read stays text"
               (assert-equal
                #:expect (list (cons 'text
                                     (format #f "```dot~%digraph { a -> b }~%```")))
                #:got (diagram-blocks "```dot\ndigraph { a -> b }\n```")))
         (test "an unterminated fence stays text, so nothing is lost"
               (assert-equal
                #:expect (list (cons 'text
                                     (format #f "Before.~%```mermaid~%~a" EXAMPLE)))
                #:got (diagram-blocks
                       (format #f "Before.~%```mermaid~%~a" EXAMPLE))))
         (test "two diagrams in one docstring are both read"
               (assert-equal
                #:expect (list (list 'diagram "mermaid" EXAMPLE)
                               (cons 'text "Prose.")
                               (list 'diagram "mermaid" EXAMPLE))
                #:got (diagram-blocks
                       (format #f "```mermaid~%~a~%```~%Prose.~%```mermaid~%~a~%```"
                               EXAMPLE EXAMPLE))))
         (test "a diagram quoted inside a Texinfo block stays a sample"
               (assert-equal
                #:expect (list (cons 'text
                                     (format #f
                                             "@example~%Write it so:~%```mermaid~%~a~%```~%@end example"
                                             EXAMPLE)))
                #:got (diagram-blocks
                       (format #f
                               "@example~%Write it so:~%```mermaid~%~a~%```~%@end example"
                               EXAMPLE))))))


(define diagram-stem-suite
  (suite "The name a diagram's files are written under"
         (test "the same diagram under the same owner gets the same name"
               (assert-true (equal? (diagram-stem "manual" EXAMPLE)
                                    (diagram-stem "manual" EXAMPLE))))
         ;; The digest is what makes a stale image unreachable, so a changed
         ;; diagram has to land in a file of its own.
         (test "a changed diagram gets a name of its own"
               (assert-true (not (equal? (diagram-stem "manual" EXAMPLE)
                                         (diagram-stem
                                          "manual"
                                          "graph LR\n  source --> manual")))))
         (test "the owner is spelled the way a shell and a URL accept, and a digest follows"
               (assert-matches #:pattern "^api-symbols-[0-9a-f]+$"
                               #:got (diagram-stem "api symbols" EXAMPLE)))))


(define diagram-stexi-suite
  (suite "The Texinfo that shows a diagram"
         ;; `rm -rf' and not a recursive delete from a library: the suites take
         ;; no dependency they do not test.
         #:after-all (lambda (vc)
                       (false-if-exception (system* "rm" "-rf" TEST_DIR)))
         (test "a mermaid diagram a renderer drew becomes the image it wrote"
               (let* ((stem (diagram-stem "render-me" EXAMPLE))
                      (nodes (render "mermaid" EXAMPLE "render-me" FAKE_MERMAID)))
                 (assert-equal
                  #:name "the node is a paragraph holding the image"
                  #:expect `(para (image (% (file ,(format #f "diagrams/~a" stem))
                                           (alt-text "Mermaid diagram"))))
                  #:got (first nodes))
                 (assert-true (file-exists? (diagram-file stem "png"))
                              #:name "the image is written where the reference says")
                 (assert-true (file-exists? (diagram-file stem "mmd"))
                              #:name "the source stays beside the image for a reader who re-renders it")))
         (test "a mermaid diagram no renderer drew is left as marked source"
               (let ((nodes (render "mermaid" EXAMPLE "unrendered" "")))
                 (assert-equal #:name "the source is shown instead of an image"
                               #:expect (list 'para 'example)
                               #:got (map car nodes))
                 ;; The marker is a mermaid comment, so the source is still a
                 ;; diagram, and the script uses it to tell one from a sample.
                 (assert-equal #:name "the script can tell the diagram from a sample"
                               #:expect (format #f "~a~%~a"
                                                EXAMPLE MERMAID_SOURCE_MARKER)
                               #:got (cadr (second nodes)))))
         (test "a plot a renderer drew becomes the SVG gnuplot wrote, named as such"
               (let ((stem (diagram-stem "plot-me" PLOT)))
                 (assert-equal
                  #:name "the node is a paragraph holding an SVG image"
                  #:expect `(para (image (% (file ,(format #f "diagrams/~a" stem))
                                           (alt-text "Gnuplot diagram")
                                           (extension "svg"))))
                  #:got (first (render "gnuplot" PLOT "plot-me" FAKE_GNUPLOT)))
                 (assert-true (file-exists? (diagram-file stem "gp"))
                              #:name "the plot's source is kept, without the terminal the run chose")
                 (assert-true (file-exists? (diagram-file stem "svg"))
                              #:name "the image gnuplot wrote is the one used")
                 (assert-true (not (file-exists? (diagram-file stem "render.gp")))
                              #:name "no wrapper script is left behind")
                 ;; The terminal and the output path belong to the run, not to
                 ;; the plot a project commits.
                 (let ((svg (call-with-input-file (diagram-file stem "svg")
                              get-string-all)))
                   (assert-contains #:name "the terminal that draws an SVG is asked for"
                                    #:expect svg
                                    #:got "set terminal svg")
                   (assert-not-contains
                    #:name "no background is asked for, which gnuplot 6 would refuse"
                    #:expect svg
                    #:got "transparent"))))
         (test "a gnuplot diagram nothing drew is left as plain source"
               (assert-equal #:expect (list '(para "Gnuplot diagram, as source:")
                                            `(example ,PLOT))
                             #:got (render "gnuplot" PLOT "unrendered-plot" "")
                             #:name "gnuplot has no browser path, so the source stands"))
         (test "an image already in the destination is used without a renderer"
               (let* ((stem (diagram-stem "pre-rendered" EXAMPLE))
                      (image (diagram-file stem "png")))
                 ;; `-p' because another scenario's renderer may have made the
                 ;; directory already.
                 (system* "mkdir" "-p" (format #f "~a/diagrams" TEST_DIR))
                 (call-with-output-file image
                   (lambda (port)
                     (display "rendered earlier" port)))
                 (assert-equal
                  #:expect `(para (image (% (file ,(format #f "diagrams/~a" stem))
                                           (alt-text "Mermaid diagram"))))
                  #:got (first (render "mermaid" EXAMPLE "pre-rendered" "")))))))


(define (spec)
  (veritas-run diagram-blocks-suite
               diagram-stem-suite
               diagram-stexi-suite))
