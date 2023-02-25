#| Documentation commands.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta commands)
  #:declarative? #false  ; Because it loads modules.
  #:use-module ((documenta data) #:prefix data:)
  #:use-module ((documenta templates stexi) #:prefix stexi:)
  #:use-module (documenta writer)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (texinfo serialize)
  #:export (DEFAULT_DOC_PATH

            build))


;;; CONSTANTS

(define DEFAULT_DOC_PATH "doc/api")
(define DEFAULT_API_FILE_INDEX "index.texi")


;;; COMMANDS

(define* (build directory #:optional (destination DEFAULT_DOC_PATH))
  "Build the API documentation for the library in the given directory.

  DIRECTORY (string):
    Absolute or relative path to a directory containing a Guile Scheme
    library.

  DESTINATION (string):
    Optional path to a directory where the documentation should be
    saved. If not provided, the documentation will be saved in the
    current working directory, in a subdirectory defined by the constant
    DEFAULT_DOC_PATH.

  RESULT:
    The API documentation is saved to the DESTINATION directory."
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
                        (sort file-paths string<?)))
         (api-file-path (string-append destination
                                       file-name-separator-string
                                       DEFAULT_API_FILE_INDEX))]

    ;; Add the library to GUILE_LOAD_PATH so that it can be inspected.
    (add-to-load-path lib-parent-path)

    ;; Save API documentation to the destination directory.
    (save
     (stexi->texi
      (stexi:api-chapter
       (map stexi:module-section module-names)))
     api-file-path)

    (format
     #true
     "API documentation of ~a library saved to ~a~%"
     directory
     destination)))
