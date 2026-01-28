import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];

  connect() {
    this.boundRefocusInput = this.refocusInput.bind(this);
    document.addEventListener("turbo:frame-load", this.boundRefocusInput);
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundRefocusInput);
  }

  search() {
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => {
      this.element.requestSubmit();
    }, 300);
  }

  submitAndRefocus(event) {
    event.preventDefault();
    this.element.requestSubmit();
  }

  refocusInput() {
    if (this.hasInputTarget) {
      // Always place cursor at the end of the input
      this.inputTarget.focus();
      const len = this.inputTarget.value.length;
      this.inputTarget.setSelectionRange(len, len);
    }
  }
}
