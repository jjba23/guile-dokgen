;; guile-dokgen --- test: veritas/unit/stexi-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| What (dokgen templates stexi) builds: the definition a reader meets for a
binding, the chapter a manual includes, the overview that opens a module, and
the two chapters dokgen writes for a project's manual.

Most cases compare a whole stexi fragment with the one the template should
build, because the fragment is the contract: a forgotten anchor or a sentence
in the wrong place is a page a reader sees and a maintainer never does. |#

(define-module (veritas unit stexi-spec)
  #:use-module (dokgen templates stexi)
  #:use-module (dokgen utils)
  #:use-module (ice-9 format)
  #:use-module (ice-9 session)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (veritas all))


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


;;; HELPERS

;; The module these fixtures are defined in.  A test body runs under the
;; runner, where `(current-module)` is the module the run started from, so a
;; case that looks a macro up by name keeps the module it was written in.
(define spec-module (current-module))

(define (holds? thing)
  "Return @code{#t} when THING was found, so an assertion compares with #t.

@code{assert-true} compares with @code{eq?}, so a node or a matched element,
truthy as it is, would fail the assertion it satisfies."
  (if thing #t #f))

(define (chapter-sections nodes)
  "Return the titles of the sections the chapter NODES holds."
  (append-map (lambda (node)
                (if (and (pair? node) (eq? (car node) 'section))
                    (list (second node))
                    '()))
              nodes))

(define (first-paragraph nodes)
  "Return the text of the first paragraph of NODES, as one string."
  (let ((paragraph (find (lambda (node)
                           (and (pair? node) (eq? (car node) 'para)))
                         nodes)))
    (apply string-append (filter string? paragraph))))

(define (placeholder-arguments? procedure)
  "Return @code{#t} when reflection answered placeholders, not the names.

Guile keeps a procedure's argument names only while it has debug information
for it: a module loaded from a compiled file is reported with @code{a},
@code{b}, @code{c} @dots{} in the order of its arguments, and @code{_} for an
optional one.  Which of the two a run gets depends on how the file that
defines the procedure was loaded, so a case that insists on the names asks
this first and reports itself as skipped where the answer cannot be had."
  (let* ((arguments (procedure-arguments procedure))
         (required (or (assoc-ref arguments 'required) '()))
         (optional (or (assoc-ref arguments 'optional) '()))
         (letter (lambda (index) (string->symbol
                                  (string (integer->char (+ 97 index)))))))
    (or (and (pair? required)
             (equal? required (map letter (iota (length required)))))
        (any (lambda (entry)
               (eq? (if (pair? entry) (car entry) entry) '_))
             optional))))

(define (definition-node-of nodes)
  "Return the definition node among NODES, whatever kind it is."
  (find (lambda (node)
          (and (pair? node) (memq (car node) '(deffn defmac defvr deftp))))
        nodes))

(define (anchor-name node)
  "Return the name the anchor NODE is marked with, or @code{#f}.

A stexi anchor carries its name in the attribute list the templates write as
@code{(@@code{%} (@@code{name} \"...\"))}, which is what the serializer turns
into the @code{@@anchor} of the chapter."
  (let ((attributes (and (pair? node) (eq? (car node) 'anchor)
                         (pair? (cdr node)) (cadr node))))
    (and (pair? attributes)
         (let ((name (assq 'name (cdr attributes))))
           (and name (cadr name))))))


;;; SUITES

(define api-binding-suite
  (suite "A binding, as the definition a reader meets"
         (test "a record type names its fields"
               (assert-equal
                #:expect
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
                #:got (api-binding '<being> <being> '(somelib amodule))))

         (test "a record names its type and its fields"
               (assert-equal
                #:expect
                `(*fragment*
                  (anchor (% (name "somelib_amodule_panda")))
                  "\n"
                  (defvar
                   (% (name "panda"))
                   (para "This is a record of the type " (code "<being>") ", with"
                         " 2 fields: " (code "name") ", " (code "binomial") ".")))
                #:got (api-binding 'panda
                                   (make-being "panda" "ailuropoda melanoleuca")
                                   '(somelib amodule))))

         (test "a value short enough to read is written as it stands"
               (assert-equal
                #:expect
                '(*fragment*
                  (anchor (% (name "somelib_amodule_greeting")))
                  "\n"
                  (defvr
                   (% (category "Variable") (name "greeting"))
                   (verbatim "\"hello\"")))
                #:got (api-binding 'greeting "hello" '(somelib amodule))))

         (test "a value too long to read is described by its length instead"
               (assert-equal
                #:expect
                `(*fragment*
                  (anchor (% (name "somelib_amodule_big")))
                  "\n"
                  (defvr
                   (% (category "Variable") (name "big"))
                   (para "The value is a string of " (code "500")
                         " characters, too long to print here.")))
                #:got (api-binding 'big (make-string 500 #\x)
                                   '(somelib amodule))))

         (test "a procedure with no argument says so with an empty list"
               (assert-equal
                #:expect
                '(*fragment*
                  (anchor (% (name "somelib_amodule_paramless-procedure")))
                  "\n"
                  (deffn
                   (% (category "Procedure")
                      (name "paramless-procedure")
                      (arguments ""))
                   (para "This thunk says hi to another thunk.")))
                #:got (api-binding 'paramless-procedure
                                   paramless-procedure
                                   '(somelib amodule))))

         (test "a verbatim example in a docstring renders as a block"
               ;; Parsing a docstring that holds `@verbatim' used to fail with
               ;; "EOF while reading a token" unless the fragment ended with a
               ;; newline; the template appends one, and this is the case that
               ;; noticed.  See the note in `docstring->stexi'.
               (assert-equal
                #:expect
                '(*fragment*
                  (anchor (% (name "somelib_amodule_verbatim-in-docstring")))
                  "\n"
                  (deffn
                   (% (category "Procedure")
                      (name "verbatim-in-docstring")
                      (arguments ""))
                   (para "This procedure contains verbatim examples.")
                   (verbatim "(+ 3 5)\n")))
                #:got (api-binding 'verbatim-in-docstring
                                   verbatim-in-docstring
                                   '(somelib amodule))))

         (test "a diagram nothing drew is kept as its source"
               (assert-equal
                #:expect
                '(*fragment*
                  (anchor (% (name "somelib_amodule_diagrammed-procedure")))
                  "\n"
                  (deffn
                   (% (category "Procedure")
                      (name "diagrammed-procedure")
                      (arguments ""))
                   (para "This procedure is drawn.")
                   (para "Mermaid diagram, as source:")
                   (example "graph TD\n  a --> b\n%% dokgen-mermaid")))
                #:got (api-binding 'diagrammed-procedure
                                   diagrammed-procedure
                                   '(somelib amodule))))

         (test "a procedure with no docstring is still documented"
               (assert-equal
                #:expect
                '(*fragment*
                  (anchor (% (name "somelib_amodule_undocumented-procedure")))
                  "\n"
                  (deffn
                   (% (category "Procedure")
                      (name "undocumented-procedure")
                      (arguments ""))
                   (para "Undocumented procedure.")))
                #:got (api-binding 'undocumented-procedure
                                   undocumented-procedure
                                   '(somelib amodule))))

         (test "a macro is a definition of its own, arguments included"
               (let ((transformer (macro-transformer
                                   (module-ref spec-module 'add1))))
                 (assert-equal
                  #:expect
                  `(*fragment*
                    (anchor (% (name "somelib_amodule_add1")))
                    "\n"
                    (defmac
                     (% (name "add1")
                        (arguments ,(procedure-parameters transformer)))
                     (para "Add 1 to the given number.")))
                  #:got (api-binding 'add1
                                     (module-ref spec-module 'add1)
                                     '(somelib amodule)))))

         (test "a macro's arguments are named the way its source writes them"
               ;; Reflection answers the names only where the debug
               ;; information survived the load; see `placeholder-arguments?'.
               #:skip? (placeholder-arguments?
                        (macro-transformer (module-ref spec-module 'add1)))
               (assert-equal #:expect "x"
                             #:got (procedure-parameters
                                    (macro-transformer
                                     (module-ref spec-module 'add1)))))

         (test "an undocumented macro says so rather than nothing"
               (let ((transformer (macro-transformer
                                   (module-ref spec-module 'sub1))))
                 (assert-equal
                  #:expect
                  `(*fragment*
                    (anchor (% (name "somelib_amodule_sub1")))
                    "\n"
                    (defmac
                     (% (name "sub1")
                        (arguments ,(procedure-parameters transformer)))
                     (para "Undocumented macro.")))
                  #:got (api-binding 'sub1
                                     (module-ref spec-module 'sub1)
                                     '(somelib amodule)))))

         (test "a parameter is documented with the value it defaults to"
               (let ((bogus-parameter (make-parameter "default value")))
                 (assert-equal
                  #:expect
                  `(*fragment*
                    (anchor (% (name "somelib_amodule_bogus-parameter")))
                    "\n"
                    (defvr
                     (% (category "Parameter")
                        (name "bogus-parameter"))
                     (para "Default value:")
                     (verbatim ,(format #f "~s" (bogus-parameter)))))
                  #:got (api-binding 'bogus-parameter
                                     bogus-parameter
                                     '(somelib amodule)))))))

(define source-suite
  (suite "The source of a definition"
         (test "a definition the tree holds carries the form behind it"
               (let* ((nodes (api-binding 'unindent unindent '(dokgen utils)))
                      (body (cddr (definition-node-of nodes)))
                      (example (find (lambda (node)
                                       (and (pair? node)
                                            (eq? (car node) 'example)))
                                     body)))
                 (assert-equal
                  #:expect `(anchor (% (name "dk_source_dokgen_utils_unindent")))
                  #:got (find (lambda (node)
                                (let ((name (anchor-name node)))
                                  (and name (string-prefix? "dk_source_" name))))
                              body)
                  #:name "an anchor marks the panel")
                 (assert-true (and example
                                   (string-prefix? "(define (unindent docstring)"
                                                   (second example)))
                              #:name "the form is the one the file writes")))
         (test "a definition no file holds carries no source"
               (let* ((nodes (api-binding 'undocumented-procedure
                                          undocumented-procedure
                                          '(somelib amodule)))
                      (body (cddr (definition-node-of nodes))))
                 (assert-true (holds? (definition-node-of nodes))
                              #:name "the definition is still built")
                 (assert-false
                  (any (lambda (node)
                         (and (pair? node) (eq? (car node) 'example)))
                       body)
                  #:name "no example is added under the docstring")
                 (assert-false
                  (any (lambda (node)
                         (let ((name (anchor-name node)))
                           (and name (string-prefix? "dk_source_" name))))
                       body)
                  #:name "no panel is marked")))))

(define module-overview-suite
  (suite "The overview that opens a module"
         (test "the names are listed with the sentence that documents each"
               (assert-equal
                #:expect
                '(*fragment*
                  (subsection "Overview")
                  (itemize
                   (item (ref (% (node "somelib_amodule_paramless-procedure")
                                 (name "paramless-procedure")))
                         " \u2014 "
                         (para "This thunk says hi to another thunk.")
                         "\n")))
                #:got (module-overview
                       (list (cons "procedures"
                                   (list (cons 'paramless-procedure
                                               paramless-procedure))))
                       '(somelib amodule))))
         (test "an object that says nothing is described, not left blank"
               (assert-equal
                #:expect
                '(*fragment*
                  (subsection "Overview")
                  (itemize
                   (item (ref (% (node "somelib_amodule_undocumented-procedure")
                                 (name "undocumented-procedure")))
                         " \u2014 "
                         (para "An undocumented procedure.")
                         "\n")))
                #:got (module-overview
                       (list (cons "procedures"
                                   (list (cons 'undocumented-procedure
                                               undocumented-procedure))))
                       '(somelib amodule))))))

(define api-chapter-suite
  (suite "The chapter a manual includes"
         (test "the chapter opens with what it documents, not with its list"
               (let* ((nodes (api-chapter '((somelib amodule) (somelib bmodule))
                                          '()))
                      (intro (find (lambda (node)
                                     (and (pair? node) (eq? (car node) 'para)))
                                   nodes)))
                 (assert-false (any (lambda (node)
                                      (and (pair? node) (eq? (car node) 'itemize)))
                                    nodes)
                               #:name "the modules are not listed twice")
                 (assert-equal #:expect "The API reference for "
                               #:got (second intro)
                               #:name "it names the library")
                 (assert-equal #:expect '(code "somelib")
                               #:got (third intro)
                               #:name "the name is set as code")))
         (test "the opening sentence counts what the chapter documents"
               (let ((text (first-paragraph
                            (api-chapter '((somelib amodule) (somelib bmodule))
                                         '()))))
                 (assert-contains #:expect text
                                  #:got "2 modules and 0 exported names"
                                  #:name "the size is counted")
                 (assert-contains #:expect text
                                  #:got "the index filters all of them"
                                  #:name "the reader is told how to search")))
         (test "a short guide says how to read the reference"
               (let* ((nodes (api-chapter '((somelib amodule)) '()))
                      (heading (find (lambda (node)
                                       (and (pair? node)
                                            (eq? (car node) 'heading)))
                                     nodes))
                      (steps (find (lambda (node)
                                     (and (pair? node)
                                          (eq? (car node) 'enumerate)))
                                   nodes)))
                 (assert-equal #:expect "How to read this reference"
                               #:got (second heading))
                 (assert-length #:expect 4 #:got (cdr steps)
                                #:name "four steps, the source panel among them")))
         (test "a note says the chapter is generated and where to correct it"
               (let ((nodes (api-chapter '((somelib amodule)) '())))
                 (assert-true
                  (holds? (find (lambda (node)
                                  (and (pair? node)
                                       (eq? (car node) 'heading)
                                       (equal? (second node)
                                               "A generated chapter")))
                                nodes))
                  #:name "the heading is there")
                 (assert-true
                  (holds? (find (lambda (node)
                                  (and (pair? node)
                                       (eq? (car node) 'para)
                                       (string? (second node))
                                       (string-contains (second node)
                                                        "docstring")))
                                nodes))
                  #:name "the paragraph says a docstring is the place to fix it")))
         (test "the chapter is named the way a manual includes it"
               (assert-equal
                #:expect '(node (% (name "API")))
                #:got (second (cdr (api-chapter '((somelib amodule)) '())))))))

(define counted-kinds-suite
  (suite "What the chapter says it documents"
         (test "a definition is counted wherever it sits, and nothing else is"
               (let* ((section
                       '(*fragment*
                         (deffn (% (category "Procedure") (name "first")
                                   (arguments ""))
                                (para "The first one."))
                         (itemize
                          (item "a" "\n"))
                         (defvr (% (name "second")) (verbatim "2"))))
                      (text (first-paragraph
                             (api-chapter '((somelib amodule))
                                          (list section)))))
                 (assert-contains #:expect text
                                  #:got "1 module and 2 exported names")))
         (test "the kinds of name are named in the plural"
               (let* ((section
                       '(*fragment*
                         (section "Module"
                                  (*fragment* (subsection "Overview"))
                                  (*fragment*
                                   (subsection "Macros")
                                   (defmac (% (name "first"))
                                           (para "A macro.")))
                                  (*fragment*
                                   (subsection "Procedures")
                                   (deffn (% (name "second"))
                                          (para "A procedure."))
                                   (deffn (% (name "third"))
                                          (para "Another procedure."))))))
                      (text (first-paragraph
                             (api-chapter '((somelib amodule))
                                          (list section)))))
                 (assert-contains #:expect text
                                  #:got "2 procedures and 1 macro")))))

(define procedure-parameters-suite
  (suite "The parameters of a procedure, as its signature shows them"
         (test "a procedure with no parameter shows none"
               (assert-equal #:expect ""
                             #:got (procedure-parameters paramless-procedure)))
         (test "required parameters follow one another, in order"
               (assert-match
                #:pattern (a b c)
                #:got (string-split (procedure-parameters required-params)
                                    #\space)
                #:name "three words, one per parameter"))
         (test "the required parameters are the ones the source names"
               #:skip? (placeholder-arguments? required-params)
               (assert-equal #:expect "param1 param2 param3"
                             #:got (procedure-parameters required-params)))
         (test "optional parameters are introduced as optional"
               (assert-match
                #:pattern ("OPT:" a b)
                #:got (string-split (procedure-parameters optional-params)
                                    #\space)
                #:name "the marker, then one word per parameter"))
         (test "the optional parameters are the ones the source names"
               #:skip? (placeholder-arguments? optional-params)
               (assert-equal #:expect "OPT: opt1 opt2"
                             #:got (procedure-parameters optional-params)))
         (test "keyword parameters carry their keyword"
               (assert-equal #:expect "KEY: #:key1 #:key2"
                             #:got (procedure-parameters keyword-params)))
         (test "a procedure that takes any keyword says so"
               (assert-equal #:expect "KEY: #:key1 #:key2 [arbitrary keys]"
                             #:got (procedure-parameters
                                    arbitrary-keyword-params)))
         (test "a rest argument is shown after a dot"
               (let ((rest (assoc-ref (procedure-arguments arbitrary-arguments)
                                      'rest)))
                 (assert-equal #:expect (string-append "." " "
                                                       (symbol->string rest))
                               #:got (procedure-parameters
                                      arbitrary-arguments))))))

(define stats-chapter-suite
  (suite "The statistics chapter"
         (test "the chapter is titled the way a manual includes it"
               (assert-equal
                #:expect '(node (% (name "Statistics")))
                #:got (second (cdr (stats-chapter
                                    (example-statistics #false))))))
         (test "a tree with no history reports its size and nothing invented"
               (let ((nodes (stats-chapter (example-statistics #false))))
                 (assert-equal
                  #:expect '("Size" "The largest files" "Documentation")
                  #:got (chapter-sections nodes))
                 (assert-true
                  (holds? (any (lambda (node)
                                 (and (pair? node)
                                      (eq? (car node) 'para)
                                      (string? (second node))
                                      (string-contains (second node)
                                                       "no git history")))
                               nodes))
                  #:name "the missing history is said, not imagined")))
         (test "a tree with a history reports its authors and its churn"
               (let ((nodes (stats-chapter (example-statistics
                                            (example-history)))))
                 (assert-equal
                  #:expect '("Size" "The largest files" "Documentation"
                             "Authors" "The files that change most")
                  #:got (chapter-sections nodes))
                 (assert-true
                  (holds? (any (lambda (node)
                                 (and (pair? node)
                                      (eq? (car node) 'para)
                                      (string? (second node))
                                      (string-contains (second node)
                                                       "3 of the 4 exported")))
                               nodes))
                  #:name "the documented names are counted against the exported ones")))))

(define (spec)
  (veritas-run api-binding-suite
               source-suite
               module-overview-suite
               api-chapter-suite
               counted-kinds-suite
               procedure-parameters-suite
               stats-chapter-suite))
