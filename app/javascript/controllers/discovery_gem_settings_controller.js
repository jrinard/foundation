import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["panel", "toggle"];

  connect() {
    const params = new URLSearchParams(window.location.search);
    const shouldOpen =
      sessionStorage.getItem("mountainGemsLibraryOpen") === "1" ||
      params.get("mountain_library") === "1";

    sessionStorage.removeItem("mountainGemsLibraryOpen");

    if (params.get("mountain_library") === "1") {
      const url = new URL(window.location.href);
      url.searchParams.delete("mountain_library");
      window.history.replaceState({}, "", url);
    }

    this.setCollapsed(!shouldOpen);
  }

  toggleLibrary(event) {
    event?.preventDefault();
    if (!this.hasPanelTarget) return;

    const collapsed = !this.panelTarget.classList.contains("is-collapsed");
    this.setCollapsed(collapsed);
  }

  setCollapsed(collapsed) {
    if (!this.hasPanelTarget) return;

    this.panelTarget.classList.toggle("is-collapsed", collapsed);

    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("is-collapsed", collapsed);
      this.toggleTarget.setAttribute("aria-expanded", collapsed ? "false" : "true");
    }
  }
}
