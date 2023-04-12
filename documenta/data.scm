#| Data.

Procedures to retrieve data from libraries and their modules.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

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

  INTERFACE (<interface>):
    A module's interface record as returned by Guile's procedure
    'resolve-interface'.

  RETURN VALUE (list of symbols):
    Where every symbol identifies a public object exported by the
    interface."
  (hash-map->list
   (lambda (key var) key)
   (record-field interface 'obarray)))


(define (get-file-paths directory)
  "Return a list of paths to Scheme files stored in the directory.

  Scheme files are identified by their «.scm» extension.

  DIRECTORY (string):
    Absolute path to a directory containing a Guile Scheme library.

  RETURN VALUE (list of string):
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

  A kind can be one of the following: macros, procedures, record types,
  variables.

  INTERFACE (<interface>):
    An interface record as returned by Guile's procedure
    'resolve-interface'.

  RETURN VALUE (alist):
    Association list where every entry corresponds to a kind of object
    and a list of its members. Only groups with members are returned."
  ;; Helpers.
  (define (add object group catalog)
    #| Add object to the group in catalog |#
    (list (cons "macros"
                (if (string=? group "macros")
                    (append (assq-ref catalog group) (list object))
                    (assq-ref catalog "macros")))
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
                            (cons "procedures" '())
                            (cons "record types" '())
                            (cons "variables" '())))]

    (filter non-empty-group?
     (fold
      (lambda (key result-so-far)
        (let* [(variable (hashq-ref api-table key))
               (value (variable-ref variable))
               (object (cons key value))]

          (cond
           [(macro? value) (add object "macros" result-so-far)]
           [(procedure? value) (add object "procedures" result-so-far)]
           [(record-type? value) (add object "record types" result-so-far)]
           [else (add object "variables" result-so-far)])))
      api-catalog
      api-symbols-sorted))))


(define (file-path->module-name file-path lib-parent-path)
  "Convert the given Scheme file path into a module name.

  FILE-PATH (string):
    Absolute path to Guile Scheme module file. For example:
    «/home/user/project-x/libx/module-a.scm».

  LIB-PARENT-PATH (string):
    Absolute path to the directory containing the library FILE-PATH
    belongs to. For example: «/home/user/project-x/».

  RETURN VALUE (symbol):
    The name of the module. For example: (libx module-a)."
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
  "Get the value of FIELD from RECORD.

  RECORD (Guile record or SRFI 9 record):
    A record of any type.

  FIELD (symbol):
    The name of the field.

  RETURN VALUE (anything):
    The value of the field.

  If the FIELD does not exist, a no-such-field exception is raised."
  (let* [(descriptor (record-type-descriptor record))
         (access-field (record-accessor descriptor field))]

    (access-field record)))
