/* dokgen.js --- the behaviour of an API chapter.
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
    "use strict";

    var THEME_KEY = "dokgen-theme";
    var root = document.documentElement;

    function each(list, fn) {
        Array.prototype.forEach.call(list, fn);
    }

    function definitions() {
        return document.querySelectorAll("dl.def-block");
    }

    function signatureOf(block) {
        var line = block.querySelector(":scope > dt");
        if (!line) {
            return "";
        }
        var name = line.querySelector(".def-name");
        var args = line.querySelector(".def-var-arguments");
        var text = (name ? name.textContent : line.textContent) || "";
        if (args && args.textContent.trim()) {
            text += " " + args.textContent.trim();
        }
        return text.trim();
    }

    function nameOf(block) {
        var name = block.querySelector(":scope > dt .def-name");
        return name ? name.textContent.trim() : "";
    }

    function kindOf(block) {
        var kind = block.querySelector(".category-def");
        return kind ? kind.textContent.replace(/[:\s]+$/, "").trim() : "";
    }

    function summaryOf(block) {
        var body = block.querySelector(":scope > dd");
        var first = body && body.querySelector("p");
        return first ? first.textContent.trim() : "";
    }

    /* --- the theme ---------------------------------------------------- */

    function preferredTheme() {
        var saved = null;
        try {
            saved = window.localStorage.getItem(THEME_KEY);
        } catch (error) {
            saved = null;
        }
        if (saved === "light" || saved === "dark") {
            return saved;
        }
        return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }

    function applyTheme(theme) {
        root.setAttribute("data-dk-theme", theme);
        try {
            window.localStorage.setItem(THEME_KEY, theme);
        } catch (error) {
            /* A reader with storage turned off gets the theme for the visit. */
        }
    }

    /* --- copyable signatures ------------------------------------------ */

    function addCopyButtons() {
        each(definitions(), function (block) {
            var line = block.querySelector(":scope > dt");
            var signature = signatureOf(block);
            if (!line || !signature) {
                return;
            }
            var button = document.createElement("button");
            button.type = "button";
            button.className = "dk-copy";
            button.textContent = "copy";
            button.title = "Copy " + signature;
            button.addEventListener("click", function () {
                var wrote = navigator.clipboard && navigator.clipboard.writeText(signature);
                if (wrote && wrote.then) {
                    wrote.then(function () {
                        button.textContent = "copied";
                        button.setAttribute("data-dk-copied", "yes");
                        window.setTimeout(function () {
                            button.textContent = "copy";
                            button.removeAttribute("data-dk-copied");
                        }, 1400);
                    })["catch"](function () {
                        button.textContent = "copy failed";
                    });
                }
            });
            line.appendChild(button);
        });
    }

    /* --- the tail of a long definition -------------------------------- */

    function foldLongDefinitions() {
        each(definitions(), function (block) {
            var body = block.querySelector(":scope > dd");
            /* A definition short enough to read is not folded: only the
               ones with a tail worth skipping get one. */
            if (!body || body.children.length <= 6) {
                return;
            }
            var details = document.createElement("details");
            details.className = "dk-more";
            var summary = document.createElement("summary");
            summary.textContent = "Details";
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
        var nav = document.createElement("nav");
        nav.className = "dk-index";
        nav.setAttribute("aria-label", "Definitions");

        var title = document.createElement("h2");
        title.textContent = "Definitions";
        nav.appendChild(title);

        var filter = document.createElement("input");
        filter.type = "search";
        filter.placeholder = "Filter\u2026";
        filter.setAttribute("aria-label", "Filter the definitions on this page");
        nav.appendChild(filter);

        var list = document.createElement("ul");
        var entries = [];

        each(blocks, function (block, position) {
            var anchor = block.previousElementSibling;
            while (anchor && !(anchor.tagName === "A" && anchor.id)) {
                anchor = anchor.previousElementSibling;
            }
            var id = anchor ? anchor.id : "dk-definition-" + position;
            if (!anchor) {
                block.id = id;
            }

            var item = document.createElement("li");
            var link = document.createElement("a");
            link.href = "#" + id;
            var kind = document.createElement("span");
            kind.className = "dk-kind";
            kind.textContent = kindOf(block);
            link.appendChild(kind);
            link.appendChild(document.createTextNode(nameOf(block) || signatureOf(block)));
            item.appendChild(link);
            list.appendChild(item);

            entries.push({
                item: item,
                link: link,
                block: block,
                text: (kindOf(block) + " " + signatureOf(block) + " " + summaryOf(block)).toLowerCase()
            });
        });

        nav.appendChild(list);

        var theme = document.createElement("button");
        theme.type = "button";
        theme.className = "dk-copy";
        theme.style.opacity = "1";
        theme.style.margin = "1rem 0 0";
        theme.textContent = "Theme";
        theme.title = "Switch between a light and a dark page";
        theme.addEventListener("click", function () {
            applyTheme(root.getAttribute("data-dk-theme") === "dark" ? "light" : "dark");
        });
        nav.appendChild(theme);

        filter.addEventListener("input", function () {
            var needle = filter.value.trim().toLowerCase();
            entries.forEach(function (entry) {
                var matches = needle === "" || entry.text.indexOf(needle) !== -1;
                entry.item.hidden = !matches;
                entry.block.hidden = needle !== "" && !matches;
            });
        });

        document.body.insertBefore(nav, document.body.firstChild);
        document.body.classList.add("dk-has-index");

        /* The entry of the definition being read is marked as it scrolls. */
        var active = null;
        var spy = function () {
            var best = null;
            entries.forEach(function (entry) {
                if (filter.value.trim() !== "") {
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
                active.link.removeAttribute("aria-current");
            }
            active = best || entries[0];
            active.link.setAttribute("aria-current", "true");
        };
        window.addEventListener("scroll", spy, { passive: true });
        spy();
    }

    /* --- diagrams ----------------------------------------------------- */

    function addZoom() {
        each(document.querySelectorAll("img.image"), function (image) {
            image.title = "Click to zoom";
            image.addEventListener("click", function (event) {
                event.preventDefault();
                openLightbox(image);
            });
        });
    }

    function openLightbox(source) {
        var overlay = document.createElement("div");
        overlay.className = "dk-lightbox";
        overlay.setAttribute("role", "dialog");
        overlay.setAttribute("aria-modal", "true");
        overlay.setAttribute("aria-label", "Diagram");

        var image = document.createElement("img");
        image.src = source.src;
        image.alt = source.alt || "Diagram";

        var controls = document.createElement("div");
        controls.className = "dk-zoom";

        var scale = 1;
        var offsetX = 0;
        var offsetY = 0;
        var draw = function () {
            image.style.transform = "translate(" + offsetX + "px, " + offsetY + "px) scale(" + scale + ")";
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
            { label: "+", title: "Zoom in", action: function () { zoom(1.25); } },
            { label: "\u2212", title: "Zoom out", action: function () { zoom(0.8); } },
            { label: "1:1", title: "Actual size", action: function () { scale = 1; offsetX = 0; offsetY = 0; draw(); } },
            { label: "\u2715", title: "Close", action: function () { close(); } }
        ].forEach(function (control) {
            var button = document.createElement("button");
            button.type = "button";
            button.textContent = control.label;
            button.title = control.title;
            button.addEventListener("click", function (event) {
                event.stopPropagation();
                control.action();
            });
            controls.appendChild(button);
        });

        overlay.appendChild(image);
        overlay.appendChild(controls);

        var close = function () {
            overlay.remove();
            document.removeEventListener("keydown", onKey);
        };

        var onKey = function (event) {
            if (event.key === "Escape") {
                close();
            } else if (event.key === "+" || event.key === "=") {
                zoom(1.25);
            } else if (event.key === "-") {
                zoom(0.8);
            }
        };

        overlay.addEventListener("click", function (event) {
            if (event.target === overlay) {
                close();
            }
        });
        overlay.addEventListener("wheel", function (event) {
            event.preventDefault();
            zoom(event.deltaY < 0 ? 1.12 : 0.89);
        }, { passive: false });

        var dragging = null;
        image.addEventListener("mousedown", function (event) {
            event.preventDefault();
            dragging = { x: event.clientX - offsetX, y: event.clientY - offsetY };
            image.style.cursor = "grabbing";
        });
        window.addEventListener("mousemove", function (event) {
            if (!dragging) {
                return;
            }
            offsetX = event.clientX - dragging.x;
            offsetY = event.clientY - dragging.y;
            draw();
        });
        window.addEventListener("mouseup", function () {
            dragging = null;
            image.style.cursor = "grab";
        });

        document.addEventListener("keydown", onKey);
        document.body.appendChild(overlay);
    }

    /* --- start -------------------------------------------------------- */

    applyTheme(preferredTheme());
    addCopyButtons();
    foldLongDefinitions();
    buildIndex();
    addZoom();
}());
