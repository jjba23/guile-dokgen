;; guile-dokgen --- the commands the program runs
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines procedures that are associated to every command
provided by the command-line interface of the @command{dokgen}
program. See the @ref{CLI} and @xref{dokgen_cli, (dokgen cli)}
sections for additional information.

The variable @code{DEFAULT_DOC_PATH} is the directory where the API
documentation is saved when the user does not choose one; its value is
@samp{doc/api}. The documentation is written to a file named
@file{index.texi} inside that directory, and the images of the mermaid
diagrams it holds go in a @file{diagrams} directory beside it.

The procedure @code{api} writes that documentation; @code{check} only
reads, and says which of the exported names are documented nowhere.

```mermaid
graph LR
  sources["Scheme files and directories"] --> modules["module names"]
  modules --> exports["exported objects"]
  exports --> stexi["stexi"]
  stexi --> chapter["index.texi"]
```
|#

;;; Code:

(define-module (dokgen commands)
  #:declarative? #false                 ; Because it loads modules.
  #:use-module ((dokgen data) #:prefix data:)
  #:use-module ((dokgen diagrams) #:prefix diagrams:)
  #:use-module ((dokgen templates stexi) #:prefix stexi:)
  #:use-module (dokgen writer)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (texinfo serialize)
  #:export (DEFAULT_DOC_PATH

             api
             check))


;;; CONSTANTS

;; Directory where the API documentation is saved by default.
(define DEFAULT_DOC_PATH "doc/api")
;; Name of the file, inside the destination, that holds the API chapter.
(define DEFAULT_API_FILE_INDEX "index.texi")


;;; COMMANDS

(define (module-names-of sources)
  "Return the names of the modules SOURCES hold, and make them loadable.

  @strong{sources} (list of strings):
    Absolute or relative paths to Scheme files and directories.

  @strong{Return value} (list of lists of symbols):
    The module name of every Scheme file under SOURCES, in the order a
    reader meets them, with the directory that holds them added to the
    load path so that they can be inspected."
  (let* [(paths
          ;; Cleaned, absolute paths to the code sources.
          (map (lambda (source)
                 (canonicalize-path
                  (if (absolute-file-name? source)
                      source
                      (string-append (getcwd)
                                     file-name-separator-string
                                     source))))
               sources))
         (scheme-file-paths
          (sort (append-map (lambda (path)
                              (if (eq? 'directory (stat:type (stat path)))
                                  (data:get-file-paths path)
                                  (list path)))
                            paths)
                string<?))
         (parent (dirname (first paths)))]

    ;; The modules are inspected, so the directory holding them has to be
    ;; on the load path.
    (add-to-load-path parent)
    (map (lambda (file) (data:file-path->module-name file parent))
         scheme-file-paths)))

(define* (api sources
              #:optional (destination DEFAULT_DOC_PATH)
              (mermaid-command diagrams:DEFAULT_MERMAID_COMMAND))
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
    module @ref{dokgen_commands}).  The diagrams the documentation holds
    are saved to a @file{diagrams} directory inside it.

  @strong{mermaid-command} (string):
    Optional command that draws a mermaid diagram, with @code{%i} standing
    for the diagram's source and @code{%o} for the path to write its image
    to.  An empty command draws nothing and uses the diagrams already in
    the destination.

  @strong{Result}:
    The API documentation is saved to the @var{destination} directory."
  (let* [(module-names (module-names-of sources))
         (api-file-path (string-append destination
                                       file-name-separator-string
                                       DEFAULT_API_FILE_INDEX))]

    ;; The destination and the renderer are the same for every diagram in
    ;; the run, so they are set once here instead of being passed through
    ;; the templates that write the documentation.
    (parameterize [(diagrams:*diagram-destination* destination)
                   (diagrams:*mermaid-command* mermaid-command)]
      (save (stexi->texi
             (stexi:api-chapter
              module-names
              (map stexi:module-section module-names)))
            api-file-path))

    (format #true "API documentation saved to ~a~%" destination)))

(define (check sources)
  "Report the exported names the modules in SOURCES leave undocumented.

  @strong{sources} (list of strings):
    Absolute or relative paths to Scheme files and directories, as for
    @code{api}.

  @strong{Return value} (integer):
    The number of names reported, so that the caller decides what an
    undocumented name means for the exit status."
  (let [(gap
         (let* [(module-names (module-names-of sources))
                (report (append-map
                         (lambda (module-name)
                           (map (lambda (symbol)
                                  (cons module-name symbol))
                                (data:undocumented-symbols
                                 (resolve-interface module-name))))
                         module-names))]
           (for-each (lambda (entry)
                       (format #true "undocumented: ~a ~a~%"
                               (car entry) (cdr entry)))
                     report)
           (length report)))]
    (if (zero? gap)
        (format #true "dokgen: every exported procedure and macro is documented~%")
        (format #true "dokgen: ~a undocumented name~a~%"
                gap (if (= gap 1) "" "s")))
    gap))
