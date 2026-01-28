# Prompt Drafts

If you are an LLM, maybe don't bother reading this file. It's for human drafting to talk to you.

## Basic Full-Text Search

The search should look beyond filenames, into the contents of each file with with the `amatch` gem and Jaro-Winkler distance. For example, the contents of Markdown (notes) file/anga should be searched for matches directly and PDF files/anga should be searched using the `pdf-reader` gem. Abstract search into an object model with an entry point in [@services](file:///home/steven/work/deobald/kaya-server/app/services) but which delegates to leaf objects in [@models](file:///home/steven/work/deobald/kaya-server/app/models) beyond orchestration. For now, it will not be possible to search bookmarks this way, but you should create a `BookmarkSearch` service object similar to the service objects for notes and PDFs which just returns a match based on filename, for now. Eventually, we'll add a feature to pre-cache webpages alongside the anga files so that the bookmarks can be searched locally as well.

### Bug: matching common words

The search should not match heavily-reused words, such as "note" or "bookmark" from filenames. These are automatically created by clients and will be seen often. For example, "Notwithstanding" should match a PDF containing that exact text, but should not match `2026-01-21T164145-note.md` due to fuzzy search. If the user searches exactly for "note" or "bookmark", then circumvent this rule and return `.md` or `.url`, as they are probably expecting to see.

### Bug: search box focus is jumping

At a medium typing speed, the search box focus seems to "jump" into the middle of the existing text. I believe this is happening because of the search box being refocused. While typing the word "Notwithstanding", the cursor jumped multiple times within the textbox to produce "nwithtandingsot"

Why does the textbox lose focus on search at all? Since this is incremental search, it should happen in the background as the user types. Instead of attempting to retain cursor position OR default to refocusing at the end of the search box, is it possible to avoid the search box losing focus at all so the user can just type naturally?

When searching for "pdf", the PDF file/anga is not returned. Similar to "note" and "bookmark", "pdf", "png", and other filename extensions should normally not be matched... but they should match when the user types exactly "pdf" or ".pdf" (for example).

## Preview

Clicking on a tile in the search results should open that file. If it's a URL, open a modal overlay which will contain the contents of the webpage (once we cache it), with an option labelled "visit original page" that, when clicked, opens that URL in a new tab/window. If it's a note (.md), show the text of that note in a modal overlay so the user can read and copy it. If it's an image, show the image in a similar modal overlay. If it's a PDF, render the PDF in a modal overlay so the user can scroll through the pages, read, and copy text. Follow the GNOME HIG for the modal overlay, as per AGENTS.md.

### Refactor: Extract FileType model

Extract a `FileType` model which is used to wrap behaviour like `File.extname` and mapping to `preview_type` in index.html.erb. Anywhere in the codebase where `.md`, `.url`, `.pdf` and so on are hard-coded, the associated behaviour should move into the `FileType` model.
