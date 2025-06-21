;;; Commentary:

#| This module defines procedures to retrieve data from Guile Scheme
libraries (e.g. the names and attributes of their Scheme modules and
the objects these modules export). This data is then passed to
template procedures to render API documentation in different
formats. See, for example, the templates used to work with the
@url{https://www.gnu.org/software/texinfo/, Texinfo format}:
@ref{documenta-templates-stexi, (documenta templates stexi)}. |#

;;; Code:

(define-module (documenta data)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:export (api-symbols
            file-path->module-name
            get-file-paths
            group-api-objects
            record-field))


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
  ;; Enter to any directory.
  (define (enter? name stat result) #true)

  ;; Only include files whose NAME has a ".scm" extension.
  (define (leaf name stat result)
    (if (string-suffix? ".scm" name)
	(cons name result)
	result))

  ;; Don't append directories to the resulting list.
  (define (down name stat result) result)
  (define (up name stat result) result)

  ;; Likewise for skipped directories.
  (define (skip name stat result) result)

  ;; Ignore unreadable files/directories but warn the user.
  (define (error name stat errno result)
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
    #| Add object to the group in catalog |#
    (list (cons "macros"
                (if (string=? group "macros")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "macros")))
          (cons "parameters"
                (if (string=? group "parameters")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "parameters")))
          (cons "procedures"
                (if (string=? group "procedures")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "procedures")))
          (cons "record types"
                (if (string=? group "record types")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "record types")))
          (cons "variables"
                (if (string=? group "variables")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "variables")))))
  (define (non-empty-group? group)
    #| Return true if the group has members. |#
    (not (null? (cdr group))))
  (define (symbol-precedes? a b)
    #| Return #true if symbol A goes before B alphabetically. |#
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
               ;; FIXME: Handle "Unbound variable" exceptions.
               ;; These can occur when modules export symbols that
               ;; are not bound to any defined values.
               (value (variable-ref variable))
               (object (cons key value))]

          (cond
           [(macro? value) (add object "macros" result-so-far)]
           [(parameter? value) (add object "parameters" result-so-far)]
           [(procedure? value) (add object "procedures" result-so-far)]
           [(record-type? value) (add object "record types" result-so-far)]
           [else (add object "variables" result-so-far)])))
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
