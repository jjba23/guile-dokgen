#| Documentation commands.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta commands)
  #:declarative? #false  ; Because it loads modules.
  #:use-module (ice-9 ftw)
  #:export (build))


;;; CONSTANTS

(define DEFAULT_DOC_PATH "doc/api")


;;; COMMANDS

(define* (build directory #:key (destination #false))
  #| Build the API documentation for the library in the given directory.

  DESTINATION (string)
    Optional path to a directory where the documentation should be
    saved. If not provided, the documentation will be saved in the
    current working directory, in a subdirectory called "doc/api".

  RESULT
    A summary report is displayed in the standard output with the
    results of running the test suite. A full report is saved to a log
    file in LOG_PATH. |#
  (display "TODO: Build API documentation for\n")
  (display directory)
  (newline))
