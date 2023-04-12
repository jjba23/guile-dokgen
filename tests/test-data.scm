#| Test suite for the module (documenta data). |#

(use-modules (documenta data)
             (proba utils)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta data)")



;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name file-path->module-name)

  (test-equal
      "Convert Scheme file path to module name (multi-module library)."
    '(libx module-a)
    (file-path->module-name
     "/home/user/project-x/libx/module-a.scm"
     "/home/user/project-x"))

  (test-equal
      "Convert Scheme file path to module name (single-module library)."
    '(module)
    (file-path->module-name
     "/home/user/project-z/module.scm"
     "/home/user/project-z")))

(test-end SUITE_NAME)
