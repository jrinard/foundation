//This is the place to put main javascript

import "@hotwired/turbo-rails";
import "./controllers";
// import * as bootstrap from "bootstrap";
//! node_modules version trying not to use.
// import "bootstrap";

import "./test";

import { Application } from "@hotwired/stimulus";

const application = Application.start();

// Import each controller dynamically and register it with the application
(async () => {
  const controllerContext = require.context("../controllers", true, /\.js$/);
  for (const controllerModuleKey of controllerContext.keys()) {
    const { default: Controller } = await import(controllerModuleKey);
    const controllerName = controllerModuleKey.replace(/^\.\/(.*)\.js$/, "$1");
    application.register(controllerName, Controller);
  }
})();

console.log("=== Stimulus JavaScript Loaded");

addEventListener("direct-upload:initialize", (event) => {
  const { target, detail } = event;
  const { id, file } = detail;
  target.insertAdjacentHTML(
    "beforebegin",
    `
      <div id="direct-upload-${id}" class="direct-upload direct-upload--pending">
        <div id="direct-upload-progress-${id}" class="direct-upload__progress" style="width: 0%"></div>
        <span class="direct-upload__filename">${file.name}</span>
      </div>
    `
  );
});

addEventListener("direct-upload:start", (event) => {
  const { id } = event.detail;
  const element = document.getElementById(`direct-upload-${id}`);
  element.classList.remove("direct-upload--pending");
});

addEventListener("direct-upload:progress", (event) => {
  const { id, progress } = event.detail;
  const progressElement = document.getElementById(
    `direct-upload-progress-${id}`
  );
  progressElement.style.width = `${progress}%`;
});

addEventListener("direct-upload:error", (event) => {
  event.preventDefault();
  const { id, error } = event.detail;
  const element = document.getElementById(`direct-upload-${id}`);
  element.classList.add("direct-upload--error");
  element.setAttribute("title", error);
});

addEventListener("direct-upload:end", (event) => {
  const { id } = event.detail;
  const element = document.getElementById(`direct-upload-${id}`);
  element.classList.add("direct-upload--complete");
});

// Turbolinks test
// $(document).on('turbolinks:load', function (){ alert("turbolinks on load event works") });

//Flash Message Fade
$("document").ready(function () {
  setTimeout(function () {
    $("#flash").fadeOut();
  }, 3000);
});

$("document").ready(function () {
  setTimeout(function () {
    $("#flash-m").fadeOut();
  }, 3000);
});

// Depreciating for 2.0 Toggle details and hide the others
// $(document).on("turbolinks:load", function () {
//   $(".edit_toggle").on("click", function () {
//     var $details = $(this).next(".edit_f");
//     $details.toggle(); //toggle the current one
//     $(".edit_f").not($details).slideUp(); //hide the others
//   });
// });

// // Toggle Hide on Templates
// $(".item-content").show();
// $(document).on("click", ".item-title", function (e) {
//   e.preventDefault();
//   $(this).prev(".item-content").toggle();
//   $(".item-content-old").hide();
// });

// //Toggle details and hide the others
// $(document).on("turbolinks:load", function () {
//   $(".edit_family").on("click", function () {
//     var $details = $(this).toggle().next(".edit_f");
//     $details.toggle(); //toggle the current one
//     $(".edit_f").not($details).slideUp(); //hide the others
//   });
// });

// //Toggle details and hide the others
// $(document).on("turbolinks:load", function () {
//   $(".edit_note").on("click", function () {
//     var $details = $(this).toggle().next(".edit_n");
//     $details.toggle(); //toggle the current one
//     $(".edit_n").not($details).slideUp(); //hide the others
//   });
// });

//Works. But #note-toggle-edit can't be dynamic so it works only on one at a time not a loop. onClick = noteToggle(p)
function noteToggle(p) {
  var x = document.getElementById("note-toggle-" + p);
  if (x.style.display === "none") {
    x.style.display = "block";
    console.log("main on ");
  } else {
    x.style.display = "none";
    console.log("main off");
  }
  var y = document.getElementById("note-toggle-edit-" + p);
  if (y.style.display === "block") {
    y.style.display = "none";
    console.log("edit off");
  } else {
    y.style.display = "block";
    console.log("edit on");
  }
}

