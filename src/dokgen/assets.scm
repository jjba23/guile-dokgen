;; guile-dokgen --- the stylesheet and the script the chapter is read with
;;
;; SPDX-License-Identifier: MIT
;; Copyright © Josep Bigorra <jjbigorra@gmail.com>

;;; Commentary:

#| A Texinfo chapter is complete without these two files, and Info and
print output never see them.  They are what makes the HTML a reader
expects from reference documentation: the definition as a card with its
signature at the top, an index of those definitions down the side with a
filter, a button that copies a signature, a folded tail on the long ones,
a theme that follows the reader, and diagrams that open into something
they can zoom into and drag.

They are written into the destination beside the chapter, so a manual
that is built with this directory on its include path and these two files
beside its pages gets all of it, and a manual that ignores them gets a
chapter that still reads.  The JavaScript is progressive and has no
dependencies: every feature is one selector away from disappearing.

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
 * dokgen writes this file beside the Texinfo chapter it generates.  Its
 * stylesheet turns what texi2any emits into what a reader of modern
 * reference documentation expects: a card per definition, the signature
 * of each one readable at a glance, an index of them down the side, and
 * diagrams that open into something they can zoom into.
 *
 * Nothing here is required: the chapter is complete Texinfo without it,
 * and Info and print output never see a line of it.  It is written for
 * the HTML readers, and every rule is either a `dk-` class that the
 * script adds or a selector texi2any is known to emit.
 */

:root {
    --dk-fg: #1b1b1f;
    --dk-muted: #5f5f6b;
    --dk-card: #fbfbfd;
    --dk-signature: #f2f2f7;
    --dk-border: #dcdce6;
    --dk-accent: #a8480c;
    --dk-accent-soft: rgba(168, 72, 12, 0.12);
    --dk-radius: 10px;
    --dk-shadow: 0 1px 2px rgba(16, 16, 24, 0.06), 0 4px 14px rgba(16, 16, 24, 0.05);
    --dk-mono: ui-monospace, SFMono-Regular, \"SF Mono\", Menlo, Consolas, monospace;
}

@media (prefers-color-scheme: dark) {
    :root {
        --dk-fg: #e9e9ef;
        --dk-muted: #a3a3b0;
        --dk-card: #1b1b20;
        --dk-signature: #232329;
        --dk-border: #2f2f38;
        --dk-accent: #ffa066;
        --dk-accent-soft: rgba(255, 160, 102, 0.14);
        --dk-shadow: 0 1px 2px rgba(0, 0, 0, 0.5), 0 4px 14px rgba(0, 0, 0, 0.35);
    }
}

[data-dk-theme=\"light\"] {
    --dk-fg: #1b1b1f;
    --dk-muted: #5f5f6b;
    --dk-card: #fbfbfd;
    --dk-signature: #f2f2f7;
    --dk-border: #dcdce6;
    --dk-accent: #a8480c;
    --dk-accent-soft: rgba(168, 72, 12, 0.12);
    --dk-shadow: 0 1px 2px rgba(16, 16, 24, 0.06), 0 4px 14px rgba(16, 16, 24, 0.05);
}

[data-dk-theme=\"dark\"] {
    --dk-fg: #e9e9ef;
    --dk-muted: #a3a3b0;
    --dk-card: #1b1b20;
    --dk-signature: #232329;
    --dk-border: #2f2f38;
    --dk-accent: #ffa066;
    --dk-accent-soft: rgba(255, 160, 102, 0.14);
    --dk-shadow: 0 1px 2px rgba(0, 0, 0, 0.5), 0 4px 14px rgba(0, 0, 0, 0.35);
}

html {
    scroll-behavior: smooth;
}

@media (prefers-reduced-motion: reduce) {
    html {
        scroll-behavior: auto;
    }
}

/* One card per definition, which is the unit a reader comes for. */

