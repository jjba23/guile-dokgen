;; guile-dokgen --- helper procedures
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines helper procedures that didn't quite fit anywhere
else. |#

;;; Code:

(define-module (dokgen utils)
  #:use-module (srfi srfi-1)
  #:export (DEFAULT_SPACE_INDENT_SIZE

             min-indent
             tabs->spaces
             trim
             unindent))


;;; CONSTANTS

(define DEFAULT_SPACE_INDENT_SIZE 2)



;;; PROCEDURES

(define (min-indent string)
  "Return the shorter number of spaces used for indentation in the given
  string.

  This procedure assumes indentation is space-based, not tab-based.

  @strong{string} (string):
    The text to inspect.

  @strong{Return value} (integer):
    The number of spaces representing the shorter indentation."
  (if (or (string-null? string) (not (string-contains string "\n")))
      0
      (let [(target-lines (cdr (string-split string #\newline)))]
        ;; Target lines omit the first line (never indented). Otherwise,
        ;; the procedure would always return zero.
        (fold
         (lambda (line result-so-far)
           (if (string-null? line)
               result-so-far
               (min result-so-far
                    (- (string-length line) (string-length (string-trim line))))))
         9999           ; Arbitrary big min-indent to start comparing.
         target-lines))))


(define* (tabs->spaces string #:optional (tabsize DEFAULT_SPACE_INDENT_SIZE))
  "Convert tabs to spaces in the given string.

  @strong{string} (string):
    The original text.

  @strong{tabsize} (integer):
    Optional. The number of spaces that will replace a single tab.
    If not provided, @var{DEFAULT_SPACE_INDENT_SIZE} is used.

  @strong{Return value} (string):
    A new string where all tabs are replaced by spaces."
  (string-concatenate
   (map
    (lambda (character)
      (if (char=? character #\tab)
          (make-string tabsize #\space)
          (make-string 1 character)))
    (string->list string))))


(define (trim string spaces)
  "Trim off the given number of spaces at the beginning of the string.

  @strong{string} (string):
    The original text.

  @strong{spaces} (integer):
    The number of spaces to trim off.

  @strong{Return value} (string):
    A new string with the exact number of spaces removed, if they exist.
    Otherwise, the original string is returned."
  (let [(indent (make-string spaces #\space))]

    (if (string-prefix? indent string)
        (string-drop string spaces)
        string)))


(define (unindent docstring)
  "Remove unwanted indentation from the given documentation string.

  'Unwanted' indentation is what results, for example, from aligning
  documentation lines to the first line of the documentation string so
  that they look aesthetic in the source code.

  @strong{docstring} (string):
    A string that documents a procedure or any other object.

  @strong{Return value} (string):
    A new string with the undesired indentation removed."
  (let* [(untabbed-docstring (tabs->spaces docstring))
         (min-indent (min-indent untabbed-docstring))
         (lines (string-split untabbed-docstring #\newline))
         ;; Remove 1st level indents, if any.
         (lines-trimmed
          (map
           (lambda (line) (trim line min-indent))
           lines))]

    (string-join lines-trimmed "\n")))
