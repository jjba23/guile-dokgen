;;; Commentary:

#| This module defines procedures that are associated to every command
provided by the command-line interface of the @command{documenta}
program. See the @ref{CLI} and @xref{documenta_cli, (documenta cli)}
sections for additional information. |#

;;; Code:

(define-module (documenta commands)
  #:declarative? #false                 ; Because it loads modules.
  #:use-module ((documenta data) #:prefix data:)
  #:use-module ((documenta templates stexi) #:prefix stexi:)
  #:use-module (documenta writer)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (texinfo serialize)
  #:export (DEFAULT_DOC_PATH

             api))


;;; CONSTANTS

(define DEFAULT_DOC_PATH "doc/api")
(define DEFAULT_API_FILE_INDEX "index.texi")


;;; COMMANDS

(define* (api sources #:optional (destination DEFAULT_DOC_PATH))
  "Extract the API documentation of the given set of Guile Scheme
   modules.

  @strong{sources} (list of strings):
    Absolute or relative paths to Guile Scheme modules that compose
    the code whose API documentation will be extracted. These paths
    can lead to both Scheme files or Scheme directories. For example:

  @example
  (list «myproject/liby.scm»
        «myproject/liby»
        «myproject/libz.scm»
        «myproject/libz»)
  @end example

  @strong{destination} (string):
    Optional path to a directory where the final Texinfo files will be
    saved. If not provided, @var{DEFAULT_DOC_PATH} is used (see the
    module @ref{documenta_commands}).

  @strong{Result}:
    The API documentation is saved to the @var{destination} directory."
  (let* [(canonical-source-paths
          ;; Cleaned, absolute paths to the code sources.
          (map
           (lambda (source)
             (if (absolute-file-name? source)
                 (canonicalize-path source)
                 (canonicalize-path
                  (string-append (getcwd)
                                 file-name-separator-string
                                 source))))
           sources))
         (scheme-file-paths
          (fold
           (lambda (source-path result-so-far)
             (let [(path-type           ; file, directory
                    (stat:type (stat source-path)))]

               (if (equal? path-type 'directory)
                   (append result-so-far (data:get-file-paths source-path))
                   (cons source-path result-so-far))))
           '()
           canonical-source-paths))
         (sources-parent-path (dirname (first canonical-source-paths)))
         (module-names
          (map
           (lambda (file-path)
             (data:file-path->module-name file-path
                                          sources-parent-path))
           (sort scheme-file-paths string<?)))
         (api-file-path (string-append destination
                                       file-name-separator-string
                                       DEFAULT_API_FILE_INDEX))]

    ;; Add the directory containing the source modules to
    ;; GUILE_LOAD_PATH so that they can be inspected.
    (add-to-load-path sources-parent-path)

    ;; Save API documentation to the destination directory.
    (save
     (stexi->texi
      (stexi:api-chapter
       (map stexi:module-section module-names)))
     api-file-path)

    (format #true "API documentation saved to ~a~%" destination)))
