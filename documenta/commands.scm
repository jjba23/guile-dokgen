#| Documentation commands.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta commands)
  #:declarative? #false  ; Because it loads modules.
  #:use-module ((documenta data) #:prefix data:)
  #:use-module (documenta templates)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:export (build))


;;; CONSTANTS

(define DEFAULT_DOC_PATH "doc/api")


;;; COMMANDS

(define* (build directory #:key (destination DEFAULT_DOC_PATH))
  "Build the API documentation for the library in the given directory.

  DIRECTORY (string)
    Absolute or relative path to a directory containing a Guile Scheme
    library.

  DESTINATION (string)
    Optional path to a directory where the documentation should be
    saved. If not provided, the documentation will be saved in the
    current working directory, in a subdirectory called «doc/api».

  RESULT
    A summary report is displayed in the standard output with the
    results of running the test suite. A full report is saved to a log
    file in LOG_PATH."
  (let* [(canonical-lib-path
          (if (absolute-file-name? directory)
              (canonicalize-path directory)
              (canonicalize-path
               (string-append (getcwd)
                              file-name-separator-string
                              directory))))
         (lib-parent-path (dirname canonical-lib-path))
         (file-paths (data:get-file-paths canonical-lib-path))
         (module-names (map
                        (lambda (file-path)
                          (data:file-path->module-name file-path
                                                       lib-parent-path))
                        file-paths))]

    ;; Add the library to GUILE_LOAD_PATH so that it can be inspected.
    (add-to-load-path lib-parent-path)

    ;; Save API documentation to the destination directory.
    (format #true "Library: ~a~%" directory)
    (for-each
     (lambda (module-name)
       (display (texi:module-section module-name)))
     module-names)))
