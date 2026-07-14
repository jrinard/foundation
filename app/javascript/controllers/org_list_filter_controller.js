import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["query", "card", "noResults"];

  filter() {
    const term = this.queryTarget.value.trim().toLowerCase();
    let visibleCount = 0;

    this.cardTargets.forEach((card) => {
      const haystack = card.dataset.filterText || "";
      const match = term === "" || haystack.includes(term);
      card.hidden = !match;
      if (match) visibleCount += 1;
    });

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.hidden = visibleCount > 0;
    }
  }
}
