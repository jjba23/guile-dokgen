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
  #:use-module ((dokgen stats) #:prefix stats:)
  #:use-module ((dokgen templates stexi) #:prefix stexi:)
  #:use-module (dokgen writer)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (texinfo serialize)
  #:export (DEFAULT_DOC_PATH

             api
             check
             stats))


;;; CONSTANTS

;; Directory where the API documentation is saved by default.
(define DEFAULT_DOC_PATH "doc/api")
;; Name of the file, inside the destination, that holds the API chapter.
(define DEFAULT_API_FILE_INDEX "index.texi")
;; Name of the file, inside the destination, that holds the statistics.
(define DEFAULT_STATS_FILE_INDEX "stats.texi")


;;; COMMANDS

(define (source-tree sources)
  "Return the directory the modules are named from and the files under SOURCES.

  @strong{sources} (list of strings):
    Absolute or relative paths to Scheme files and directories.

  @strong{Return value} (list):
    The parent directory of the first source, and every Scheme file under
    all of them, sorted, so that a run means the same thing twice."
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
         (files (sort (append-map (lambda (path)
                                    (if (eq? 'directory (stat:type (stat path)))
                                        (data:get-file-paths path)
                                        (list path)))
                                  paths)
                      string<?))]
    (list (dirname (first paths)) files)))

(define (module-names-of sources)
  "Return the names of the modules SOURCES hold, and make them loadable.

  @strong{sources} (list of strings):
    Absolute or relative paths to Scheme files and directories.

  @strong{Return value} (list of lists of symbols):
    The module name of every Scheme file under SOURCES, in the order a
    reader meets them, with the directory that holds them added to the
    load path so that they can be inspected."
  (let* [(tree (source-tree sources))
         (parent (first tree))]
    ;; The modules are inspected, so the directory holding them has to be
    ;; on the load path.
    (add-to-load-path parent)
    (map (lambda (file) (data:file-path->module-name file parent))
         (second tree))))

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

(define (display-name path)
  "Return @var{path} as a reader would write it: relative to where dokgen ran.

  @strong{path} (string):
    An absolute path.

  @strong{Return value} (string):
    The path without the current directory in front of it when it is
    inside the current directory, and the whole path otherwise."
  (let [(here (string-append (getcwd) file-name-separator-string))]
    (if (string-prefix? here path)
        (substring path (string-length here))
        path)))

(define (named name statistics)
  "Return @var{statistics} with @var{name} as its name.

  @strong{name} (string):
    What a reader calls the file.

  @strong{statistics} (alist):
    What @code{(dokgen stats) analyze-file} returned for it.

  @strong{Return value} (alist):
    The same counts, named the way the reader wrote the path."
  (acons 'name name
         (filter (lambda (entry) (not (eq? (car entry) 'name))) statistics)))

(define (measured-history history files)
  "Return HISTORY with the churn of only the files FILES names.

  A commit that touches the sources touches other things as well, and a
  table headed ``the files that change most'' should name the files the
  chapter measured.  The authors stay as git reported them: they are the
  people who wrote these files, whichever file of a commit they edited.

  @strong{history} (alist or @code{#false}):
    What @code{(dokgen stats) git-stats} returned.

  @strong{files} (list of alists):
    The measured files, named as @code{analyze-file} names them.

  @strong{Return value} (alist or @code{#false}):
    The history, with its @code{files} entry filtered."
  (let [(names (map (lambda (file) (assoc-ref file 'name)) files))]
    (and history
         (acons 'files
                (filter (lambda (entry) (member (car entry) names))
                        (assoc-ref history 'files))
                history))))

(define (documentation-coverage module-names)
  "Return how many exported names MODULE-NAMES document, and how many there are.

  @strong{module-names} (list of lists of symbols):
    The modules to inspect.

  @strong{Return value} (pair):
    @code{(documented . exported)}, counting procedures and macros: they
    are the names that can carry a documentation string."
  (fold (lambda (module-name seed)
          (let* [(interface (resolve-interface module-name))
                 (groups (data:group-api-objects interface))
                 (exported (+ (length (or (assoc-ref groups "procedures") '()))
                              (length (or (assoc-ref groups "macros") '()))))
                 (undocumented (length (data:undocumented-symbols interface)))]
            (cons (+ (car seed) (- exported undocumented))
                  (+ (cdr seed) exported))))
        '(0 . 0)
        module-names))

(define* (stats sources #:optional (destination DEFAULT_DOC_PATH))
  "Measure the tree SOURCES hold and write its statistics chapter.

  @strong{sources} (list of strings):
    Absolute or relative paths to Scheme files and directories, as for
    @code{api}.

  @strong{destination} (string):
    Optional path to a directory where the Texinfo chapter will be saved.
    If not provided, @var{DEFAULT_DOC_PATH} is used.  The chapter is named
    @file{stats.texi}, so that a manual can include it beside the API
    chapter @code{api} writes.

  @strong{Result}:
    The statistics are saved to the @var{destination} directory, and the
    numbers a reader of a terminal wants are printed."
  (let* [(tree (source-tree sources))
         (parent (first tree))
         (files (second tree))
         (module-names (begin
                         (add-to-load-path parent)
                         (map (lambda (file)
                                (data:file-path->module-name file parent))
                              files)))
         (measured (map (lambda (file)
                          (named (display-name file) (stats:analyze-file file)))
                        files))
         (totals (stats:project-stats measured))
         (coverage (documentation-coverage module-names))
         (history (measured-history (stats:git-stats parent) measured))
         (statistics `((totals . ,totals)
                       (coverage . ,coverage)
                       (modules . ,(length module-names))
                       (git . ,history)))
         (path (string-append destination
                              file-name-separator-string
                              DEFAULT_STATS_FILE_INDEX))]

    (save (stexi->texi (stexi:stats-chapter statistics)) path)

    (format #true "~a files, ~a modules, ~a lines of code, ~a decision points~%"
            (length files) (length module-names)
            (assoc-ref totals 'code) (assoc-ref totals 'decisions))
    (format #true "~a of ~a exported names documented~%"
            (car coverage) (cdr coverage))
    (when history
      (format #true "~a commits by ~a author~a, the last on ~a~%"
              (assoc-ref history 'commits)
              (length (assoc-ref history 'authors))
              (if (= 1 (length (assoc-ref history 'authors))) "" "s")
              (assoc-ref history 'last)))
    (format #true "Statistics saved to ~a~%" destination)))
