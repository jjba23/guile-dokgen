#| Templates.

Procedures that accept data and present it in different ways depending
on the target documentation format (texinfo, HTML, etc.). |#

(define-module (documenta templates)
  #:use-module (ice-9 format)
  #:use-module (texinfo reflection)
  #:use-module (texinfo serialize)
  #:export (texi:module-section
            text:module-page))


;;; TEMPLATES

(define (texi:module-section module-name)
  "Return the module documentation as a Texinfo section.

  MODULE-NAME (list of symbols)
    For example: '(mylib amodule).

  RETURN VALUE (string)
    A Texinfo-formatted string representing the module documentation."
  (stexi->texi (module-stexi-documentation module-name)))


(define (text:module-page module-name)
  "Render the API of the given module in plain text."
  (let* [(module (resolve-module module-name))
         (module-api (resolve-interface module-name))
         (module-api-bindings (get-field module-api 'obarray))]

    ;; TODO: Return module page as a string instead.
    (format #true "~%§ Module ~a~%~%" module-name)
    (hash-for-each
     (lambda (key var)
       (let [(value (variable-ref var))]

         (format #true "• ~a" key)

         (cond [(procedure? value)
                (format #true
                        " [procedure]~%~a~%"
                        (or (procedure-documentation value) ""))]
               [(macro? value) (display " [macro]\n")]
               [(record? value) (display " [record]\n")]
               [else (display " [unknown]\n")])))
     module-api-bindings)))



;;; HELPERS
(define (get-field record field)
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
