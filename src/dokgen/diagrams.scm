;; guile-dokgen --- diagrams in the documentation
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module turns the diagrams a documentation string carries into
images the manual can show, or into source a browser can draw.

A diagram is written in a docstring as a fenced block, the way a markdown
reader already knows.  Two languages are read: mermaid and gnuplot.  What
follows is one, and it is drawn where the manual shows this module:

```mermaid
graph LR
  source["a docstring"] --> fence["a fenced block"]
  fence --> diagram["a diagram"]
  diagram --> image["an image"]
```

The fence is consumed, the diagram is written next to the generated
Texinfo as @file{diagrams/NAME-HASH.mmd} (or @file{.gp} for gnuplot), and
a renderer turns it into @file{diagrams/NAME-HASH.png} or @file{.svg},
which the API chapter references with @code{@@image}.  The name carries a
digest of the diagram's own text, so a diagram that changed gets a file of
its own and an old rendering can never be shown as the current one.

A renderer is a command, not a build-time library: @code{mmdc} is a Node
program, and a manual should not need it to show a diagram.  Each language
has a command of its own, and a command left empty draws nothing.  A
command whose program is not installed is skipped in silence: a diagram
that cannot be drawn is still a diagram that can be read, and a project
without the renderer should not be told off on every build.

Mermaid has a second path: when there is no image, the source is written
into the manual with a marker, and the script dokgen writes beside the
chapter draws it in the reader's browser from a bundled copy of mermaid.
That is what lets a project show its diagrams without installing
@code{mmdc} at all.  A reader without JavaScript, and every Info or print
reader, gets the source instead.  Gnuplot has no such path -- it is a
small program that draws an SVG at build time -- but its source stays
readable when the program is missing. |#

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
            DEFAULT_GNUPLOT_COMMAND
            MERMAID_SOURCE_MARKER
            *diagram-destination*
            *mermaid-command*
            *gnuplot-command*
            diagram-blocks
            diagram-stem
            diagram-stexi))


;;; CONSTANTS

;; Opens a fenced diagram in a documentation string.
(define FENCE_OPEN "```")

;; Closes one.
(define FENCE "```")

