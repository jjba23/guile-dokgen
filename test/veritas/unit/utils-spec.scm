;; guile-dokgen --- test: veritas/unit/utils-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What (dokgen utils) does to a string on its way to a chapter: it measures
the indentation, turns tabs into spaces, and drops the indentation a docstring
was aligned to so that its examples keep only the indent they meant.

Getting this wrong changes every rendered example, and the two indentation
units are easy to confuse - min-indent measures where unindent cuts - so each
one is pinned here on its own, including the empty and one-line docstrings that
reach it. |#

(define-module (veritas unit utils-spec)
  #:use-module (dokgen utils)
  #:use-module (veritas all))

;; The default replacement for a tab, spelled out to compare against.
(define SPACE_TAB (make-string DEFAULT_SPACE_INDENT_SIZE #\space))

(define min-indent-suite
  (suite "The shortest indentation in a docstring"
         (test "the shallowest of several paragraphs is the answer"
               ;; The third line is indented twice as deep as the others, so a
               ;; wrong fold would report the deeper indent.
               (let* ((indent-size 3)
                      (tab (make-string indent-size #\space)))
                 (assert-equal
                  #:expect indent-size
                  #:got (min-indent
                         (string-append
                          "First paragraph.\n"
                          "\n"
                          tab "Second paragraph.\n"
                          "\n"
                          tab tab "Indented example.\n"
                          "\n"
                          tab "Third paragraph.")))))
         (test "an empty string is indented by nothing"
               (assert-equal #:expect 0 #:got (min-indent "")))
         (test "a single line has no indentation to measure"
               (assert-equal #:expect 0
                             #:got (min-indent
                                    "Single line (no newlines).")))))

(define tabs->spaces-suite
  (suite "Tabs become spaces"
         (test "each tab becomes the default number of spaces"
               (assert-equal #:expect (string-append SPACE_TAB SPACE_TAB
                                                     "Line." SPACE_TAB "\n")
                             #:got (tabs->spaces "\t\tLine.\t\n")))
         (test "each tab becomes the size the caller asks for"
               (let ((tab (make-string 4 #\space)))  ; A four-space indentation.
                 (assert-equal #:expect (string-append tab tab "Line." tab "\n")
                               #:got (tabs->spaces "\t\tLine.\t\n" 4))))))

(define trim-suite
  (suite "Trimming a number of spaces off the front of a line"
         (test "exactly that many spaces come off"
               (assert-equal
                #:expect "Line."
                #:got (trim (string-append
                             (make-string DEFAULT_SPACE_INDENT_SIZE #\space)
                             "Line.")
                            DEFAULT_SPACE_INDENT_SIZE)))
         (test "a line indented deeper keeps what lies past the cut"
               (assert-equal #:expect (string-append (make-string 2 #\space)
                                                     "Line.")
                             #:got (trim (string-append
                                          (make-string 4 #\space) "Line.")
                                         2)))))

(define unindent-suite
  (suite "Dropping the indentation a docstring was aligned to"
         (test "tab indentation is removed from every line"
               (assert-equal
                #:expect (string-append
                          "First paragraph.\n"
                          "\n"
                          "Second paragraph.\n"
                          "\n"
                          "Third paragraph.\n"
                          "\n"
                          "Fourth paragraph.")
                #:got (unindent
                       (string-append
                        "First paragraph.\n"
                        "\n"
                        "\tSecond paragraph.\n"
                        "\n"
                        "\tThird paragraph.\n"
                        "\n"
                        "\tFourth paragraph."))))
         (test "space indentation is removed from every line"
               (assert-equal
                #:expect (string-append
                          "First paragraph.\n"
                          "\n"
                          "Second paragraph.\n"
                          "\n"
                          "Third paragraph.\n"
                          "\n"
                          "Fourth paragraph.")
                #:got (unindent
                       (string-append
                        "First paragraph.\n"
                        "\n"
                        SPACE_TAB "Second paragraph.\n"
                        "\n"
                        SPACE_TAB "Third paragraph.\n"
                        "\n"
                        SPACE_TAB "Fourth paragraph."))))
         (test "indentation deeper than the shallowest line is left alone"
               ;; This is what makes an indented example inside a docstring
               ;; survive, so it is the case the whole pipeline depends on.
               (assert-equal
                #:expect (string-append
                          "First paragraph.\n"
                          "\n"
                          "Second paragraph.\n"
                          "\n"
                          SPACE_TAB "Indented paragraph.\n"
                          "\n"
                          "Last paragraph.")
                #:got (unindent
                       (string-append
                        "First paragraph.\n"
                        "\n"
                        "\tSecond paragraph.\n"
                        "\n"
                        "\t\tIndented paragraph.\n"
                        "\n"
                        "\tLast paragraph."))))
         (test "an empty docstring stays empty"
               (assert-equal #:expect "" #:got (unindent "")))
         (test "a docstring of one line comes back unchanged"
               (assert-equal #:expect "One line." #:got (unindent "One line.")))))

(define (spec)
  (veritas-run min-indent-suite
               tabs->spaces-suite
               trim-suite
               unindent-suite))