dl.def-block {
    position: relative;
    margin: 1.3rem 0;
    padding: 0.85rem 1.1rem 1rem;
    background: var(--dk-card);
    border: 1px solid var(--dk-border);
    border-left: 3px solid var(--dk-accent);
    border-radius: var(--dk-radius);
    box-shadow: var(--dk-shadow);
    transition: box-shadow 0.15s ease, border-color 0.15s ease;
}

dl.def-block:hover {
    box-shadow: 0 2px 4px rgba(16, 16, 24, 0.08), 0 10px 28px rgba(16, 16, 24, 0.08);
}

dl.def-block:target {
    border-color: var(--dk-accent);
    box-shadow: 0 0 0 3px var(--dk-accent-soft);
}

dl.def-block > dt.def-line {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0.5rem;
    margin: 0 0 0.6rem;
    padding: 0.5rem 0.65rem;
    background: var(--dk-signature);
    border-radius: calc(var(--dk-radius) - 4px);
    font-family: var(--dk-mono);
    font-size: 1rem;
}

dl.def-block .category-def {
    font-family: system-ui, sans-serif;
    font-size: 0.68rem;
    font-weight: 600;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: var(--dk-accent);
    background: var(--dk-accent-soft);
    border-radius: 999px;
    padding: 0.18rem 0.55rem;
}

dl.def-block .def-name {
    font-size: 1.06rem;
    font-weight: 700;
}

dl.def-block .def-var-arguments,
dl.def-block .def-type {
    color: var(--dk-muted);
    font-weight: 400;
}

dl.def-block > dd {
    margin: 0;
}

dl.def-block > dd > p:first-child {
    font-size: 1.03rem;
}

dl.def-block > dd > p {
    max-width: 78ch;
}

/* The paragraph that says what a parameter is reads as a definition. */

dl.def-block > dd strong.strong {
    color: var(--dk-fg);
}

/* What the script adds: a copy button, a folding tail, an index pane. */

.dk-copy {
    margin-left: auto;
    font: 500 0.72rem/1 system-ui, sans-serif;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--dk-muted);
    background: transparent;
    border: 1px solid var(--dk-border);
    border-radius: 6px;
    padding: 0.3rem 0.5rem;
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

dl.def-block:hover .dk-copy,
.dk-copy:focus-visible {
    opacity: 1;
}

.dk-copy:hover {
    color: var(--dk-accent);
    border-color: var(--dk-accent);
}

.dk-copy[data-dk-copied=\"yes\"] {
    color: var(--dk-accent);
    border-color: var(--dk-accent);
    opacity: 1;
}

details.dk-more {
    margin-top: 0.6rem;
}

details.dk-more > summary {
    cursor: pointer;
    font: 500 0.82rem/1.4 system-ui, sans-serif;
    color: var(--dk-accent);
    list-style: none;
}

details.dk-more > summary::-webkit-details-marker {
    display: none;
}

details.dk-more > summary::before {
    content: \"▸ \";
}

details.dk-more[open] > summary::before {
    content: \"▾ \";
}

nav.dk-index {
    position: fixed;
    inset: 0 auto 0 0;
    width: 270px;
    padding: 1.1rem 0.9rem 2rem;
    overflow-y: auto;
    background: var(--dk-card);
    border-right: 1px solid var(--dk-border);
    font: 0.86rem/1.45 system-ui, sans-serif;
    z-index: 20;
}

body.dk-has-index {
    margin-left: 270px;
}

nav.dk-index h2 {
    margin: 0 0 0.6rem;
    font-size: 0.72rem;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--dk-muted);
}

nav.dk-index input {
    width: 100%;
    box-sizing: border-box;
    margin-bottom: 0.7rem;
    padding: 0.4rem 0.55rem;
    color: inherit;
    background: var(--dk-signature);
    border: 1px solid var(--dk-border);
    border-radius: 6px;
    font: inherit;
}

nav.dk-index input:focus-visible {
    outline: 2px solid var(--dk-accent);
    outline-offset: 1px;
}

