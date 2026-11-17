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
a module but forgets to remove its name from the export list. It
provides the following procedures:

@itemize
@item
@code{make-residual-export-exception}: the constructor. It takes the
reason, the exported residue and the exporter module, in that order.
@item
@code{residual-export-exception?}: the predicate.
@item
@code{residual-export-exception-reason}: a string that explains the
problem.
@item
@code{residual-export-exception-exported-residue}: the symbol that was
exported but is unbound.
@item
@code{residual-export-exception-exporter-module}: the name of the
module that exports the residue, as a list of symbols.
@end itemize |#

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
  ;; Raised when an unbound export is found in a module's API; see the
  ;; module commentary for the details of each field.
  &exception
  make-residual-export-exception
  residual-export-exception?
  (reason residual-export-exception-reason)                      ; string
  (exported-residue residual-export-exception-exported-residue)  ; symbol
  (exporter-module residual-export-exception-exporter-module))   ; list
