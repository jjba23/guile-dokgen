;; guile-dokgen --- test: examplelib/mixed
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; A module that exports both documented and undocumented names, to test
;; the report `dokgen check' makes: a procedure without a documentation
;; string is a gap, while a variable, a parameter and a record type cannot
;; carry one and are therefore never reported.
;;
;;; Code:

(define-module (examplelib mixed)
  #:export (documented
            undocumented
            blank-docstring
            documented-variable
            some-parameter))


(define (documented)
  "This procedure says what it does."

  #true)


(define (undocumented)
  #true)


(define (blank-docstring)
  "   "

  #true)


(define documented-variable 42)


(define some-parameter (make-parameter 1))
