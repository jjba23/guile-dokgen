;; guile-dokgen --- tests: boguslibs/unbound
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

#| Dummy module that exports things with undefined values.

This is to test cases where developers remove definitions from a
module but forget to remove the associated name from the list of
exports. |#

(define-module (tests boguslibs unbound)
  #:export (residual-export))