//Copy TEXT - Phone
// document.addEventListener("turbo:load", function () {
//   function copyPhone(c) {
//     console.log("=== copyphone");
//     //TODO going to need top turbo:load
//     /* Get the text field */
//     var copyText = document.getElementById("copyPhone_" + c);
//     /* Select the text field */
//     copyText.select();
//     copyText.setSelectionRange(0, 99999); /* For mobile devices */
//     /* Copy the text inside the text field */
//     navigator.clipboard.writeText(copyText.value);
//     /* Alert the copied text */
//     // alert("Copied the text: " + copyText.value);
//   }
// });

document.addEventListener("turbo:load", function () {
  function copyPhone(imageElement) {
    // Get the value of data-id attribute from the image element
    var cId = imageElement.getAttribute("data-id");
    console.log("=== copyphone, c.id:", cId);

    //TODO going to need top turbo:load
    /* Get the text field */
    var copyText = document.getElementById("copyPhone_" + cId);
    /* Select the text field */
    copyText.select();
    copyText.setSelectionRange(0, 99999); /* For mobile devices */
    /* Copy the text inside the text field */
    navigator.clipboard.writeText(copyText.value);
    /* Alert the copied text */
    // alert("Copied the text: " + copyText.value);
  }
});

//Copy TEXT - Email - //TODO going to need top turbo:load
function copyEmail(c) {
  /* Get the text field */
  var copyText = document.getElementById("copyEmail_" + c);
  /* Select the text field */
  copyText.select();
  copyText.setSelectionRange(0, 99999); /* For mobile devices */
  /* Copy the text inside the text field */
  // navigator.clipboard.writeText(copyText.value);
  navigator.clipboard.writeText(copyText.value);
  /* Alert the copied text */
  // alert("Copied the text: " + copyText.value);
}

// Infinite Scroll on customers
$(document).ready(function () {
  if ($(".pagination").length) {
    $(window).scroll(function () {
      var url = $(".pagination .next_page").attr("href");
      if (
        url &&
        $(window).scrollTop() > $(document).height() - $(window).height() - 1
      ) {
        $(".pagination").text("Please Wait...");
        return $.getScript(url);
      }
    });
    return $(window).scroll();
  }
});

//OpenCity TABS V2 - working
// application.js
document.addEventListener("turbo:load", function () {
  const tabLinks = document.querySelectorAll(".tablinks");
  tabLinks.forEach(function (tabLink) {
    tabLink.addEventListener("click", function (event) {
      const specifictab = this.dataset.tab;
      openCity(event, specifictab);
    });
  });
});

function openCity(evt, specifictab) {
  // Declare all variables
  var i, tabcontent, tablinks;

  // Get all elements with class="tabcontent" and hide them
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }

  // Get all elements with class="tablinks" and remove the class "active"
  tablinks = document.getElementsByClassName("tablinks");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }

  // Show the current tab, and add an "active" class to the button that opened the tab
  document.getElementById(specifictab).style.display = "block";
  evt.currentTarget.className += " active";
}
//OpenCity V2 end

//
// No longer using Jquery
// $("#tabs").click(function (e) {
//   e.preventDefault();
//   $("#tabs li").removeClass("active");
//   $(this).parent().addClass("active");
//   $(this).tab("show");
// });

// NAVIGATION POPOUT - Master - Temp Off
// function openNav() {
//     document.getElementById("mySidenav").style.width = "200px";
//     document.getElementById("content-container").style.marginLeft = "265px";
// }
// function closeNav() {
//     document.getElementById("mySidenav").style.width = "0";
//     document.getElementById("content-container").style.marginLeft = "0";
// }

// Toggle Button for + Contact and + Revenue 7-22-23
document.addEventListener("turbo:load", function () {
  var editToggleButtons = document.querySelectorAll(
    ".toggle_contact .dropdown-toggle"
  );
  editToggleButtons.forEach(function (button) {
    var dropdownMenu = button.nextElementSibling;
    dropdownMenu.style.display = "none"; // Hide the dropdown menu initially

    button.addEventListener("click", function () {
      var isHidden = dropdownMenu.style.display === "none";
      dropdownMenu.style.display = isHidden ? "block" : "none";
    });
  });
});

