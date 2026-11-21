;; guile-dokgen --- mermaid diagrams in the documentation
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module turns the mermaid diagrams a documentation string carries
into images the manual can show.

A diagram is written in a docstring as a fenced block, the way a markdown
reader already knows.  What follows is one, and it is drawn where the
manual shows this module:

```mermaid
graph LR
  source["a docstring"] --> fence["a fenced block"]
  fence --> diagram["a diagram"]
  diagram --> image["an image"]
```

The fence is consumed, the diagram is written next to the generated
Texinfo as @file{diagrams/NAME-HASH.mmd}, and a renderer turns it into
@file{diagrams/NAME-HASH.png}, which the API chapter references with
@code{@@image}. The name carries a digest of the diagram's own text, so a
diagram that changed gets a file of its own and an old rendering can never
be shown as the current one.

The renderer is a command, not a library: mermaid is JavaScript, and a
documentation generator that embedded a browser to draw an arrow would be a
worse trade than one that calls the tool a project already uses. The
command @code{mmdc} (from @code{mermaid-cli}) is the default; the
parameters @code{*mermaid-command*} and @code{*diagram-destination*} say
what to run and where to write, so a caller sets them once around a whole
run. A command left empty renders nothing, which is how a tree that
commits its images builds its manual without a renderer.

When there is no image, the diagram's source is written into the manual
instead, in an @code{@@example} block with a line saying what it is. A
diagram that silently disappeared from a manual would be worse than one a
reader has to copy. |#

;;; Code:

(define-module (dokgen diagrams)
  #:declarative? #t
  #:use-module (dokgen writer)
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 string-fun)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:export (DEFAULT_MERMAID_COMMAND
            *diagram-destination*
            *mermaid-command*
            diagram-blocks
            diagram-stem
            diagram-stexi))


;;; CONSTANTS

;; Opens a fenced mermaid block in a documentation string.
(define DIAGRAM_FENCE "```mermaid")

;; Closes one.
(define FENCE "```")

;; The command that renders a diagram when the caller names no other.  The
;; renderer gets the diagram's source as %i and the path to write as %o,
;; without an extension, so that a renderer writing PNG and one writing SVG
;; are configured by the same option.
(define DEFAULT_MERMAID_COMMAND "mmdc --input %i --output %o.png")

