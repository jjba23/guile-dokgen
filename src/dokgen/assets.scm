;; guile-dokgen --- the stylesheet and the script the chapter is read with
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| A Texinfo chapter is complete without these files, and Info and print
output never see them.  They are what makes the HTML a reader expects
from reference documentation: one index down the side holding the
sections and every definition (a drawer on a phone), a card for each
definition with its signature at the top, a button that copies a
signature, a theme that follows the reader, and diagrams that sit on a
plate of their own.  The index replaces the table of contents texi2any
writes into the body: a page with the same list twice makes a reader
choose, and the list down the side is the one that stays in view.

They are written into the destination beside the chapter, so a manual
that is built with this directory on its include path and these files
beside its pages gets all of it, and a manual that ignores them gets a
chapter that still reads.  The JavaScript is progressive and has no
external dependencies: every feature is one selector away from
disappearing, the body's own table of contents stays where it is when
the script does not run, and the bundled Mermaid renderer is loaded only
when a page carries a diagram whose image was not built with it.

The manual of this project says how a build points at them; `maak manual'
does it. |#

;;; Code:

(define-module (dokgen assets)
  #:use-module (dokgen writer)
  #:export (STYLESHEET
            SCRIPT
            write-assets!))


;;; CONSTANTS

;; The stylesheet, written to @file{dokgen.css} beside the chapter.
(define STYLESHEET
  "/* dokgen.css --- the presentation of an API chapter.
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
 *
 * dokgen writes this file beside the Texinfo chapter it generates.  It
 * turns what texi2any emits into a page of reference documentation: one
 * index down the side with the sections and every definition, a card per
 * definition, a signature that can be copied, a light and a dark page,
 * and diagrams that sit on a plate of their own.
 *
 * Nothing here is required: the chapter is complete Texinfo without it,
 * and Info and print output never see a line of it.  Every rule is either
 * a `dk-' class that the script adds or a selector texi2any is known to
 * emit.
 */

:root {
    --dk-bg: #faf7f2;
    --dk-fg: #232019;
    --dk-muted: #6d6457;
    --dk-card: #fffdf9;
    --dk-signature: #f3ece1;
    --dk-code: #f6f0e6;
    --dk-border: #e3d8c8;
    --dk-accent: #b45309;
    --dk-accent-strong: #8f3f06;
    --dk-accent-soft: rgba(180, 83, 9, 0.10);
    --dk-radius: 8px;
    --dk-sidebar: 17rem;
    --dk-bar: 3.25rem;
    --dk-serif: \"Iowan Old Style\", \"Palatino Linotype\", Palatino, \"Book Antiqua\", Georgia, serif;
    --dk-sans: system-ui, -apple-system, \"Segoe UI\", Roboto, \"Helvetica Neue\", sans-serif;
    --dk-mono: ui-monospace, SFMono-Regular, \"SF Mono\", Menlo, Consolas, monospace;
    --dk-ease: cubic-bezier(0.2, 0.6, 0.3, 1);
    color-scheme: light dark;
}

@media (prefers-color-scheme: dark) {
    :root {
        --dk-bg: #171411;
        --dk-fg: #ece5da;
        --dk-muted: #a99d8c;
        --dk-card: #1e1a15;
        --dk-signature: #272119;
        --dk-code: #241f19;
        --dk-border: #3a3127;
        --dk-accent: #e9a15f;
        --dk-accent-strong: #f1b67f;
        --dk-accent-soft: rgba(233, 161, 95, 0.12);
    }
}

[data-dk-theme=\"light\"] {
    --dk-bg: #faf7f2;
    --dk-fg: #232019;
    --dk-muted: #6d6457;
    --dk-card: #fffdf9;
    --dk-signature: #f3ece1;
    --dk-code: #f6f0e6;
    --dk-border: #e3d8c8;
    --dk-accent: #b45309;
    --dk-accent-strong: #8f3f06;
    --dk-accent-soft: rgba(180, 83, 9, 0.10);
    color-scheme: light;
}

[data-dk-theme=\"dark\"] {
    --dk-bg: #171411;
    --dk-fg: #ece5da;
    --dk-muted: #a99d8c;
    --dk-card: #1e1a15;
    --dk-signature: #272119;
    --dk-code: #241f19;
    --dk-border: #3a3127;
    --dk-accent: #e9a15f;
    --dk-accent-strong: #f1b67f;
    --dk-accent-soft: rgba(233, 161, 95, 0.12);
    color-scheme: dark;
}

html {
    scroll-behavior: smooth;
    scroll-padding-top: calc(var(--dk-bar) + 1.5rem);
    background: var(--dk-bg);
}

@media (prefers-reduced-motion: reduce) {
    html {
        scroll-behavior: auto;
    }

    .dk-index,
    .dk-toggle::before {
        transition: none;
    }
}

/* --- the page before the script builds the index -------------------- */

/* The script adds `dk-has-index' and the rules below take over.  Until
   it runs, and for a reader who never runs it, this is the page: the
   same type and colours, a readable column, and a body table of contents
   with room for its nested levels. */

body:not(.dk-has-index) {
    box-sizing: border-box;
    max-width: 1120px;
    margin: 0 auto;
    padding: 0 clamp(1.1rem, 3vw, 2.8rem) 6rem;
    color: var(--dk-fg);
    background: var(--dk-bg);
    font-family: var(--dk-sans);
    font-size: 1rem;
    line-height: 1.68;
}

body:not(.dk-has-index) h1.top,
body:not(.dk-has-index) h1.settitle,
body:not(.dk-has-index) h2.chapter,
body:not(.dk-has-index) h3.section,
body:not(.dk-has-index) h3.heading,
body:not(.dk-has-index) h4.subsection {
    color: var(--dk-fg);
    font-family: var(--dk-serif);
    font-weight: 600;
    line-height: 1.2;
    letter-spacing: -0.015em;
}

body:not(.dk-has-index) h1.settitle {
    margin: 1.8rem 0 0;
    font-size: clamp(2rem, 4vw, 2.75rem);
}

body:not(.dk-has-index) h1.top,
body:not(.dk-has-index) h2.chapter {
    margin: 2.4rem 0 1rem;
    font-size: clamp(1.8rem, 4vw, 2.4rem);
}

body:not(.dk-has-index) h3.section {
    margin: 2.2rem 0 0.8rem;
    font-size: clamp(1.35rem, 2.4vw, 1.7rem);
}

body:not(.dk-has-index) h3.heading,
body:not(.dk-has-index) h4.subsection {
    margin: 2rem 0 0.7rem;
    font-size: 1.25rem;
}

body:not(.dk-has-index) a {
    color: var(--dk-accent-strong);
    text-underline-offset: 0.18em;
}

body:not(.dk-has-index) a:hover {
    color: var(--dk-accent);
}

body:not(.dk-has-index) p {
    max-width: 74ch;
}

.nav-panel .nav-button {
    white-space: nowrap;
}

