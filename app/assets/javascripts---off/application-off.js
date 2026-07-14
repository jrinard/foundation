// // This is a manifest file that'll be compiled into application.js, which will include all the files
// // listed below.
// //
// // Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// // vendor/assets/javascripts directory can be referenced here using a relative path.
// //
// // It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// // compiled file. JavaScript code in this file should be added after the last require_* statement.
// //
// // Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// // about supported directives.
// //
// //= require rails-ujs
// //= require activestorage
// //= require turbolinks
// //= require_tree .

// //= require bootstrap-sprockets
// //= require turbolinks
// //= require_tree .
// //= require chartkick

// //= require_self
// // direct_uploads.js

// //= require test

// addEventListener("direct-upload:initialize", (event) => {
//   const { target, detail } = event;
//   const { id, file } = detail;
//   target.insertAdjacentHTML(
//     "beforebegin",
//     `
//     <div id="direct-upload-${id}" class="direct-upload direct-upload--pending">
//       <div id="direct-upload-progress-${id}" class="direct-upload__progress" style="width: 0%"></div>
//       <span class="direct-upload__filename">${file.name}</span>
//     </div>
//   `
//   );
// });

// addEventListener("direct-upload:start", (event) => {
//   const { id } = event.detail;
//   const element = document.getElementById(`direct-upload-${id}`);
//   element.classList.remove("direct-upload--pending");
// });

// addEventListener("direct-upload:progress", (event) => {
//   const { id, progress } = event.detail;
//   const progressElement = document.getElementById(
//     `direct-upload-progress-${id}`
//   );
//   progressElement.style.width = `${progress}%`;
// });

// addEventListener("direct-upload:error", (event) => {
//   event.preventDefault();
//   const { id, error } = event.detail;
//   const element = document.getElementById(`direct-upload-${id}`);
//   element.classList.add("direct-upload--error");
//   element.setAttribute("title", error);
// });

// addEventListener("direct-upload:end", (event) => {
//   const { id } = event.detail;
//   const element = document.getElementById(`direct-upload-${id}`);
//   element.classList.add("direct-upload--complete");
// });

// // Turbolinks test
// // $(document).on('turbolinks:load', function (){ alert("turbolinks on load event works") });

// //Flash Message Fade
// // $("document").ready(function () {
// //   setTimeout(function () {
// //     $("#flash").fadeOut();
// //   }, 3000);
// // });

// // $("document").ready(function () {
// //   setTimeout(function () {
// //     $("#flash-m").fadeOut();
// //   }, 3000);
// // });

// // //Toggle details and hide the others
// // $(document).on("turbolinks:load", function () {
// //   $(".edit_toggle").on("click", function () {
// //     var $details = $(this).next(".edit_f");
// //     $details.toggle(); //toggle the current one
// //     $(".edit_f").not($details).slideUp(); //hide the others
// //   });
// // });

// // document.addEventListener("turbo:load", function () {
// //   console.log("=== js");
// //   var editToggles = document.querySelectorAll(".edit_toggle");

// //   editToggles.forEach(function (toggle) {
// //     toggle.addEventListener("click", function () {
// //       var details = this.nextElementSibling;
// //       details.classList.toggle("hidden"); // toggle the current one

// //       var otherDetails = document.querySelectorAll(".edit_f:not(.hidden)");
// //       otherDetails.forEach(function (detail) {
// //         if (detail !== details) {
// //           detail.classList.add("hidden"); // hide the others
// //         }
// //       });
// //     });
// //   });
// // });

// // // Toggle Hide on Templates
// // $(".item-content").show();
// // $(document).on("click", ".item-title", function (e) {
// //   e.preventDefault();
// //   $(this).prev(".item-content").toggle();
// //   $(".item-content-old").hide();
// // });

// document.addEventListener("turbo:load", function () {
//   var itemContents = document.querySelectorAll(".item-content");
//   itemContents.forEach(function (itemContent) {
//     itemContent.style.display = "block"; // show the item contents
//   });

