;; guile-dokgen --- test: plotlib/plot
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; This module's commentary carries a gnuplot diagram, to test that a
;; plot written in a commentary reaches the generated documentation,
;; drawn or not.
;;
;; ```gnuplot
;; set xlabel "requests"
;; plot sin(x) title "response"
;; ```
;;
;;; Code:

(define-module (plotlib plot)
  #:export (draw))


(define (draw)
  "This procedure says what it draws."

  #true)
