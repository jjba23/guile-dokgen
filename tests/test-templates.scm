#| Test suite for the module (documenta templates). |#

(use-modules (documenta templates)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta templates)")



;;; STUBS

;;; ...



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name stexi:procedure-parameters)

  (test-equal
      "Test name"
      'expected
      (stexi:procedure-parameters)))

(test-end SUITE_NAME)