;; The extensions an image may have, most portable first: texi2any looks
;; for the first four on its own, and an SVG has to be named in the
;; @code{@@image} command itself.
(define IMAGE_EXTENSIONS '("png" "jpg" "gif" "svg"))


;;; PARAMETERS

;; Where diagrams are written, and what renders them.  Both are set once
;; around a whole extraction rather than passed through every template:
;; the destination reaches the diagrams from the command, eight calls up
;; the rendering stack, and it is the only thing those calls would add.
(define *diagram-destination* (make-parameter #f))
(define *mermaid-command* (make-parameter DEFAULT_MERMAID_COMMAND))


;;; PROCEDURES

(define (fence? line)
  "Return @code{#t} when @var{line} opens a mermaid diagram."
  (string-prefix? DIAGRAM_FENCE (string-trim-both line)))

(define (closing-fence? line)
  "Return @code{#t} when @var{line} closes a mermaid diagram."
  (string=? FENCE (string-trim-both line)))

(define (opens-verbatim line)
  "Return the name of the Texinfo block @var{line} opens, or @code{#f}.

  A mermaid block written inside one of these quotes the syntax instead
  of drawing it: a reader of a docstring that shows how to write a diagram
  must not find the sample drawn."
  (and=> (string-match
          "^\\s*@(example|smallexample|lisp|smalllisp|format|display|verbatim)\\s*$"
          line)
         (lambda (found) (match:substring found 1))))

(define (closes-verbatim? block line)
  "Return @code{#t} when @var{line} closes the Texinfo @var{block}."
  (and (string-match (format #f "^\\s*@end ~a\\s*$" block) line) #true))

(define (take-diagram lines)
  "Return the lines of a diagram and the lines that follow it.

  @strong{lines} (list of strings):
    The lines after the one that opens the diagram.

  @strong{Return value} (two values):
    The diagram's lines and the remaining lines, or @code{#f} and the
    remaining lines when the diagram is never closed."
  (let loop [(rest lines) (diagram '())]
    (cond
     [(null? rest) (values #f '())]
     [(closing-fence? (first rest)) (values (reverse diagram) (cdr rest))]
     [else (loop (cdr rest) (cons (first rest) diagram))])))

(define (diagram-blocks docstring)
  "Return the documentation string split into prose and diagrams.

  @strong{docstring} (string):
    The documentation of a module or of one of its objects.

  @strong{Return value} (list of pairs):
    Every pair is either @code{(text . STRING)} or
    @code{(diagram . STRING)}, in the order they are written.  A fence
    that is never closed stays prose, because a docstring with a typo in
    it should still reach the reader, and so does one written inside a
    Texinfo block that quotes it."
  (define (add-prose prose blocks)
    "Cons the prose so far onto BLOCKS, unless there is none."
    (if (or (null? prose) (string-null? (string-trim-both (string-join prose ""))))
        blocks
        (cons (cons 'text (string-join (reverse prose) "\n")) blocks)))
  (let loop [(lines (string-split docstring #\newline)) (prose '()) (blocks '())
             (verbatim #false)]
    (cond
     [(null? lines) (reverse (add-prose prose blocks))]
     [(and verbatim (closes-verbatim? verbatim (first lines)))
      (loop (cdr lines) (cons (first lines) prose) blocks #false)]
     [verbatim (loop (cdr lines) (cons (first lines) prose) blocks verbatim)]
     [(opens-verbatim (first lines))
      => (lambda (block)
           (loop (cdr lines) (cons (first lines) prose) blocks block))]
     [(fence? (first lines))
      (call-with-values (lambda () (take-diagram (cdr lines)))
        (lambda (diagram rest)
          (if diagram
              (loop rest '()
                    (cons (cons 'diagram (string-join diagram "\n"))
                          (add-prose prose blocks))
                    #false)
              ;; The fence never closes, so the whole tail is prose.
              (loop '() (append (reverse lines) prose) blocks #false))))]
     [else (loop (cdr lines) (cons (first lines) prose) blocks verbatim)])))

(define (digest text)
  "Return eight hexadecimal digits of FNV-1a applied to @var{text}.

  A digest is wanted, not a hash: the same diagram must get the same name
  on every machine and in every run, or the file a tree committed would
  be replaced by a new one on each build."
  (let loop [(characters (string->list text)) (hash 2166136261)]
    (if (null? characters)
        (format #f "~8,'0x" hash)
        (loop (cdr characters)
              (modulo (* (logxor hash (char->integer (first characters)))
                         16777619)
                      4294967296)))))

(define (diagram-stem owner source)
  "Return the name a diagram is written under, without an extension.

  @strong{owner} (string):
    What holds the diagram: a procedure's name, or a module's name.

  @strong{source} (string):
    The diagram, as mermaid.

  @strong{Return value} (string):
    The owner, with every character a shell or a URL would have to escape
    replaced by a dash, and a digest of the diagram."
  (format #f "~a-~a"
          (list->string
           (map (lambda (character)
                  (if (or (char-alphabetic? character)
                          (char-numeric? character)
                          (memv character '(#\- #\_)))
                      character
                      #\-))
                (string->list owner)))
          (digest source)))

(define (image-extension base)
  "Return the extension of the image that exists under @var{base}, or #f."
  (find (lambda (extension) (file-exists? (format #f "~a.~a" base extension)))
        IMAGE_EXTENSIONS))

(define (render! command source-file base)
  "Render the diagram in @var{source-file} to @var{base}, without extension.

  @strong{command} (string):
    The renderer, split on whitespace and run without a shell, so a path
    in it is a path and not something a shell could read.  @code{%i} is
    replaced by the source and @code{%o} by @var{base}.

  @strong{Result}:
    The renderer is run; a failure is reported and not raised, because a
    diagram that could not be drawn is still a diagram that can be read as
    source."
  (let [(arguments
         (map (lambda (word)
                (string-replace-substring
                 (string-replace-substring word "%i" source-file)
                 "%o" base))
              (string-tokenize command)))]
    (unless (and (pair? arguments)
                 (false-if-exception (zero? (apply system* arguments))))
      (format (current-error-port)
              "warning: the mermaid renderer failed on ~a: ~a~%"
              source-file command))))

(define (diagram-file source stem destination)
  "Write @var{source} as a diagram, and return its image's path, or #f.

  @strong{source} (string):
    The diagram, as mermaid.

  @strong{stem} (string):
    The name of its files, as from @code{diagram-stem}.

  @strong{destination} (string):
    The directory the Texinfo file is written to; the diagram goes in a
    @file{diagrams} directory inside it.

  @strong{Return value} (string or @code{#f}):
    The image's path relative to @var{destination}, or @code{#f} when
    there is no image: either nothing was drawn and none was drawn before,
    or the renderer that ran failed.  The diagram's source is written
    either way, so that a reader can draw it later with the tool of their
    choice."
  (let* [(base (format #f "~a/diagrams/~a" destination stem))
         (command (*mermaid-command*))
         (extension (begin
                      (let [(source-file (string-append base ".mmd"))]
                        (save source source-file)
                        (when (and command (not (string-null? command)))
                          (render! command source-file base)))
                      (image-extension base)))]
    (and extension (format #f "diagrams/~a.~a" stem extension))))

(define (image-stexi path)
  "Return the stexi that shows the image at @var{path}.

  @strong{path} (string):
    The image's path, relative to the Texinfo file that references it.

  @strong{Return value} (stexi):
    An @code{@@image} node.  The extension is left out of the file name,
    because Texinfo searches the extensions its writers know; SVG is the
    exception, and is named in the command's last argument."
  (let* [(dot (string-rindex path #\.))
         (extension (and dot (string-downcase (substring path (+ 1 dot)))))
         (file (if dot (substring path 0 dot) path))
         (alt-text "Mermaid diagram")]
    (if (and extension (string=? extension "svg"))
        `(image (% (file ,file) (alt-text ,alt-text) (extension "svg")))
        `(image (% (file ,file) (alt-text ,alt-text))))))

(define (diagram-stexi source owner)
  "Return the stexi nodes that show the diagram @var{source}.

  @strong{source} (string):
    The diagram, as mermaid.

  @strong{owner} (string):
    What holds the diagram; see @code{diagram-stem}.

  @strong{Return value} (list of stexi):
    One node holding the image, in a paragraph of its own because Texinfo
    writes an image inline where it stands, or two nodes holding the
    diagram's source and a line that says what it is when no image could
    be made."
  (let* [(destination (*diagram-destination*))
         (image (and destination
                     (diagram-file source
                                   (diagram-stem owner source)
                                   destination)))]
    (if image
        (list (list 'para (image-stexi image)))
        (list '(para "Mermaid diagram, as source:")
              `(example ,source)))))
