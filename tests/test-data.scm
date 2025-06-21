#| Test suite for the module (documenta data). |#

(use-modules (documenta data)
             (proba utils)
             (srfi srfi-1)
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


(test-group
    (unit-name group-api-objects)

  (let [(test-name "A «parameters» group exists when the API exports parameters.")
        (grouped-objects
         (group-api-objects (resolve-interface
                             '(tests boguslibs objects))))]

    (test-assert test-name
      (assoc "parameters" grouped-objects)))

  (let* [(test-name "All parameters exported by the API are included in their group.")
         (grouped-objects
          (group-api-objects (resolve-interface
                              '(tests boguslibs objects))))
         (parameters (assoc-ref grouped-objects "parameters"))]

    (test-assert test-name
      (= 2 (length parameters))))

  (let* [(test-name "All objects in the «parameters» group are actually parameters.")
         (grouped-objects
          (group-api-objects (resolve-interface
                              '(tests boguslibs objects))))
         (parameters (assoc-ref grouped-objects "parameters"))]

    (test-assert test-name
      (every (lambda (object) (parameter? (cdr object))) parameters))))

(test-end SUITE_NAME)
