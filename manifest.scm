;; guile-dokgen --- API documentation for GNU Guile Scheme projects.
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; The development environment: Guile, the libraries the program needs
;; (guile-config for the command line, guile-lib for stexi), Texinfo to build
;; the manual, and veritas for the tests.  Every `maak' task enters it through
;; `guix time-machine -C channels.scm', so the Guix revision is the one
;; `channels.scm' pins.
;;
;; The program itself is never installed here: the tasks run `bin/dokgen'
;; from the checkout, because the checkout under test is the one being
;; developed.

(use-modules (gnu packages)
             (gnu packages guile)
             (gnu packages guile-xyz)
             (guix build-system guile)
             (guix git-download)
             (guix packages)
             ((guix licenses) #:prefix license:))

;;; Veritas is the test framework `maak test' runs.  Specs are discovered
;;; under test/veritas/unit and their suites are named `(veritas unit ...)',
;;; so the library is part of the development environment as much as it is a
;;; run-time dependency of the test task.  The channel `channels.scm' pins
;;; carries an older release, which is why it is defined here: a test
;;; framework is the one dependency whose version should be stated by the
;;; project that writes the tests.
(define-public guile-veritas
  (package
    (name "guile-veritas")
    (version "1.6.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jjba23/veritas.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1lb80y2dks68a2jlr5xix9m8pyqnzwiqiaynbl05p463xxhzs0v7"))))
    (build-system guile-build-system)
    (arguments
     (list
      #:source-directory "src"))
    (native-inputs (list guile-3.0))
    (propagated-inputs (list guile-fibers guile-json-4))
    (home-page "https://github.com/jjba23/veritas")
    (synopsis "Testing framework for Guile")
    (description
     "Veritas is a testing framework for Guile with an @acronym{EDSL,
embedded domain specific language} to define test suites.  Emphasis is placed
on legible, maintainable tests.  Veritas shuffles tests and runs them
concurrently by default.")
    (license license:expat)))

;;; Named rather than imported: a name resolves in whichever module of the
;;; pinned Guix defines it, so the manifest does not have to know which one.
(packages->manifest
 (list guile-3.0-latest
       (specification->package "guile-config")
       (specification->package "guile-lib")
       (specification->package "texinfo")
       guile-veritas))
