;; guile-dokgen --- test: examplelib/diagrammed
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; This module's commentary carries a mermaid diagram, to test that a
;; diagram written in a commentary reaches the generated documentation,
;; drawn or not.
;;
;; ```mermaid
;; graph LR
;;   source --> manual
;; ```
;;
;;; Code:

(define-module (examplelib diagrammed)
  #:export (documented))


(define (documented)
  "This procedure says what it does."

  #true)
