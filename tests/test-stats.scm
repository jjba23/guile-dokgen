;; guile-dokgen --- tests: test-stats
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (dokgen stats). |#

(use-modules ((dokgen stats) #:prefix stats:)
             (ice-9 format)
             (proba utils)
             (srfi srfi-1)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(dokgen stats)")

;; A source file with one of everything the counter has to tell apart: a
;; line of code, a line of comment, a blank line, a string holding what
;; looks like a comment, and a block comment holding what looks like code.
(define EXAMPLE-SOURCE
  (string-append
   ";; A comment line.\n"
   "\n"
   "(define (f x)\n"
   "  ;; A comment that follows code on its own line.\n"
   "  (if (string=? x \"; not a comment\")\n"
   "      x\n"
   "      #true))\n"
   "\n"
   "#| A block comment.\n"
   "(if this were code it would be a decision) |#\n"
   "(display x)   ; trailing comment\n"))

;; What `git log --numstat' prints, cut down to two commits and two
;; authors: the marker line, then one line per touched file.
(define EXAMPLE-GIT-LOG
  (string-append
   "@@ff0021d\tJosep Bigorra\t1795259058\n"
   "12\t3\tsrc/dokgen/stats.scm\n"
   "0\t1\tREADME.org\n"
   "\n"
   "@@aa00119\tSomeone Else\t1795172658\n"
   "40\t2\tsrc/dokgen/stats.scm\n"
   "-\t-\timages/logo.png\n"))

;; Two files, so that the order a report shows them in is asserted.
(define EXAMPLE-FILES
  (list '((name . "small.scm") (blank . 0) (comment . 0) (code . 1)
          (decisions . 0) (bytes . 12))
        '((name . "large.scm") (blank . 2) (comment . 4) (code . 5)
          (decisions . 1) (bytes . 150))))



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name stats:analyze-source)

  (test-equal
      "Count the code, comment and blank lines of a source file."
    '((blank . 2) (comment . 4) (code . 5) (decisions . 1))
    (stats:analyze-source EXAMPLE-SOURCE))

  (test-equal
      "Count one decision point for each branching form in the code."
    4
    (assoc-ref (stats:analyze-source
                "(if a b c)\n(cond (a b))\n(when a b)\n(unless a b)\n")
               'decisions))

  (test-equal
      "Count no decision point for a branch in a comment or in a string."
    0
    (assoc-ref (stats:analyze-source
                ";; (if a b c)\n(display \"(if a b c)\")\n#| (when a b) |#\n")
               'decisions))

  (test-equal
      "Count nothing in an empty file."
    '((blank . 0) (comment . 0) (code . 0) (decisions . 0))
    (stats:analyze-source ""))

  (test-equal
      "Count the line of a file that ends without a newline."
    '((blank . 0) (comment . 0) (code . 1) (decisions . 0))
    (stats:analyze-source "(display x)"))

  (test-equal
      "Count every line of a string that spans several of them."
    '((blank . 0) (comment . 0) (code . 3) (decisions . 0))
    (stats:analyze-source "(display \"one\ntwo\")\n(display x)\n"))

  (test-equal
      "Count every line of a block comment that spans several of them."
    '((blank . 0) (comment . 2) (code . 1) (decisions . 0))
    (stats:analyze-source "#| one\ntwo |#\n(display x)\n"))

  (test-equal
      "Read a string that holds an escaped quote as one string."
    '((blank . 0) (comment . 0) (code . 1) (decisions . 0))
    (stats:analyze-source "(display \"a \\\" b ; still the string\")\n")))


(test-group
    (unit-name stats:project-stats)

  (let [(totals (stats:project-stats EXAMPLE-FILES))]

    (test-equal
        "Add the files' counts up."
      '((blank . 2) (comment . 4) (code . 6) (decisions . 1) (bytes . 162))
      (remove (lambda (entry) (eq? (car entry) 'files)) totals))

    (test-equal
        "Keep the files, largest first, so a reader sees where the code is."
      '("large.scm" "small.scm")
      (map (lambda (file) (assoc-ref file 'name)) (assoc-ref totals 'files)))))


(test-group
    (unit-name stats:parse-git-log)

  (let [(history (stats:parse-git-log EXAMPLE-GIT-LOG))]

    (test-equal
        "Count the commits the log holds."
      2
      (assoc-ref history 'commits))

    (test-equal
        "Name the newest commit, which is the one the report describes."
      "ff0021d"
      (assoc-ref history 'commit))

    (test-equal
        "Date the newest and the oldest commit, in UTC."
      '("2026-11-21" "2026-11-20")
      (list (assoc-ref history 'last) (assoc-ref history 'first)))

    (test-equal
        "Sum what each author added and removed, the largest first."
      '(("Someone Else" 40 2) ("Josep Bigorra" 12 4))
      (assoc-ref history 'authors))

    (test-equal
        "Sum what each file cost, largest first, and skip what git cannot count."
      '(("src/dokgen/stats.scm" 52 5) ("README.org" 0 1))
      (assoc-ref history 'files)))

  (test-equal
      "Report nothing when there is no history to read."
    #false
    (stats:parse-git-log "")))

(test-end SUITE_NAME)
