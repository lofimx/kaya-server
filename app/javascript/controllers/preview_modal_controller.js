import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "content", "title", "visitLink"];

  open(event) {
    event.preventDefault();
    const url = event.currentTarget.dataset.previewUrl;
    const filename = event.currentTarget.dataset.previewFilename;
    const fileType = event.currentTarget.dataset.previewType;
    const originalUrl = event.currentTarget.dataset.previewOriginalUrl;

    this.titleTarget.textContent = filename;

    // Show/hide visit link for bookmarks
    if (originalUrl) {
      this.visitLinkTarget.href = originalUrl;
      this.visitLinkTarget.classList.remove("hidden");
    } else {
      this.visitLinkTarget.classList.add("hidden");
    }

    // Load content based on file type
    this.loadContent(url, fileType);

    this.modalTarget.classList.add("active");
    document.body.style.overflow = "hidden";

    // Focus the modal for keyboard navigation
    this.modalTarget.focus();
  }

  close() {
    this.modalTarget.classList.remove("active");
    document.body.style.overflow = "";
    this.contentTarget.innerHTML = "";
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close();
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  loadContent(url, fileType) {
    this.contentTarget.innerHTML =
      '<div class="preview-loading">Loading...</div>';

    switch (fileType) {
      case "note":
      case "text":
        this.loadNote(url);
        break;
      case "image":
        this.loadImage(url);
        break;
      case "pdf":
        this.loadPdf(url);
        break;
      case "bookmark":
        this.loadBookmark(url);
        break;
      default:
        this.contentTarget.innerHTML =
          '<div class="preview-unsupported">Preview not available for this file type.</div>';
    }
  }

  loadNote(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        this.contentTarget.innerHTML = `<pre class="preview-note">${this.escapeHtml(text)}</pre>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load note.</div>';
      });
  }

  loadImage(url) {
    const img = document.createElement("img");
    img.src = url;
    img.alt = "Preview";
    img.className = "preview-image";
    img.onload = () => {
      this.contentTarget.innerHTML = "";
      this.contentTarget.appendChild(img);
    };
    img.onerror = () => {
      this.contentTarget.innerHTML =
        '<div class="preview-error">Failed to load image.</div>';
    };
  }

  loadPdf(url) {
    // Use an iframe to render PDF with browser's built-in PDF viewer
    this.contentTarget.innerHTML = `<iframe src="${url}" class="preview-pdf" title="PDF Preview"></iframe>`;
  }

  loadBookmark(url) {
    fetch(url)
      .then((response) => response.text())
      .then((text) => {
        // For now, just show the URL file contents
        // In the future, this could show cached webpage content
        this.contentTarget.innerHTML = `<div class="preview-bookmark"><p class="preview-bookmark-notice">Webpage preview coming soon.</p><pre class="preview-bookmark-content">${this.escapeHtml(text)}</pre></div>`;
      })
      .catch(() => {
        this.contentTarget.innerHTML =
          '<div class="preview-error">Failed to load bookmark.</div>';
      });
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
