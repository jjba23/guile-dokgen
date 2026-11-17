;; guile-dokgen --- API documentation for GNU Guile Scheme projects.
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; The development environment: Guile, the libraries the program needs
;; (guile-config for the command line, guile-lib for stexi), Texinfo to build
;; the manual, and guile-proba for the tests.  Every `maak' task enters it
;; through `guix time-machine -C channels.scm', so the Guix revision is the
;; one `channels.scm' pins.
;;
;; The program itself is never installed here: the tasks run `bin/dokgen'
;; from the checkout, because the checkout under test is the one being
;; developed.

(use-modules (gnu packages))

;; Named rather than imported: a name resolves in whichever module of the
;; pinned Guix defines it, so the manifest does not have to know which one.
(specifications->manifest
 (list "guile"
       "guile-config"
       "guile-lib"
       "guile-proba"
       "texinfo"))
