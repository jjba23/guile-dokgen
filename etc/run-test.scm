;; guile-documenta --- run one SRFI-64 test file and exit with its verdict
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; SRFI-64 reports failures but never turns them into an exit status, so a
;; `maak test' built on a bare `guile file.scm' would stay green over a red
;; suite.  This installs a runner whose counters are read once the file has
;; been loaded: 0 when nothing failed, 1 otherwise.
;;
;; Usage: guile -L src -L . etc/run-test.scm tests/test-utils.scm

;;; Code:

(use-modules (srfi srfi-64))

(define runner #f)

(test-runner-factory
 (lambda ()
   (set! runner (test-runner-simple))
   runner))

(load (canonicalize-path (cadr (command-line))))

(exit (if (and runner (zero? (test-runner-fail-count runner))) 0 1))
