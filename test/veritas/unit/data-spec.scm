;; guile-dokgen --- test: veritas/unit/data-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What (dokgen data) reads out of a module: the names it exports, the groups
they fall in, and the source of the form that defines them.

The libraries this points at live beside this spec, under test/, named the
way a project names its modules, so a fixture is a library `dokgen' could be
run on rather than a mock of one. |#

(define-module (veritas unit data-spec)
  #:use-module (dokgen data)
  #:use-module (dokgen exceptions)
  #:use-module (srfi srfi-1)
  #:use-module (veritas all))

(define (bogus-objects)
  "Return the API objects the fixture exports."
  (group-api-objects (resolve-interface '(boguslibs objects))))

(define file-path-suite
  (suite "A file path, as a module name"
         (test "a library with more than one module"
               (assert-equal #:expect '(libx module-a)
                             #:got (file-path->module-name
                                    "/home/user/project-x/libx/module-a.scm"
                                    "/home/user/project-x")))
         (test "a library that is one file"
               (assert-equal #:expect '(module)
                             #:got (file-path->module-name
                                    "/home/user/project-z/module.scm"
                                    "/home/user/project-z")))))

(define group-api-objects-suite
  (suite "The objects a module exports, grouped by kind"
         (test "parameters get a group of their own"
               (assert-not-empty #:got (assoc "parameters" (bogus-objects))))
         (test "every parameter the fixture exports is in it"
               (assert-length #:expect 2
                                 #:got (assoc-ref (bogus-objects)
                                                  "parameters")))
         (test "the group holds parameters and not procedures"
               (assert-true (every (lambda (object) (parameter? (cdr object)))
                                   (assoc-ref (bogus-objects)
                                              "parameters"))))
         (test "an export bound to nothing is reported, not skipped"
               (assert-error (lambda ()
                               (group-api-objects
                                (resolve-interface '(boguslibs unbound))))
                             #:name "reading the interface raises"))))

(define definition-source-suite
  (suite "The source behind a definition"
         (test "a variable's form, and nothing around it"
               (assert-equal #:expect "(define documented-variable 42)"
                             #:got (definition-source
                                    '(cleanlib documented)
                                    'documented-variable)))
         (test "a procedure's whole form, docstring and body included"
               (let ((source (definition-source '(cleanlib documented)
                                                'documented)))
                 (assert-true (string-prefix? "(define (documented)"
                                                    source)
                                #:name "it starts with the definition")
                 (assert-contains #:expect source
                                  #:got "This procedure says what it does."
                                  #:name "the docstring is part of it")
                 (assert-true (string-suffix? "#true)" source)
                                #:name "it ends where the form ends")))
         (test "a module no file holds has no source"
               (assert-equal #:expect #f
                             #:got (definition-source '(somelib amodule)
                                                       'documented)))
         (test "a name no form defines has no source"
               (assert-equal #:expect #f
                             #:got (definition-source '(cleanlib documented)
                                                       'not-a-name)))))

(define undocumented-symbols-suite
  (suite "The exported names that are documented nowhere"
         (test "the gaps are named"
               (assert-equal #:expect '(blank-docstring undocumented)
                             #:got (undocumented-symbols
                                    (resolve-interface '(examplelib mixed)))))
         (test "a library with no gap reports none"
               (assert-empty #:got (undocumented-symbols
                                   (resolve-interface '(boguslibs objects)))))))

(define (spec)
  (veritas-run file-path-suite
               group-api-objects-suite
               definition-source-suite
               undocumented-symbols-suite))
