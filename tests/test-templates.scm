#| Test suite for the module (documenta templates). |#

(use-modules (documenta templates)
             (proba utils)
             (srfi srfi-9)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta templates)")



;;; TEST DATA

(define (paramless-procedure)
  "Hello, thunk!")

(define (required-params param1 param2 param3) "...")

(define* (optional-params #:optional opt1 opt2) "...")

(define* (keyword-params #:key key1 key2) "...")

(define* (arbitrary-keyword-params #:key key1 key2 #:allow-other-keys)
  "...")

(define (arbitrary-arguments . args) "...")

(define-record-type <being>
  (make-being name binomial)
  being?
  (name being-name)
  (binomial being-binomial))



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name stexi:api-binding)

  (test-equal
      "Render a binding that holds a record type."
    `(deftp
       (% (category "Record type")
          (name "<being>")
          (attributes))
       (para "This record type has the following fields:")
       (itemize
        (item (code "name"))
        (item (code "binomial"))))
    (stexi:api-binding '<being> <being>))


  (test-equal
      "Render a binding that holds a record."
    `(defvar
       (% (name "panda"))
       (para "This is a record of the type " (code "<being>") ", "
             "which has the following fields:")
       (itemize
        (item (code "name"))
        (item (code "binomial"))))
    (stexi:api-binding
     'panda
     (make-being "panda" "ailuropoda melanoleuca"))))



(test-group
    (unit-name stexi:procedure-parameters)

  (test-equal
      "Render empty parameters."
    ""
    (stexi:procedure-parameters paramless-procedure))


  (test-equal
      "Render required parameters."
    "param1 param2 param3"
    (stexi:procedure-parameters required-params))


  (test-equal
      "Render optional parameters."
    "OPT: opt1 opt2"
    (stexi:procedure-parameters optional-params))


  (test-equal
      "Render keyword parameters."
    "KEY: #:key1 #:key2"
    (stexi:procedure-parameters keyword-params))


  (test-equal
      "Render note when arbitrary keyword parameters are allowed."
    "KEY: #:key1 #:key2 [arbitrary keys]"
    (stexi:procedure-parameters arbitrary-keyword-params))


  (test-equal
      "Render note when arbitrary arguments are accepted."
    "[arbitrary arguments]"
    (stexi:procedure-parameters arbitrary-arguments)))

(test-end SUITE_NAME)
