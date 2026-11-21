;; guile-dokgen --- tests: test-commands
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (dokgen commands). |#

(use-modules ((dokgen commands) #:prefix commands:)
             (ice-9 format)
             (ice-9 ftw)
             (ice-9 textual-ports)
             (proba utils)
             (srfi srfi-1)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(dokgen commands)")

;; A destination of its own, so that a run of a command never writes into
;; the tree and leaves nothing behind.
(define TEST_DIR (format #f "/tmp/dokgen-commands-~a" (getpid)))

(define BARE_DIR (format #f "~a-bare" TEST_DIR))

(define FAKE_RENDERER
  (format #f "sh ~a/fake-mermaid %i %o" (dirname (current-filename))))

;; Two libraries: one with gaps in it, and one a check has nothing to say
;; about.  Each is a directory whose modules are named after it, which is
;; how a project lays its own tree out.
(define LIBRARY "tests/examplelib")
(define CLEAN_LIBRARY "tests/cleanlib")


;;; HELPERS

(define (index-of destination)
  "Return the text of the API chapter written to DESTINATION."
  (call-with-input-file (format #f "~a/index.texi" destination)
    get-string-all))



(define (stats-of destination)
  "Return the text of the statistics chapter written to DESTINATION."
  (call-with-input-file (format #f "~a/stats.texi" destination)
    get-string-all))

;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name commands:check)

  (test-equal
      "Count the exported names a library leaves undocumented."
    2
    (commands:check (list LIBRARY)))

  (test-equal
      "Count nothing when every name is documented, or cannot be."
    0
    (commands:check (list CLEAN_LIBRARY)))

  (test-assert
      "Name the module and the name that has no documentation."
    (string-contains (with-output-to-string
                       (lambda () (commands:check (list LIBRARY))))
                     "undocumented: (examplelib mixed) blank-docstring")))


(test-group
    (unit-name commands:api)

    (commands:api (list LIBRARY) TEST_DIR FAKE_RENDERER)

  (test-assert
      "Write the API chapter to the destination."
    (file-exists? (format #f "~a/index.texi" TEST_DIR)))

  (test-assert
      "Name the documented module, so a reader can find its section."
    (string-contains (index-of TEST_DIR) "@node examplelib_diagrammed"))

  (test-assert
      "Reference the image of a diagram the documentation holds."
    (string-contains (index-of TEST_DIR) "@image{diagrams/examplelib_diagrammed-"))

  (test-assert
      "Write the diagram's image beside the chapter."
    (pair? (scandir (format #f "~a/diagrams" TEST_DIR)
                    (lambda (name) (string-suffix? ".png" name)))))


  (commands:api (list LIBRARY) TEST_DIR "")

  (test-assert
      "Keep a diagram whose image is already written when nothing draws it."
    (string-contains (index-of TEST_DIR) "@image{diagrams/examplelib_diagrammed-"))


  (commands:api (list LIBRARY) BARE_DIR "")

  (test-assert
      "Write a diagram's source when it has no image and no renderer."
    (string-contains (index-of BARE_DIR) "@example")))


(test-group
    (unit-name commands:stats)

  (commands:stats (list LIBRARY) TEST_DIR)

  (test-assert
      "Write the statistics chapter beside the API chapter."
    (file-exists? (format #f "~a/stats.texi" TEST_DIR)))

  (test-assert
      "Title the chapter a manual can include by name."
    (string-contains (stats-of TEST_DIR) "@chapter Statistics"))

  (test-assert
      "Report the size of what it measured."
    (string-contains (stats-of TEST_DIR) "lines of code"))

  (test-assert
      "Report how much of the exported API is documented."
    (string-contains (stats-of TEST_DIR) "2 of the 4 exported")))

(test-end SUITE_NAME)

;; `rm -rf` and not a recursive delete from a library: the suites
;; take no dependency they do not test.
(false-if-exception (system* "rm" "-rf" TEST_DIR))
(false-if-exception (system* "rm" "-rf" BARE_DIR))
