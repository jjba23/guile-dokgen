;; guile-dokgen --- API documentation for GNU Guile Scheme projects.
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:
;;
;; This is guile-dokgen's Maak file, and it follows the two rules the other
;; Maak files in the collection follow.
;;
;; The *exports* are the task list.  Maak runs every procedure a file defines
;; when the file declares no exports, and only the exported ones when it does,
;; so the helpers below stay helpers and `maak' lists the commands rather than
;; the plumbing.
;;
;; Every task runs inside `guix time-machine -C channels.scm -- shell -m
;; manifest.scm', through `time-machine-manifest-shell': the Guix revision is
;; pinned, so a task means the same thing on every machine and a year from now.
;; That procedure joins its words into one command line, so anything that must
;; survive as one word -- a Scheme expression, a script -- is quoted with
;; `shell-quote'.

(define-module (maak)
  #:declarative? #t
  #:use-module (maak maak)
  #:use-module ((ice-9 rdelim) #:select (read-line))
  ;; `git' is the command, and the prefix says so at every call site.
  #:use-module ((maak git) #:prefix git:)
  #:use-module (ice-9 format)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 string-fun)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:export (help
            version
            default
            test
            check
            version-check
            docs
            docs-check
            manual
            deploy
            repl
            install
            uninstall
            clean
            release
            agents))

;; ====== Maak file constants ======

(define version-file
  "src/dokgen/cli.scm")

;; The stylesheet the HTML manual is rendered with: the jointhefreeworld one,
;; so the manual looks like the rest of the collection.
(define manual-css-url
  "https://jointhefreeworld.org/static/css/jointhefreeworld.css")

(define manual-dist
  "reports/manual")

;; Where the project page is published.  jointhefreeworld.org serves
;; /srv/http/<name> as https://<name>/, and the collection's projects live in
;; a directory each, so publishing the page is putting a directory there.
(define deploy-directory
  "/srv/http/jointhefreeworld.org/dokgen")

;; ====== Maak file helpers ======

