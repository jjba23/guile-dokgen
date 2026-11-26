;; guile-dokgen --- test: cleanlib/documented
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; A library `dokgen check' has nothing to say about: every name it
;; exports is documented, or cannot be.
;;
;;; Code:

(define-module (cleanlib documented)
  #:export (documented
            documented-variable
            some-parameter))


(define (documented)
  "This procedure says what it does."

  #true)


(define documented-variable 42)


(define some-parameter (make-parameter 1))
