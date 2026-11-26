;; guile-dokgen --- extracting API data from modules
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines procedures to retrieve data from Guile Scheme
libraries (e.g. the names and attributes of their Scheme modules and
the objects these modules export). This data is then passed to
template procedures to render API documentation in different
formats. See, for example, the templates used to work with the
@url{https://www.gnu.org/software/texinfo/, Texinfo format}:
@ref{dokgen_templates_stexi, (dokgen templates stexi)}. |#

;;; Code:

(define-module (dokgen data)
  #:use-module (dokgen exceptions)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 session)
  #:use-module (ice-9 textual-ports)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (srfi srfi-34)
  #:export (api-symbols
            definition-source
            file-path->module-name
            get-file-paths
            group-api-objects
            record-field
            undocumented-symbols))


(define (api-symbols interface)
  "Return the symbols provided by the interface.

  @strong{interface} (interface):
    A module's @code{<interface>} record as returned by Guile's
    procedure @code{resolve-interface}.

  @strong{Return value} (list of symbols):
    Where every symbol identifies a public object exported by the
    @var{interface}."
  (hash-map->list
   (lambda (key var) key)
   (record-field interface 'obarray)))


(define (get-file-paths directory)
  "Return a list of paths to Scheme files stored in the directory.

  Scheme files are identified by their @code{.scm} extension.

  @strong{directory} (string):
    Absolute path to a directory containing a Guile Scheme library.

  @strong{Return value} (list of strings):
    A list where every element represents a path to a Scheme file."
  (define (enter? name stat result)
    "Return true to enter any directory."
    #true)

  (define (leaf name stat result)
    "Add NAME to RESULT when it has a \".scm\" extension."
    (if (string-suffix? ".scm" name)
	(cons name result)
	result))

  (define (down name stat result)
    "Leave RESULT as it is: directories are not listed."
    result)
  (define (up name stat result)
    "Leave RESULT as it is when leaving a directory."
    result)

  (define (skip name stat result)
    "Leave RESULT as it is for skipped directories."
    result)

  (define (error name stat errno result)
    "Warn about the unreadable NAME and leave RESULT as it is."
    (format (current-error-port) "warning: ~a: ~a~%"
            name (strerror errno))
    result)

  (file-system-fold enter? leaf down up skip error (list) directory))


(define (group-api-objects interface)
  "Return the API objects grouped by kind.

  A kind can be one of the following: macros, parameters, procedures,
  record types, variables.

  @strong{interface} (interface):
    An @code{<interface>} record as returned by Guile's procedure
    @code{resolve-interface}.

  @strong{Return value} (alist):
    Association list where every entry corresponds to a kind of object
    and a list of its members. Only groups with members are returned."
  ;; Helpers.
  (define (add object group catalog)
    "Return a new CATALOG with OBJECT added to the GROUP.

    The groups are compared with @code{string=?} and not with the
    @code{eq?} that @code{assq-ref} would use: two occurrences of the same
    group name need not be the same string once a module is compiled, and a
    catalog that loses its own key is an @code{append} of @code{#f}."
    (map (lambda (entry)
           (if (string=? (car entry) group)
               (cons (car entry) (append (cdr entry) (list object)))
               entry))
         catalog))
  (define (kind-of value)
    "Return the name of the group the API object VALUE belongs to."
    (cond
     [(macro? value) "macros"]
     [(parameter? value) "parameters"]
     [(procedure? value) "procedures"]
     [(record-type? value) "record types"]
     [else "variables"]))
  (define (non-empty-group? group)
    "Return true if the GROUP has members."
    (not (null? (cdr group))))
  (define (symbol-precedes? a b)
    "Return true if symbol A goes before B alphabetically."
    (string<? (symbol->string a) (symbol->string b)))
  ;; Main body.
  (let* [(api-table (record-field interface 'obarray))
         (api-symbols (api-symbols interface))
         (api-symbols-sorted (sort api-symbols symbol-precedes?))
         (api-catalog (list (cons "macros" '())
                            (cons "parameters" '())
                            (cons "procedures" '())
                            (cons "record types" '())
                            (cons "variables" '())))]

    (filter non-empty-group?
     (fold
      (lambda (key result-so-far)
        (let* [(variable (hashq-ref api-table key))
               (value
                (guard
                    (problem [(exception? problem)
                              (raise-exception
                               (make-residual-export-exception
                                "Possible residual export found."
                                key
                                (record-field interface 'name)))])
                    (variable-ref variable)))
               (object (cons key value))]

          (add object (kind-of value) result-so-far)))
      api-catalog
      api-symbols-sorted))))


(define (file-path->module-name file-path lib-parent-path)
  "Convert the given Scheme file path into a module name.

  @strong{file-path} (string):
    Absolute path to Guile Scheme module file. For example:
    @samp{/home/user/project-x/libx/module-a.scm}.

  @strong{lib-parent-path} (string):
    Absolute path to the directory containing the library
    @var{file-path} belongs to. For example:
    @samp{/home/user/project-x/}.

  @strong{Return value} (symbol):
    The name of the module. For example: @code{(libx module-a)}."
  (let* [(extensionless-file-path (string-drop-right file-path 4))
         (relative-file-path  ; Relative to lib-parent-path.
          (string-drop extensionless-file-path
                       (+ 1 (string-length lib-parent-path))))
         (module-name
          (map
           string->symbol
           (string-split relative-file-path
                         (string->char-set
                          file-name-separator-string))))]

    module-name))


;; The forms that give a name to a value.
(define DEFINITION_FORMS
  '(define define* define-public define*-public
    define-syntax define-syntax-rule define-record-type))

(define (module-file module-name)
  "Return the file that holds MODULE-NAME, or @code{#false} when none does.

  @strong{module-name} (list of symbols):
    For example: @code{'(mylib amodule)}.

  @strong{Return value} (string or @code{#false}):
    The first file on the load path that the module name spells, which is
    the file Guile itself loads the module from."
  (let [(file (string-append
               (string-join (map symbol->string module-name)
                            file-name-separator-string)
               ".scm"))]
    (find file-exists?
          (map (lambda (directory) (in-vicinity directory file))
               %load-path))))

(define (definition-form? name form)
  "Return @code{#true} when FORM is the top-level form that defines NAME.

  @strong{name} (symbol):
    The name a binding is exported under.

  @strong{form} (anything):
    One top-level form of the module's file, as @code{read} returns it."
  (and (pair? form)
       (memq (car form) DEFINITION_FORMS)
       (pair? (cdr form))
       (let [(defined (cadr form))]
         (if (pair? defined)
             (eq? (car defined) name)
             (eq? defined name)))))

(define (definition-source module-name name)
  "Return the source of NAME as MODULE-NAME defines it, or @code{#false}.

  @strong{module-name} (list of symbols):
    The module the object belongs to.  For example:
    @code{'(mylib amodule)}.

  @strong{name} (symbol):
    The name it is exported under.

  @strong{Return value} (string or @code{#false}):
    The text of the top-level form that defines @var{name}, exactly as the
    file writes it, so that a reader of the documentation sees the code
    behind a definition and not a second copy of it.  @code{#false} when no
    file on the load path holds the module, and when no form defines the
    name: a binding a macro invents has no source of its own."
  (and=> (module-file module-name)
         (lambda (file)
           (call-with-input-file file
             (lambda (port)
               (let loop ()
                 (let [(start (ftell port))
                       (form (read port))]
                   (cond
                    [(eof-object? form) #false]
                    [(definition-form? name form)
                     (let* [(end (ftell port))
                            ;; The form starts where `read' met its opening
                            ;; bracket; the comment above it is not shown.
                            (text (begin
                                    (seek port start SEEK_SET)
                                    (get-string-n port (- end start))))
                            (open (or (string-index text #\() 0))]
                       (string-trim-both (substring text open)))]
                    [else (loop)]))))))))

(define (record-field record field)
  "Get the value of @var{field} from @var{record}.

  @strong{record} (Guile record or SRFI 9 record):
    A record of any type.

  @strong{field} (symbol):
    The name of the field.

  @strong{Return value} (anything):
    The value of the field.

  If the FIELD does not exist, a @var{no-such-field} exception is
  raised."
  (let* [(descriptor (record-type-descriptor record))
         (access-field (record-accessor descriptor field))]

    (access-field record)))


(define (documented-string? documentation)
  "Return @code{#t} when @var{documentation} is text a reader can use.

  @strong{documentation} (string or @code{#f}):
    A documentation string, as the reflection procedures return it.

  @strong{Return value} (boolean):
    @code{#t} for a string that holds something besides whitespace: a
    docstring of indentation alone documents nothing."
  (and (string? documentation)
       (not (string-null? (string-trim documentation)))))


(define (undocumented? value)
  "Return @code{#t} when the API object @var{value} has no documentation.

  @strong{value} (anything):
    An object exported by a module.

  @strong{Return value} (boolean):
    @code{#t} when a procedure or a macro is exported without a docstring.
    A variable, a parameter and a record type carry no docstring at all,
    so they are never reported: a list of names that cannot be fixed
    teaches a reader to ignore the list."
  (cond
   [(parameter? value) #false]
   [(macro? value) (not (documented-string?
                         (procedure-documentation (macro-transformer value))))]
   [(procedure? value) (not (documented-string?
                             (procedure-documentation value)))]
   [else #false]))


(define (undocumented-symbols interface)
  "Return the names @var{interface} exports without documenting them.

  @strong{interface} (interface):
    A module's @code{<interface>} record, as returned by Guile's
    procedure @code{resolve-interface}.

  @strong{Return value} (list of symbols):
    The documented gaps of the module's API, in the order a reader meets
    them in the manual, so that a build can fail on them.  An export that
    is bound to nothing is left out: that name is a bug in the module and
    not a gap in its documentation, and the @code{api} command is where it
    is reported."
  (let [(api-table (record-field interface 'obarray))]
    (sort (filter
           (lambda (symbol)
             (let [(variable (hashq-ref api-table symbol))]
               (and (variable-bound? variable)
                    (undocumented? (variable-ref variable)))))
           (api-symbols interface))
          (lambda (a b) (string<? (symbol->string a) (symbol->string b))))))