.nav-panel .nav-button + .nav-button {
    margin-left: 0.35rem;
}

.nav-panel a {
    color: var(--dk-muted);
    font-weight: 400;
    text-decoration: none;
    border-bottom: 1px dotted var(--dk-border);
}

.nav-panel a:hover {
    color: var(--dk-accent-strong);
    border-bottom-color: currentColor;
}

body:not(.dk-has-index) #SEC_Contents {
    margin: 2rem 0 2.6rem;
    padding: 1rem 1.2rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

body:not(.dk-has-index) #SEC_Contents .contents-heading {
    margin-top: 0;
    font-size: 1.35rem;
}

body:not(.dk-has-index) #SEC_Contents ul {
    padding-left: 1.1rem;
}

body:not(.dk-has-index) #SEC_Contents li {
    margin: 0.18rem 0;
}

body:not(.dk-has-index) #SEC_Contents a {
    text-decoration: none;
    overflow-wrap: anywhere;
}

body:not(.dk-has-index) ul.mini-toc {
    margin: 1rem 0 1.8rem;
    padding: 0.8rem 1.1rem 0.8rem 2rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

body:not(.dk-has-index) h3.heading + ol.enumerate {
    margin: 1rem 0 1.8rem;
    padding: 1.1rem 1.35rem 1.1rem 2.6rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

body:not(.dk-has-index) h3.heading + ol.enumerate li {
    margin: 0.45rem 0;
}

body:not(.dk-has-index) h3.heading + ol.enumerate li::marker {
    color: var(--dk-accent);
    font-weight: 650;
}

body:not(.dk-has-index) div.example {
    margin: 1rem 0;
}

body:not(.dk-has-index) pre {
    max-width: 100%;
    margin: 1rem 0;
    padding: 0.8rem 1rem;
    overflow-x: auto;
    color: var(--dk-fg);
    background: var(--dk-signature);
    border: 1px solid var(--dk-border);
    border-radius: 6px;
    font-size: 0.86rem;
    line-height: 1.6;
}

body:not(.dk-has-index) table {
    display: block;
    max-width: 100%;
    overflow-x: auto;
}

/* --- the page, once the script has built the index ------------------ */

body.dk-has-index {
    box-sizing: border-box;
    max-width: 1120px;
    margin-left: var(--dk-sidebar);
    margin-right: 0;
    padding: 0 clamp(1.1rem, 3vw, 2.8rem) 6rem;
    color: var(--dk-fg);
    background: var(--dk-bg);
    font-family: var(--dk-sans);
    font-size: 1rem;
    line-height: 1.68;
}

body.dk-has-index h2.chapter,
body.dk-has-index h3.section,
body.dk-has-index h3.heading,
body.dk-has-index h4.subsection,
body.dk-has-index .anchor,
body.dk-has-index dl.def-block {
    scroll-margin-top: calc(var(--dk-bar) + 1.5rem);
}

body.dk-has-index h1.top,
body.dk-has-index h2.chapter,
body.dk-has-index h3.section,
body.dk-has-index h3.heading,
body.dk-has-index h4.subsection {
    color: var(--dk-fg);
    font-family: var(--dk-serif);
    font-weight: 600;
    line-height: 1.2;
    letter-spacing: -0.015em;
}

body.dk-has-index h1.top,
body.dk-has-index h2.chapter {
    margin: 2.8rem 0 1rem;
    font-size: clamp(2rem, 4vw, 2.75rem);
}

body.dk-has-index h1.top {
    margin-top: 0;
}

body.dk-has-index h3.section {
    margin: 2.6rem 0 0.9rem;
    font-size: clamp(1.45rem, 2.4vw, 1.85rem);
}

body.dk-has-index h3.heading {
    margin: 2.4rem 0 0.8rem;
    font-size: clamp(1.3rem, 1.8vw, 1.5rem);
}

body.dk-has-index h4.subsection {
    margin: 2.1rem 0 0.7rem;
    font-size: 1.25rem;
}

/* The reading guide on a chapter landing page: a short numbered list in
   a card, not another copy of the index. */

body.dk-has-index h3.heading + ol.enumerate {
    margin: 1rem 0 1.8rem;
    padding: 1.1rem 1.35rem 1.1rem 2.6rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

body.dk-has-index h3.heading + ol.enumerate li {
    margin: 0.45rem 0;
}

body.dk-has-index h3.heading + ol.enumerate li::marker {
    color: var(--dk-accent);
    font-weight: 650;
}

body.dk-has-index a {
    color: var(--dk-accent-strong);
    text-decoration-color: color-mix(in srgb, var(--dk-accent) 40%, transparent);
    text-underline-offset: 0.18em;
}

body.dk-has-index a:hover {
    color: var(--dk-accent);
}

body.dk-has-index p {
    max-width: 74ch;
}

/* The sentence that says what the chapter is. */

h1.top + p,
h2.chapter + p {
    max-width: 64ch;
    margin: 0 0 2.4rem;
    padding-bottom: 1.7rem;
    border-bottom: 1px solid var(--dk-border);
    color: var(--dk-muted);
    font-family: var(--dk-serif);
    font-size: clamp(1.12rem, 1.5vw, 1.3rem);
    line-height: 1.62;
}

/* The one index replaces the list texi2any writes into the body.  It is
   hidden only after the script has built its own, so a reader without
   JavaScript keeps a table of contents. */

body.dk-has-index ul.mini-toc {
    display: none;
}

/* The manual's title is in the bar above every page; on the page that
   carries it, it does not need a second heading of its own. */
body.dk-has-index h1.settitle {
    display: none;
}

body.dk-has-index h1.settitle + hr {
    display: none;
}

/* A single-page manual repeats Next/Previous/Up before every section;
   with the index down the side those rows only get in the way.  A split
   manual keeps them, because they carry the Contents and Index links. */

body.dk-flat .nav-panel,
body.dk-flat .nav-panel + hr {
    display: none;
}

/* On a single page the index holds the whole manual, so the body's own
   table of contents would be the second copy of it. */

body.dk-flat .region-contents#SEC_Contents {
    display: none;
}

.nav-panel {
    max-width: 100%;
    color: var(--dk-muted);
    font: 0.78rem/1.6 var(--dk-sans);
}

body.dk-has-index .nav-panel a {
    color: var(--dk-muted);
    font-weight: 400;
    text-decoration: none;
    border-bottom: 1px dotted var(--dk-border);
}

body.dk-has-index .nav-panel a:hover {
    color: var(--dk-accent-strong);
    border-bottom-color: currentColor;
}

hr {
    border: 0;
    border-top: 1px solid var(--dk-border);
    margin: 1.8rem 0;
}

/* --- code and examples ---------------------------------------------- */

body.dk-has-index code,
body.dk-has-index kbd,
body.dk-has-index samp,
body.dk-has-index var {
    font-family: var(--dk-mono);
    font-size: 0.9em;
}

body.dk-has-index :not(pre) > code {
    padding: 0.08em 0.32em;
    color: var(--dk-fg);
    background: var(--dk-code);
    border: 1px solid var(--dk-border);
    border-radius: 4px;
}

body.dk-has-index div.example,
body.dk-has-index pre,
body.dk-has-index pre.example,
body.dk-has-index pre.verbatim {
    max-width: 100%;
    box-sizing: border-box;
    overflow-x: auto;
}

body.dk-has-index div.example {
    margin: 1rem 0;
    padding: 0.85rem 1rem;
    background: var(--dk-code);
    border: 1px solid var(--dk-border);
    border-radius: 6px;
}

body.dk-has-index div.example pre {
    margin: 0;
    padding: 0;
    background: none;
    border: 0;
    border-radius: 0;
}

body.dk-has-index pre {
    margin: 1rem 0;
    padding: 0.8rem 1rem;
    color: var(--dk-fg);
    background: var(--dk-signature);
    border: 1px solid var(--dk-border);
    border-radius: 6px;
    box-shadow: none;
    font-size: 0.86rem;
    line-height: 1.6;
}

/* --- lists and tables ----------------------------------------------- */

body.dk-has-index ul,
body.dk-has-index ol {
    padding-left: 1.2rem;
}

body.dk-has-index li {
    margin: 0.24rem 0;
}

body.dk-has-index li::marker {
    color: var(--dk-muted);
}

body.dk-has-index table {
    width: 100%;
    margin: 1.1rem 0;
    border-collapse: collapse;
    font-size: 0.9rem;
}

body.dk-has-index th,
body.dk-has-index td {
    padding: 0.45rem 0.6rem;
    border-bottom: 1px solid var(--dk-border);
    text-align: left;
    vertical-align: top;
}

body.dk-has-index th {
    color: var(--dk-muted);
    font-family: var(--dk-sans);
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
}

body.dk-has-index blockquote {
    margin: 1.2rem 0;
    padding: 0.1rem 0 0.1rem 1rem;
    border-left: 2px solid var(--dk-border);
    color: var(--dk-muted);
}

/* --- the bar -------------------------------------------------------- */

.dk-skip {
    position: absolute;
    left: -9999px;
    z-index: 60;
    padding: 0.55rem 0.9rem;
    color: var(--dk-fg);
    background: var(--dk-card);
    border: 1px solid var(--dk-accent);
    border-radius: 6px;
}

.dk-skip:focus {
    left: 0.6rem;
    top: 0.6rem;
}

.dk-bar {
    position: sticky;
    top: 0;
    z-index: 30;
    display: flex;
    align-items: center;
    gap: 0.4rem;
    margin: 0 calc(-1 * clamp(1.1rem, 3vw, 2.8rem));
    padding: 0.5rem clamp(1.1rem, 3vw, 2.8rem);
    background: var(--dk-bg);
    border-bottom: 1px solid var(--dk-border);
}

@supports (backdrop-filter: blur(1px)) {
    .dk-bar {
        background: color-mix(in srgb, var(--dk-bg) 88%, transparent);
        backdrop-filter: blur(12px) saturate(120%);
    }
}

.dk-bar-title {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    color: var(--dk-fg);
    font-family: var(--dk-serif);
    font-size: 1rem;
    font-weight: 600;
    letter-spacing: 0.01em;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.dk-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    min-width: 2.15rem;
    height: 2.15rem;
    padding: 0 0.45rem;
    color: var(--dk-muted);
    background: transparent;
    border: 1px solid transparent;
    border-radius: 6px;
    font: 500 0.95rem/1 var(--dk-sans);
    cursor: pointer;
}

.dk-icon:hover {
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
}

.dk-menu {
    display: none;
}

.dk-top[hidden] {
    display: none;
}

.dk-scrim {
    display: none;
}

/* --- the index ------------------------------------------------------ */

.dk-index {
    position: fixed;
    inset: 0 auto 0 0;
    z-index: 50;
    display: flex;
    flex-direction: column;
    width: var(--dk-sidebar);
    overflow: hidden;
    background: var(--dk-card);
    border-right: 1px solid var(--dk-border);
    font: 0.85rem/1.5 var(--dk-sans);
}

.dk-index-head {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 1.1rem 1rem 0.55rem;
}

.dk-index-head h2 {
    flex: 1;
    margin: 0;
    color: var(--dk-muted);
    font-family: var(--dk-sans);
    font-size: 0.66rem;
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
}

.dk-index-close {
    display: none;
}

.dk-index-filter {
    display: block;
    width: calc(100% - 2rem);
    margin: 0 1rem 0.8rem;
    padding: 0.42rem 0.6rem;
    color: var(--dk-fg);
    background: var(--dk-signature);
    border: 1px solid var(--dk-border);
    border-radius: 6px;
    font: inherit;
    font-size: 0.9rem;
}

.dk-index-scroll {
    flex: 1;
    overflow-y: auto;
    overscroll-behavior: contain;
    padding: 0 0.6rem 1.5rem;
    /* Its own surface, so a page stylesheet's link decoration cannot
       show through the rows of the index. */
    background: var(--dk-card);
    scrollbar-color: var(--dk-border) transparent;
}

.dk-index-scroll::-webkit-scrollbar {
    width: 8px;
}

.dk-index-scroll::-webkit-scrollbar-thumb {
    background: var(--dk-border);
    border-radius: 999px;
}

.dk-index-scroll::-webkit-scrollbar-track {
    background: transparent;
}

.dk-index-empty {
    margin: 0.8rem 0.5rem 0;
    color: var(--dk-muted);
    font-size: 0.8rem;
}

.dk-nav,
.dk-nav ul {
    margin: 0;
    padding: 0;
    list-style: none;
}

.dk-nav ul {
    margin: 0.1rem 0 0.35rem 0.55rem;
    padding-left: 0.3rem;
    border-left: 1px solid var(--dk-border);
}

.dk-nav [hidden] {
    display: none;
}

.dk-row {
    display: flex;
    align-items: center;
    gap: 0.05rem;
    border-radius: 5px;
}

.dk-row > a {
    flex: 1;
    min-width: 0;
    padding: 0.28rem 0.45rem;
    color: var(--dk-fg);
    text-decoration: none;
    /* The site stylesheet underlines every link; a row of the index is
       read as a list, so its underline is the surface it sits on. */
    border-bottom: 0;
    box-shadow: none;
    border-radius: 5px;
}

.dk-group > .dk-row > a {
    font-family: var(--dk-serif);
    font-size: 0.92rem;
    font-weight: 600;
}

.dk-nav ul .dk-group > .dk-row > a {
    font-family: var(--dk-sans);
    font-size: 0.81rem;
    font-weight: 500;
    color: var(--dk-muted);
}

.dk-row > a:hover {
    background: var(--dk-accent-soft);
}

.dk-row > a[aria-current=\"location\"] {
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
}

.dk-toggle {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex: none;
    width: 1.35rem;
    height: 1.35rem;
    color: var(--dk-muted);
    background: transparent;
    border: 0;
    border-radius: 4px;
    cursor: pointer;
}

.dk-toggle::before {
    content: \"▸\";
    font-size: 0.66rem;
    transition: transform 0.15s ease;
}

.dk-toggle[aria-expanded=\"true\"]::before {
    transform: rotate(90deg);
}

.dk-toggle-empty {
    visibility: hidden;
}

.dk-def-link {
    display: block;
    padding: 0.24rem 0.45rem;
    color: var(--dk-fg);
    font-family: var(--dk-mono);
    font-size: 0.74rem;
    overflow-wrap: anywhere;
    text-decoration: none;
    border-bottom: 0;
    box-shadow: none;
    border-radius: 5px;
}

.dk-def-link:hover {
    background: var(--dk-accent-soft);
}

.dk-def-link[aria-current=\"location\"] {
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
}

.dk-kind {
    display: inline-block;
    margin-right: 0.35rem;
    color: var(--dk-muted);
    font-family: var(--dk-sans);
    font-size: 0.56rem;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    vertical-align: 0.08em;
}

/* --- a definition --------------------------------------------------- */

dl.def-block {
    position: relative;
    margin: 1.1rem 0;
    padding: 0.9rem 1.1rem 1rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-left: 3px solid var(--dk-accent);
    border-radius: var(--dk-radius);
}

dl.def-block:target {
    border-color: var(--dk-accent);
    box-shadow: 0 0 0 3px var(--dk-accent-soft);
}

dl.def-block > dt.def-line {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.45rem;
    margin: 0 0 0.65rem;
    padding: 0.5rem 0.7rem;
    overflow-wrap: anywhere;
    background: var(--dk-signature);
    border-radius: 5px;
    font-family: var(--dk-mono);
    font-size: 0.95rem;
}

dl.def-block .category-def {
    padding: 0.16rem 0.5rem;
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
    border-radius: 999px;
    font-family: var(--dk-sans);
    font-size: 0.62rem;
    font-weight: 600;
    letter-spacing: 0.07em;
    text-transform: uppercase;
}

dl.def-block .def-name {
    color: var(--dk-fg);
    font-family: var(--dk-mono);
    font-size: 1.02rem;
    font-style: normal;
    font-weight: 600;
}

dl.def-block .def-var-arguments,
dl.def-block .def-type {
    color: var(--dk-muted);
    font-family: var(--dk-mono);
    font-style: normal;
    font-weight: 400;
}

dl.def-block > dd {
    margin: 0;
}

dl.def-block > dd > p {
    max-width: 78ch;
}

dl.def-block > dd > p:first-child {
    font-size: 1.02rem;
}

dl.def-block > dd strong.strong {
    color: var(--dk-fg);
}

/* --- what the script adds ------------------------------------------- */

.dk-copy {
    margin-left: auto;
    padding: 0.28rem 0.45rem;
    color: var(--dk-muted);
    background: transparent;
    border: 1px solid transparent;
    border-radius: 5px;
    font: 500 0.68rem/1 var(--dk-sans);
    letter-spacing: 0.02em;
    cursor: pointer;
}

.dk-copy:hover {
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
}

.dk-copy[data-dk-copied=\"yes\"] {
    color: var(--dk-accent-strong);
    background: var(--dk-accent-soft);
}

/* --- diagrams ------------------------------------------------------- */

img.image {
    display: block;
    max-width: 100%;
    height: auto;
    margin: 1rem auto;
    padding: 0.5rem;
    background: #ffffff;
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

.dk-diagram {
    margin: 1rem 0;
    padding: 0.75rem 1rem;
    overflow-x: auto;
    text-align: center;
    background: #ffffff;
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
}

.dk-diagram svg {
    max-width: 100%;
    height: auto;
}

/* --- focus ---------------------------------------------------------- */

.dk-index a:focus-visible,
.dk-icon:focus-visible,
.dk-copy:focus-visible,
.dk-toggle:focus-visible,
.dk-skip:focus-visible,
.dk-index-filter:focus-visible {
    outline: 2px solid var(--dk-accent);
    outline-offset: 2px;
}

/* --- the phone and the tablet --------------------------------------- */

@media (max-width: 1024px) {
    body.dk-has-index {
        margin-left: 0;
        padding: 0 1.1rem 4rem;
    }

    .dk-bar {
        margin: 0 -1.1rem;
        padding: 0.5rem 1.1rem;
    }

    .dk-menu {
        display: inline-flex;
    }

    .dk-index {
        width: min(86vw, 20rem);
        visibility: hidden;
        transform: translateX(-103%);
        /* Stay visible while the drawer slides away, then leave the tab
           order; opening makes it visible at once so the filter can take
           the focus. */
        transition: transform 0.24s var(--dk-ease), visibility 0s linear 0.24s;
    }

    /* A closed drawer is out of the tab order too, not only out of sight. */
    body.dk-index-open .dk-index {
        visibility: visible;
        transform: none;
        transition: transform 0.24s var(--dk-ease), visibility 0s linear 0s;
        box-shadow: 0 0 0 1px var(--dk-border), 0 24px 64px rgba(8, 8, 12, 0.28);
    }

    .dk-index-close {
        display: inline-flex;
    }

    body.dk-index-open {
        overflow: hidden;
    }

    .dk-scrim {
        position: fixed;
        inset: 0;
        z-index: 45;
        display: block;
        background: rgba(20, 16, 12, 0.45);
    }

    .dk-scrim[hidden] {
        display: none;
    }
}

@media (max-width: 600px) {
    body.dk-has-index h2.chapter {
        margin-top: 2rem;
        font-size: clamp(1.8rem, 8vw, 2.3rem);
    }

    body.dk-has-index h3.section {
        font-size: 1.35rem;
    }

    body.dk-has-index h3.heading {
        font-size: 1.2rem;
    }

    body.dk-has-index h3.heading + ol.enumerate,
    body:not(.dk-has-index) h3.heading + ol.enumerate {
        padding: 0.9rem 1rem 0.9rem 2.2rem;
    }

    h2.chapter + p {
        font-size: 1.08rem;
    }

    dl.def-block {
        padding: 0.75rem 0.85rem 0.9rem;
    }

    dl.def-block > dt.def-line {
        font-size: 0.9rem;
    }

    dl.def-block .def-name {
        font-size: 0.98rem;
    }

    .dk-bar-title {
        font-size: 0.92rem;
    }

    body.dk-has-index table {
        display: block;
        overflow-x: auto;
    }
}

/* --- print ---------------------------------------------------------- */

@media print {
    .dk-index,
    .dk-bar,
    .dk-skip,
    .dk-scrim,
    .dk-copy {
        display: none !important;
    }

    body,
    body.dk-has-index,
    body:not(.dk-has-index) {
        max-width: none;
        margin: 0;
        padding: 0;
        background: none;
        font-size: 11pt;
    }

    /* The index is not printed, so the body's own table of contents
       comes back for the paper. */
    body.dk-has-index ul.mini-toc,
    body.dk-flat .region-contents#SEC_Contents {
        display: block;
    }

    dl.def-block {
        break-inside: avoid;
        border: 1px solid #cccccc;
        border-left: 3px solid #888888;
    }

    body.dk-has-index h3.heading + ol.enumerate,
    body:not(.dk-has-index) h3.heading + ol.enumerate,
    body:not(.dk-has-index) #SEC_Contents,
    body:not(.dk-has-index) ul.mini-toc {
        background: none;
        border-color: #cccccc;
    }

    .dk-diagram,
    img.image {
        break-inside: avoid;
    }
}
")

;; The script, written to @file{dokgen.js} beside the chapter.
(define SCRIPT
  "/* dokgen.js --- the behaviour of an API chapter.
 *
 * SPDX-License-Identifier: MIT
 * Copyright © Josep Bigorra <jjbigorra@gmail.com>
 *
 * dokgen writes this file beside the Texinfo chapter it generates.  It
 * adds, on top of what texi2any emits, the few things that make a page of
 * reference documentation pleasant to read: one index holding the sections
 * and every definition, a filter over it, a bar with the theme and, on a
 * phone, the button that opens the index as a drawer.  It also folds the
 * body's own table of contents away, because the index already is one, and
 * draws a diagram the build left as source from the bundled renderer.
 *
 * Everything is progressive: the page is complete without this file, and
 * every feature is one selector away from disappearing if the HTML it
 * looks for is not there.  No network and no global of its own: the
 * renderer is a local file, loaded only when a page needs it.
 */

(function () {
    \"use strict\";

    var THEME_KEY = \"dokgen-theme\";
    var root = document.documentElement;
    var body = document.body;
    var phone = window.matchMedia(\"(max-width: 1024px)\");

    function each(list, fn) {
        Array.prototype.forEach.call(list, fn);
    }

    function definitions() {
        return document.querySelectorAll(\"dl.def-block\");
    }

    function tidy(text) {
        return (text || \"\")
            .replace(/\\s+/g, \" \")
            .replace(/\\s*¶+$/, \"\")
            .replace(/^\\d+(\\.\\d+)*\\s+/, \"\")
            .trim();
    }

    function signatureOf(block) {
        var line = block.querySelector(\":scope > dt\");
        if (!line) {
            return \"\";
        }
        var name = line.querySelector(\".def-name\");
        var args = line.querySelector(\".def-var-arguments\");
        var text = (name ? name.textContent : line.textContent) || \"\";
        if (args && args.textContent.trim()) {
            text += \" \" + args.textContent.trim();
        }
        return text.replace(/\\s+/g, \" \").trim();
    }

    function nameOf(block) {
        var name = block.querySelector(\":scope > dt .def-name\");
        return name ? name.textContent.trim() : \"\";
    }

    function kindOf(block) {
        var kind = block.querySelector(\".category-def\");
        return kind ? kind.textContent.replace(/[:\\s]+$/, \"\").trim() : \"\";
    }

    function summaryOf(block) {
        var statement = block.querySelector(\":scope > dd\");
        var first = statement && statement.querySelector(\"p\");
        return first ? first.textContent.replace(/\\s+/g, \" \").trim() : \"\";
    }

    function reduceMotion() {
        return window.matchMedia(\"(prefers-reduced-motion: reduce)\").matches;
    }

    /* --- the theme ---------------------------------------------------- */

    function preferredTheme() {
        var saved = null;
        try {
            saved = window.localStorage.getItem(THEME_KEY);
        } catch (error) {
            saved = null;
        }
        if (saved === \"light\" || saved === \"dark\") {
            return saved;
        }
        return window.matchMedia(\"(prefers-color-scheme: dark)\").matches ? \"dark\" : \"light\";
    }

    function applyTheme(theme) {
        root.setAttribute(\"data-dk-theme\", theme);
        try {
            window.localStorage.setItem(THEME_KEY, theme);
        } catch (error) {
            /* A reader with storage turned off gets the theme for the visit. */
        }
    }

    /* --- copyable signatures ------------------------------------------ */

    function addCopyButtons() {
        each(definitions(), function (block) {
            var line = block.querySelector(\":scope > dt\");
            var signature = signatureOf(block);
            if (!line || !signature) {
                return;
            }
            var button = document.createElement(\"button\");
            button.type = \"button\";
            button.className = \"dk-copy\";
            button.textContent = \"copy\";
            button.title = \"Copy \" + signature;
            button.setAttribute(\"aria-label\", \"Copy the signature of \" + signature);
            button.addEventListener(\"click\", function () {
                var wrote = navigator.clipboard && navigator.clipboard.writeText(signature);
                if (wrote && wrote.then) {
                    wrote.then(function () {
                        button.textContent = \"copied\";
                        button.setAttribute(\"data-dk-copied\", \"yes\");
                        window.setTimeout(function () {
                            button.textContent = \"copy\";
                            button.removeAttribute(\"data-dk-copied\");
                        }, 1400);
                    })[\"catch\"](function () {
                        button.textContent = \"copy failed\";
                    });
                }
            });
            line.appendChild(button);
        });
    }

    /* --- the index ---------------------------------------------------- */

    function targetOf(link) {
        var href = link.getAttribute(\"href\") || \"\";
        if (href.charAt(0) !== \"#\") {
            return null;
        }
        return document.getElementById(href.slice(1));
    }

    function anchorTarget(block, position) {
        var anchor = block.previousElementSibling;
        while (anchor && !(anchor.tagName === \"A\" && anchor.id)) {
            anchor = anchor.previousElementSibling;
        }
        if (anchor) {
            return anchor;
        }
        var id = \"dk-definition-\" + position;
        block.id = id;
        return block;
    }

    function buildIndex() {
        var toc = document.querySelector(\"ul.mini-toc\");
        var blocks = definitions();
        if (!toc && !blocks.length) {
            return null;
        }

        var nav = document.createElement(\"nav\");
        nav.className = \"dk-index\";
        nav.id = \"dk-index\";
        nav.setAttribute(\"aria-label\", \"Contents\");

        var head = document.createElement(\"div\");
        head.className = \"dk-index-head\";
        var title = document.createElement(\"h2\");
        title.textContent = \"Contents\";
        var close = createIcon(\"✕\", \"Close the contents\");
        close.className += \" dk-index-close\";
        head.appendChild(title);
        head.appendChild(close);
        nav.appendChild(head);

        var filter = document.createElement(\"input\");
        filter.type = \"search\";
        filter.className = \"dk-index-filter\";
        filter.placeholder = \"Filter the contents…\";
        filter.setAttribute(\"aria-label\", \"Filter the contents of this page\");
        nav.appendChild(filter);

        var scroll = document.createElement(\"div\");
        scroll.className = \"dk-index-scroll\";
        var list = document.createElement(\"ul\");
        list.className = \"dk-nav\";
        var empty = document.createElement(\"p\");
        empty.className = \"dk-index-empty\";
        empty.textContent = \"Nothing here matches.\";
        empty.hidden = true;
        scroll.appendChild(list);
        scroll.appendChild(empty);
        nav.appendChild(scroll);

        var groups = [];
        var entries = [];
        var position = 0;

        function entryFor(block) {
            var name = nameOf(block) || signatureOf(block);
            if (!name) {
                return null;
            }
            var anchor = anchorTarget(block, position++);
            var item = document.createElement(\"li\");
            var link = document.createElement(\"a\");
            link.className = \"dk-def-link\";
            link.href = \"#\" + anchor.id;
            link.title = signatureOf(block) || name;
            var kind = document.createElement(\"span\");
            kind.className = \"dk-kind\";
            kind.textContent = kindOf(block);
            link.appendChild(kind);
            link.appendChild(document.createTextNode(name));
            item.appendChild(link);
            return {
                li: item,
                link: link,
                block: block,
                anchor: anchor,
                group: null,
                text: (kindOf(block) + \" \" + signatureOf(block) + \" \" + summaryOf(block)).toLowerCase()
            };
        }

        function openGroup(group, open) {
            if (!group.list) {
                return;
            }
            group.list.hidden = !open;
            group.toggle.setAttribute(\"aria-expanded\", open ? \"true\" : \"false\");
            group.li.classList.toggle(\"dk-open\", open);
        }

        function headingLevel(heading) {
            /* The top node is an unnumbered chapter, not a container for
               the numbered ones: the index lists it beside them. */
            if (heading.tagName === \"H1\") {
                return 2;
            }
            if (heading.classList.contains(\"chapter\")) {
                return 2;
            }
            return heading.classList.contains(\"section\") ? 3 : 4;
        }

        function headingTarget(heading) {
            var box = heading.parentElement;
            while (box && !box.id) {
                box = box.parentElement;
            }
            var target = box && box.id ? box : heading;
            if (!target.id) {
                target.id = \"dk-\" + tidy(heading.textContent).toLowerCase().replace(/[^a-z0-9]+/g, \"-\");
            }
            return target;
        }

        function headingGroup(heading) {
            var label = tidy(heading.textContent);
            var item = document.createElement(\"li\");
            item.className = \"dk-group\";
            var row = document.createElement(\"div\");
            row.className = \"dk-row\";
            var target = headingTarget(heading);
            var anchor = document.createElement(\"a\");
            anchor.href = \"#\" + target.id;
            anchor.textContent = label;
            anchor.title = label;
            row.appendChild(anchor);
            item.appendChild(row);
            var children = document.createElement(\"ul\");
            children.hidden = true;
            item.appendChild(children);
            return {
                li: item,
                row: row,
                link: anchor,
                target: target,
                label: label.toLowerCase(),
                entries: [],
                list: children,
                toggle: null,
                parent: null
            };
        }

        function finishGroup(group) {
            if (!group.list || !group.list.children.length) {
                if (group.list) {
                    group.list.remove();
                    group.list = null;
                }
                var spacer = document.createElement(\"span\");
                spacer.className = \"dk-toggle dk-toggle-empty\";
                group.row.insertBefore(spacer, group.link);
                return;
            }
            var toggle = document.createElement(\"button\");
            toggle.type = \"button\";
            toggle.className = \"dk-toggle\";
            toggle.setAttribute(\"aria-expanded\", \"false\");
            toggle.setAttribute(\"aria-label\", \"Show what \" + group.link.textContent + \" contains\");
            toggle.addEventListener(\"click\", function () {
                openGroup(group, group.list.hidden);
            });
            group.row.insertBefore(toggle, group.link);
            group.toggle = toggle;
        }

        /* A page that holds its own sections is indexed from its
           headings, which is the whole page even in a single-page manual. */
        function buildTree() {
            var stack = [];
            each(document.querySelectorAll(\"h1, h2.chapter, h3.section, h4.subsection, dl.def-block\"), function (node) {
                if (node.classList.contains(\"settitle\")) {
                    return;
                }
                if (node.tagName === \"DL\") {
                    var entry = entryFor(node);
                    if (!entry) {
                        return;
                    }
                    var holder = stack.length ? stack[stack.length - 1].group : null;
                    entry.group = holder;
                    if (holder) {
                        holder.entries.push(entry);
                        holder.list.appendChild(entry.li);
                    } else {
                        list.appendChild(entry.li);
                    }
                    entries.push(entry);
                    return;
                }
                var level = headingLevel(node);
                while (stack.length && stack[stack.length - 1].level >= level) {
                    stack.pop();
                }
                var group = headingGroup(node);
                var parent = stack.length ? stack[stack.length - 1].group : null;
                group.depth = parent ? parent.depth + 1 : 0;
                if (parent) {
                    group.parent = parent;
                    parent.list.appendChild(group.li);
                } else {
                    list.appendChild(group.li);
                }
                stack.push({ level: level, group: group });
                groups.push(group);
            });
            each(groups, finishGroup);
        }

        function groupFor(link) {
            var label = tidy(link.textContent);
            var target = targetOf(link);
            var item = document.createElement(\"li\");
            item.className = \"dk-group\";
            var row = document.createElement(\"div\");
            row.className = \"dk-row\";
            var group = { li: item, row: row, link: null, target: target, label: label.toLowerCase(), entries: [], list: null, toggle: null, parent: null, depth: 0 };

            if (target) {
                each(target.querySelectorAll(\"dl.def-block\"), function (block) {
                    var entry = entryFor(block);
                    if (!entry) {
                        return;
                    }
                    entry.group = group;
                    group.entries.push(entry);
                });
            }

            if (group.entries.length) {
                var toggle = document.createElement(\"button\");
                toggle.type = \"button\";
                toggle.className = \"dk-toggle\";
                toggle.setAttribute(\"aria-expanded\", \"false\");
                toggle.setAttribute(\"aria-label\", \"Show what \" + label + \" contains\");
                toggle.addEventListener(\"click\", function () {
                    openGroup(group, group.list.hidden);
                });
                row.appendChild(toggle);
                group.toggle = toggle;
                group.list = document.createElement(\"ul\");
                group.list.hidden = true;
                each(group.entries, function (entry) {
                    group.list.appendChild(entry.li);
                });
            } else {
                var spacer = document.createElement(\"span\");
                spacer.className = \"dk-toggle dk-toggle-empty\";
                row.appendChild(spacer);
            }

            var anchor = document.createElement(\"a\");
            anchor.href = link.getAttribute(\"href\");
            anchor.textContent = label;
            anchor.title = label;
            row.appendChild(anchor);
            item.appendChild(row);
            if (group.list) {
                item.appendChild(group.list);
            }
            group.link = anchor;
            return group;
        }

        /* A chapter page of a split manual has no sections of its own: its
           mini-toc names the pages that follow, so that is the tree. */
        if (document.querySelector(\".section-level-extent, .subsection-level-extent\")) {
            buildTree();
        } else if (toc) {
            each(toc.children, function (item) {
                var link = item.querySelector(\"a\");
                if (!link) {
                    return;
                }
                var group = groupFor(link);
                list.appendChild(group.li);
                groups.push(group);
                each(group.entries, function (entry) {
                    entries.push(entry);
                });
            });
        }

        if (!groups.length) {
            each(blocks, function (block) {
                var entry = entryFor(block);
                if (!entry) {
                    return;
                }
                list.appendChild(entry.li);
                entries.push(entry);
            });
        }

        if (!groups.length && !entries.length) {
            return null;
        }

        /* A reference index shows its shape before it is touched: the
           top level is open, so a chapter lists its sections (or a
           module its subsections) without a click.  The definitions
           below them stay folded until a section is opened. */
        each(groups, function (group) {
            if (group.depth === 0 && group.list) {
                openGroup(group, true);
            }
        });

        /* The definition being read is marked as it scrolls, and the
           group that holds it opens, so the index says where the reader
           is even after a jump from a link. */
        var active = null;
        function activate(item) {
            if (active === item) {
                return;
            }
            if (active) {
                active.link.removeAttribute(\"aria-current\");
            }
            active = item;
            item.link.setAttribute(\"aria-current\", \"location\");
            var holder = item.group || item.parent || null;
            while (holder) {
                if (holder.list && holder.list.hidden) {
                    openGroup(holder, true);
                }
                holder = holder.parent;
            }
            var linkBox = item.link.getBoundingClientRect();
            var scrollBox = scroll.getBoundingClientRect();
            if (linkBox.top < scrollBox.top || linkBox.bottom > scrollBox.bottom) {
                scroll.scrollTop += linkBox.top - scrollBox.top - scrollBox.height / 2;
            }
        }

        /* The bar marks the heading or definition being read: the last one
           whose top has passed under the bar is the one in view. */
        var byTarget = new Map();
        each(groups, function (group) {
            if (group.target) {
                byTarget.set(group.target, group);
            }
        });
        each(entries, function (entry) {
            byTarget.set(entry.anchor, entry);
        });
        var watched = [];
        each(document.querySelectorAll(\".top-level-extent, .chapter-level-extent, .section-level-extent, .subsection-level-extent, a.anchor, dl.def-block\"), function (target) {
            if (byTarget.has(target)) {
                watched.push(target);
            }
        });
        function mark() {
            // The bar is inserted after the index, so it is looked up now.
            var bar = document.querySelector(\".dk-bar\");
            var line = (bar ? bar.getBoundingClientRect().bottom : 0) + 32;
            var found = null;
            each(watched, function (target) {
                if (target.getBoundingClientRect().top <= line) {
                    found = byTarget.get(target);
                }
            });
            if (!found && groups.length) {
                found = groups[0];
            }
            if (found) {
                activate(found);
            }
        }

        if (watched.length) {
            var waiting = false;
            var later = function () {
                waiting = false;
                mark();
            };
            window.addEventListener(\"scroll\", function () {
                if (!waiting) {
                    waiting = true;
                    window.requestAnimationFrame(later);
                }
            }, { passive: true });
            window.addEventListener(\"resize\", later);
            mark();
        }

        filter.addEventListener(\"input\", function () {
            var needle = filter.value.trim().toLowerCase();
            var found = 0;
            each(groups, function (group) {
                var shown = 0;
                each(group.entries, function (entry) {
                    var hit = needle === \"\" || entry.text.indexOf(needle) !== -1;
                    entry.li.hidden = !hit;
                    if (hit) {
                        shown += 1;
                    }
                });
                var named = needle !== \"\" && group.label.indexOf(needle) !== -1;
                group.li.hidden = needle !== \"\" && !named && shown === 0;
                if (group.list) {
                    openGroup(group, needle !== \"\");
                }
                if (!group.li.hidden) {
                    found += 1;
                }
            });
            each(entries, function (entry) {
                if (entry.group) {
                    return;
                }
                var hit = needle === \"\" || entry.text.indexOf(needle) !== -1;
                entry.li.hidden = !hit;
                if (!entry.li.hidden) {
                    found += 1;
                }
            });
            /* A matching definition can sit under a group whose own title
               does not match: the path to it is shown with it. */
            if (needle !== \"\") {
                for (var index = groups.length - 1; index >= 0; index -= 1) {
                    var group = groups[index];
                    if (!group.li.hidden && group.parent) {
                        group.parent.li.hidden = false;
                    }
                }
            }
            empty.hidden = !(needle !== \"\" && found === 0);
            /* Clearing the filter should not hide the reader's place. */
            if (needle === \"\" && active && active.group) {
                openGroup(active.group, true);
            }
        });

        return { nav: nav, filter: filter, close: close, groups: groups };
    }

    /* --- the bar and the drawer --------------------------------------- */

    function createIcon(label, description) {
        var button = document.createElement(\"button\");
        button.type = \"button\";
        button.className = \"dk-icon\";
        button.textContent = label;
        button.title = description;
        button.setAttribute(\"aria-label\", description);
        return button;
    }

    function pageTitle() {
        var heading = document.querySelector(\"h2.chapter, h3.section, h4.subsection, h1\");
        var title = heading ? tidy(heading.textContent) : \"\";
        if (!title) {
            title = tidy(document.title);
        }
        return title || \"Contents\";
    }

    function buildBar(index) {
        var bar = document.createElement(\"header\");
        bar.className = \"dk-bar\";

        var menu = createIcon(\"☰\", \"Open the contents\");
        menu.className += \" dk-menu\";
        menu.setAttribute(\"aria-controls\", index.nav.id);
        menu.setAttribute(\"aria-expanded\", \"false\");

        var title = document.createElement(\"span\");
        title.className = \"dk-bar-title\";
        title.textContent = pageTitle();

        var top = createIcon(\"↑\", \"Back to the top\");
        top.className += \" dk-top\";
        top.hidden = true;

        var theme = createIcon(\"◐\", \"Switch between a light and a dark page\");
        theme.className += \" dk-theme\";

        bar.appendChild(menu);
        bar.appendChild(title);
        bar.appendChild(top);
        bar.appendChild(theme);

        theme.addEventListener(\"click\", function () {
            applyTheme(root.getAttribute(\"data-dk-theme\") === \"dark\" ? \"light\" : \"dark\");
        });
        top.addEventListener(\"click\", function () {
            window.scrollTo({ top: 0, behavior: reduceMotion() ? \"auto\" : \"smooth\" });
        });
        window.addEventListener(\"scroll\", function () {
            top.hidden = window.scrollY < 640;
        }, { passive: true });

        return { bar: bar, menu: menu, theme: theme, top: top };
    }

    function isTyping(element) {
        if (!element) {
            return false;
        }
        var tag = element.tagName;
        return tag === \"INPUT\" || tag === \"TEXTAREA\" || tag === \"SELECT\" || element.isContentEditable;
    }

    function wireDrawer(chrome, index) {
        var scrim = document.createElement(\"div\");
        scrim.className = \"dk-scrim\";
        scrim.hidden = true;

        function open() {
            if (!phone.matches) {
                return;
            }
            body.classList.add(\"dk-index-open\");
            chrome.menu.setAttribute(\"aria-expanded\", \"true\");
            scrim.hidden = false;
            index.filter.focus();
        }

        function close() {
            var wasOpen = body.classList.contains(\"dk-index-open\");
            body.classList.remove(\"dk-index-open\");
            chrome.menu.setAttribute(\"aria-expanded\", \"false\");
            scrim.hidden = true;
            if (wasOpen) {
                chrome.menu.focus();
            }
        }

        chrome.menu.addEventListener(\"click\", function () {
            if (body.classList.contains(\"dk-index-open\")) {
                close();
            } else {
                open();
            }
        });
        index.close.addEventListener(\"click\", close);
        scrim.addEventListener(\"click\", close);
        each(index.nav.querySelectorAll(\"a\"), function (link) {
            link.addEventListener(\"click\", close);
        });
        document.addEventListener(\"keydown\", function (event) {
            if (event.key === \"Escape\" && body.classList.contains(\"dk-index-open\")) {
                close();
            } else if (event.key === \"/\" && !isTyping(event.target)) {
                event.preventDefault();
                open();
                index.filter.focus();
            }
        });
        var onResize = function () {
            if (!phone.matches) {
                close();
            }
        };
        if (phone.addEventListener) {
            phone.addEventListener(\"change\", onResize);
        } else {
            phone.addListener(onResize);
        }
        return scrim;
    }

    function buildSkip() {
        var target = document.querySelector(\".chapter-level-extent[id], .section-level-extent[id]\");
        if (!target) {
            return null;
        }
        target.setAttribute(\"tabindex\", \"-1\");
        var link = document.createElement(\"a\");
        link.className = \"dk-skip\";
        link.href = \"#\" + target.id;
        link.textContent = \"Skip to the content\";
        link.addEventListener(\"click\", function () {
            target.focus();
        });
        return link;
    }

    /* --- diagrams ----------------------------------------------------- */

    var MERMAID_MARKER = \"%%dokgen-mermaid\";

    function diagramSource(pre) {
        var lines = pre.textContent.replace(/\\s+$/, \"\").split(\"\\n\");
        if (lines.length < 2) {
            return null;
        }
        if (lines[lines.length - 1].replace(/\\s/g, \"\") !== MERMAID_MARKER) {
            return null;
        }
        lines.pop();
        return lines.join(\"\\n\");
    }

    function loadMermaid(done) {
        if (window.mermaid) {
            done();
            return;
        }
        var base = \"\";
        each(document.scripts, function (tag) {
            if (tag.src && /dokgen\\.js(?:\\?|$)/.test(tag.src)) {
                base = tag.src.replace(/[^\\/]*$/, \"\");
            }
        });
        var script = document.createElement(\"script\");
        script.src = base + \"dokgen-mermaid.js\";
        script.onload = done;
        /* A page built without the bundled renderer keeps the source. */
        script.onerror = function () {};
        document.head.appendChild(script);
    }

    function renderDiagrams() {
        var pending = [];
        each(document.querySelectorAll(\"pre\"), function (pre) {
            var source = diagramSource(pre);
            if (source) {
                pending.push({ pre: pre, source: source });
            }
        });
        if (!pending.length) {
            return;
        }
        loadMermaid(function () {
            var boxes = [];
            var restore = function () {
                each(pending, function (item) {
                    item.pre.hidden = false;
                });
                each(boxes, function (box) {
                    box.remove();
                });
            };
            try {
                window.mermaid.initialize({
                    startOnLoad: false,
                    securityLevel: \"strict\",
                    theme: \"neutral\"
                });
            } catch (error) {
                restore();
                return;
            }
            each(pending, function (item) {
                var box = document.createElement(\"div\");
                box.className = \"mermaid dk-diagram\";
                box.textContent = item.source;
                item.pre.parentNode.insertBefore(box, item.pre.nextSibling);
                item.pre.hidden = true;
                boxes.push(box);
            });
            var drawing;
            try {
                drawing = window.mermaid.run({ nodes: boxes });
            } catch (error) {
                restore();
                return;
            }
            if (drawing && drawing.catch) {
                drawing.catch(restore);
            }
        });
    }

    /* --- start -------------------------------------------------------- */

    applyTheme(preferredTheme());
    addCopyButtons();
    renderDiagrams();

    var index = buildIndex();
    if (index) {
        body.classList.add(\"dk-has-index\");
        /* A split manual links between pages in its navigation rows; a
           single-page manual repeats links to itself before every
           section, and the index already offers those. */
        if (!document.querySelector(\".nav-panel a[href$='.html']\")) {
            body.classList.add(\"dk-flat\");
        }
        var chrome = buildBar(index);
        var scrim = wireDrawer(chrome, index);
        var skip = buildSkip();
        body.insertBefore(index.nav, body.firstChild);
        body.insertBefore(scrim, index.nav);
        body.insertBefore(chrome.bar, scrim);
        if (skip) {
            body.insertBefore(skip, chrome.bar);
        }
        /* The index was built before the bar existed; measuring now that
           both are in the page marks the reader's place on arrival. */
        window.dispatchEvent(new Event(\"scroll\"));
    }
}());
")


;;; PROCEDURES

(define (write-assets! destination)
  "Write the stylesheet and the scripts into @var{destination}.

  @strong{destination} (string):
    The directory the chapter is written to.

  @strong{Result}:
    @file{dokgen.css}, @file{dokgen.js} and @file{dokgen-mermaid.js} are
    written there, beside the Texinfo, so that a manual which copies that
    directory beside its pages finds them where the chapter says they are.
    The bundled copy of mermaid, @file{mermaid.min.js}, is copied as
    @file{dokgen-mermaid.js} when it is present; the script loads it only
    on a page that holds a diagram no renderer drew."
  (save STYLESHEET (in-vicinity destination "dokgen.css"))
  (save SCRIPT (in-vicinity destination "dokgen.js"))
  (let [(mermaid (bundled-asset "mermaid.min.js"))]
    (when (and mermaid (file-exists? mermaid))
      (system* "cp" mermaid (in-vicinity destination "dokgen-mermaid.js")))))

(define (bundled-asset name)
  "Return the path of NAME beside this module, or @code{#false}.

  The path is found through the load path rather than from the file being
  compiled, because a compiled module does not always know where its
  source is.  The asset is optional: a tree that does not carry it still
  writes a working stylesheet and script."
  (and=> (%search-load-path "dokgen/assets.scm")
         (lambda (path) (in-vicinity (dirname path) name))))
