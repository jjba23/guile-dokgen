;; guile-dokgen --- the exceptions the program raises
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines the exceptions raised by the @command{dokgen}
program.

The exception type @code{&residual-export-exception} is raised when a
module exports a name that is not bound to any object. This can occur,
for example, when a developer removes a procedure, variable, etc., from
a module but forgets to remove its name from the export list.

Its constructor, its predicate and its three field readers are defined by
@code{define-exception-type}, which gives them no documentation strings;
each one is given its own below, so that a name this module exports is a
name the manual can document. |#

;;; Code:

(define-module (dokgen exceptions)
  #:use-module (ice-9 exceptions)
  #:export (&residual-export-exception
            make-residual-export-exception
            residual-export-exception?
            residual-export-exception-reason
            residual-export-exception-exported-residue
            residual-export-exception-exporter-module))


(define-exception-type &residual-export-exception
  ;; Raised when an unbound export is found in a module's API.
  &exception
  make-residual-export-exception
  residual-export-exception?
  (reason residual-export-exception-reason)                      ; string
  (exported-residue residual-export-exception-exported-residue)  ; symbol
  (exporter-module residual-export-exception-exporter-module))   ; list


;;; DOCUMENTATION
;;;
;;; A generated procedure carries no documentation string, so this
;;; project's own `check' would report five names in this module.  That is
;;; the right answer for a gap and the wrong one here: the sentences exist,
;;; they were only written by hand instead of by `define-exception-type'.

(set-procedure-property!
 make-residual-export-exception 'documentation
 "Return a new @code{&residual-export-exception}.

  @strong{reason} (string):
    What went wrong, in a sentence a reader can act on.

  @strong{exported-residue} (symbol):
    The name that was exported but never bound.

  @strong{exporter-module} (list of symbols):
    The module that exports it, for example: @code{'(mylib amodule)}.")

(set-procedure-property!
 residual-export-exception? 'documentation
 "Return @code{#true} when the given object is a residual export exception.")

(set-procedure-property!
 residual-export-exception-reason 'documentation
 "Return the sentence that explains what went wrong.")

(set-procedure-property!
 residual-export-exception-exported-residue 'documentation
 "Return the name that was exported but never bound.")

(set-procedure-property!
 residual-export-exception-exporter-module 'documentation
 "Return the module that exports the residue, as a list of symbols.")
