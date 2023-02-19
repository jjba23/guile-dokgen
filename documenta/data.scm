#| Data.

Procedures to retrieve data from libraries and their modules.

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta data)
  #:use-module (ice-9 format)
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:export (api-symbols
            api-types
            api-values
            file-path->module-name
            get-file-paths
            record-field))


(define (api-symbols interface)
  "Returm the symbols provided by the interface."
  (hash-map->list
   (lambda (key var) key)
   (record-field interface 'obarray)))


(define (api-types interface)
  "Return the kinds of objects provided by the interface."
  (fold
   (lambda (value result-so-far)
     (let [(value-type (class-name (class-of value)))]

       (if (member value-type result-so-far)
           result-so-far
           (cons value-type result-so-far))))
   '()
   (api-values interface)))


(define (api-values interface)
  "Return the list of values provided by the interface."
  (hash-map->list
   (lambda (key var)
     (variable-ref var))
   (record-field interface 'obarray)))


(define (get-file-paths directory)
  "Return a list of paths to Scheme files in the given directory.

  Scheme files are identified by their «.scm» extension.

  DIRECTORY (string)
    Absolute path to a directory containing a Guile Scheme library.

  RETURN VALUE (list of string)
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


(define (file-path->module-name file-path lib-parent-path)
  "Convert the given Scheme file path into a module name."
  (let* [(extensionless-file-path (string-drop-right file-path 4))
         (relative-file-path
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

  RECORD (Guile record or SRFI 9 record)
    A record of any type.

  FIELD (symbol)
    The name of the field.

  RETURN VALUE (anything)
    The value of the field.

  If the FIELD does not exist, a no-such-field exception is raised."
  (let* [(descriptor (record-type-descriptor record))
         (access-field (record-accessor descriptor field))]

    (access-field record)))