(define (run-script script)
  "Run SCRIPT with `sh -c' inside the manifest shell.

The shell is handed the script as one word, so the script keeps its pipes, its
`;' and its quoting instead of being split on them."
  (time-machine-manifest-shell (list "sh" "-c" (shell-quote script))
                               #:verbose? #t))

(define (current-version)
  "Return the version `src/dokgen/cli.scm' states."
  (let* ((text (call-with-input-file version-file get-string-all))
         (found (string-match "\\(version \"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\)" text)))
    (unless found
      (task-error "~a does not state a version" #:args (list version-file)))
    (match:substring found 1)))

(define (valid-version? version)
  "Return @code{#t} when @var{version} is numbered like 0.5.0."
  (and (string? version)
       (string-match "^[0-9]+\\.[0-9]+\\.[0-9]+$" version)
       #t))

;; ====== Maak file tasks ======

(define (help)
  "Display maak's help screen."
  (time-machine-program-shell (list "maak" "--help")))

(define (default)
  "List the tasks this project defines."
  (list-tasks))

(define (version)
  "Print the version this checkout states."
  (format #t "guile-dokgen ~a~%" (current-version)))

(define (test)
  "Run every test file under tests/.

SRFI-64 never turns a failure into an exit status, so each file goes through
`etc/run-test.scm', which does.  The `test-module-*' files are fixtures the
suites document, not suites."
  (run-script
   "set -eu
status=0
for file in tests/test-*.scm; do
  case $file in tests/test-module-*) continue ;; esac
  guile -L ./src -L . etc/run-test.scm \"$file\" || status=1
done
rm -f ./*.log
exit $status"))

(define (check)
  "Compile every source and test module, so a syntax error fails the build.

Each file is compiled on its own, which is what makes one broken file name
itself rather than a pile of them."
  (run-script
   (~ "set -eu\nexport GUILE_LOAD_PATH='./src:.:$GUILE_LOAD_PATH'\nfind src tests etc -name '*.scm' -print0 "
      "| xargs -0 -n 1 sh -c 'guild compile -o \"$(mktemp)\" \"$1\"' sh")))

(define (docs)
  "Regenerate the API reference, manual/api/index.texi, from the sources.

The program documents itself: the reference is not written by hand, and a
procedure that is exported is in it."
  (time-machine-manifest-shell
   (list "guile" "-L" "./src" "bin/dokgen" "api" "--destination" "manual/api"
         "./src/dokgen")
   #:verbose? #t))

(define (docs-check)
  "Fail when manual/api/index.texi is not what the sources generate.

The reference is generated, so a committed copy that differs from a fresh one
is a procedure that was changed without the documentation following."
  (docs)
  (git:git (list "diff" "--exit-code" "--" "manual/api")))

(define (manual)
  "Build the HTML manual into reports/manual."
  (run (list "mkdir" "-p" manual-dist))
  (time-machine-manifest-shell
   (list "makeinfo" "--html" (~ "--css-ref=~a" manual-css-url)
         "-c" "SHOW_TITLE=true" "-o" manual-dist "manual/main.texi")
   #:verbose? #t)
  (log-info "open file://~a/~a/index.html" (getcwd) manual-dist))

(define (deploy)
  "Build the manual and publish it, with the project page, to the web directory.

Deployment is a copy, the way the rest of jointhefreeworld.org is deployed: the
directory is emptied and the fresh build is put in its place, so a file this
build does not have does not linger beside the one that replaced it.  The build
is removed afterwards; what the tree keeps is the source."
  (manual)
  (log-info "publishing the page and the manual to ~a" deploy-directory)
  (delete-file-recursively deploy-directory)
  (cp "website" deploy-directory)
  (cp manual-dist (~ "~a/manual" deploy-directory))
  (delete-file-recursively manual-dist))

(define (repl)
  "A REPL with the library and the tests on the load path."
  (time-machine-manifest-shell (list "guile" "-L" "./src" "-L" ".")
                               #:verbose? #t))

;;; --- installing ---
;;;
;;; The launcher finds its modules relative to itself, so the tree is installed
;;; rather than only copied: bin/dokgen lands in $(prefix)/bin and the
;;; library in $(prefix)/share/guile/site/3.0.  A prefix the user owns needs no
;;; escalation.

(define (needs-sudo? prefix)
  "Return @code{#t} when @var{prefix} is not one this user can write."
  (not (or (string-prefix? (home-dir) prefix)
           (string-prefix? "/tmp" prefix))))

(define (install)
  "Install the library and the launcher under $(prefix)."
  (let* ((prefix (or (getenv "PREFIX") "/usr/local"))
         (site (~ "~a/share/guile/site/3.0" prefix))
         (bin (~ "~a/bin" prefix))
         (sudo? (needs-sudo? prefix)))
    (run (list "install" "-d" site bin) #:sudo? sudo? #:verbose? #t)
    (run (list "cp" "-r" "src/dokgen" site) #:sudo? sudo? #:verbose? #t)
    (run (list "install" "-m" "755" "bin/dokgen" bin)
         #:sudo? sudo? #:verbose? #t)))

(define (uninstall)
  "Remove what `install' put under $(prefix)."
  (let* ((prefix (or (getenv "PREFIX") "/usr/local"))
         (site (~ "~a/share/guile/site/3.0/dokgen" prefix))
         (bin (~ "~a/bin/dokgen" prefix)))
    (run (list "rm" "-rf" site bin)
         #:sudo? (needs-sudo? prefix) #:verbose? #t)))

(define (clean)
  "Remove build artefacts."
  (delete-file-recursively "reports"))

;;; --- releasing ---
;;;
;;; The version is stated once, in the command-line specification, and quoted
;;; everywhere a reader meets it: the manual's `@set VERSION', the README badge
;;; and the website.  A release rewrites the number inside a shape it knows and
;;; touches nothing else -- prose that happens to contain a number is not a
;;; version -- and `maak version-check' fails when a quotation has drifted, so
;;; CI notices before a reader does.  The package definition reads the number
;;; from the source and keeps no copy.

;; Each entry is a file and the shape the number takes in it.
(define version-quotations
  '(("src/dokgen/cli.scm" . "(version \"~a\")")
    ("manual/main.texi" . "@set VERSION ~a")
    ("README.org" . "release-~a")
    ("website/index.html" . "v~a")))

(define (quotation-text file)
  "Return the text of FILE, or fail closed when it cannot be read."
  (unless (file-exists? file)
    (task-error "~a quotes the version but does not exist" #:args (list file)))
  (call-with-input-file file get-string-all))

(define (write-version! old new)
  "Write NEW over OLD in every file that quotes the version.

A file that does not quote OLD in the shape listed is an error rather than a
silent skip: a quotation that was not rewritten is the inconsistency this
exists to prevent."
  (for-each
   (lambda (entry)
     (let* ((file (car entry))
            (text (quotation-text file))
            (from (format #f (cdr entry) old))
            (to (format #f (cdr entry) new)))
       (unless (string-contains text from)
         (task-error "~a does not quote ~s" #:args (list file from)))
       (call-with-output-file file
         (lambda (port) (display (string-replace-substring text from to) port)))))
   version-quotations))

(define (version-check)
  "Fail when a file quotes a version other than the one the source states."
  (let ((current (current-version)))
    (for-each
     (lambda (entry)
       (let ((expected (format #f (cdr entry) current)))
         (unless (string-contains (quotation-text (car entry)) expected)
           (task-error "~a does not quote ~s; run `maak release VERSION'"
                       #:args (list (car entry) expected)))))
     version-quotations)
    (log-info "version ~a is consistent in ~a files"
              current (length version-quotations))))

(define (release . args)
  "Cut a release: write the version, run the gates, commit and tag.

With a version, write it into every file that quotes it, run `version-check',
`check' and `test',
commit everything tracked as `chore(release): vX.Y.Z' and tag that commit
`vX.Y.Z'.  The gates run before the commit, so a release that would have been
broken is never tagged.  A version that is already tagged is refused.

With no argument, say what the current version is and change nothing."
  (let ((current (current-version))
        (requested (and (pair? args) (car args))))
    (cond
     ((null? args)
      (format #t "guile-dokgen ~a~%~%To release: maak release VERSION~%"
              current))
     ((not (valid-version? requested))
      (task-error "~s is not a version; a release is numbered like 0.5.0"
                  #:args (list requested)))
     (else
      (let ((tag (~ "v~a" requested)))
        (when (member tag (git:git-tags))
          (task-error "~a is already a tag; bump the version first"
                      #:args (list tag)))
        (log-info "release: ~a -> ~a" current requested)
        (write-version! current requested)
        (version-check)
        (check)
        (test)
        (git:git (list "add" "--all"))
        (let ((staged (string-trim-both
                       (git:git-output (list "diff" "--cached" "--name-only")))))
          (if (string-null? staged)
              (log-info "release: nothing to commit")
              (git:git (list "commit" "--message"
                             (~ "chore(release): v~a" requested))))
          (git:git (list "tag" "--annotate" tag "--message"
                         (~ "guile-dokgen ~a" requested)))
          (log-info "A tag nobody has fetched is not a release yet:~%  git push origin trunk --follow-tags")))))))

;; ====== Agent skills ======

;; AGENTS.md is generated, never edited by hand.  The section has two halves:
;; the data below, which is this project's, and the task itself, which is not.
;; Another repository copies the whole section and replaces the data - the
;; header, the pinned skills (repository, commit, path, licence) and the
;; practices - and `maak agents' writes its own AGENTS.md.  Regeneration is
;; deterministic: the same pins and the same text produce the same file, byte
;; for byte, and it needs nothing but curl.  The skill URLs assume GitHub, so a
;; skill hosted elsewhere needs a URL of its own.

(define ponytail-commit
  "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846")

(define tdd-commit
  "22f0b463e7a5e579904dd6211a520321035526f7")

;; Name, repository, commit, the path the repository keeps the skill at and the
;; licence.  A skill arrives whole: trimming it means scanning for headings, and
;; such a scan cannot tell a heading from a `##' line inside a code fence.
(define agent-skills
  (list (list "ponytail"
              "DietrichGebert/ponytail"
              ponytail-commit
              "skills/ponytail/SKILL.md"
              "MIT")
        (list "test-driven-development"
              "obra/superpowers"
              tdd-commit
              "skills/test-driven-development/SKILL.md"
              "MIT")))

(define agent-skills-dir
  "reports/agent-skills")

(define agents-header
  "# AGENTS.md

Generated by `maak agents` from the pinned skills and the practices in
`maak.scm`; edit that task, never this file.  The pins and the text are the whole
input, so regenerating gives the same document.  The repository's own rules win
over general advice, and the narrowest rule here wins over the broadest.
")

;; Practices this project keeps.  They are short on purpose: a rule a reader
;; checks in a second is a rule that gets followed.  The pinned skills are the
;; long form of the same habits.
(define agent-practices
  (list
   "## Documentation

- Every user-visible change reaches the documentation: the chapter of the
  manual that owns the feature, the CLI reference for a flag, and the version
  history in `manual/main.texi` and `CHANGELOG.org` under the unreleased
  heading.
- The manual is Texinfo: `manual/main.texi` is written by hand, and
  `manual/api/index.texi` is generated by `maak docs` and never edited.
- Keep the menu in step with the nodes.  A node with no menu entry is a node
  nobody finds.
- Explain why and when, never what: the code already says what.  A docstring's
  first line works as a summary on its own.
- Spell an identifier the way the code spells it - the exact name, not a
  description of it.
- An example must run as written, copied from a real invocation.
- No promises about the future and no changelog in the manual's chapters;
  history lives in the version history and the changelog.
"
   "## Security

- No secrets in the tree.  Tokens, keys and passwords arrive through the
  environment, and no recipe, workflow or example embeds one.
- Validate at the edge: anything from a file, a report, a path or a subprocess
  is untrusted until it has been checked.
- Never build a shell string out of data.  Tasks pass argument lists, and Guile
  calls `(system \"program\" \"arg\")` or `open-pipe*`, never a command
  assembled with `string-append`.
- Do not `eval` or `read` input you did not write; parse with `(json)` or a
  reader built for the format.
- Escape what leaves the process: a name that came from input is escaped when
  it is written to XML, HTML or a data file.
- Fail closed.  A file that cannot be read is an error, not an empty result.
- Input never chooses the path of a written file; writes stay inside the
  directory reserved for them.
- A dependency is a security decision: it must be needed, MIT compatible and
  pinned.
- Report a vulnerability privately, not in a public issue.
"
   "## Performance

- Measure first.  A before and after belongs in the benchmark, and a speedup
  claimed without a number is not a speedup.
- Prefer not doing the work: cache it, skip it, batch it, or delete the call,
  before making the call faster.
- Then the algorithm, then the data structure (hash table, vector), then the
  micro-optimisation.  In that order, for that reason.
- Guile specifics: keep module resolution and long `assoc` chains out of loops,
  use `#:declarative?` modules and compiled `.go` files at startup, and reach
  for `statprof` instead of guessing where the time goes.
- A shortcut that buys speed costs clarity; it gets a measurement and a
  `shortcut:` comment saying what it costs and when to revisit it.
- Coverage instrumentation is slow by design: iterate without it, and measure
  before finishing.
"
   "## Architecture decisions

- A decision that is expensive to reverse gets a short record: the context, the
  decision, the consequences, and the alternatives that lost.  A small decision
  belongs in the commit body instead.
- Two paragraphs beat a design document; record the choice while it is still a
  choice, not after it has become a fact.
- An accepted record is not rewritten.  Supersede it with a new one and link the
  two directions.
- The record lives next to its subject: the documentation for anything a user
  would notice, the release notes for the release-level result.
- Changes to the public API, a file format, the pipeline or the licence get this
  treatment at a minimum in the commit body.
"
   "## Semantic versioning

- The project follows SemVer 2.0.0 for its public API: the exported functions,
  the CLI flags and environment variables, and the shape of its file formats.
- A breaking change bumps MAJOR, a new feature MINOR, a fix PATCH.  A new export
  is MINOR; removing or changing one is MAJOR.
- One version string, named everywhere it appears: the source, the build
  recipes, the manual page and the packaging.
- A release is a dated release-notes section, an annotated `vX.Y.Z` tag on the
  release commit, and a packaging checksum updated afterwards from the published
  archive.
"
   "## Conventional commits

- `type(scope): summary`, imperative, lower case, no full stop, about seventy
  characters.
- Types in use: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
  `chore`.  A `!` after the type or a `BREAKING CHANGE:` footer marks a MAJOR
  change, and says what breaks.
- The subject says what changed.  The body says why, and what was rejected.
- One logical change per commit: a refactor and a fix travel apart, so either
  can be reverted alone.
- Run the full validation task before committing, and never commit a red suite
  without saying so in the message.
- Reference the issue in the footer - `Closes #12` - not in the subject.
"
   "## Functional programming and immutability

- Pure functions in the core, effects at the edges.  Whatever touches the file
  system or the clock sits at the edge; the core does not.
- Prefer `let` and new values to `set!`.  Build results with `map`, `filter`,
  `fold` and named `let`, not with index loops that push into a list.
- A record is a value: construct a new one instead of mutating a shared one, and
  pass configuration as arguments or parameters rather than as globals.
- Handle an exception at the boundary: catch it there, turn it into a result
  record, and let the caller decide what it means.
- A function that both computes and prints is two functions.
- Temporary effects - a changed directory, a bound environment variable - go
  through `dynamic-wind`.
- Prefer the expression style: `if` and `cond` that return a value, not a branch
  that assigns one.
"
   "## Do not reinvent the wheel

- Guile's standard library first: `(ice-9 ...)` for the runtime, `(srfi srfi-1)`
  for lists, `(srfi srfi-9)` for records, `(srfi srfi-13)` for strings, `(json)`
  for JSON.  The project already depends on all of them.
- Then this codebase: read the existing modules before writing a helper, and use
  the one that is nearly right instead of adding a second one.
- A new dependency needs a reason the standard library cannot meet, a licence
  the project can carry, and a paragraph in the commit body.
- Prefer deleting a special case to writing code that handles it.
- The best diff removes lines and keeps the behaviour; the second best is a
  small diff that is obvious a year later.
"))

(define (slurp path)
  "Return the whole of @var{path} as a string."
  (call-with-input-file path
    (lambda (port)
      (let loop ((lines '())
                 (line (read-line port)))
        (if (eof-object? line)
            (string-concatenate-reverse lines)
            (loop (cons (string-append line "\n") lines)
                  (read-line port)))))))

(define (fetch-skill name repository commit path)
  "Download one skill pinned at @var{commit}, into the reports tree.

  Returns the skill's text."
  (let ((target (~ "~a/~a.md" agent-skills-dir name))
        (url (~ "https://raw.githubusercontent.com/~a/~a/~a"
                repository commit path)))
    (run (list "curl" "--fail" "--silent" "--show-error" "--location"
               "--output" target url)
         #:verbose? #t)
    (slurp target)))

(define (agents)
  "Regenerate AGENTS.md from the pinned skills and the practices."
  (run (list "mkdir" "-p" agent-skills-dir))
  ;; Every download happens before the file is opened, so a fetch that fails
  ;; leaves the previous AGENTS.md in place rather than a half-written one.
  (let ((skills (map (lambda (skill)
                       (append skill
                               (list (fetch-skill (list-ref skill 0)
                                                  (list-ref skill 1)
                                                  (list-ref skill 2)
                                                  (list-ref skill 3)))))
                     agent-skills)))
    (call-with-output-file "AGENTS.md"
      (lambda (port)
        (display agents-header port)
        (for-each (lambda (skill)
                    (format port
                            "~%## ~a~%~%`~a` at `~a`, `~a`, ~a licensed.~%~%"
                            (list-ref skill 0)
                            (list-ref skill 1)
                            (list-ref skill 2)
                            (list-ref skill 3)
                            (list-ref skill 4))
                    (display (list-ref skill 5) port))
                  skills)
        (for-each (lambda (practice)
                    (newline port)
                    (display practice port))
                  agent-practices)))))
