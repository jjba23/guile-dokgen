;; guile-dokgen --- tests: test-templates-stexi
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (dokgen templates stexi). |#

(use-modules ((dokgen templates stexi) #:prefix stexi:)
             (ice-9 session)
             (proba utils)
             (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(dokgen templates)")



;;; TEST DATA

(define (paramless-procedure)
  "This thunk says hi to another thunk."
  "Hello, thunk!")

(define (required-params param1 param2 param3) "...")

(define* (optional-params #:optional opt1 opt2) "...")

(define* (keyword-params #:key key1 key2) "...")

(define* (arbitrary-keyword-params #:key key1 key2 #:allow-other-keys)
  "...")

(define (arbitrary-arguments . parts) "...")

(define (undocumented-procedure)
  #true)

(define (verbatim-in-docstring)
  "This procedure contains verbatim examples.

  @verbatim
  (+ 3 5)
  @end verbatim"
  #true)

(define (diagrammed-procedure)
  "This procedure is drawn.

  ```mermaid
  graph TD
    a --> b
  ```"
  #true)

(define-syntax add1
  ;; Example of a documented macro.
  (lambda (x)
    "Add 1 to the given number."
    (syntax-case x ()
      ((_ exp)
       (syntax (+ exp 1))))))

(define-syntax sub1
  ;; Example of an undocumented macro.
  (lambda (x)
    (syntax-case x ()
      ((_ exp)
       (syntax (- exp 1))))))

(define-record-type <being>
  (make-being name binomial)
  being?
  (name being-name)
  (binomial being-binomial))


;;; STATISTICS TEST DATA

;; What (dokgen commands) stats measures and counts, cut down to two files
;; so that every section of the chapter has something to say.
(define (example-statistics history)
  `((totals . ((files . (((name . "b.scm") (blank . 0) (comment . 0) (code . 1)
                          (decisions . 0) (bytes . 10))
                         ((name . "a.scm") (blank . 1) (comment . 2) (code . 3)
                          (decisions . 1) (bytes . 40))))
               (blank . 1) (comment . 2) (code . 4) (decisions . 1) (bytes . 50)))
    (coverage . (3 . 4))
    (modules . 2)
    (git . ,history)))

(define (example-history)
  '((commits . 7) (commit . "abc1234") (last . "2026-11-21") (first . "2026-11-01")
    (authors . (("A Writer" 10 2)))
    (files . (("a.scm" 5 1)))))

(define (chapter-sections nodes)
  "Return the titles of the sections the chapter NODES holds."
  (append-map (lambda (node)
                (if (and (pair? node) (eq? (car node) 'section))
                    (list (second node))
                    '()))
              nodes))


;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    (unit-name stexi:api-binding)

  (test-equal
      "Render a binding that holds a record type."
    `(*fragment*
      (anchor (% (name "somelib_amodule_<being>")))
      ;; Texinfo wants an anchor on a line of its own.
      "\n"
      (deftp
        (% (category "Record type")
           (name "<being>")
           (attributes))
        (para "This record type has" " 2 fields: "
              (code "name") ", " (code "binomial") ".")))
    (stexi:api-binding '<being> <being> '(somelib amodule)))


  (test-equal
      "Render a binding that holds a record."
    `(*fragment*
      (anchor (% (name "somelib_amodule_panda")))
      ;; Texinfo wants an anchor on a line of its own.
      "\n"
      (defvar
        (% (name "panda"))
        (para "This is a record of the type " (code "<being>") ", with"
              " 2 fields: " (code "name") ", " (code "binomial") ".")))
    (stexi:api-binding
     'panda
     (make-being "panda" "ailuropoda melanoleuca")
     '(somelib amodule)))


  (test-equal
      "Render a variable whose value is short enough to print."
    '(*fragment*
      (anchor (% (name "somelib_amodule_greeting")))
      ;; Texinfo wants an anchor on a line of its own.
      "\n"
      (defvr
        (% (category "Variable") (name "greeting"))
        (verbatim "\"hello\"")))
    (stexi:api-binding 'greeting "hello" '(somelib amodule)))


  (test-equal
      "Describe a value too long to print instead of printing it."
    `(*fragment*
      (anchor (% (name "somelib_amodule_big")))
      "\n"
      (defvr
        (% (category "Variable") (name "big"))
        (para "The value is a string of " (code "500")
              " characters, too long to print here.")))
    (stexi:api-binding 'big (make-string 500 #\x) '(somelib amodule)))


  (let [(test-name "Render a parameterless procedure.")]

    (test-equal
        test-name
      '(*fragment*
        (anchor (% (name "somelib_amodule_paramless-procedure")))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        (deffn
          (% (category "Procedure")
             (name "paramless-procedure")
             (arguments ""))
          (para "This thunk says hi to another thunk.")))
      (stexi:api-binding 'paramless-procedure
                         paramless-procedure
                         '(somelib amodule))))


  (let [(test-name "Render a procedure containing @verbatim examples.")]
    #| Rendering procedures whose documentation strings included Texinfo
    @verbatim commands failed with the following error:

    (parser-error #<input: string 7f80903492a0>
     EOF while reading a token  reading verbatim)

    This error comes from calling texi-fragment->stexi. The following
    fails in the same way:

    (texi-fragment->stexi "Example:

    @verbatim
    (+ 3 5)
    @end verbatim")

    Verbatim seems to be the only block enclosing command that triggers
    the error. Quotation, example and lisp commands are parsed
    correctly.

    Ending the little reproducer above with a newline character solves
    the problem. But I wonder if this is a defect upstream. |#

    (test-equal
        test-name
      '(*fragment*
        (anchor (% (name "somelib_amodule_verbatim-in-docstring")))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        (deffn
          (% (category "Procedure")
             (name "verbatim-in-docstring")
             (arguments ""))
          (para "This procedure contains verbatim examples.")
          (verbatim "(+ 3 5)\n")))
            (stexi:api-binding 'verbatim-in-docstring
                               verbatim-in-docstring
                               '(somelib amodule))))

  (test-equal
      "Render a diagram in a docstring as source when nothing draws it."
    '(*fragment*
      (anchor (% (name "somelib_amodule_diagrammed-procedure")))
      ;; Texinfo wants an anchor on a line of its own.
      "\n"
      (deffn
        (% (category "Procedure")
           (name "diagrammed-procedure")
           (arguments ""))
        (para "This procedure is drawn.")
        (para "Mermaid diagram:")
        (example "graph TD\n  a --> b\n%% dokgen-mermaid")))
    (stexi:api-binding 'diagrammed-procedure
                       diagrammed-procedure
                       '(somelib amodule))))


  (test-equal
      "Render undocumented procedure."
    '(*fragment*
      (anchor (% (name "somelib_amodule_undocumented-procedure")))
      ;; Texinfo wants an anchor on a line of its own.
      "\n"
      (deffn
        (% (category "Procedure")
           (name "undocumented-procedure")
           (arguments ""))
        (para "Undocumented procedure.")))
    (stexi:api-binding 'undocumented-procedure
                       undocumented-procedure
                       '(somelib amodule)))


  #| A macro's arguments are read by reflection, and reflection answers
  with the names in the source only when Guile kept them: a transformer it
  has no debug information for is reported as (a), (b), @dots{} in the order
  of its arguments.  Which of the two a run gets depends on how the file
  that defines the macro was loaded, so the renderings below take their
  expected arguments from the same reflection, and the names themselves
  are asserted once, as a test that passes where they are kept. |#

  (let [(transformer (macro-transformer (module-ref (current-module) 'add1)))]

    (test-equal
        "Render a documented macro."
      `(*fragment*
        (anchor (% (name "somelib_amodule_add1")))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        (defmac
          (% (name "add1")
             (arguments ,(stexi:procedure-parameters transformer)))
          (para "Add 1 to the given number.")))
      (stexi:api-binding 'add1
                         (module-ref (current-module) 'add1)
                         '(somelib amodule)))

    (test-expect-fail 1)                ; XFAIL where reflection has no names.
    (test-equal
        "Name a macro's arguments the way its source does."
      "x"
      (stexi:procedure-parameters transformer)))


  (let [(transformer (macro-transformer (module-ref (current-module) 'sub1)))]

    (test-equal
        "Render an undocumented macro."
      `(*fragment*
        (anchor (% (name "somelib_amodule_sub1")))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        (defmac
          (% (name "sub1")
             (arguments ,(stexi:procedure-parameters transformer)))
          (para "Undocumented macro.")))
      (stexi:api-binding 'sub1
                         (module-ref (current-module) 'sub1)
                         '(somelib amodule)))

  (let [(test-name "Render a parameter.")
        (parameter-name 'bogus-parameter)
        (bogus-parameter (make-parameter "default value"))]

    (test-equal
        test-name
      `(*fragment*
        (anchor (% (name "somelib_amodule_bogus-parameter")))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        (defvr
          (% (category "Parameter")
             (name ,(symbol->string parameter-name)))
          (para "Default value:")
          (verbatim ,(format #f "~s" (bogus-parameter)))))
      (stexi:api-binding parameter-name
                         bogus-parameter
                         '(somelib amodule)))))



(test-group
    (unit-name stexi:api-chapter)

  (let* [(nodes (stexi:api-chapter '((somelib amodule) (somelib bmodule)) '()))
         (intro (find (lambda (node) (and (pair? node) (eq? (car node) 'para)))
                      nodes))
         (text (apply string-append (filter string? intro)))]

    (test-assert
        "Introduce the library instead of listing its sections twice."
      (and (not (any (lambda (node) (and (pair? node) (eq? (car node) 'itemize)))
                     nodes))
           (equal? (second intro) "The API reference for ")
           (equal? (third intro) '(code "somelib"))))

    (test-assert
        "Say how much the chapter documents, in one sentence a reader can use."
      (and (string-contains text "2 modules and 0 exported names")
           (string-contains text "the index filters all of them"))))

  (test-equal
      "Open the chapter with the name a manual includes it by."
    '(node (% (name "API")))
    (second (cdr (stexi:api-chapter '((somelib amodule)) '())))))


(test-group
    "the count of what the chapter documents"

  (let* [(section
          '(*fragment*
            (deffn (% (category "Procedure") (name "first") (arguments ""))
                   (para "The first one."))
            (itemize
             (item (code "a") "\n"))
            (defvr (% (name "second")) (verbatim "2"))))
         (nodes (stexi:api-chapter '((somelib amodule)) (list section)))
         (intro (find (lambda (node) (and (pair? node) (eq? (car node) 'para)))
                      nodes))
         (text (apply string-append (filter string? intro)))]

    (test-assert
        "Count the definitions wherever they sit, and nothing else."
      (string-contains text "1 module and 2 exported names"))))



(test-group
    (unit-name stexi:module-overview)

  (let [(entries (list (cons "procedures"
                             (list (cons 'paramless-procedure
                                         paramless-procedure)))))]
    (test-equal
        "Lead the module with the names it exports and what each says."
      '(*fragment*
        (subsection "Overview")
        (itemize
         (item (ref (% (node "somelib_amodule_paramless-procedure")
                       (name "paramless-procedure")))
               " \u2014 "
               (para "This thunk says hi to another thunk.")
               "\n")))
      (stexi:module-overview entries '(somelib amodule))))

  (test-equal
      "Say what an object that cannot be read is, rather than nothing."
    '(*fragment*
      (subsection "Overview")
      (itemize
       (item (ref (% (node "somelib_amodule_undocumented-procedure")
                     (name "undocumented-procedure")))
             " \u2014 "
             (para "An undocumented procedure.")
             "\n")))
    (stexi:module-overview
     (list (cons "procedures"
                 (list (cons 'undocumented-procedure undocumented-procedure))))
     '(somelib amodule))))



(test-group
    (unit-name stexi:procedure-parameters)

  (test-equal
      "Render empty parameters."
    ""
    (stexi:procedure-parameters paramless-procedure))


  (test-expect-fail 1)  ; XFAIL.
  #| This test passes in a Guix shell environment, but fails in a Guix
  package building environment. In the latter, the actual value returned
  by the procedure under test is "a b c". Where is that coming from? |#
  (test-equal
      "Render required parameters."
    "param1 param2 param3"
    (stexi:procedure-parameters required-params))


  (test-expect-fail 1)  ; XFAIL.
  #| As with the "Render required parameters" test, this test passes in
  a Guix shell environment, but fails in a Guix package building
  environment. In the latter, the actual value returned by the procedure
  under test is "_ _". Where is that coming from? |#
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


  (let* [(test-name "Render args parameter.")
         (params (procedure-arguments arbitrary-arguments))
         (rest-name (assoc-ref params 'rest))]

    (test-equal
        test-name
      (string-append "." " " (symbol->string rest-name))
      (stexi:procedure-parameters arbitrary-arguments))))


(test-group
    (unit-name stexi:stats-chapter)

  (let [(nodes (stexi:stats-chapter (example-statistics #false)))]

    (test-equal
        "Title the chapter a manual can include beside its API chapter."
      '(node (% (name "Statistics")))
      (second (cdr nodes)))

    (test-equal
        "Report the size, the largest files and how much is documented."
      '("Size" "The largest files" "Documentation")
      (chapter-sections nodes))

    (test-assert
        "Say that the history is missing rather than inventing one."
      (any (lambda (node)
             (and (pair? node)
                  (eq? (car node) 'para)
                  (string? (second node))
                  (string-contains (second node) "no git history")))
           nodes)))


  (let [(nodes (stexi:stats-chapter (example-statistics (example-history))))]

    (test-equal
        "Report the authors and the churn when there is a history."
      '("Size" "The largest files" "Documentation" "Authors"
        "The files that change most")
      (chapter-sections nodes))

    (test-assert
        "Count the documented names of the exported ones."
      (any (lambda (node)
             (and (pair? node)
                  (eq? (car node) 'para)
                  (string? (second node))
                  (string-contains (second node) "3 of the 4 exported")))
           nodes))))

(test-end SUITE_NAME)
