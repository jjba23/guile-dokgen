#| Command-line interface

Public domain 2023 Luis Felipe López Acevedo. All rights waived. |#

(define-module (documenta cli)
  #:use-module (config)
  #:use-module (config api)
  #:use-module (config licenses)
  #:use-module (documenta commands)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:export (call
            spec))


;;; VALIDATORS

(define (directory? path)
  #| Tell whether the given PATH leads to a directory.

  PATH (string):
    An absolute or relative path to something in the file system. For
    example: "/home/bob/videos", "images/sky/sunset.png".

  RETURN VALUE (boolean):
    True if the PATH leads to a directory; false otherwise. |#
  (let [(type (stat:type (stat path)))]

    (equal? type 'directory)))



;;; ARGUMENTS AND FLAGS

(define source
  (argument (name 'source)
            (synopsis "Absolute or relative path to a library's directory.")
            (example "/home/user/project/mylib")
            (test directory?)))

(define destination
  (argument (name 'destination)
            (synopsis "Absolute or relative path to a directory where the final documentation will be saved.")
            (example "/home/user/project/doc/api")
            (default DEFAULT_DOC_PATH)))



;;; CLI SPECIFICATION

(define spec
  (configuration
   (name 'documenta)
   (synopsis "Generate API documentation.")
   (description
    "This is the command-line interface of Guile Documentá, a piece of software to generate API documentation for libraries written in GNU Guile Scheme.")
   (version "0.1.0")
   (license public-domain)
   (author "Luis Felipe López Acevedo")

   (subcommands
    (list
     (configuration
      (name 'extract)
      (synopsis "Extract the documentation of the given library.")
      (arguments (list source destination)))))))



;;; COMMAND OBSERVER

(define (call command spec)
  "Call an appropriate procedure for the given command.

  COMMAND (list of strings):
    A list of strings that represent a command-line instruction passed
    to the program (see Guile's command-line procedure).

  SPEC (Configuration):
    A <configuration> record as defined by the guile-config library,
    which specifies the command-line interface of the program.

  RESULT:
    The COMMAND is followed. If the command is not recognized, display
    help information."
  (let* [(options (getopt-config-auto command spec))
         (source (option-ref options '(source)))
         (destination (option-ref options '(destination)))]

    (catch 'match-error
      (lambda ()
        (match (full-command options)
          ((_ "extract") (extract source destination))))

      (lambda (. args)
        (begin (format #true "ERROR: Command not found: ~a~%~%" command)
               (emit-help options))))))
