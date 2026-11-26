;; guile-dokgen --- test: veritas/unit/assets-spec
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| The two files a chapter is read with: the stylesheet that turns what texi2any
emits into a page of reference documentation, and the script that builds the
index, the source panels and the diagrams, both written beside the chapter.

They are strings the module owns, so a selector a feature hangs on can leave
them in silence: nothing raises, and a reader meets a page without the feature.
What is checked is that every feature still names the selector it depends on,
and that what lands beside the chapter is the module's own text rather than
something read off the tree. |#

(define-module (veritas unit assets-spec)
  #:use-module (dokgen assets)
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:use-module (veritas all))


;;; CONSTANTS

;; A destination of its own, so that a run never writes into the tree.
(define TEST_DIR (format #f "/tmp/dokgen-assets-~a" (getpid)))


;;; HELPERS

(define (asset-text name)
  "Return the text of the asset NAME written beside the chapter."
  (call-with-input-file (format #f "~a/~a" TEST_DIR name) get-string-all))


;;; SUITES

(define stylesheet-suite
  (suite "The stylesheet a chapter is read with"
         (test "each definition is a card a reader reads one at a time"
               (assert-contains #:expect STYLESHEET
                                #:got "dl.def-block"))
         (test "the page follows the reader's own choice of light or dark"
               (assert-contains #:expect STYLESHEET
                                #:got "prefers-color-scheme"))
         (test "a printed page is left as a page and not as a screen"
               (assert-contains #:expect STYLESHEET
                                #:got "@media print"))
         (test "a narrow page keeps the index in a drawer"
               (assert-contains #:expect STYLESHEET
                                #:got "translateX(-103%)"))
         (test "a single-page manual drops the body's table of contents"
               (assert-contains #:expect STYLESHEET
                                #:got ".region-contents#SEC_Contents"))
         (test "a definition opens the source it is read from"
               (assert-contains #:expect STYLESHEET
                                #:got ".dk-source"
                                #:name "the panel the source is folded into")
               (assert-contains #:expect STYLESHEET
                                #:got ".dk-tok-keyword"
                                #:name "the colour the source is read in"))
         (test "the surfaces that sit over the page are blurred"
               (assert-contains #:expect STYLESHEET
                                #:got "backdrop-filter"))))


(define script-suite
  (suite "The script a chapter is read with"
         (test "the index holds the definitions by the id their anchors carry"
               (assert-contains #:expect SCRIPT
                                #:got "def-block"))
         (test "a diagram the renderer left as source is drawn"
               (assert-contains #:expect SCRIPT
                                #:got "dokgen-mermaid.js"
                                #:name "the bundled renderer is loaded")
               (assert-contains #:expect SCRIPT
                                #:got "dk-diagram"
                                #:name "the diagram gets a plate of its own"))
         (test "the index takes the place of the body's table of contents"
               (assert-contains #:expect SCRIPT
                                #:got "ul.mini-toc"
                                #:name "the body's own list is the one folded")
               (assert-contains #:expect SCRIPT
                                #:got "dk-has-index"
                                #:name "the page says the index is up"))
         (test "a page that holds its own sections is read as a tree of its headings"
               (assert-contains #:expect SCRIPT
                                #:got "h2.chapter"
                                #:name "the chapters are the top of the tree")
               (assert-contains #:expect SCRIPT
                                #:got "subsection-level-extent"
                                #:name "the page's own sections decide the rest"))
         (test "a definition that matches the filter keeps the path to it"
               (assert-contains #:expect SCRIPT
                                #:got "group.parent.li.hidden"))
         (test "a definition marked to carry its source opens a panel"
               (assert-contains #:expect SCRIPT
                                #:got "dk-source"
                                #:name "the panel is the script's")
               ;; texi2any writes the underscore of the anchor's name as _005f.
               (assert-contains #:expect SCRIPT
                                #:got "dk_005fsource_005f"
                                #:name "the marker is found by its escaped id"))
         (test "the source a panel reveals is coloured"
               (assert-contains #:expect SCRIPT
                                #:got "dk-tok-"
                                #:name "every token gets a class")
               (assert-contains #:expect SCRIPT
                                #:got "kind = \"comment\""
                                #:name "a comment is told apart")
               ;; The forms a reader looks for first.
               (assert-contains #:expect SCRIPT
                                #:got "define-record-type"
                                #:name "the forms that matter are named"))))


(define write-assets-suite
  (suite "Writing the assets beside the chapter"
         #:before-all (lambda (vc)
                        (write-assets! TEST_DIR))
         #:after-all (lambda (vc)
                       (false-if-exception (system* "rm" "-rf" TEST_DIR)))
         (test "the stylesheet lands beside the chapter"
               (assert-true (file-exists?
                             (format #f "~a/dokgen.css" TEST_DIR))))
         (test "the script lands beside it too"
               (assert-true (file-exists?
                             (format #f "~a/dokgen.js" TEST_DIR))))
         (test "the bundled renderer is copied beside them"
               (assert-true (file-exists?
                             (format #f "~a/dokgen-mermaid.js" TEST_DIR))))
         (test "the files hold what the module says, not what the tree holds"
               (assert-equal #:expect STYLESHEET
                             #:got (asset-text "dokgen.css")
                             #:name "the stylesheet written is the module's")
               (assert-equal #:expect SCRIPT
                             #:got (asset-text "dokgen.js")
                             #:name "the script written is the module's"))))


(define (spec)
  (veritas-run stylesheet-suite
               script-suite
               write-assets-suite))
