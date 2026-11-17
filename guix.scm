;; guile-documenta --- API documentation for GNU Guile Scheme projects.
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; A package definition for the working tree.  Build or enter it with:
;;
;;   guix shell -f guix.scm -- documenta --help
;;
;; The version is stated once, in `src/documenta/cli.scm', and read from there:
;; a package definition is code, so it reads the number rather than keep a
;; second copy that a release would have to remember to rewrite.

(use-modules (ice-9 regex)
             (ice-9 textual-ports)
             (guix gexp)
             (guix packages)
             (guix utils)
             (gnu packages guile)
             (gnu packages guile-xyz)
             (gnu packages texinfo)
             (guix build-system guile)
             ((guix licenses) #:prefix license:))

(define %source-dir
  (dirname (current-filename)))

(define %documenta-version
  (let* ((text (call-with-input-file
                   (string-append %source-dir "/src/documenta/cli.scm")
                 get-string-all))
         (found (string-match "\\(version \"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\)"
                              text)))
    (unless found
      (error "guix.scm: src/documenta/cli.scm does not state a version"))
    (match:substring found 1)))

(define-public guile-documenta
  (package
    (name "guile-documenta")
    (version %documenta-version)
    (source (local-file %source-dir
                        #:recursive? #t
                        #:select? (git-predicate %source-dir)))
    (build-system guile-build-system)
    (arguments
     (list #:source-directory "src"
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'install 'install-launcher
                 (lambda* (#:key inputs outputs #:allow-other-keys)
                   (let* ((out (assoc-ref outputs "out"))
                          (bin (string-append out "/bin")))
                     (mkdir-p bin)
                     (call-with-output-file (string-append bin "/documenta")
                       (lambda (port)
                         (format port "#!/bin/sh~%exec guile -c '(begin (use-modules (documenta cli)) (call (command-line) spec))' \"$@\"~%")))
                     (chmod (string-append bin "/documenta") #o755))))))
    (inputs (list guile-3.0))
    (propagated-inputs (list guile-config guile-lib))
    (native-inputs (list guile-proba texinfo))
    (home-page "https://github.com/jjba23/guile-documenta")
    (synopsis "Generate API documentation for GNU Guile projects")
    (description
     "Guile Documentá is a command-line program and library that extracts the
API documentation of GNU Guile Scheme modules and writes it in Texinfo
format.")
    (license license:expat)))

guile-documenta
