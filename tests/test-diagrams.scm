;; guile-dokgen --- tests: test-diagrams
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (dokgen diagrams). |#

(use-modules ((dokgen diagrams) #:prefix diagrams:)
             (ice-9 format)
             (ice-9 ftw)
             (ice-9 regex)
             (proba utils)
             (srfi srfi-1)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(dokgen diagrams)")

;; A directory of its own, so that what a rendered diagram writes never
;; lands in the tree and goes away with the suite.
(define TEST_DIR (format #f "/tmp/dokgen-test-~a" (getpid)))

;; The renderers the suites use: the program under test spawns them the way
;; it spawns a real one, so the spawn itself is tested too.
(define FAKE_RENDERER
  (format #f "sh ~a/fake-mermaid %i %o" (dirname (current-filename))))
(define FAKE_GNUPLOT
  (format #f "sh ~a/fake-gnuplot %i %o" (dirname (current-filename))))

(define EXAMPLE "graph TD\n  source --> manual")
(define PLOT "plot sin(x)")


;;; HELPERS

(define (make-diagram-dir)
  "Create the directory a rendered diagram is written to."
  (unless (file-exists? TEST_DIR)
    (mkdir TEST_DIR)
    (mkdir (format #f "~a/diagrams" TEST_DIR))))



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name diagrams:diagram-blocks)

  (test-equal
      "Leave a docstring with no diagram as a single text block."
    (list (cons 'text "Just prose."))
    (diagrams:diagram-blocks "Just prose."))

  (test-equal
      "Split a fenced diagram out of the prose around it."
    (list (cons 'text "Before.")
          (list 'diagram "mermaid" EXAMPLE)
          (cons 'text "After."))
    (diagrams:diagram-blocks
     (format #f "Before.~%```mermaid~%~a~%```~%After." EXAMPLE)))

  (test-equal
      "Read a fence that stands on an indented line."
    (list (list 'diagram "mermaid" EXAMPLE))
    (diagrams:diagram-blocks
     (format #f "  ```mermaid~%~a~%  ```" EXAMPLE)))

  (test-equal
      "Read a gnuplot fence as gnuplot."
    (list (list 'diagram "gnuplot" PLOT))
    (diagrams:diagram-blocks
     (format #f "```gnuplot~%~a~%```" PLOT)))

  (test-equal
      "Leave a fence of a language dokgen does not read as text."
    (list (cons 'text (format #f "```dot~%digraph { a -> b }~%```")))
    (diagrams:diagram-blocks "```dot\ndigraph { a -> b }\n```"))

  (test-equal
      "Keep an unterminated fence as text, so nothing is lost."
    (list (cons 'text (format #f "Before.~%```mermaid~%~a" EXAMPLE)))
    (diagrams:diagram-blocks
     (format #f "Before.~%```mermaid~%~a" EXAMPLE)))

  (test-equal
      "Read two diagrams in one docstring."
    (list (list 'diagram "mermaid" EXAMPLE)
          (cons 'text "Prose.")
          (list 'diagram "mermaid" EXAMPLE))
    (diagrams:diagram-blocks
     (format #f "```mermaid~%~a~%```~%Prose.~%```mermaid~%~a~%```"
             EXAMPLE EXAMPLE)))

    (test-equal
        "Leave a diagram quoted inside a Texinfo block alone, as a sample."
      (list (cons 'text (format #f "@example~%Write it so:~%```mermaid~%~a~%```~%@end example"
                                EXAMPLE)))
      (diagrams:diagram-blocks
       (format #f "@example~%Write it so:~%```mermaid~%~a~%```~%@end example" EXAMPLE))))


(test-group
    (unit-name diagrams:diagram-stem)

  (test-assert
      "Name a diagram after what it holds, so a stale image is never shown."
    (equal? (diagrams:diagram-stem "manual" EXAMPLE)
            (diagrams:diagram-stem "manual" EXAMPLE)))

  (test-assert
      "Give a changed diagram a name of its own."
    (not (equal? (diagrams:diagram-stem "manual" EXAMPLE)
                 (diagrams:diagram-stem "manual" "graph LR\n  source --> manual"))))

  (test-assert
      "Name a diagram after its owner, with a file name a shell and a URL accept."
    (string-match "^api-symbols-[0-9a-f]+$"
                  (diagrams:diagram-stem "api symbols" EXAMPLE))))


(test-group
    (unit-name diagrams:diagram-stexi)

  (let* [(stem (diagrams:diagram-stem "render-me" EXAMPLE))
         (nodes (parameterize ((diagrams:*diagram-destination* TEST_DIR)
                               (diagrams:*mermaid-command* FAKE_RENDERER))
                  (diagrams:diagram-stexi "mermaid" EXAMPLE "render-me")))]

    (test-equal
        "Show a rendered diagram as an image, in a paragraph of its own."
      `(para (image (% (file ,(format #f "diagrams/~a" stem))
                       (alt-text "Mermaid diagram"))))
      (first nodes))

    (test-assert
        "Write the diagram where the reference says it is."
      (file-exists? (format #f "~a/diagrams/~a.png" TEST_DIR stem)))

    (test-assert
        "Keep the diagram's source beside the image, for the reader who re-renders it."
      (file-exists? (format #f "~a/diagrams/~a.mmd" TEST_DIR stem))))


  (let [(nodes (parameterize ((diagrams:*diagram-destination* TEST_DIR)
                              (diagrams:*mermaid-command* ""))
                 (diagrams:diagram-stexi "mermaid" EXAMPLE "unrendered")))]

    (test-equal
        "Show the source when no renderer is configured."
      (list 'para 'example)
      (map car nodes))

    (test-equal
        "Mark the source so the script can draw it in the page."
      (format #f "~a~%~a" EXAMPLE diagrams:MERMAID_SOURCE_MARKER)
      (cadr (second nodes))))


  (let* [(stem (diagrams:diagram-stem "plot-me" PLOT))
         (nodes (parameterize ((diagrams:*diagram-destination* TEST_DIR)
                               (diagrams:*gnuplot-command* FAKE_GNUPLOT))
                  (diagrams:diagram-stexi "gnuplot" PLOT "plot-me")))]

    (test-equal
        "Show a plot as the SVG gnuplot wrote, and name its own extension."
      `(para (image (% (file ,(format #f "diagrams/~a" stem))
                       (alt-text "Gnuplot diagram")
                       (extension "svg"))))
      (first nodes))

    (test-assert
        "Keep the plot's source, without the terminal the run chose."
      (file-exists? (format #f "~a/diagrams/~a.gp" TEST_DIR stem)))

    (test-assert
        "Use the image gnuplot wrote."
      (file-exists? (format #f "~a/diagrams/~a.svg" TEST_DIR stem)))

    (test-assert
        "Leave no wrapper script behind."
      (not (file-exists? (format #f "~a/diagrams/~a.render.gp" TEST_DIR stem)))))


  (let* [(stem (diagrams:diagram-stem "unrendered-plot" PLOT))
         (nodes (parameterize ((diagrams:*diagram-destination* TEST_DIR)
                               (diagrams:*gnuplot-command* ""))
                  (diagrams:diagram-stexi "gnuplot" PLOT "unrendered-plot")))]

    (test-equal
        "Show a gnuplot diagram as source when nothing draws it."
      (list '(para "Gnuplot diagram, as source:")
            `(example ,PLOT))
      nodes))

  (let* [(stem (diagrams:diagram-stem "pre-rendered" EXAMPLE))
         (image (format #f "~a/diagrams/~a.png" TEST_DIR stem))]

    (make-diagram-dir)
    (call-with-output-file image (lambda (port) (display "rendered earlier" port)))

    (test-equal
        "Use an image that is already in the destination."
      `(para (image (% (file ,(format #f "diagrams/~a" stem))
                       (alt-text "Mermaid diagram"))))
      (first (parameterize ((diagrams:*diagram-destination* TEST_DIR)
                            (diagrams:*mermaid-command* ""))
               (diagrams:diagram-stexi "mermaid" EXAMPLE "pre-rendered"))))))

(test-end SUITE_NAME)

;; `rm -rf` and not a recursive delete from a library: the suites
;; take no dependency they do not test.
(false-if-exception (system* "rm" "-rf" TEST_DIR))
