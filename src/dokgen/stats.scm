;; guile-dokgen --- what a project is made of
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| This module measures a tree: how much of it is code, how much of that
code branches, who wrote it, and which files cost the most to keep.

What it reports is a small set of numbers a reader can reproduce.  The
lines of code, of comment and the bytes come from the files themselves;
the decision points are the branching forms a reader can find with a
search; the authors and the churn come from the repository's own history.
Nothing here guesses, and nothing here grades: a file with many decision
points is a file that branches often, not a file that is badly written.

@example
(analyze-source "(display x)\n")
;; => ((blank . 0) (comment . 0) (code . 1) (decisions . 0))
@end example

The parsers are separate from the calls that feed them, so the suite that
checks a log can hand over a log written by hand instead of building a
repository. |#

;;; Code:

(define-module (dokgen stats)
  #:use-module (ice-9 format)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (srfi srfi-19)
  #:export (analyze-source
            analyze-file
            project-stats
            git-log
            parse-git-log
            git-stats))


;;; CONSTANTS

;; The forms that make a program take more than one path through it.
(define DECISION-FORMS '("if" "cond" "case" "when" "unless" "do"))

;; An opening parenthesis, one of those forms, and the character that has
;; to follow it for the form to be a form and not the start of a longer
;; name such as `case-lambda'.
(define DECISION-REGEXP
  (make-regexp (format #f "\\(~a[][() \t\n]"
                       (string-join DECISION-FORMS "|"))))

;; Where each commit starts in the log this module asks git for: a marker
;; no line of a numstat can begin with, the abbreviated commit, the
;; author's name and the commit time in seconds.
(define GIT-LOG-MARKER "@@")

(define GIT-LOG-FORMAT "@@%h%x09%aN%x09%at")

;; What `git log --numstat' prints for a file: two counts and a path, or
;; two dashes for a file whose lines git cannot count.
(define NUMSTAT-REGEXP (make-regexp "^([0-9]+|-)\t([0-9]+|-)\t(.*)$"))


;;; PROCEDURES

(define (strip-comments text)
  "Return @var{text} with the characters of its comments turned into spaces.

  Newlines are kept, so a line of the result is the line with the same
  number in @var{text}.  Block comments nest, as they do in Scheme, and a
  semicolon inside a string is part of the string.

  @strong{text} (string):
    Scheme source.

  @strong{Return value} (string):
    The code of @var{text}, with everything a reader would call a comment
    replaced by whitespace."
  (let [(length (string-length text))]
    (let loop [(index 0) (in-string? #false) (depth 0) (characters '())]
      (if (>= index length)
          (list->string (reverse characters))
          (let* [(character (string-ref text index))
                 (next (and (< (+ index 1) length) (string-ref text (+ index 1))))
                 (escaped? (and in-string? (char=? character #\\)))]
            (cond
             [escaped?
              (loop (+ index 2) in-string? depth
                    (cons (if (char=? character #\newline) #\newline #\space)
                          (cons #\space characters)))]
             [in-string?
              (loop (+ index 1) (not (char=? character #\")) depth
                    (cons character characters))]
             [(and (char=? character #\#) next (char=? next #\|))
              (loop (+ index 2) #false (+ depth 1) (cons* #\space #\space characters))]
             [(and (> depth 0) (char=? character #\|) next (char=? next #\#))
              (loop (+ index 2) #false (- depth 1) (cons* #\space #\space characters))]
             [(> depth 0)
              (loop (+ index 1) #false depth
                    (cons (if (char=? character #\newline) #\newline #\space)
                          characters))]
             [(char=? character #\")
              (loop (+ index 1) #true depth (cons character characters))]
             [(char=? character #\;)
              (let skip [(index index)]
                (if (or (>= index length) (char=? (string-ref text index) #\newline))
                    (loop index #false depth characters)
                    (skip (+ index 1))))]
             [else (loop (+ index 1) #false depth (cons character characters))]))))))

(define (strip-strings text)
  "Return @var{text} with the characters of its strings turned into spaces.

  @strong{text} (string):
    Scheme source, with its comments already stripped.

  @strong{Return value} (string):
    The structure of @var{text} without the words a reader would call
    data: a branch form written inside a string is not a branch."
  (let [(length (string-length text))]
    (let loop [(index 0) (in-string? #false) (characters '())]
      (if (>= index length)
          (list->string (reverse characters))
          (let [(character (string-ref text index))]
            (cond
             [(and in-string? (char=? character #\\))
              (loop (+ index 2) #true (cons* #\space #\space characters))]
             [in-string? (loop (+ index 1) (not (char=? character #\"))
                               (cons #\space characters))]
             [(char=? character #\") (loop (+ index 1) #true (cons #\space characters))]
             [else (loop (+ index 1) #false (cons character characters))]))))))

(define (code-of text)
  "Return the code of @var{text}, without comments and without strings."
  (strip-strings (strip-comments text)))

(define (count-decisions code)
  "Return the number of decision points in @var{code}.

  @strong{code} (string):
    Scheme source with no comments and no strings.

  @strong{Return value} (integer):
    How often one of the branching forms is opened.  It counts shapes and
    not paths: a reader can check every one of them with a search, which
    is what makes it worth reporting."
  (let loop [(start 0) (count 0)]
    (let [(found (regexp-exec DECISION-REGEXP code start))]
      (if found
          (loop (match:end found) (+ count 1))
          count))))

(define (lines-of text)
  "Return the lines of @var{text}, without the empty one a final newline makes.

  @strong{text} (string):
    Any text.

  @strong{Return value} (list of strings):
    One element per line, so that counting them counts lines."
  (let [(lines (string-split text #\newline))]
    (if (and (string-suffix? "\n" text) (pair? lines))
        (drop-right lines 1)
        lines)))

(define (blank? line)
  "Return @code{#true} when @var{line} holds nothing but whitespace."
  (string-null? (string-trim-both line)))

(define (count-lines text)
  "Return how many lines of @var{text} are blank, comment and code.

  @strong{text} (string):
    Scheme source.

  @strong{Return value} (alist):
    The counts, in the order @code{blank}, @code{comment}, @code{code}
    and @code{decisions}."
  (if (string-null? text)
      '((blank . 0) (comment . 0) (code . 0) (decisions . 0))
      (let* [(code (code-of text))
             (without-comments (strip-comments text))
             (source-lines (lines-of text))
             (code-lines (lines-of code))
             (comment-lines (lines-of without-comments))]
        `((blank . ,(count blank? source-lines))
          ;; A line that held nothing but a comment is a comment line; one
          ;; that held nothing at all was counted as blank above.
          (comment . ,(count (lambda (pair) (and (not (blank? (car pair)))
                                                 (blank? (cdr pair))))
                             (map cons source-lines comment-lines)))
          (code . ,(count (lambda (line) (not (blank? line))) code-lines))
          (decisions . ,(count-decisions code))))))

(define (analyze-source text)
  "Return what @var{text} is made of.

  @strong{text} (string):
    Scheme source.

  @strong{Return value} (alist):
    Lines of code, of comment and of nothing, and the decision points the
    code holds; see @code{count-lines}."
  (count-lines text))

(define (analyze-file path)
  "Return what the file at @var{path} is made of.

  @strong{path} (string):
    A path to a file of Scheme source.

  @strong{Return value} (alist):
    Its name, the counts of @code{analyze-source} and its size in bytes."
  (let [(text (call-with-input-file path get-string-all))
        (size (stat:size (stat path)))]
    `((name . ,path)
      ,@(analyze-source text)
      (bytes . ,size))))

(define (project-stats files)
  "Return the totals of @var{files} and the files in the order to show them.

  @strong{files} (list of alists):
    What @code{analyze-file} returns for each file of the project.

  @strong{Return value} (alist):
    @code{files}, largest first and then by name, and the totals of the
    lines, the decision points and the bytes."
  (define (larger-first? a b)
    (let [(left (assoc-ref a 'code))
          (right (assoc-ref b 'code))]
      (or (> left right)
          (and (= left right)
               (string<? (assoc-ref a 'name) (assoc-ref b 'name))))))
  (let* [(sorted (sort files larger-first?))
         (total (lambda (key)
                  (reduce + 0 (map (lambda (file) (assoc-ref file key)) sorted))))]
    `((files . ,sorted)
      (blank . ,(total 'blank))
      (comment . ,(total 'comment))
      (code . ,(total 'code))
      (decisions . ,(total 'decisions))
      (bytes . ,(total 'bytes)))))

(define (git-log directory)
  "Return the history of @var{directory} as git prints it, or @code{#false}.

  @strong{directory} (string):
    A path inside a repository; git finds the repository above it.

  @strong{Return value} (string or @code{#false}):
    What @command{git log} prints for the commits that touch the tree, one
    line per commit and one per file it touched, or @code{#false} when git
    could not read one.  It is run without a shell, so a directory is a
    path and not something a shell could read."
  (let [(port (false-if-exception
               (open-pipe* OPEN_READ "git" "-C" directory
                           "--no-pager" "log" "--no-merges" "--use-mailmap"
                           "--numstat" (format #f "--format=~a" GIT-LOG-FORMAT))))]
    (if (not port)
        #false
        (let [(text (get-string-all port))]
          (and (zero? (close-pipe port)) text)))))

(define (timestamp->date seconds)
  "Return the UTC date of @var{seconds}, as 2026-11-21.

  UTC and not the machine's timezone: a report written on one machine and
  regenerated on another must date the same commit the same way."
  (date->string (time-utc->date (make-time time-utc 0 seconds) 0) "~Y-~m-~d"))

(define (bump table key added removed)
  "Return @var{table} with @var{added} and @var{removed} added under @var{key}."
  (let* [(entry (or (assoc key table) (cons key '(0 0))))
         (totals (list (+ (second entry) added) (+ (third entry) removed)))]
    (cons (cons key totals)
          (remove (lambda (other) (equal? (car other) key)) table))))

(define (numstat line)
  "Return the counts and the path of a numstat LINE, or @code{#false}.

  A binary file is printed as two dashes, because git cannot count what a
  binary file adds: it is reported as @code{#false} and left out."
  (let [(found (regexp-exec NUMSTAT-REGEXP line))]
    (and found
         (not (string=? (match:substring found 1) "-"))
         (list (string->number (match:substring found 1))
               (string->number (match:substring found 2))
               (match:substring found 3)))))

(define (parse-git-log text)
  "Return the history in @var{text} as the numbers a report needs.

  @strong{text} (string):
    The output @code{git-log} returns.

  @strong{Return value} (alist or @code{#false}):
    The commits, the newest of them, the oldest and the newest dates, and
    what each author and each file cost, largest first.  @code{#false}
    when there is no history in @var{text}."
  (define (cost entry) (+ (second entry) (third entry)))
  (define (largest-first entries)
    (sort entries
          (lambda (a b)
            (let [(left (cost a))
                  (right (cost b))]
              (or (> left right)
                  (and (= left right) (string<? (car a) (car b))))))))
  (let loop [(lines (lines-of text))
             (commits 0)
             (newest #false)
             (newest-date #false)
             (oldest-date #false)
             (authors '())
             (files '())
             (author #false)]
    (cond
     [(null? lines)
      (and (> commits 0)
           `((commits . ,commits)
             (commit . ,newest)
             (last . ,newest-date)
             (first . ,oldest-date)
             (authors . ,(largest-first authors))
             (files . ,(largest-first files))))]
     [(string-prefix? GIT-LOG-MARKER (first lines))
      (let* [(header (string-split
                      (substring (first lines) (string-length GIT-LOG-MARKER))
                      #\tab))
             (date (timestamp->date (string->number (third header))))]
        (loop (cdr lines) (+ commits 1)
              (if newest newest (first header))
              (if newest-date newest-date date)
              date
              authors files (second header)))]
     [(and author (numstat (first lines)))
      => (lambda (field)
           (loop (cdr lines) commits newest newest-date oldest-date
                 (bump authors author (first field) (second field))
                 (bump files (third field) (first field) (second field))
                 author))]
     [else (loop (cdr lines) commits newest newest-date oldest-date
                 authors files author)])))

(define (git-stats directory)
  "Return the numbers of the history of @var{directory}, or @code{#false}.

  @strong{directory} (string):
    A path inside a repository.

  @strong{Return value} (alist or @code{#false}):
    What @code{parse-git-log} returns, or @code{#false} when the tree has
    no history git can read."
  (and=> (git-log directory) parse-git-log))
