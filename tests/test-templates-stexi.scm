#| Test suite for the module (documenta templates stexi). |#

(use-modules ((documenta templates stexi) #:prefix stexi:)
             (ice-9 session)
             (proba utils)
             (srfi srfi-9)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(documenta templates)")



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
     (make-being "panda" "ailuropoda melanoleuca")))


  (let [(test-name "Render a parameterless procedure.")]

    (test-equal
        test-name
      '(deffn
         (% (category "Procedure")
            (name "paramless-procedure")
            (arguments ""))
         (para "This thunk says hi to another thunk."))
      (stexi:api-binding 'paramless-procedure paramless-procedure)))


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
      '(deffn
         (% (category "Procedure")
            (name "verbatim-in-docstring")
            (arguments ""))
         (para "This procedure contains verbatim examples.")
         (verbatim "(+ 3 5)\n"))
      (stexi:api-binding 'verbatim-in-docstring verbatim-in-docstring)))


  (test-equal
      "Render undocumented procedure."
    '(deffn
       (% (category "Procedure")
          (name "undocumented-procedure")
          (arguments ""))
       (para "Undocumented procedure."))
    (stexi:api-binding 'undocumented-procedure undocumented-procedure))


  (test-equal
      "Render a documented macro."
    '(defmac
       (% (name "add1")
          (arguments "x"))
       (para "Add 1 to the given number."))
    (stexi:api-binding 'add1 (module-ref (current-module) 'add1)))

  (test-equal
      "Render an undocumented macro."
    '(defmac
       (% (name "sub1")
          (arguments "x"))
       (para "Undocumented macro."))
    (stexi:api-binding 'sub1 (module-ref (current-module) 'sub1))))



(test-group
    (unit-name stexi:module-description)

  (test-equal
      "Render standard module commentary."
    `(*fragment*
      (para "This is an empty module with a standard commentary."))
    (stexi:module-description '(tests test-module-commentary)))


  (test-equal
      "Render block-commented module commentary."
    `(*fragment*
      (para "This is an empty module with block commentary."))
    (stexi:module-description '(tests test-module-commentary-block))))



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

(test-end SUITE_NAME)