;; The languages a fence may name.
(define DIAGRAM_LANGUAGES '("mermaid" "gnuplot"))

;; The default renderer for a mermaid diagram.  The renderer gets the
;; diagram's source as %i and the path to write as %o, without an
;; extension, so that a renderer writing PNG and one writing SVG are
;; configured by the same option.  Twice the size and no background,
;; because the image is read on a page of any width and on a page that may
;; be dark.
(define DEFAULT_MERMAID_COMMAND "mmdc --input %i --output %o.png --scale 2 --backgroundColor transparent")

;; Gnuplot reads a script that says where its own output goes, so dokgen
;; writes one and hands the renderer that script.  The source a project
;; commits stays the plot alone.
(define DEFAULT_GNUPLOT_COMMAND "gnuplot %i")

;; The extensions an image may have: an SVG first for gnuplot, because it
;; is what the default terminal writes; the others are what texi2any finds
;; on its own.
(define MERMAID_EXTENSIONS '("png" "jpg" "gif" "svg"))
(define GNUPLOT_EXTENSIONS '("svg" "png"))

;; The last line of a mermaid diagram left as source.  It is a mermaid
;; comment, so the source is still a diagram, and the script uses it to
;; tell a diagram from a code sample.
(define MERMAID_SOURCE_MARKER "%% dokgen-mermaid")


;;; PARAMETERS

;; Where diagrams are written, and what renders them.  They are set once
;; around a whole extraction rather than passed through every template:
;; the destination reaches the diagrams from the command, eight calls up
;; the rendering stack, and it is the only thing those calls would add.
(define *diagram-destination* (make-parameter #f))
(define *mermaid-command* (make-parameter DEFAULT_MERMAID_COMMAND))
(define *gnuplot-command* (make-parameter DEFAULT_GNUPLOT_COMMAND))


;;; PROCEDURES

(define (diagram-language line)
  "Return the language of the fence on LINE, or @code{#false}.

  @strong{line} (string):
    One line of a documentation string.

  @strong{Return value} (string or @code{#false}):
    @samp{mermaid}, @samp{gnuplot}, or @code{#false} when the line is
    not a fence dokgen reads.  A closing fence names no language and is
    not an opening one."
  (let [(trimmed (string-trim-both line))]
    (and (string-prefix? FENCE_OPEN trimmed)
         (let [(language (string-trim-both
                          (substring trimmed (string-length FENCE_OPEN))))]
           (and (member language DIAGRAM_LANGUAGES)
                language)))))

(define (closing-fence? line)
  "Return @code{#t} when @var{line} closes a diagram."
  (string=? FENCE (string-trim-both line)))

(define (opens-verbatim line)
  "Return the name of the Texinfo block @var{line} opens, or @code{#f}.

  A diagram written inside one of these quotes the syntax instead of
  drawing it: a reader of a docstring that shows how to write a diagram
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
    Every item is either @code{(text . STRING)} or
    @code{(diagram LANGUAGE SOURCE)}, in the order they are written.  A
    fence that is never closed stays prose, because a docstring with a
    typo in it should still reach the reader, and so does one written
    inside a Texinfo block that quotes it."
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
     [(diagram-language (first lines))
      => (lambda (language)
           (call-with-values (lambda () (take-diagram (cdr lines)))
             (lambda (diagram rest)
               (if diagram
                   (loop rest '()
                         (cons (list 'diagram language (string-join diagram "\n"))
                               (add-prose prose blocks))
                         #false)
                   ;; The fence never closes, so the whole tail is prose.
                   (loop '() (append (reverse lines) prose) blocks #false)))))]
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
    The diagram's own text.

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

(define (diagram-command language)
  "Return the renderer configured for @var{language}."
  (cond
   [(string=? language "mermaid") (*mermaid-command*)]
   [(string=? language "gnuplot") (*gnuplot-command*)]
   [else ""]))

(define (diagram-extensions language)
  "Return the image extensions @var{language} may have written."
  (if (string=? language "gnuplot") GNUPLOT_EXTENSIONS MERMAID_EXTENSIONS))

(define (source-extension language)
  "Return the extension the diagram's own source is written with."
  (if (string=? language "gnuplot") "gp" "mmd"))

(define (executable? program)
  "Return @code{#t} when PROGRAM names something that can be run.

  A renderer that is not installed is not an error: the diagram is left as
  source.  A path is looked at as a path, and a bare name is looked for on
  @var{PATH}, the same order a shell uses."
  (if (string-contains program file-name-separator-string)
      (file-exists? program)
      (let [(path (getenv "PATH"))]
        (and path
             (any (lambda (directory)
                    (file-exists? (in-vicinity directory program)))
                  (string-split path #\:))))))

(define (render! command language source-file base)
  "Render the diagram in @var{source-file} to @var{base}, without extension.

  @strong{command} (string):
    The renderer, split on whitespace and run without a shell, so a path
    in it is a path and not something a shell could read.  @code{%i} is
    replaced by the source and @code{%o} by @var{base}.

  @strong{Result}:
    The renderer is run when its program is on @var{PATH}; a failure is
    reported and not raised, because a diagram that could not be drawn is
    still a diagram that can be read as source.  A program that is not
    installed is skipped in silence for the same reason."
  (let [(program (first (string-tokenize command)))]
    (when (and program (executable? program))
      (let [(arguments
             (map (lambda (word)
                    (string-replace-substring
                     (string-replace-substring word "%i" source-file)
                     "%o" base))
                  (string-tokenize command)))]
        (unless (and (pair? arguments)
                     (false-if-exception (zero? (apply system* arguments))))
          (format (current-error-port)
                  "warning: the ~a renderer failed on ~a: ~a~%"
                  language source-file command))))))

(define (gnuplot-string text)
  "Return TEXT quoted as a gnuplot string."
  (string-append "\""
                 (string-replace-substring
                  (string-replace-substring text "\\" "\\\\")
                  "\"" "\\\"")
                 "\""))

(define (gnuplot-wrapper source-file base)
  "Return a gnuplot script that draws SOURCE-FILE to BASE.svg.

  The source a project commits says what is plotted; the terminal and the
  output path belong to the run and are written here, so the same source
  draws the same picture on any machine."
  (format #f "set terminal svg size 900,520 background transparent~%set output ~a~%load ~a~%"
          (gnuplot-string (string-append base ".svg"))
          (gnuplot-string source-file)))

(define (image-extension base extensions)
  "Return the extension of the image that exists under @var{base}, or #f."
  (find (lambda (extension) (file-exists? (format #f "~a.~a" base extension)))
        extensions))

(define (diagram-file language source stem destination)
  "Write @var{source} as a diagram, and return its image's path, or #f.

  @strong{language} (string):
    @samp{mermaid} or @samp{gnuplot}.

  @strong{source} (string):
    The diagram's own text.

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
         (source-file (format #f "~a.~a" base (source-extension language)))
         (command (diagram-command language))]
    (save source source-file)
    (when (and command (not (string-null? command)))
      (if (string=? language "gnuplot")
          (let [(wrapper (string-append base ".render.gp"))]
            (save (gnuplot-wrapper source-file base) wrapper)
            (render! command language wrapper base)
            (false-if-exception (delete-file wrapper)))
          (render! command language source-file base)))
    (and=> (image-extension base (diagram-extensions language))
           (lambda (extension) (format #f "diagrams/~a.~a" stem extension)))))

(define (image-stexi path language)
  "Return the stexi that shows the image at @var{path}.

  @strong{path} (string):
    The image's path, relative to the Texinfo file that references it.

  @strong{language} (string):
    What drew it, so that a reader who does not see the image knows what
    it would have been.

  @strong{Return value} (stexi):
    An @code{@@image} node.  The extension is left out of the file name,
    because Texinfo searches the extensions its writers know; SVG is the
    exception, and is named in the command's last argument."
  (let* [(dot (string-rindex path #\.))
         (extension (and dot (string-downcase (substring path (+ 1 dot)))))
         (file (if dot (substring path 0 dot) path))
         (alt-text (format #f "~a diagram"
                           (if (string=? language "gnuplot") "Gnuplot" "Mermaid")))]
    (if (and extension (string=? extension "svg"))
        `(image (% (file ,file) (alt-text ,alt-text) (extension "svg")))
        `(image (% (file ,file) (alt-text ,alt-text))))))

(define (diagram-source language source)
  "Return the stexi that shows a diagram @var{source} no image was made of.

  A mermaid diagram is marked for the script, which draws it in the page;
  a reader without JavaScript, and every Info or print reader, sees the
  source.  A gnuplot diagram is left as source: the picture is made by
  gnuplot, not by a browser."
  (if (string=? language "mermaid")
      (list '(para "Mermaid diagram:")
            `(example ,(format #f "~a~%~a"
                               (string-trim-right source #\newline)
                               MERMAID_SOURCE_MARKER)))
      (list '(para "Gnuplot diagram, as source:")
            `(example ,source))))

(define (diagram-stexi language source owner)
  "Return the stexi nodes that show the diagram @var{source}.

  @strong{language} (string):
    @samp{mermaid} or @samp{gnuplot}.

  @strong{source} (string):
    The diagram's own text.

  @strong{owner} (string):
    What holds the diagram; see @code{diagram-stem}.

  @strong{Return value} (list of stexi):
    One node holding the image, in a paragraph of its own because Texinfo
    writes an image inline where it stands, or the diagram's source and a
    line that says what it is when no image could be made."
  (let* [(destination (*diagram-destination*))
         (image (and destination
                     (diagram-file language source
                                   (diagram-stem owner source)
                                   destination)))]
    (if image
        (list (list 'para (image-stexi image language)))
        (diagram-source language source))))
