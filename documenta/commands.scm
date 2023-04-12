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

            extract))


;;; CONSTANTS

(define DEFAULT_DOC_PATH "doc/api")
(define DEFAULT_API_FILE_INDEX "index.texi")


;;; COMMANDS

(define* (extract source #:optional (destination DEFAULT_DOC_PATH))
  "Extract the documentation of the library defined in source.

  SOURCE (string):
    An absolute or relative path to a single Guile Scheme module file
    or to a directory containing a collection of modules. For example:
    «projects/project-x/libx.scm», «projects/project-z/libz».

  DESTINATION (string):
    Optional path to a directory where the final Texinfo files will be
    saved. If not provided, DEFAULT_DOC_PATH is used (see the module
    @ref{documenta-commands}).

  RESULT:
    The API documentation is saved to the destination directory."
  (let* [(canonical-lib-path
          (if (absolute-file-name? source)
              (canonicalize-path source)
              (canonicalize-path
               (string-append (getcwd)
                              file-name-separator-string
                              source))))
         (lib-path-type (stat:type (stat canonical-lib-path)))  ; File, dir?
         (lib-parent-path (dirname canonical-lib-path))
         (file-paths            ; Files to extract documentation from.
          (if (equal? lib-path-type 'directory)
              (data:get-file-paths canonical-lib-path)
              (list canonical-lib-path)))
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
     source
     destination)))
