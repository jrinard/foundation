import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["results", "formInput"];

  connect() {
    console.log("Stimulus Search Connected");
    this.formInputTarget.addEventListener(
      "input",
      this.handleChange.bind(this)
    );
  }

  handleChange(event) {
    if (this.formInputTarget.value.trim() !== "") {
      this.submitForm();
    }
  }

  search(event) {
    event.preventDefault();
    this.submitForm();
  }

  submitForm() {
    const query = this.formInputTarget.value;

    fetch(`/search?query=${query}`, {
      headers: { accept: "application/json" },
    })
      .then((response) => response.json())
      .then((data) => {
        // if (data.customers.length === 0 && data.contacts.length === 0) {
        if (data.customers.length === 0) {
          // If nothing found, display new customer button
          this.resultsTarget.innerHTML = this.renderNewCustomerButton();
        } else {
          this.resultsTarget.innerHTML = this.renderSearchResults(data);
        }
      });
  }

  renderNewCustomerButton() {
    const query = this.formInputTarget.value.trim();
    const link = document.createElement("a");
    // link.href = "/new_custom_lead";
    link.href = `/new_custom_lead?initial_query=${encodeURIComponent(query)}`;
    link.classList.add(
      "btn",
      "btn-long-home-nav",
      "btn-text-mobile-nav",
      "btn",
      "btn-md",
      "btn-warning",
      "btn",
      "btn-dark"
    );
    link.setAttribute("data-turbo-frame", "modal");
    link.textContent = "New Customer";

    const li = document.createElement("li");
    li.appendChild(link);

    return li.outerHTML;
  }

  renderSearchResults(data) {
    const itemsHTML = this.renderCCFunnel(data.customers);
    // const itemsHTML = this.renderCCFunnel(data.customers.concat(data.contacts));
    return itemsHTML;
  }

  renderCCFunnel(items) {
    return items
      .map((item) => {
        //! Disabled Searching for Contacts
        // if ("active" in item) {
        return this.renderCardCustomer(item);
        // } else {
        //   return this.renderCardContact(item);
        // }
      })
      .join("");
  }

  renderCardCustomer(customer) {
    const customerLink = this.renderEditCustomerLink(customer);

    return `
      <div class="search-results center ">
        ${customerLink}
      </div>
    `;
  }

  renderEditCustomerLink(customer) {
    const { id, name } = customer;
    const link = document.createElement("a");
    link.href = `/customers/${id}/existing_edit`;
    link.textContent = `${name}`;
    link.classList.add(
      "btn",
      "btn-long-home-nav",
      "btn-text-mobile-nav",
      "btn-md",
      "customer-card-search-dark"
    );
    link.setAttribute("data-turbo-frame", "modal");

    const statusParagraph = document.createElement("p");
    statusParagraph.textContent = this.getStatus(customer);
    statusParagraph.classList.add("tiny-text");
    link.appendChild(statusParagraph);

    // const type = document.createElement("p");
    // type.textContent = "Customer";
    // link.prepend(type);

    const li = document.createElement("li");
    li.appendChild(link);

    return li.outerHTML;
  }

  //   renderCardContact(contact) {
  //     const contactLink = this.renderEditContactLink(contact);

  //     return `
  //       <div class="search-results center ">
  //         ${contactLink}
  //       </div>
  //     `;
  //   }

  //   renderEditContactLink(contact) {
  //     const { firstname, lastname, customer_id } = contact;
  //     const link = document.createElement("a");
  //     link.href = `/customers/${customer_id}/edit`;
  //     link.textContent = `${firstname} ${lastname}`;
  //     link.classList.add(
  //       "btn",
  //       "btn-long-home-nav",
  //       "btn-text-mobile-nav",
  //       "btn-md",
  //       "customer-card-search-dark"
  //     );
  //     link.setAttribute("data-turbo-frame", "modal");

  //     const emailParagraph = document.createElement("p");
  //     emailParagraph.textContent = contact.email;
  //     link.appendChild(emailParagraph);

  //     const type = document.createElement("p");
  //     type.textContent = "Contact";
  //     link.prepend(type);

  //     const li = document.createElement("li");
  //     li.appendChild(link);

  //     return li.outerHTML;
  //   }

  getStatus(item) {
    if (item.active && item.list_id !== null) {
      return "Current Client in Leads";
    } else if (item.active) {
      return "Current Client";
    } else if (item.archived) {
      return "Archived";
    } else if (item.active === false && item.list_id !== null) {
      return "Lead";
    } else {
      return "Status Not Available";
    }
  }
}
