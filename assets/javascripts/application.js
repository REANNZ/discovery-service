//= require jquery
//= require jquery.scrollbar
//= require mousetrap

/// Service Providers
function getSP(spJson, initiatingSP) {
  for (var i = 0; i < spJson.length; i++) {
    if (spJson[i].entity_id == initiatingSP) {
      return spJson[i];
    }
  }
  return null;
}

function getUrlParameter(sParam) {
  var sPageURL = decodeURIComponent(window.location.search.substring(1)),
    sURLVariables = sPageURL.split("&"),
    sParameterName,
    i;

  for (var i = 0; i < sURLVariables.length; i++) {
    sParameterName = sURLVariables[i].split("=");

    if (sParameterName[0] === sParam) {
      return sParameterName[1] === undefined ? true : sParameterName[1];
    }
  }
}

function decodeString(source) {
  var textArea = document.createElement("textarea");
  textArea.innerHTML = source;
  decodedString = textArea.value;

  if ("remove" in Element.prototype) textArea.remove();

  return decodedString;
}

function loadInitiatingSPDetails() {
  var spJson = $.parseJSON($("#sps").html());
  var initiatingSP = getUrlParameter("entityID");

  if (initiatingSP) {
    var sp = getSP(spJson, initiatingSP);
    if (sp == null) return;

    $("#sp_name").text("Login to " + decodeString(sp.name));

    if (sp.description) {
      $("#sp_description").empty();
      $("#sp_description").append(
        "<p>" + decodeString(sp.description) + "</p>"
      );
    }

    $("#sp_help").css("display", "inherit");
    if (sp.information_url || sp.privacy_statement_url) {
      $("#sp_links").css("display", "inherit");

      if (sp.information_url) {
        $("#sp_information_url").attr("href", sp.information_url);
        $("#sp_information_url").text("Further Information");
      }

      if (sp.privacy_statement_url) {
        $("#sp_privacy_statement_url").attr("href", sp.privacy_statement_url);
        $("#sp_privacy_statement_url").text("Privacy Statement");
      }
    }
  }
}

/// Tabs
function changeTab(target) {
  var tab_id = target.attr("data-tab");

  $("ul.tabs li").removeClass("current");
  $(".tab-content").css("display", "none");

  target.addClass("current");
  $("#" + tab_id).css("display", "inherit");
}

function nextTab() {
  var current = $(".tab.current");

  // Check we're actually in tabbed mode, not rendered when only a single
  // group of organisation tags is present.
  if (current.length) {
    current.removeClass("current");
    $(".tab-content").removeClass("current");

    var next = current.next();

    if (next.length) {
      changeTab(next);
    } else {
      var first = $(".tab:first");
      changeTab(first);
    }
  }
}

/// Identity Providers (s.a. Organisations)
function enableSelectOrganisationButton(tr) {
  $(".continue_button").attr("disabled", true);
  tr.parents("form")
    .find(".continue_button")
    .attr("disabled", false);
}

function selectIdP(tr) {
  $(".idp_selection_table tbody tr").removeClass("active");
  tr.addClass("active");
  enableSelectOrganisationButton(tr);
}

function nextIdP() {
  var current = $(".idp.active:visible");
  if (current.length) {
    // nextAll as the immediate sibling may be hidden due to search
    var next = current.nextAll(":visible").first();
    if (next.length) {
      selectIdP(next);
      next[0].scrollIntoView({
        block: "nearest"
      });
    }
  } else {
    var first = $(".idp:visible").first();
    if (first.length) {
      selectIdP(first);
      first[0].scrollIntoView({
        block: "nearest"
      });
    }
  }
}

function previousIdP() {
  var current = $(".idp.active:visible");
  if (current.length) {
    // prevAll as the immediate sibling may be hidden due to search
    var prev = current.prevAll(":visible").first();
    if (prev.length) {
      selectIdP(prev);
      prev[0].scrollIntoView({
        block: "nearest"
      });
    }
  } else {
    var last = $(".idp:visible").last();
    if (last.length) {
      selectIdP(last);
      last[0].scrollIntoView({
        block: "nearest"
      });
    }
  }
}

function focusIdPSearchInput() {
  $(".search_input:visible")
    .first()
    .focus();
  return false; // Prevent shortcut key entering input field.
}

function toggleRememberIdP() {
  $("[name=remember]:visible")
    .first()
    .click();
}

