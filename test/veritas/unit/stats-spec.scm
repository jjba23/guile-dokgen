;; guile-dokgen --- test: veritas/unit/stats-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What (dokgen stats) counts in a tree: the lines of code, of comment and of
nothing, the points where the code branches, and what a repository's own
history says about who wrote it and which files cost the most.

Both parsers are handed text written by hand here rather than a real tree, so
every number a report shows can be checked against a source and a log a
reader holds in front of them.  A count that is wrong is silent: nothing
raises, and the report simply describes a tree that is not there. |#

(define-module (veritas unit stats-spec)
  #:use-module (dokgen stats)
  #:use-module (srfi srfi-1)
  #:use-module (veritas all))


;;; CONSTANTS

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


;;; HELPERS

;; Parsed for each test that reads them, so the case that fails names the
;; number it broke and not a fixture that broke once for all of them.
(define (example-totals)
  (project-stats EXAMPLE-FILES))

(define (example-history)
  (parse-git-log EXAMPLE-GIT-LOG))


;;; SUITES

(define analyze-source-suite
  (suite "What a single file of Scheme source is made of"
         (test "a line of code, a line of comment and a blank line are told apart"
               (assert-equal
                #:expect '((blank . 2) (comment . 4) (code . 5) (decisions . 1))
                #:got (analyze-source EXAMPLE-SOURCE)))
         (test "one decision point is counted for each branching form"
               (assert-equal
                #:expect 4
                #:got (assoc-ref
                       (analyze-source
                        "(if a b c)\n(cond (a b))\n(when a b)\n(unless a b)\n")
                       'decisions)))
         (test "a branch written in a comment or in a string is not counted"
               (assert-equal
                #:expect 0
                #:got (assoc-ref
                       (analyze-source
                        ";; (if a b c)\n(display \"(if a b c)\")\n#| (when a b) |#\n")
                       'decisions)))
         (test "an empty file counts nothing"
               (assert-equal
                #:expect '((blank . 0) (comment . 0) (code . 0) (decisions . 0))
                #:got (analyze-source "")))
         (test "the line of a file that ends without a newline is counted"
               (assert-equal
                #:expect '((blank . 0) (comment . 0) (code . 1) (decisions . 0))
                #:got (analyze-source "(display x)")))
         (test "every line of a string that spans several of them is counted"
               (assert-equal
                #:expect '((blank . 0) (comment . 0) (code . 3) (decisions . 0))
                #:got (analyze-source "(display \"one\ntwo\")\n(display x)\n")))
         (test "every line of a block comment that spans several of them is counted"
               (assert-equal
                #:expect '((blank . 0) (comment . 2) (code . 1) (decisions . 0))
                #:got (analyze-source "#| one\ntwo |#\n(display x)\n")))
         (test "a string holding an escaped quote stays one string"
               (assert-equal
                #:expect '((blank . 0) (comment . 0) (code . 1) (decisions . 0))
                #:got (analyze-source
                       "(display \"a \\\" b ; still the string\")\n")))))


(define project-stats-suite
  (suite "The totals of a project's files, and the order they are shown in"
         (test "the files' counts are added up"
               (assert-equal
                #:expect '((blank . 2) (comment . 4) (code . 6)
                           (decisions . 1) (bytes . 162))
                #:got (remove (lambda (entry) (eq? (car entry) 'files))
                              (example-totals))))
         (test "the files are listed largest first, so a reader sees where the code is"
               (assert-equal
                #:expect '("large.scm" "small.scm")
                #:got (map (lambda (file) (assoc-ref file 'name))
                           (assoc-ref (example-totals) 'files))))))


(define parse-git-log-suite
  (suite "What a repository's history says once git has printed it"
         (test "the commits the log holds are counted"
               (assert-equal
                #:expect 2
                #:got (assoc-ref (example-history) 'commits)))
         (test "the report is named after the newest commit"
               (assert-equal
                #:expect "ff0021d"
                #:got (assoc-ref (example-history) 'commit)))
         (test "the newest and the oldest commit are dated in UTC"
               (assert-equal
                #:expect '("2026-11-21" "2026-11-20")
                #:got (list (assoc-ref (example-history) 'last)
                            (assoc-ref (example-history) 'first))))
         (test "each author's additions and removals are summed, the largest first"
               (assert-equal
                #:expect '(("Someone Else" 40 2) ("Josep Bigorra" 12 4))
                #:got (assoc-ref (example-history) 'authors)))
         (test "what each file cost is summed, largest first, skipping what git cannot count"
               (assert-equal
                #:expect '(("src/dokgen/stats.scm" 52 5) ("README.org" 0 1))
                #:got (assoc-ref (example-history) 'files)))
         (test "no history at all is reported as nothing"
               (assert-equal
                #:expect #false
                #:got (parse-git-log "")))))

(define (spec)
  (veritas-run analyze-source-suite
               project-stats-suite
               parse-git-log-suite))
