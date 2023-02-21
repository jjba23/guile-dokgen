#| Test suite for the module (documenta templates). |#

(use-modules (documenta templates)
             (proba utils)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta templates)")



;;; TEST DATA

(define (paramless-procedure)
  "Hello, thunk!")

(define (required-params param1 param2 param3) "...")

(define* (optional-params req1 #:optional opt1 opt2) "...")

(define* (keyword-params #:key key1 key2) "...")



;;; TEST SUITE

(test-begin SUITE_NAME)

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
    "req1 #:opt opt1 opt2"
    (stexi:procedure-parameters optional-params))


  (test-equal
      "Render keyword parameters."
    "KEY: #:key1 #:key2"
    (stexi:procedure-parameters keyword-params)))

(test-end SUITE_NAME)
