#| Writing data to disk.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta writer)
  #:export (save))


(define (save text path)
  "Write TEXT to the file in PATH.

  TEXT (string):
    Arbitrary text.

  PATH (string):
    Absolute or relative path to the file the text will be written to.

  RESULT:
    If the file doesn't exist, it will be created and the text will be
    saved to it. If the file exists, its contents will be overwritten."
  (system* "mkdir" "-p" (dirname path))
  (call-with-output-file path
    (lambda (port) (display text port))
    #:encoding "UTF-8"))