function searchActiveIdPList(input, key) {
  var form = input.parents("form");

  if (key.keyCode == 27 || key.keyCode == 9) {
    input.blur();
  } else {
    var target = form.find(".idp_selection_table");
    var table_rows = target.find("tr");
    table_rows.removeClass("active");

    var val = $.trim(input.val())
      .replace(/[\W\d\s]/gi, "")
      .toLowerCase();
    if (val == "") {
      table_rows.attr("hidden", false);
    } else {
      table_rows.not('[data-idp-name*="' + val + '"]').attr("hidden", true);
      table_rows.filter('[data-idp-name*="' + val + '"]').attr("hidden", false);
    }

    var target = $(".idp_selection_table tbody tr:visible");
    if (target.length) {
      selectIdP(target.first());
      target.first()[0].scrollIntoView({
        block: "nearest"
      });
    } else {
      disableContinueButton();
    }
  }
}

function submitIdPSelection() {
  var target = $(".idp.active:visible");
  if (target.length) {
    $(".idp_selection_form:visible").submit();
    return false;
  }
}

function enableContinueButton() {
  $(".idp_selection_form").submit(function() {
    var selectedIdP = $(".idp.active:visible .select_idp_button").attr("value");

    if (selectedIdP.length) {
      $("<input />")
        .attr("type", "hidden")
        .attr("name", "user_idp")
        .attr("value", selectedIdP)
        .appendTo($(this));
    }
  });

  $(".continue_button:visible").attr("disabled", false);
}

function disableContinueButton() {
  $(".continue_button:visible").attr("disabled", true);
}

/// Keyboard shortcuts
Mousetrap.bind("s", function() {
  return focusIdPSearchInput();
});

Mousetrap.bind("/", function() {
  return focusIdPSearchInput();
});

Mousetrap.bind("t", function() {
  nextTab();
});

Mousetrap.bind("j", function() {
  nextIdP();
});

Mousetrap.bind("down", function() {
  nextIdP();
});

Mousetrap.bind("k", function() {
  previousIdP();
});

Mousetrap.bind("up", function() {
  previousIdP();
});

Mousetrap.bind("r", function() {
  toggleRememberIdP();
});

Mousetrap.bind("enter", function() {
  submitIdPSelection();
  return false;
});

Mousetrap.bind("ctrl e e 1", function() {
  $("#footer #environment").addClass("r1");
});

Mousetrap.bind("ctrl e e 2", function() {
  $("#footer #environment").addClass("r2");
});

Mousetrap.bind("ctrl e e 3", function() {
  $("#footer #environment").addClass("r3");
});

Mousetrap.bind("ctrl e e 4", function() {
  $("#footer #environment").addClass("r4");
});

Mousetrap.bind("ctrl e e g", function() {
  $(".idp_selection_table_container").css(
    "background",
    "linear-gradient(to right, red,orange,yellow,green,blue,indigo,violet)"
  );
});

Mousetrap.bind("ctrl e e u", function() {
  $("body").toggleClass("flip");
});

Mousetrap.bind("?", function() {
  $(".keyboard_shortcuts").css("display", "inherit");
  $(".extra_functions .right a").css("display", "none");
});

function init() {
  loadInitiatingSPDetails();

  $(".idp_selection_table button").hide();
  enableContinueButton();

  $(".tag-heading").css("display", "none");
  $(".tabs").css("display", "inherit");
  $(".tab-content:not(:first)").css("display", "none");
  $(".tab").click(function() {
    changeTab($(this));
  });

  // Only use our bound enter key, not the default action
  $(".idp_selection_form").bind("keypress", function(e) {
    if (e.keyCode == 13) {
      return false;
    }
  });

  // Force scrollbars to always be present when content is larger than
  // container browsers mostly hide scrollbars by default now which is not
  // user friendly in our particular case.
  if (navigator.userAgent.indexOf("Firefox") > -1) {
    $(".scroll-element").css("display", "none");
  } else {
    $(".scrollbar-inner").scrollbar();
  }

  // Active and visible are dynamic hence we need to pass these selectors
  // to 'on'
  $(".idp_selection_table").on("click", ".idp:visible", function() {
    selectIdP($(this));
  });

  $(".idp_selection_table").on("click", ".idp.active:visible", function() {
    submitIdPSelection();
  });

  $(".continue_button").on("click", function() {
    submitIdPSelection();
  });

  $(".search_input").css("display", "inherit");
  $(".search_input").keyup(function(key) {
    searchActiveIdPList($(this), key);
  });

  $(".extra_functions .right a").css("display", "inherit");
  $(".extra_functions .right a").on("click", function() {
    $(".keyboard_shortcuts").css("display", "inherit");
    $(".extra_functions .right a").css("display", "none");
  });

  // Content is styled and ready so show it. Prevents ugly
  // 'flash of unstyled content' from plaguing us. (Well me...).
  $(".no-fouc").removeClass("no-fouc");
}
