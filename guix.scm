;; guile-dokgen --- API documentation for GNU Guile Scheme projects.
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; A package definition for the working tree.  Build or enter it with:
;;
;;   guix shell -f guix.scm -- dokgen --help
;;
;; The version is stated once, in `src/dokgen/cli.scm', and read from there:
;; a package definition is code, so it reads the number rather than keep a
;; second copy that a release would have to remember to rewrite.

(use-modules (ice-9 regex)
             (ice-9 textual-ports)
             (guix gexp)
             (guix git-download)
             (guix packages)
             (guix utils)
             (gnu packages check)
             (gnu packages guile)
             (gnu packages guile-xyz)
             (gnu packages texinfo)
             (guix build-system guile)
             ((guix licenses) #:prefix license:))

(define %source-dir
  (dirname (current-filename)))

(define %dokgen-version
  (let* ((text (call-with-input-file
                   (string-append %source-dir "/src/dokgen/cli.scm")
                 get-string-all))
         (found (string-match "\\(version \"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\)"
                              text)))
    (unless found
      (error "guix.scm: src/dokgen/cli.scm does not state a version"))
    (match:substring found 1)))

(define-public guile-dokgen
  (package
    (name "guile-dokgen")
    (version %dokgen-version)
    (source (local-file %source-dir
                        #:recursive? #t
                        #:select? (git-predicate %source-dir)))
    (build-system guile-build-system)
    (arguments
     (list #:source-directory "src"
           #:phases
           #~(modify-phases %standard-phases
               ;; guile-build-system has no `install' phase to add to: its
               ;; `build' phase is the one that puts the modules in the store.
               (add-after 'install-documentation 'install-launcher
                 (lambda* (#:key inputs outputs #:allow-other-keys)
                   (let* ((out (assoc-ref outputs "out"))
                          (site (string-append out "/share/guile/site/3.0"))
                          (bin (string-append out "/bin")))
                     (mkdir-p bin)
                     (call-with-output-file (string-append bin "/dokgen")
                       (lambda (port)
                         ;; The launcher names the modules it was installed
                         ;; with and the two libraries it needs, so it
                         ;; answers outside a profile as well as inside one.
                         (format port
                                 "#!/bin/sh~%exec guile ~a -c '(begin (use-modules (dokgen cli)) (call (command-line) spec))' \"$@\"~%"
                                 (string-join
                                  (map (lambda (directory)
                                         (format #f "-L ~a/share/guile/site/3.0"
                                                 directory))
                                       (list out
                                             (assoc-ref inputs "guile-config")
                                             (assoc-ref inputs "guile-lib")))
                                  " ")))
                       #:encoding "UTF-8")
                     (chmod (string-append bin "/dokgen") #o755)))))))
    (inputs (list guile-3.0))
    (propagated-inputs (list guile-config guile-lib))
    (native-inputs (list texinfo))
    (home-page "https://github.com/jjba23/guile-dokgen")
    (synopsis "Generate API documentation for GNU Guile projects")
    (description
     "Guile Dokgen is a command-line program and library that extracts the
API documentation of GNU Guile Scheme modules and writes it in Texinfo
format.")
    (license license:expat)))

guile-dokgen
