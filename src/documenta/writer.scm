;; guile-documenta --- writing documentation to disk
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| Procedures for writing data to disk. |#

;;; Code:

(define-module (documenta writer)
  #:export (save))


(define (save text path)
  "Write @var{text} to the file in @var{path}.

  @strong{text} (string):
    Arbitrary text.

  @strong{path} (string):
    Absolute or relative path to the file the text will be written to.

  @strong{Result}:
    If the file doesn't exist, it will be created and the text will be
    saved to it. If the file exists, its contents will be overwritten."
  (system* "mkdir" "-p" (dirname path))
  (call-with-output-file path
    (lambda (port) (display text port))
    #:encoding "UTF-8"))
