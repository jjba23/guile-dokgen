;; guile-dokgen --- tests: boguslibs/objects
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Dummy objects used for testing. |#

(define-module (tests boguslibs objects)
  #:export (parameter
            parameter-with-converter))


(define parameter (make-parameter "default value"))
(define parameter-with-converter
  (make-parameter 5 (lambda (val) (* 2 val))))
