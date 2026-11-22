;; guile-dokgen --- tests: test-assets
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Test suite for the module (dokgen assets). |#

(use-modules ((dokgen assets) #:prefix assets:)
             (ice-9 format)
             (ice-9 textual-ports)
             (proba utils)
             (srfi srfi-1)
             (srfi srfi-64))


;;; CONSTANTS

(define SUITE_NAME "(dokgen assets)")

;; A destination of its own, so that a run never writes into the tree.
(define TEST_DIR (format #f "/tmp/dokgen-assets-~a" (getpid)))


;;; HELPERS

(define (asset-text name)
  "Return the text of the asset NAME written beside the chapter."
  (call-with-input-file (format #f "~a/~a" TEST_DIR name) get-string-all))


;;; TEST SUITE

(test-begin SUITE_NAME)

(test-group
    "the stylesheet"

  (test-assert
      "Style the definition cards a reader reads one at a time."
    (string-contains assets:STYLESHEET "dl.def-block"))

  (test-assert
      "Follow the reader's own preference for a light or a dark page."
    (string-contains assets:STYLESHEET "prefers-color-scheme"))

  (test-assert
      "Leave the page alone when it is printed."
    (string-contains assets:STYLESHEET "@media print"))

  (test-assert
      "Close the index into a drawer on a narrow page."
    (string-contains assets:STYLESHEET "translateX(-103%)"))

  (test-assert
      "Drop the body's table of contents when the index holds a whole manual."
    (string-contains assets:STYLESHEET ".region-contents#SEC_Contents")))


(test-group
    "the script"

  (test-assert
      "Index the definitions of the page by the id their anchors carry."
    (string-contains assets:SCRIPT "def-block"))

  (test-assert
      "Draw a diagram the renderer left as source."
    (and (string-contains assets:SCRIPT "dokgen-mermaid.js")
         (string-contains assets:SCRIPT "dk-diagram")))

  (test-assert
      "Let the index take the place of the body's table of contents."
    (and (string-contains assets:SCRIPT "ul.mini-toc")
         (string-contains assets:SCRIPT "dk-has-index")))

  (test-assert
      "Read a page that holds its own sections as a tree of its headings."
    (and (string-contains assets:SCRIPT "h2.chapter")
         (string-contains assets:SCRIPT "subsection-level-extent")))

  (test-assert
      "Keep the path to a definition that matches the filter."
    (string-contains assets:SCRIPT "group.parent.li.hidden")))


(test-group
    (unit-name assets:write-assets!)

  (begin
    (assets:write-assets! TEST_DIR)

    (test-assert
        "Write the stylesheet beside the chapter."
      (file-exists? (format #f "~a/dokgen.css" TEST_DIR)))

    (test-assert
        "Write the script beside it too."
      (file-exists? (format #f "~a/dokgen.js" TEST_DIR)))

    (test-assert
        "Copy the bundled renderer beside them."
      (file-exists? (format #f "~a/dokgen-mermaid.js" TEST_DIR)))

    (test-assert
        "Write what the module says, and not something it read from the tree."
      (and (string=? (asset-text "dokgen.css") assets:STYLESHEET)
           (string=? (asset-text "dokgen.js") assets:SCRIPT)))))

(test-end SUITE_NAME)

(false-if-exception (system* "rm" "-rf" TEST_DIR))
