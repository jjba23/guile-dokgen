;; guile-documenta --- tests: test-utils
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (documenta utils). |#

(use-modules (documenta utils)
             (proba utils)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta utils)")
(define SPACE_TAB (make-string DEFAULT_SPACE_INDENT_SIZE #\space))



;;; TEST DATA

;;; ...



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name min-indent)

  (let* [(test-name
          "Find the shorter number of spaces used for indentation.")
         (indent-size 3)
         (tab (make-string indent-size #\space))]

    (test-equal
        test-name
      indent-size
      (min-indent
       (string-append
        "First paragraph.\n"
        "\n"
        tab "Second paragraph.\n"
        "\n"
        tab tab "Indented example.\n"
        "\n"
        tab "Third paragraph."))))


  (test-equal
      "The indentation of an empty string is zero."
    0
    (min-indent ""))


  (test-equal
      "The indentation of a single-line string is zero."
    0
    (min-indent "Single line (no newlines).")))



(test-group
    (unit-name tabs->spaces)

  (test-equal
      "Replace tabs with default number of spaces."
    (string-append
     SPACE_TAB SPACE_TAB "Line." SPACE_TAB "\n")
    (tabs->spaces "\t\tLine.\t\n"))


  (let [(test-name "Replace tabs with custom number of spaces.")
        (tab (make-string 4 #\space))]  ; 4-spaces indentation.

    (test-equal
        test-name
      (string-append tab tab "Line." tab "\n")
      (tabs->spaces "\t\tLine.\t\n" 4))))



(test-group
    (unit-name trim)

  (test-equal
      "Trim off N spaces."
    "Line."
    (trim (string-append (make-string DEFAULT_SPACE_INDENT_SIZE #\space)
                         "Line.")
          DEFAULT_SPACE_INDENT_SIZE))


  (test-equal
      "Trim off more than N spaces."
    (string-append (make-string 2 #\space) "Line.")
    (trim (string-append (make-string 4 #\space) "Line.") 2)))



(test-group
    (unit-name unindent)

  (test-equal
      "Remove unwanted tab indentation."
    (string-append
     "First paragraph.\n"
     "\n"
     "Second paragraph.\n"
     "\n"
     "Third paragraph.\n"
     "\n"
     "Fourth paragraph.")
    (unindent
     (string-append
      "First paragraph.\n"
      "\n"
      "\tSecond paragraph.\n"
      "\n"
      "\tThird paragraph.\n"
      "\n"
      "\tFourth paragraph.")))


  (test-equal
      "Remove unwanted space indentation."
    (string-append
     "First paragraph.\n"
     "\n"
     "Second paragraph.\n"
     "\n"
     "Third paragraph.\n"
     "\n"
     "Fourth paragraph.")
    (unindent
     (string-append
      "First paragraph.\n"
      "\n"
      SPACE_TAB "Second paragraph.\n"
      "\n"
      SPACE_TAB "Third paragraph.\n"
      "\n"
      SPACE_TAB "Fourth paragraph.")))


  (test-equal
      "Leave desired tab indentation."
    (string-append
     "First paragraph.\n"
     "\n"
     "Second paragraph.\n"
     "\n"
     SPACE_TAB "Indented paragraph.\n"
     "\n"
     "Last paragraph.")
    (unindent
     (string-append
      "First paragraph.\n"
      "\n"
      "\tSecond paragraph.\n"
      "\n"
      "\t\tIndented paragraph.\n"
      "\n"
      "\tLast paragraph.")))


  (test-equal
      "Handle empty docstring."
    ""
    (unindent ""))


  (test-equal
      "Handle one-line docstring."
    "One line."
    (unindent "One line.")))

(test-end SUITE_NAME)