//Three Dots Menu - 7-22-23
document.addEventListener("turbo:load", function () {
  var editToggleButtons = document.querySelectorAll(".edit_toggle img");
  editToggleButtons.forEach(function (button) {
    var editFSection = button.parentElement.nextElementSibling;
    editFSection.style.display = "none"; // Hide the edit_f section initially

    button.addEventListener("click", function () {
      var isHidden = editFSection.style.display === "none";
      editFSection.style.display = isHidden ? "block" : "none";
    });
  });
});

document.addEventListener("turbo:load", function () {
  var editToggleButtons = document.querySelectorAll(
    ".toggle_general .dropdown-toggle"
  );
  editToggleButtons.forEach(function (button) {
    var dropdownMenu = button.nextElementSibling;
    dropdownMenu.style.display = "none"; // Hide the dropdown menu initially

    button.addEventListener("click", function () {
      var isHidden = dropdownMenu.style.display === "none";
      dropdownMenu.style.display = isHidden ? "block" : "none";
    });
  });
});

// //Toggle Button for + Revenue
// document.addEventListener("turbo:load", function () {
//   var editToggleButtons = document.querySelectorAll(
//     ".toggle_revenue .dropdown-toggle"
//   );
//   editToggleButtons.forEach(function (button) {
//     var dropdownMenu = button.nextElementSibling;
//     dropdownMenu.style.display = "none"; // Hide the dropdown menu initially

//     button.addEventListener("click", function () {
//       var isHidden = dropdownMenu.style.display === "none";
//       dropdownMenu.style.display = isHidden ? "block" : "none";
//     });
//   });
// });

// Needs reworked to handle js //TODO going to need top turbo:load
document.addEventListener("DOMContentLoaded", function () {
  var editToggleButtons = document.querySelectorAll(".edit_toggle");
  editToggleButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      var details = this.nextElementSibling;
      details.style.display =
        details.style.display === "none" ? "block" : "none";
      var allEditDetails = document.querySelectorAll(".edit_f");
      allEditDetails.forEach(function (editDetail) {
        if (editDetail !== details) {
          editDetail.style.display = "none";
        }
      });
    });
  });

  //TODO going to need top turbo:load
  var itemTitles = document.querySelectorAll(".item-title");
  itemTitles.forEach(function (title) {
    title.addEventListener("click", function (e) {
      e.preventDefault();
      var content = this.previousElementSibling;
      content.style.display =
        content.style.display === "none" ? "block" : "none";
      var allItemContents = document.querySelectorAll(".item-content");
      allItemContents.forEach(function (itemContent) {
        if (itemContent !== content) {
          itemContent.style.display = "none";
        }
      });
    });
  });

  // Contact Details EDIT
  var editFamilyButtons = document.querySelectorAll(".edit_family");
  editFamilyButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      var details = this.nextElementSibling;
      details.style.display =
        details.style.display === "none" ? "block" : "none";
      var allEditDetails = document.querySelectorAll(".edit_f");
      allEditDetails.forEach(function (editDetail) {
        if (editDetail !== details) {
          editDetail.style.display = "none";
        }
      });
    });
  });

  //TODO going to need top turbo:load
  var editNoteButtons = document.querySelectorAll(".edit_note");
  editNoteButtons.forEach(function (button) {
    button.addEventListener("click", function () {
      var details = this.nextElementSibling;
      details.style.display =
        details.style.display === "none" ? "block" : "none";
      var allEditDetails = document.querySelectorAll(".edit_n");
      allEditDetails.forEach(function (editDetail) {
        if (editDetail !== details) {
          editDetail.style.display = "none";
        }
      });
    });
  });
});

// Mobile Nav Dots
document.addEventListener("DOMContentLoaded", () => {
  const listsWrapper = document.getElementById("lists-wrapper");
  const navDots = document.querySelectorAll("#list-nav .nav-dot");
  // const lists = document.getElementById("lists");

  listsWrapper.addEventListener("scroll", () => {
    const scrollLeft = listsWrapper.scrollLeft;
    const width = listsWrapper.offsetWidth;
    const activeIndex = Math.round(scrollLeft / width);

    navDots.forEach((dot, index) => {
      if (index === activeIndex) {
        dot.style.backgroundColor = "#ccc"; // Active color
      } else {
        dot.style.backgroundColor = "#333"; // Inactive color
      }
    });
  });
});
