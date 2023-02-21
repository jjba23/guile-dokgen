#| Test suite for the module (documenta templates). |#

(use-modules (documenta templates)
             (proba utils)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta templates)")



;;; TEST DATA

(define (paramless-procedure)
  "Hello, thunk!")



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name stexi:procedure-parameters)

  (test-equal
      "Render empty arguments for procedures with no parameters."
      ""
      (stexi:procedure-parameters paramless-procedure)))

(test-end SUITE_NAME)