//   document.addEventListener("click", function (e) {
//     var target = e.target;
//     if (target.classList.contains("item-title")) {
//       e.preventDefault();
//       var prevItemContent = target.previousElementSibling;
//       prevItemContent.style.display =
//         prevItemContent.style.display === "none" ? "block" : "none"; // toggle the previous item content

//       var oldItemContents = document.querySelectorAll(".item-content-old");
//       oldItemContents.forEach(function (oldItemContent) {
//         oldItemContent.style.display = "none"; // hide the old item contents
//       });
//     }
//   });
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

// //Works. But #note-toggle-edit can't be dynamic so it works only on one at a time not a loop. onClick = noteToggle(p)
// function noteToggle(p) {
//   var x = document.getElementById("note-toggle-" + p);
//   if (x.style.display === "none") {
//     x.style.display = "block";
//     console.log("main on ");
//   } else {
//     x.style.display = "none";
//     console.log("main off");
//   }
//   var y = document.getElementById("note-toggle-edit-" + p);
//   if (y.style.display === "block") {
//     y.style.display = "none";
//     console.log("edit off");
//   } else {
//     y.style.display = "block";
//     console.log("edit on");
//   }
// }

// //Copy TEXT - Phone
// function copyPhone(c) {
//   /* Get the text field */
//   var copyText = document.getElementById("copyPhone_" + c);
//   /* Select the text field */
//   copyText.select();
//   copyText.setSelectionRange(0, 99999); /* For mobile devices */
//   /* Copy the text inside the text field */
//   navigator.clipboard.writeText(copyText.value);
//   /* Alert the copied text */
//   // alert("Copied the text: " + copyText.value);
// }

// //Copy TEXT - Ehone
// function copyEmail(c) {
//   /* Get the text field */
//   var copyText = document.getElementById("copyEmail_" + c);
//   /* Select the text field */
//   copyText.select();
//   copyText.setSelectionRange(0, 99999); /* For mobile devices */
//   /* Copy the text inside the text field */
//   // navigator.clipboard.writeText(copyText.value);
//   navigator.clipboard.writeText(copyText.value);
//   /* Alert the copied text */
//   // alert("Copied the text: " + copyText.value);
// }

// // Infinite Scroll on customers
// $(document).ready(function () {
//   if ($(".pagination").length) {
//     $(window).scroll(function () {
//       var url = $(".pagination .next_page").attr("href");
//       if (
//         url &&
//         $(window).scrollTop() > $(document).height() - $(window).height() - 1
//       ) {
//         $(".pagination").text("Please Wait...");
//         return $.getScript(url);
//       }
//     });
//     return $(window).scroll();
//   }
// });

// function openCity(evt, specifictab) {
//   // Declare all variables
//   var i, tabcontent, tablinks;

//   // Get all elements with class="tabcontent" and hide them
//   tabcontent = document.getElementsByClassName("tabcontent");
//   for (i = 0; i < tabcontent.length; i++) {
//     tabcontent[i].style.display = "none";
//   }

//   // Get all elements with class="tablinks" and remove the class "active"
//   tablinks = document.getElementsByClassName("tablinks");
//   for (i = 0; i < tablinks.length; i++) {
//     tablinks[i].className = tablinks[i].className.replace(" active", "");
//   }

//   // Show the current tab, and add an "active" class to the button that opened the tab
//   document.getElementById(specifictab).style.display = "block";
//   evt.currentTarget.className += " active";
// }

// $("#tabs").click(function (e) {
//   e.preventDefault();
//   $("#tabs li").removeClass("active");
//   $(this).parent().addClass("active");
//   $(this).tab("show");
// });

// // NAVIGATION POPOUT - Master - Temp Off
// // function openNav() {
// //     document.getElementById("mySidenav").style.width = "200px";
// //     document.getElementById("content-container").style.marginLeft = "265px";
// // }
// // function closeNav() {
// //     document.getElementById("mySidenav").style.width = "0";
// //     document.getElementById("content-container").style.marginLeft = "0";
// // }
