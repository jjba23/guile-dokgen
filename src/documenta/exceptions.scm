;; guile-documenta --- the exceptions the program raises
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

(define-module (documenta exceptions)
  #:use-module (ice-9 exceptions)
  #:export (&residual-export-exception
            make-residual-export-exception
            residual-export-exception?
            residual-export-exception-reason
            residual-export-exception-exported-residue
            residual-export-exception-exporter-module))


(define-exception-type &residual-export-exception
  #| Raised when an unbound export is found in a module's API.

  This can occur, for example, when a developer removes a procedure,
  variable, etc., from a module but forgets to remove its name from the
  export list. |#
  &exception
  make-residual-export-exception
  residual-export-exception?
  (reason residual-export-exception-reason)                      ; string
  (exported-residue residual-export-exception-exported-residue)  ; symbol
  (exporter-module residual-export-exception-exporter-module))   ; list