nav.dk-index ul {
    margin: 0;
    padding: 0;
    list-style: none;
}

nav.dk-index li {
    margin: 0;
}

nav.dk-index a {
    display: block;
    padding: 0.28rem 0.45rem;
    color: var(--dk-fg);
    text-decoration: none;
    border-radius: 6px;
    border-left: 2px solid transparent;
    font-family: var(--dk-mono);
    font-size: 0.84rem;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

nav.dk-index a:hover {
    background: var(--dk-accent-soft);
}

nav.dk-index a[aria-current=\"true\"] {
    color: var(--dk-accent);
    border-left-color: var(--dk-accent);
    background: var(--dk-accent-soft);
}

nav.dk-index .dk-kind {
    color: var(--dk-muted);
    font: 0.66rem/1 system-ui, sans-serif;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-right: 0.35rem;
}

@media (max-width: 1080px) {
    nav.dk-index {
        position: static;
        width: auto;
        margin: 0 0 1rem;
        border-right: 0;
        border-bottom: 1px solid var(--dk-border);
    }

    body.dk-has-index {
        margin-left: 0;
    }
}

/* Diagrams: the image is the content, so it scales and it opens. */

img.image {
    display: block;
    max-width: 100%;
    height: auto;
    margin: 1rem auto;
    padding: 0.5rem;
    background: #ffffff;
    border: 1px solid var(--dk-border);
    border-radius: var(--dk-radius);
    cursor: zoom-in;
}

.dk-lightbox {
    position: fixed;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(8, 8, 12, 0.86);
    z-index: 50;
}

.dk-lightbox img {
    max-width: 92vw;
    max-height: 92vh;
    width: auto;
    height: auto;
    cursor: grab;
    transform-origin: center center;
    transition: transform 0.05s linear;
    background: #ffffff;
    border-radius: 4px;
    padding: 0.6rem;
}

.dk-lightbox .dk-zoom {
    position: absolute;
    top: 1rem;
    right: 1rem;
    display: flex;
    gap: 0.4rem;
}

.dk-lightbox button {
    font: 600 0.9rem/1 system-ui, sans-serif;
    min-width: 2.4rem;
    padding: 0.55rem 0.7rem;
    color: #f4f4f8;
    background: rgba(255, 255, 255, 0.12);
    border: 1px solid rgba(255, 255, 255, 0.25);
    border-radius: 8px;
    cursor: pointer;
}

.dk-lightbox button:hover {
    background: rgba(255, 255, 255, 0.22);
}

@media print {
    nav.dk-index,
    .dk-copy,
    .dk-lightbox {
        display: none !important;
    }

    body.dk-has-index {
        margin-left: 0;
    }

    dl.def-block {
        box-shadow: none;
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
 * reference documentation pleasant to read: an index of the definitions
 * down the side with a filter, a button that copies a signature, a folded
 * tail on the long ones, a theme that follows the reader, and diagrams
 * that open into something they can zoom into and drag.
 *
 * Everything is progressive: the page is complete without this file, and
 * every feature is one selector away from disappearing if the HTML it
 * looks for is not there.  No dependencies, no network, no globals.
 */

(function () {
    \"use strict\";

    var THEME_KEY = \"dokgen-theme\";
    var root = document.documentElement;

    function each(list, fn) {
        Array.prototype.forEach.call(list, fn);
    }

    function definitions() {
        return document.querySelectorAll(\"dl.def-block\");
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
        return text.trim();
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
        var body = block.querySelector(\":scope > dd\");
        var first = body && body.querySelector(\"p\");
        return first ? first.textContent.trim() : \"\";
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

    /* --- the tail of a long definition -------------------------------- */

    function foldLongDefinitions() {
        each(definitions(), function (block) {
            var body = block.querySelector(\":scope > dd\");
            /* A definition short enough to read is not folded: only the
               ones with a tail worth skipping get one. */
            if (!body || body.children.length <= 6) {
                return;
            }
            var details = document.createElement(\"details\");
            details.className = \"dk-more\";
            var summary = document.createElement(\"summary\");
            summary.textContent = \"Details\";
            details.appendChild(summary);
            while (body.children.length > 4) {
                details.appendChild(body.children[4]);
            }
            body.appendChild(details);
        });
    }

    /* --- the index of the definitions --------------------------------- */

    function buildIndex() {
        var blocks = definitions();
        if (!blocks.length) {
            return;
        }
        var nav = document.createElement(\"nav\");
        nav.className = \"dk-index\";
        nav.setAttribute(\"aria-label\", \"Definitions\");

        var title = document.createElement(\"h2\");
        title.textContent = \"Definitions\";
        nav.appendChild(title);

        var filter = document.createElement(\"input\");
        filter.type = \"search\";
        filter.placeholder = \"Filter\\u2026\";
        filter.setAttribute(\"aria-label\", \"Filter the definitions on this page\");
        nav.appendChild(filter);

        var list = document.createElement(\"ul\");
        var entries = [];

        each(blocks, function (block, position) {
            var anchor = block.previousElementSibling;
            while (anchor && !(anchor.tagName === \"A\" && anchor.id)) {
                anchor = anchor.previousElementSibling;
            }
            var id = anchor ? anchor.id : \"dk-definition-\" + position;
            if (!anchor) {
                block.id = id;
            }

            var item = document.createElement(\"li\");
            var link = document.createElement(\"a\");
            link.href = \"#\" + id;
            var kind = document.createElement(\"span\");
            kind.className = \"dk-kind\";
            kind.textContent = kindOf(block);
            link.appendChild(kind);
            link.appendChild(document.createTextNode(nameOf(block) || signatureOf(block)));
            item.appendChild(link);
            list.appendChild(item);

            entries.push({
                item: item,
                link: link,
                block: block,
                text: (kindOf(block) + \" \" + signatureOf(block) + \" \" + summaryOf(block)).toLowerCase()
            });
        });

        nav.appendChild(list);

        var theme = document.createElement(\"button\");
        theme.type = \"button\";
        theme.className = \"dk-copy\";
        theme.style.opacity = \"1\";
        theme.style.margin = \"1rem 0 0\";
        theme.textContent = \"Theme\";
        theme.title = \"Switch between a light and a dark page\";
        theme.addEventListener(\"click\", function () {
            applyTheme(root.getAttribute(\"data-dk-theme\") === \"dark\" ? \"light\" : \"dark\");
        });
        nav.appendChild(theme);

        filter.addEventListener(\"input\", function () {
            var needle = filter.value.trim().toLowerCase();
            entries.forEach(function (entry) {
                var matches = needle === \"\" || entry.text.indexOf(needle) !== -1;
                entry.item.hidden = !matches;
                entry.block.hidden = needle !== \"\" && !matches;
            });
        });

        document.body.insertBefore(nav, document.body.firstChild);
        document.body.classList.add(\"dk-has-index\");

        /* The entry of the definition being read is marked as it scrolls. */
        var active = null;
        var spy = function () {
            var best = null;
            entries.forEach(function (entry) {
                if (filter.value.trim() !== \"\") {
                    return;
                }
                var top = entry.block.getBoundingClientRect().top;
                if (top <= 120) {
                    best = entry;
                }
            });
            if (best === active) {
                return;
            }
            if (active) {
                active.link.removeAttribute(\"aria-current\");
            }
            active = best || entries[0];
            active.link.setAttribute(\"aria-current\", \"true\");
        };
        window.addEventListener(\"scroll\", spy, { passive: true });
        spy();
    }

    /* --- diagrams ----------------------------------------------------- */

    function addZoom() {
        each(document.querySelectorAll(\"img.image\"), function (image) {
            image.title = \"Click to zoom\";
            image.addEventListener(\"click\", function (event) {
                event.preventDefault();
                openLightbox(image);
            });
        });
    }

    function openLightbox(source) {
        var overlay = document.createElement(\"div\");
        overlay.className = \"dk-lightbox\";
        overlay.setAttribute(\"role\", \"dialog\");
        overlay.setAttribute(\"aria-modal\", \"true\");
        overlay.setAttribute(\"aria-label\", \"Diagram\");

        var image = document.createElement(\"img\");
        image.src = source.src;
        image.alt = source.alt || \"Diagram\";

        var controls = document.createElement(\"div\");
        controls.className = \"dk-zoom\";

        var scale = 1;
        var offsetX = 0;
        var offsetY = 0;
        var draw = function () {
            image.style.transform = \"translate(\" + offsetX + \"px, \" + offsetY + \"px) scale(\" + scale + \")\";
        };

        var zoom = function (factor) {
            scale = Math.min(8, Math.max(0.25, scale * factor));
            if (scale <= 1) {
                offsetX = 0;
                offsetY = 0;
            }
            draw();
        };

        [
            { label: \"+\", title: \"Zoom in\", action: function () { zoom(1.25); } },
            { label: \"\\u2212\", title: \"Zoom out\", action: function () { zoom(0.8); } },
            { label: \"1:1\", title: \"Actual size\", action: function () { scale = 1; offsetX = 0; offsetY = 0; draw(); } },
            { label: \"\\u2715\", title: \"Close\", action: function () { close(); } }
        ].forEach(function (control) {
            var button = document.createElement(\"button\");
            button.type = \"button\";
            button.textContent = control.label;
            button.title = control.title;
            button.addEventListener(\"click\", function (event) {
                event.stopPropagation();
                control.action();
            });
            controls.appendChild(button);
        });

        overlay.appendChild(image);
        overlay.appendChild(controls);

        var close = function () {
            overlay.remove();
            document.removeEventListener(\"keydown\", onKey);
        };

        var onKey = function (event) {
            if (event.key === \"Escape\") {
                close();
            } else if (event.key === \"+\" || event.key === \"=\") {
                zoom(1.25);
            } else if (event.key === \"-\") {
                zoom(0.8);
            }
        };

        overlay.addEventListener(\"click\", function (event) {
            if (event.target === overlay) {
                close();
            }
        });
        overlay.addEventListener(\"wheel\", function (event) {
            event.preventDefault();
            zoom(event.deltaY < 0 ? 1.12 : 0.89);
        }, { passive: false });

        var dragging = null;
        image.addEventListener(\"mousedown\", function (event) {
            event.preventDefault();
            dragging = { x: event.clientX - offsetX, y: event.clientY - offsetY };
            image.style.cursor = \"grabbing\";
        });
        window.addEventListener(\"mousemove\", function (event) {
            if (!dragging) {
                return;
            }
            offsetX = event.clientX - dragging.x;
            offsetY = event.clientY - dragging.y;
            draw();
        });
        window.addEventListener(\"mouseup\", function () {
            dragging = null;
            image.style.cursor = \"grab\";
        });

        document.addEventListener(\"keydown\", onKey);
        document.body.appendChild(overlay);
    }

    /* --- start -------------------------------------------------------- */

    applyTheme(preferredTheme());
    addCopyButtons();
    foldLongDefinitions();
    buildIndex();
    addZoom();
}());
")


;;; PROCEDURES

(define (write-assets! destination)
  "Write the stylesheet and the script into @var{destination}.

  @strong{destination} (string):
    The directory the chapter is written to.

  @strong{Result}:
    @file{dokgen.css} and @file{dokgen.js} are written there, beside the
    Texinfo, so that a manual which copies that directory beside its pages
    finds them where the chapter says they are."
  (save STYLESHEET (in-vicinity destination "dokgen.css"))
  (save SCRIPT (in-vicinity destination "dokgen.js")))
