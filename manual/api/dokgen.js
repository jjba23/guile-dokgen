/* dokgen.js --- the behaviour of an API chapter.
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
    "use strict";

    var THEME_KEY = "dokgen-theme";
    var root = document.documentElement;
    var body = document.body;
    var phone = window.matchMedia("(max-width: 1024px)");

    function each(list, fn) {
        Array.prototype.forEach.call(list, fn);
    }

    function definitions() {
        return document.querySelectorAll("dl.def-block");
    }

    function tidy(text) {
        return (text || "")
            .replace(/\s+/g, " ")
            .replace(/\s*¶+$/, "")
            .replace(/^\d+(\.\d+)*\s+/, "")
            .trim();
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
        return text.replace(/\s+/g, " ").trim();
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
        var statement = block.querySelector(":scope > dd");
        var first = statement && statement.querySelector("p");
        return first ? first.textContent.replace(/\s+/g, " ").trim() : "";
    }

    function reduceMotion() {
        return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
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
            button.setAttribute("aria-label", "Copy the signature of " + signature);
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

    /* --- the index ---------------------------------------------------- */

    function targetOf(link) {
        var href = link.getAttribute("href") || "";
        if (href.charAt(0) !== "#") {
            return null;
        }
        return document.getElementById(href.slice(1));
    }

    function anchorTarget(block, position) {
        var anchor = block.previousElementSibling;
        while (anchor && !(anchor.tagName === "A" && anchor.id)) {
            anchor = anchor.previousElementSibling;
        }
        if (anchor) {
            return anchor;
        }
        var id = "dk-definition-" + position;
        block.id = id;
        return block;
    }

    function buildIndex() {
        var toc = document.querySelector("ul.mini-toc");
        var blocks = definitions();
        if (!toc && !blocks.length) {
            return null;
        }

        var nav = document.createElement("nav");
        nav.className = "dk-index";
        nav.id = "dk-index";
        nav.setAttribute("aria-label", "Contents");

        var head = document.createElement("div");
        head.className = "dk-index-head";
        var title = document.createElement("h2");
        title.textContent = "Contents";
        var close = createIcon("✕", "Close the contents");
        close.className += " dk-index-close";
        head.appendChild(title);
        head.appendChild(close);
        nav.appendChild(head);

        var filter = document.createElement("input");
        filter.type = "search";
        filter.className = "dk-index-filter";
        filter.placeholder = "Filter the contents…";
        filter.setAttribute("aria-label", "Filter the contents of this page");
        nav.appendChild(filter);

        var scroll = document.createElement("div");
        scroll.className = "dk-index-scroll";
        var list = document.createElement("ul");
        list.className = "dk-nav";
        var empty = document.createElement("p");
        empty.className = "dk-index-empty";
        empty.textContent = "Nothing here matches.";
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
            var item = document.createElement("li");
            var link = document.createElement("a");
            link.className = "dk-def-link";
            link.href = "#" + anchor.id;
            link.title = signatureOf(block) || name;
            var kind = document.createElement("span");
            kind.className = "dk-kind";
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
                text: (kindOf(block) + " " + signatureOf(block) + " " + summaryOf(block)).toLowerCase()
            };
        }

        function openGroup(group, open) {
            if (!group.list) {
                return;
            }
            group.list.hidden = !open;
            group.toggle.setAttribute("aria-expanded", open ? "true" : "false");
            group.li.classList.toggle("dk-open", open);
        }

        function headingLevel(heading) {
            /* The top node is an unnumbered chapter, not a container for
               the numbered ones: the index lists it beside them. */
            if (heading.tagName === "H1") {
                return 2;
            }
            if (heading.classList.contains("chapter")) {
                return 2;
            }
            return heading.classList.contains("section") ? 3 : 4;
        }

        function headingTarget(heading) {
            var box = heading.parentElement;
            while (box && !box.id) {
                box = box.parentElement;
            }
            var target = box && box.id ? box : heading;
            if (!target.id) {
                target.id = "dk-" + tidy(heading.textContent).toLowerCase().replace(/[^a-z0-9]+/g, "-");
            }
            return target;
        }

        function headingGroup(heading) {
            var label = tidy(heading.textContent);
            var item = document.createElement("li");
            item.className = "dk-group";
            var row = document.createElement("div");
            row.className = "dk-row";
            var target = headingTarget(heading);
            var anchor = document.createElement("a");
            anchor.href = "#" + target.id;
            anchor.textContent = label;
            anchor.title = label;
            row.appendChild(anchor);
            item.appendChild(row);
            var children = document.createElement("ul");
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
                var spacer = document.createElement("span");
                spacer.className = "dk-toggle dk-toggle-empty";
                group.row.insertBefore(spacer, group.link);
                return;
            }
            var toggle = document.createElement("button");
            toggle.type = "button";
            toggle.className = "dk-toggle";
            toggle.setAttribute("aria-expanded", "false");
            toggle.setAttribute("aria-label", "Show what " + group.link.textContent + " contains");
            toggle.addEventListener("click", function () {
                openGroup(group, group.list.hidden);
            });
            group.row.insertBefore(toggle, group.link);
            group.toggle = toggle;
        }

        /* A page that holds its own sections is indexed from its
           headings, which is the whole page even in a single-page manual. */
        function buildTree() {
            var stack = [];
            each(document.querySelectorAll("h1, h2.chapter, h3.section, h4.subsection, dl.def-block"), function (node) {
                if (node.classList.contains("settitle")) {
                    return;
                }
                if (node.tagName === "DL") {
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
            var item = document.createElement("li");
            item.className = "dk-group";
            var row = document.createElement("div");
            row.className = "dk-row";
            var group = { li: item, row: row, link: null, target: target, label: label.toLowerCase(), entries: [], list: null, toggle: null, parent: null, depth: 0 };

            if (target) {
                each(target.querySelectorAll("dl.def-block"), function (block) {
                    var entry = entryFor(block);
                    if (!entry) {
                        return;
                    }
                    entry.group = group;
                    group.entries.push(entry);
                });
            }

            if (group.entries.length) {
                var toggle = document.createElement("button");
                toggle.type = "button";
                toggle.className = "dk-toggle";
                toggle.setAttribute("aria-expanded", "false");
                toggle.setAttribute("aria-label", "Show what " + label + " contains");
                toggle.addEventListener("click", function () {
                    openGroup(group, group.list.hidden);
                });
                row.appendChild(toggle);
                group.toggle = toggle;
                group.list = document.createElement("ul");
                group.list.hidden = true;
                each(group.entries, function (entry) {
                    group.list.appendChild(entry.li);
                });
            } else {
                var spacer = document.createElement("span");
                spacer.className = "dk-toggle dk-toggle-empty";
                row.appendChild(spacer);
            }

            var anchor = document.createElement("a");
            anchor.href = link.getAttribute("href");
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
        if (document.querySelector(".section-level-extent, .subsection-level-extent")) {
            buildTree();
        } else if (toc) {
            each(toc.children, function (item) {
                var link = item.querySelector("a");
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
                active.link.removeAttribute("aria-current");
            }
            active = item;
            item.link.setAttribute("aria-current", "location");
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
        each(document.querySelectorAll(".top-level-extent, .chapter-level-extent, .section-level-extent, .subsection-level-extent, a.anchor, dl.def-block"), function (target) {
            if (byTarget.has(target)) {
                watched.push(target);
            }
        });
        function mark() {
            // The bar is inserted after the index, so it is looked up now.
            var bar = document.querySelector(".dk-bar");
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
            window.addEventListener("scroll", function () {
                if (!waiting) {
                    waiting = true;
                    window.requestAnimationFrame(later);
                }
            }, { passive: true });
            window.addEventListener("resize", later);
            mark();
        }

        filter.addEventListener("input", function () {
            var needle = filter.value.trim().toLowerCase();
            var found = 0;
            each(groups, function (group) {
                var shown = 0;
                each(group.entries, function (entry) {
                    var hit = needle === "" || entry.text.indexOf(needle) !== -1;
                    entry.li.hidden = !hit;
                    if (hit) {
                        shown += 1;
                    }
                });
                var named = needle !== "" && group.label.indexOf(needle) !== -1;
                group.li.hidden = needle !== "" && !named && shown === 0;
                if (group.list) {
                    openGroup(group, needle !== "");
                }
                if (!group.li.hidden) {
                    found += 1;
                }
            });
            each(entries, function (entry) {
                if (entry.group) {
                    return;
                }
                var hit = needle === "" || entry.text.indexOf(needle) !== -1;
                entry.li.hidden = !hit;
                if (!entry.li.hidden) {
                    found += 1;
                }
            });
            /* A matching definition can sit under a group whose own title
               does not match: the path to it is shown with it. */
            if (needle !== "") {
                for (var index = groups.length - 1; index >= 0; index -= 1) {
                    var group = groups[index];
                    if (!group.li.hidden && group.parent) {
                        group.parent.li.hidden = false;
                    }
                }
            }
            empty.hidden = !(needle !== "" && found === 0);
            /* Clearing the filter should not hide the reader's place. */
            if (needle === "" && active && active.group) {
                openGroup(active.group, true);
            }
        });

        return { nav: nav, filter: filter, close: close, groups: groups };
    }

    /* --- the bar and the drawer --------------------------------------- */

    function createIcon(label, description) {
        var button = document.createElement("button");
        button.type = "button";
        button.className = "dk-icon";
        button.textContent = label;
        button.title = description;
        button.setAttribute("aria-label", description);
        return button;
    }

    function pageTitle() {
        var heading = document.querySelector("h2.chapter, h3.section, h4.subsection, h1");
        var title = heading ? tidy(heading.textContent) : "";
        if (!title) {
            title = tidy(document.title);
        }
        return title || "Contents";
    }

    function buildBar(index) {
        var bar = document.createElement("header");
        bar.className = "dk-bar";

        var menu = createIcon("☰", "Open the contents");
        menu.className += " dk-menu";
        menu.setAttribute("aria-controls", index.nav.id);
        menu.setAttribute("aria-expanded", "false");

        var title = document.createElement("span");
        title.className = "dk-bar-title";
        title.textContent = pageTitle();

        var top = createIcon("↑", "Back to the top");
        top.className += " dk-top";
        top.hidden = true;

        var theme = createIcon("◐", "Switch between a light and a dark page");
        theme.className += " dk-theme";

        bar.appendChild(menu);
        bar.appendChild(title);
        bar.appendChild(top);
        bar.appendChild(theme);

        theme.addEventListener("click", function () {
            applyTheme(root.getAttribute("data-dk-theme") === "dark" ? "light" : "dark");
        });
        top.addEventListener("click", function () {
            window.scrollTo({ top: 0, behavior: reduceMotion() ? "auto" : "smooth" });
        });
        window.addEventListener("scroll", function () {
            top.hidden = window.scrollY < 640;
        }, { passive: true });

        return { bar: bar, menu: menu, theme: theme, top: top };
    }

    function isTyping(element) {
        if (!element) {
            return false;
        }
        var tag = element.tagName;
        return tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" || element.isContentEditable;
    }

    function wireDrawer(chrome, index) {
        var scrim = document.createElement("div");
        scrim.className = "dk-scrim";
        scrim.hidden = true;

        function open() {
            if (!phone.matches) {
                return;
            }
            body.classList.add("dk-index-open");
            chrome.menu.setAttribute("aria-expanded", "true");
            scrim.hidden = false;
            index.filter.focus();
        }

        function close() {
            var wasOpen = body.classList.contains("dk-index-open");
            body.classList.remove("dk-index-open");
            chrome.menu.setAttribute("aria-expanded", "false");
            scrim.hidden = true;
            if (wasOpen) {
                chrome.menu.focus();
            }
        }

        chrome.menu.addEventListener("click", function () {
            if (body.classList.contains("dk-index-open")) {
                close();
            } else {
                open();
            }
        });
        index.close.addEventListener("click", close);
        scrim.addEventListener("click", close);
        each(index.nav.querySelectorAll("a"), function (link) {
            link.addEventListener("click", close);
        });
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape" && body.classList.contains("dk-index-open")) {
                close();
            } else if (event.key === "/" && !isTyping(event.target)) {
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
            phone.addEventListener("change", onResize);
        } else {
            phone.addListener(onResize);
        }
        return scrim;
    }

    function buildSkip() {
        var target = document.querySelector(".chapter-level-extent[id], .section-level-extent[id]");
        if (!target) {
            return null;
        }
        target.setAttribute("tabindex", "-1");
        var link = document.createElement("a");
        link.className = "dk-skip";
        link.href = "#" + target.id;
        link.textContent = "Skip to the content";
        link.addEventListener("click", function () {
            target.focus();
        });
        return link;
    }

    /* --- diagrams ----------------------------------------------------- */

    var MERMAID_MARKER = "%%dokgen-mermaid";

    function diagramSource(pre) {
        var lines = pre.textContent.replace(/\s+$/, "").split("\n");
        if (lines.length < 2) {
            return null;
        }
        if (lines[lines.length - 1].replace(/\s/g, "") !== MERMAID_MARKER) {
            return null;
        }
        lines.pop();
        return lines.join("\n");
    }

    function loadMermaid(done) {
        if (window.mermaid) {
            done();
            return;
        }
        var base = "";
        each(document.scripts, function (tag) {
            if (tag.src && /dokgen\.js(?:\?|$)/.test(tag.src)) {
                base = tag.src.replace(/[^\/]*$/, "");
            }
        });
        var script = document.createElement("script");
        script.src = base + "dokgen-mermaid.js";
        script.onload = done;
        /* A page built without the bundled renderer keeps the source. */
        script.onerror = function () {};
        document.head.appendChild(script);
    }

    function renderDiagrams() {
        var pending = [];
        each(document.querySelectorAll("pre"), function (pre) {
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
                    securityLevel: "strict",
                    theme: "neutral"
                });
            } catch (error) {
                restore();
                return;
            }
            each(pending, function (item) {
                var box = document.createElement("div");
                box.className = "mermaid dk-diagram";
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
        body.classList.add("dk-has-index");
        /* A split manual links between pages in its navigation rows; a
           single-page manual repeats links to itself before every
           section, and the index already offers those. */
        if (!document.querySelector(".nav-panel a[href$='.html']")) {
            body.classList.add("dk-flat");
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
        window.dispatchEvent(new Event("scroll"));
    }
}());
