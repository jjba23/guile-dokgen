;; guile-dokgen --- the Texinfo (stexi) template
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines procedures that structure
@ref{dokgen_data, API data} as @emph{stexi} (symbolic texinfo),
which can later be translated into Texinfo and integrated with the rest
of the Texinfo documentation of a given software project. |#

;;; Code:

(define-module (dokgen templates stexi)
  #:use-module (dokgen data)
  #:use-module (dokgen diagrams)
  #:use-module (dokgen utils)
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 session)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (texinfo)
  #:use-module (texinfo reflection)
  #:export (api-binding
            api-chapter
            module-description
            module-overview
            module-section
            procedure-parameters
            stats-chapter))


;;; HELPERS

(define (module-id module-name)
  "Return the name MODULE-NAME is known by in a node or an anchor.

  Texinfo's Info reader is confused by a colon, a comma and a period in a
  node name, so the parts of a module name are joined with an underscore:
  @code{(dokgen cli)} becomes @code{dokgen_cli}."
  (string-join (map symbol->string module-name) "_"))

(define (first-sentence text)
  "Return the first sentence of TEXT, so a list of them reads as a list.

  @strong{text} (string):
    A documentation string, or one line of one.

  @strong{Return value} (string):
    The text up to its first period followed by a space, or its first
    line, whichever comes first."
  (let* [(line (string-trim (car (string-split (or text "") #\newline))))
         (period (string-contains line ". "))]
    (if (and period (> period 0))
        (substring line 0 (+ period 1))
        line)))

(define (summary value)
  "Return one line saying what the API object VALUE is.

  @strong{value} (anything):
    An object exported by a module.

  @strong{Return value} (string):
    Its first sentence when it has documentation, so that the overview of
    a module is the module's own words and not a second description that
    could disagree with them."
  (define (documented documentation fallback)
    (let [(sentence (first-sentence documentation))]
      (if (string-null? sentence) fallback sentence)))
  (cond
   [(parameter? value) "A parameter object."]
   [(macro? value) (documented (procedure-documentation (macro-transformer value))
                               "An undocumented macro.")]
   [(procedure? value) (documented (procedure-documentation value)
                                   "An undocumented procedure.")]
   [(record-type? value) "A record type."]
   [(record? value) (format #f "A record of the type ~a."
                            (record-type-name (record-type-descriptor value)))]
   [else "A variable."]))

(define (binding-id module-name name)
  "Return the anchor id of the binding NAME that MODULE-NAME exports.

  @strong{module-name} (list of symbols):
    The module the object belongs to.

  @strong{name} (symbol):
    The name it is exported under.

  @strong{Return value} (string):
    The identifier @code{api-binding} anchors it with, so that the
    overview and the definition cannot name it differently."
  (string-append (module-id module-name) "_" (symbol->string name)))

(define (summary-stexi value)
  "Return the summary of VALUE as the stexi nodes that read it.

  The summary is the object's own sentence, so it carries the Texinfo the
  docstring wrote: @code{@@var} and @code{@@code} are parsed here and not
  printed as they stand.

  @strong{value} (anything):
    An object exported by a module.

  @strong{Return value} (list of stexi):
    The nodes of its first sentence, or the sentence itself when it does
    not parse."
  (let [(text (summary value))]
    (catch #t
      (lambda () (cdr (texi-fragment->stexi (string-append text "\n"))))
      (lambda _ (list text)))))

(define (module-overview objects module-name)
  "Return the module's exported objects as a list a reader can skim.

  @strong{objects} (alist):
    The API objects grouped by kind, as @code{group-api-objects} returns
    them.

  @strong{module-name} (list of symbols):
    The module they belong to, so that every name links to its own
    definition.

  @strong{Return value} (stexi):
    An @code{@@itemize} of the names with the sentence that documents
    each, which is what a reader looking for one of them scans first."
  (let [(entry (lambda (object)
                 `(item (ref (% (node ,(binding-id module-name (car object)))
                                (name ,(symbol->string (car object)))))
                        " \u2014 "
                        ,@(summary-stexi (cdr object))
                        "\n")))]
    `(*fragment*
      (subsection "Overview")
      (itemize ,@(append-map (lambda (group) (map entry (cdr group)))
                             objects)))))

(define (docstring->stexi docstring owner)
  "Return DOCSTRING as a list of stexi nodes.

  A mermaid or gnuplot diagram the documentation carries is rendered, and
  OWNER names what the documentation belongs to, so that each diagram it
  holds gets a file of its own.

  @strong{docstring} (string):
    The documentation string of a procedure or a macro, or the commentary
    of a module.

  @strong{owner} (string):
    The name of the documented object.

  @strong{Return value} (list of stexi):
    The nodes of the documentation, in the order they are written."
  (append-map
   (lambda (block)
     (if (eq? (car block) 'diagram)
         (diagram-stexi (second block) (third block) owner)
         ;; NOTE: Append newline to avoid parsing error.  The error occurs
         ;; when parsing verbatim commands.  See the reproducer in
         ;; tests/test-templates-stexi.scm for more info.
         (cdr (texi-fragment->stexi (string-append (cdr block) "\n")))))
   (diagram-blocks (unindent docstring))))


;;; TEMPLATES

(define (api-binding name value module-name)
  "Return the API binding name-value as an stexi fragment.

  @strong{name} (symbol):
    The name of the binding. For example, the name of a variable,
    the name of a procedure, etc.

  @strong{value} (anything):
    Any kind of object. For example, a string, a list, a procedure, a
    record, etc.

  @strong{module-name} (list of symbols):
    The name of the module where the binding is defined. For example:
    @code{'(mylib amodule)}.

  @strong{Return value} (stexi):
    An stexi fragment that documents the @var{value}."
  (let* [(name-string (symbol->string name))
         (anchor-id (string-append (module-id module-name)
                                   "_"
                                   name-string))]

      `(*fragment*
        (anchor (% (name ,anchor-id)))
        ;; Texinfo wants an anchor on a line of its own.
        "\n"
        ,(cond
          [(macro? value) (macro name value)]
          ;; NOTE: Parameter detection must come before procedure
          ;; detection because parameters are ambiguous objects: they
          ;; are both parameters and procedures, and we want to render
          ;; them as the former.
          [(parameter? value) (parameter name value)]
          [(procedure? value) (procedure name value)]
          [(record-type? value) (record-type name value)]
          [(record? value) (record-variable name value)]
          [else
           (variable name value)]))))


(define (definition-node? node)
  "Return @code{#true} when NODE is one of the definition forms."
  (and (pair? node)
       (memq (car node) '(deffn defmac defvr deftp))))

(define (count-definitions node)
  "Return how many definition nodes NODE holds, at any depth."
  (cond
   [(definition-node? node) 1]
   [(pair? node) (+ (count-definitions (car node))
                    (count-definitions (cdr node)))]
   [else 0]))

(define (counted number thing)
  "Return NUMBER with THING beside it, in the singular or the plural."
  (format #f "~a ~a~a" number thing (if (= number 1) "" "s")))

(define (library-name module-names)
  "Return the name every module of MODULE-NAMES starts with, or @code{#false}.

  The first symbol of a module name is what a reader calls the library:
  @code{(dokgen cli)} and @code{(dokgen data)} are modules of @code{dokgen}.
  Modules that do not agree on one are a set of modules and not a library,
  so the chapter says so instead of inventing a name."
  (let [(prefixes (delete-duplicates (map car module-names)))]
    (and (= (length prefixes) 1)
         (symbol->string (car prefixes)))))

(define (api-introduction module-names sections)
  "Return the paragraph that opens the chapter.

  @strong{module-names} (list of lists of symbols):
    The modules the chapter documents.

  @strong{sections} (list of stexi):
    The sections that document them, counted so the first sentence says how
    much is in the chapter.

  @strong{Return value} (stexi):
    A paragraph naming the library and how much of it is documented.  The
    chapter used to list its modules here, which is what the HTML already
    puts in the table of contents beside the page; a reader who opens the
    chapter now learns what it is instead of meeting the same list twice."
  (let* [(name (library-name module-names))
         (head (if name
                   `("The API reference for " (code ,name) ": ")
                   '("The API reference for this library: ")))
         (counts (format #f "~a and ~a, generated from the source and the docstrings in it."
                         (counted (length module-names) "module")
                         (counted (count-definitions sections) "exported name")))]
    `(para ,@head ,counts
           "  Every module has a section of its own and every name links to its
definition; the index filters all of them.")))

(define (api-chapter module-names sections)
  "Return a library API as an stexi chapter.

  @strong{module-names} (list of lists of symbols):
    The modules the chapter documents, in the order they are documented.

  @strong{sections} (list of stexi):
    A list where every item is an stexi section.

  @strong{Return value} (stexi):
    A chapter documenting a library's API, opening with a sentence about
    what it documents so that a reader knows what the page is before
    meeting its first definition."
  `(*fragment*
    (c (% (all "NOTE: Autogenerated documentation. Do not edit manually.")))
    (node (% (name "API")))
    (chapter "API")
    ,(api-introduction module-names sections)
    ,@sections))


(define (module-description module-name)
  "Return the module's commentary or description as stexi.

  @strong{module-name} (list of symbols):
    For example: @code{'(mylib amodule)}.

  @strong{Return value} (stexi):
    An stexi fragment."
  (let* [(commentary (module-commentary module-name))
         ;; FIXME: Ignore delimiters, capture the comment only.
         ;; Maybe "(?<=#\|\s)(.*)(?=\s\|#$)" but the ? of lookahead and
         ;; look behind makes the regex invalid in Guile...
         (comment-regex ".*#\\|\\s(.*)\\s\\|#.*$")  ; TODO: Improve regex.
         (block-commentary (string-match comment-regex commentary))
         (text (if block-commentary
                   (match:substring block-commentary 1)
                   commentary))]

    `(*fragment* ,@(docstring->stexi text (module-id module-name)))))


(define (module-section module-name)
  "Return the module documentation as an stexi section.

  @strong{module-name} (list of symbols):
    For example: @code{'(mylib amodule)}.

  @strong{Return value} (stexi):
    A section documenting a module's API."
  (let* [(module-api (resolve-interface module-name))
         (grouped-api-objects (group-api-objects module-api))
         (node-name (module-id module-name))]

    `(*fragment*
      (node (% (name ,node-name)))
      (section ,(format #f "~a" module-name))
      ,(module-description module-name)
      ,(module-overview grouped-api-objects module-name)

      ,@(map
         (lambda (group)
           (let [(kind (first group))
                 (objects (cdr group))]
             (module-subsection kind objects module-name)))
         grouped-api-objects))))


(define (module-subsection kind objects module-name)
  "Return an stexi subsection listing API objects of the given
  @var{kind}.

  @strong{kind} (string):
    Any of the kinds defined by the procedure @code{group-api-objects}
    from the module @code{(dokgen data)}.

  @strong{objects} (alist):
    Association list of API objects of the given @var{kind}. Every key
    is the symbol identifying an object, and every value is the object
    itself (a procedure, a macro, a record, etc.).

  @strong{module-name} (list of symbols):
    The name of the module where the @var{objects} are defined. For
    example: @code{'(mylib amodule)}.

  @strong{Return value} (stexi):
    An stexi subsection."
  `(*fragment*
    (subsection ,(string-capitalize kind))

    ,@(map
       (lambda (object)
         (let [(key (first object))
               (value (cdr object))]
           (api-binding key value module-name)))
       objects)))


(define (macro name value)
  "Return the macro represented by name-value as an stexi definition.

  @strong{name} (symbol):
    The name of the macro (its keyword part).

  @strong{value} (syntax transformer):
    The other part of the macro, its syntax transformer.

  @strong{Return value} (stexi):
    An stexi @code{@@defmac} definition."
  (let [(name-string (symbol->string name))
        (transformer (macro-transformer value))]

    `(defmac
       (% (name ,name-string)
          (arguments ,(procedure-parameters transformer)))
       ,@(docstring->stexi (if (procedure-documentation transformer)
                               (procedure-documentation transformer)
                               "Undocumented macro.")
                           name-string))))


(define (parameter name value)
  "Return the parameter represented by name-value as an stexi definition.

  @strong{name} (symbol):
    The name of the parameter.

  @strong{value} (anything):
    Any kind of object. For example, a string, a number, a list, etc.

  @strong{Return value} (stexi):
    An stexi @code{@@defvr} definition."
  (let [(name-string (symbol->string name))]

    `(defvr
       (% (category "Parameter") (name ,name-string))
       (para "Default value:")
       (verbatim ,(format #f "~s" (value))))))


(define (procedure name value)
  "Return the procedure represented by name-value as an stexi
  definition.

  @strong{name} (symbol):
    The name of the procedure.

  @strong{value} (procedure):
    The procedure.

  @strong{Return value} (stexi):
    An stexi @code{@@deffn} definition."
  (let [(name-string (symbol->string name))]

    `(deffn
       (% (category "Procedure")
          (name ,name-string)
          (arguments ,(procedure-parameters value)))
       ,@(docstring->stexi (if (procedure-documentation value)
                               (procedure-documentation value)
                               "Undocumented procedure.")
                           name-string))))


(define (procedure-parameters proc)
  "Return the parameters of the given procedure as a string.

  @strong{proc} (procedure):
    A procedure object.

  @strong{Return value} (string):
    A string listing the names of all the required, optional, keyword,
    and rest of parameters of the procedure. Default values for optional
    and keyword parameters are not included."
  ;; Helper.
  (define (symbol-or-pair->string obj)
    "Return OBJ, a symbol or a pair, as it is written in source code."
    (format #f "~s" obj))
  (define (keyword->string keyword)
    "Return the name of the KEYWORD parameter, ignoring its default."
    (format #f "~a" (car keyword)))
  ;; Main body.
  (let* [(parameters (procedure-arguments proc))
         (required-params (assoc-ref parameters 'required))
         (optional-params (assoc-ref parameters 'optional))
         (keyword-params (assoc-ref parameters 'keyword))
         (arbitrary-keys? (assoc-ref parameters 'allow-other-keys?))
         (rest-param (assoc-ref parameters 'rest))]

    (string-join
     (append
      (map symbol->string required-params)
      (if (null? optional-params)
          (list)
          (cons "OPT:"
                (map symbol-or-pair->string optional-params)))
      (if (null? keyword-params)
          (list)
          (cons "KEY:" (map keyword->string keyword-params)))
      (if arbitrary-keys?
          (list "[arbitrary keys]")
          (list))
      (if rest-param
          (list "." (symbol->string rest-param))
          (list)))
     " ")))


(define (comma-list nodes)
  "Return NODES with a comma and a space between them."
  (if (null? nodes)
      '()
      (cons (first nodes)
            (append-map (lambda (node) (list ", " node)) (cdr nodes)))))

(define (fields-sentence fields)
  "Return the words that name FIELDS, a record's fields."
  (if (null? fields)
      '(" no fields.")
      `(,(format #f " ~a: " (counted (length fields) "field"))
        ,@(comma-list (map (lambda (field)
                             `(code ,(symbol->string field)))
                           fields))
        ".")))

(define (record-type name value)
  "Return the record type represented by name-value as an stexi
  definition.

  @strong{name} (symbol):
    The name of the record type.

  @strong{value} (record-type descriptor):
    A representation of a record type.

  @strong{Return value} (stexi):
    An stexi @code{@@deftp} definition."
  (let [(name-string (symbol->string name))]

    `(deftp
       (% (category "Record type")
          (name ,name-string)
          (attributes))
       (para "This record type has"
             ,@(fields-sentence (record-type-fields value))))))


(define (record-variable name value)
  "Return the variable represented by name-value as an stexi definition.

  @strong{name} (symbol):
    The name of the variable holding a record.

  @strong{value} (record):
    A record.

  @strong{Return value} (stexi):
    An stexi @code{@@defvar} definition."
  (let* [(name-string (symbol->string name))
         (descriptor (record-type-descriptor value))
         (type-name (record-type-name descriptor))
         (record-fields (record-type-fields descriptor))]

    `(defvar
       (% (name ,name-string))
       (para "This is a record of the type "
             (code ,(symbol->string type-name)) ", with"
             ,@(fields-sentence record-fields)))))


(define (variable name value)
  "Return the variable represented by name-value as an stexi definition.

  @strong{name} (symbol):
    The name of the variable.

  @strong{value} (anything):
    Any kind of object. For example, a string, a number, a list, etc.

  @strong{Return value} (stexi):
    An stexi @code{@@defvr} definition.  A string too long to read in a
    page is described by its length instead of printed: the stylesheet
    and the script are values of exported variables, and printing all of
    them would bury every other definition in the manual."
  (let [(name-string (symbol->string name))]

    `(defvr
       (% (category "Variable") (name ,name-string))
       ,(if (and (string? value) (> (string-length value) 400))
            `(para "The value is a string of "
                   (code ,(number->string (string-length value)))
                   " characters, too long to print here.")
            `(verbatim ,(format #f "~s" value))))))


;;; STATISTICS

(define (at-most count items)
  "Return the first COUNT of ITEMS, or all of them when there are fewer."
  (if (or (<= count 0) (null? items))
      '()
      (cons (first items) (at-most (- count 1) (cdr items)))))

(define (padded-rows rows)
  "Return ROWS as text whose columns line up.

  @strong{rows} (list of lists of strings):
    A table, without a header: the first row names the columns and the
    rest are its lines.

  @strong{Return value} (string):
    The rows, one per line, with every column as wide as its widest cell
    and two spaces between columns.  A monospaced block is what Texinfo
    renders the same way in a browser, in Info and in print, which is what
    a table of numbers needs."
  (let* [(widths (fold (lambda (row widths)
                         (map (lambda (cell width) (max (string-length cell) width))
                              row widths))
                       (map string-length (first rows))
                       (cdr rows)))
         (line (lambda (row)
                 (string-trim-right
                  (string-join (map (lambda (cell width)
                                      (string-pad-right cell (+ width 2)))
                                    row widths)
                               ""))))]
    (string-join (map line rows) "\n")))

(define (file-table files)
  "Return the FILES as lines of a table, largest first.

  @strong{files} (list of alists):
    What @code{(dokgen stats) analyze-file} returns for each file.

  @strong{Return value} (string):
    The name, the lines of code, the lines of comment and the decision
    points of each file."
  (padded-rows
   (cons '("file" "code" "comment" "decisions")
         (map (lambda (file)
                (list (assoc-ref file 'name)
                      (number->string (assoc-ref file 'code))
                      (number->string (assoc-ref file 'comment))
                      (number->string (assoc-ref file 'decisions))))
              files))))

(define (cost-table entries)
  "Return ENTRIES as lines of a table of who or what cost how much.

  @strong{entries} (list of triples):
    A name and the lines added and removed under it.

  @strong{Return value} (string):
    The name, what it added, what it removed and the two added up."
  (padded-rows
   (cons '("name" "added" "removed" "changed")
         (map (lambda (entry)
                (list (first entry)
                      (number->string (second entry))
                      (number->string (third entry))
                      (number->string (+ (second entry) (third entry)))))
              entries))))

(define (size-table totals files modules)
  "Return the size of the tree as lines of a table.

  @strong{totals} (alist):
    What @code{(dokgen stats) project-stats} returned.

  @strong{files} (list of alists):
    The measured files, one per row of the table that counts them.

  @strong{modules} (integer):
    How many modules the files make.

  @strong{Return value} (string):
    The rows a reader scans first: how much there is of everything.  It is
    a monospaced block and not a @code{@@table} because Texinfo wants a
    heading on every item of one, and because every other table in the
    chapter is monospaced already."
  (padded-rows
   `(("size" "")
     ("files" ,(number->string (length files)))
     ("modules" ,(number->string (or modules 0)))
     ("lines of code" ,(number->string (assoc-ref totals 'code)))
     ("lines of comment" ,(number->string (assoc-ref totals 'comment)))
     ("blank lines" ,(number->string (assoc-ref totals 'blank)))
     ("bytes" ,(number->string (assoc-ref totals 'bytes)))
     ("decision points" ,(number->string (assoc-ref totals 'decisions))))))

(define (stats-chapter statistics)
  "Return the statistics of a project as an stexi chapter.

  @strong{statistics} (alist):
    What @code{(dokgen commands) stats} measured and counted:
    @code{totals} from @code{(dokgen stats) project-stats}, the
    @code{coverage} of the exported names, the number of @code{modules},
    and @code{git}, the history or @code{#false} when the tree has none.

  @strong{Return value} (stexi):
    A chapter describing the tree: its size, where its code sits, how much
    of its API is documented, who wrote it and what churns."
  (let* [(totals (assoc-ref statistics 'totals))
         (files (assoc-ref totals 'files))
         (coverage (assoc-ref statistics 'coverage))
         (documented (car coverage))
         (exported (cdr coverage))
         (modules (assoc-ref statistics 'modules))
         (git (assoc-ref statistics 'git))
         (churn (and git (assoc-ref git 'files)))
         (percentage
          (and (> exported 0) (* 100 (exact->inexact (/ documented exported)))))]
    `(*fragment*
      (c (% (all "NOTE: Autogenerated documentation. Do not edit manually.")))
      (node (% (name "Statistics")))
      (chapter "Statistics")
      (para "This chapter is written by " (command "dokgen stats")
            " from the tree itself, so it says what the code is rather than
what someone remembers it to be.")
      ,@(if git
            `((para "It describes the tree at commit "
                    (code ,(assoc-ref git 'commit)) ", on "
                    ,(assoc-ref git 'last) "."))
            '((para "The tree carries no git history this run could read, so
the chapter reports no authors and no churn.")))

      (section "Size")
      (example ,(size-table totals files modules))

      (section "The largest files")
      (para "The files with the most code in them, with the lines of comment
and the decision points that sit beside it.")
      (example ,(file-table files))

      (section "Documentation")
      (para ,(if percentage
                 (format #f "~a of the ~a exported procedures and macros have a documentation string (~a%)."
                         documented exported (inexact->exact (round percentage)))
                 "The tree exports no procedure or macro, so there is nothing to document."))

      ,@(if (and git (pair? churn))
            `((section "Authors")
              (para "The people the repository's history names, with the
lines they added and removed.")
              (example ,(cost-table (assoc-ref git 'authors)))

              (section "The files that change most")
              (para "The files among those measured that the history touched
most: the ones where a change costs the most to review.")
              (example ,(cost-table (at-most 10 churn)))

              (para "The repository holds "
                    ,(number->string (assoc-ref git 'commits))
                    " commits, the first on "
                    ,(assoc-ref git 'first) "."))
            '())

      (para "A decision point is an " (code "if") ", " (code "cond") ", "
            (code "case") ", " (code "when") ", " (code "unless") " or "
            (code "do") " in the code.  It counts shapes and not paths, and
it grades nothing: a file with many of them is a file that branches
often."))))
