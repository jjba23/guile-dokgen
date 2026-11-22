;; guile-dokgen --- the command-line interface
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module defines the command-line interface of the
@command{dokgen} program. See the @ref{CLI} section for additional
information.

The variable @code{spec} is the specification of the interface, a
@code{<configuration>} record as defined by the guile-config library.
It names the program, states its version, license and author, and
declares the @code{api} subcommand with its @code{sources} argument and
its @code{destination} keyword. The procedure @code{call} dispatches a
command line to the procedure that carries it out. |#

;;; Code:

(define-module (dokgen cli)
  #:use-module (config)
  #:use-module (config api)
  #:use-module (config licenses)
  #:use-module (dokgen commands)
  #:use-module (dokgen diagrams)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (call
            spec))


;;; ARGUMENTS AND FLAGS

(define sources
  (argument (name 'sources)
            (synopsis "Absolute or relative paths to Guile Scheme modules that compose the code whose API documentation will be extracted.")
            (example "libz or \"libz.scm libz\"")
            (handler (lambda (sources)
                       ;; Convert string of space-separated sources to
                       ;; to list of sources.
                       (string-split sources #\space)))
            (test (lambda (sources) (every file-exists? sources)))))

(define destination
  (switch (name 'destination)
          (synopsis "Absolute or relative path to a directory where the final documentation will be saved.")
          (example "/home/user/project/doc/api")
          (default DEFAULT_DOC_PATH)))

(define mermaid-command
  (switch (name 'mermaid-command)
          (synopsis "Command that draws a mermaid diagram, with %i standing for the diagram's source and %o for the path its image is written to. An empty command draws nothing; without an image the page draws the diagram itself.")
          (example "mmdc --input %i --output %o.png --scale 2 --backgroundColor transparent")
          (default DEFAULT_MERMAID_COMMAND)))

(define gnuplot-command
  (switch (name 'gnuplot-command)
          (synopsis "Command that draws a gnuplot diagram, with %i standing for the script dokgen writes and %o for the path its image is written to. An empty command draws nothing.")
          (example "gnuplot %i")
          (default DEFAULT_GNUPLOT_COMMAND)))



;;; CLI SPECIFICATION

(define spec
  (configuration
   (name 'dokgen)
   (synopsis "Generate API documentation.")
   (description
    "This is the command-line interface of Guile Dokgen, a software to generate API documentation for GNU Guile Scheme projects.")
   (version "0.10.2")
   (license expat)
   (author "Josep Bigorra")

   (subcommands
    (list
     (configuration
      (name 'api)
      (synopsis "Extract the API documentation of the given Guile Scheme package or module.")
      (arguments (list sources))
      (keywords (list destination mermaid-command gnuplot-command)))

     (configuration
      (name 'check)
      (synopsis "Report the exported procedures and macros that have no documentation string.")
      (arguments (list sources)))

     (configuration
      (name 'stats)
      (synopsis "Measure the sources: lines, decision points, authors and churn.")
      (arguments (list sources))
      (keywords (list destination)))))))



;;; COMMAND OBSERVER

(define (call command spec)
  "Call an appropriate procedure for the given command.

  @strong{command} (list):
    A list of strings that represent a command-line instruction passed
    to the program (see Guile's command-line procedure).

  @strong{spec} (Configuration):
    A @code{<configuration>} record as defined by the guile-config
    library, which specifies the command-line interface of the program.

  @strong{Result}:
    The @var{command} is followed. If the command is not recognized,
    display help information."
  (let* [(options (getopt-config-auto command spec))
         (sources (option-ref options '(sources)))
         (destination (or (option-ref options 'destination) DEFAULT_DOC_PATH))
         (mermaid-command (or (option-ref options 'mermaid-command)
                              DEFAULT_MERMAID_COMMAND))
         (gnuplot-command (or (option-ref options 'gnuplot-command)
                              DEFAULT_GNUPLOT_COMMAND))]

    (catch 'match-error
      (lambda ()
        (match (full-command options)
          ((_ "api") (api sources destination mermaid-command gnuplot-command))
          ((_ "stats") (stats sources destination))
          ;; A name with no documentation is what `check' exists to find,
          ;; so it is what its exit status has to say.
          ((_ "check") (unless (zero? (check sources)) (exit 1)))))

      (lambda (. args)
        (begin (format #true "ERROR: Command not found: ~a~%~%" command)
               (emit-help options))))))
