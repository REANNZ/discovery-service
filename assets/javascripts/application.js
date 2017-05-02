//= require jquery
//= require semantic-ui
//= require datatables/jquery.dataTables
//= require slimscroll/jquery.slimscroll

function enableHelpLink() {
  $('#help_link').show();
  $('#help_link').on('click', function () {
    $('.ui.modal').modal().modal('show');
  });
}

function initScroller() {
  $('#scroller').slimScroll({
    height: '250px',
    wheelStep: 40,
    alwaysVisible: true
  });
}

function makeMessagesClosable() {
  $('.message .close').on('click', function () {
    $(this).closest('.message').transition('fade');
  });
}

function focusSearchField() {
  $("#search_input").focus();
}

function initialiseCheckbox() {
  $('.ui.checkbox').checkbox();
}

function disableSelectOrganisationButton() {
  $('#select_organisation_button').addClass('disabled');
}

function enableSelectOrganisationButton() {
  $('#select_organisation_button').removeClass('disabled');
}

function unselectIdP() {
  $('#idp_selection_table tbody tr').removeClass('active');
}

function selectIdPRow(tr) {
  if (tr.attr('role') == 'row') {
    if (tr.hasClass('active')) {
      tr.removeClass('active');
      disableSelectOrganisationButton();
    }
    else {
      unselectIdP();
      tr.addClass('active');
      enableSelectOrganisationButton();
      return true;
    }
  }
  return false;
}
function makeIdPRowsSelectable() {
  $('#idp_selection_table tbody').on('click', 'tr', function () {
    var tr = $(this);
    selectIdPRow(tr);
  });
}

function appendIdPSelectionOnFormSubmit() {
  $("#idp_selection_form").submit(function () {
    var selectedIdPRowSelector = "#idp_selection_table tbody tr.active td"
        + " input.select_organisation_input";
    var selectedIdP = $(selectedIdPRowSelector).attr('name');

    if (selectedIdP) {
      $('<input />').attr('type', 'hidden')
          .attr('name', 'user_idp')
          .attr('value', selectedIdP)
          .appendTo('#idp_selection_form');
      return true;

    }
  });
}

function showSearchOptions() {
  $('#search_options').show();
}

function submitFormOnSelectIdPButtonClick() {
  $('#select_organisation_button').on('click', function () {
    $("#idp_selection_form").submit();
  });
}

function clearSearch() {
  unselectIdP();
  disableSelectOrganisationButton();
  $('#search_input').val('');
  $('#idp_selection_table').DataTable()
      .search('')
      .columns().search('')
      .draw();
}

function clearSearchOnClearButtonClick() {
  $('#search_clear_button').on('click', function () {
    clearSearch();
  });
}

function displayMainIdPSelectButton() {
  $('#select_organisation_button').addClass('disabled');
  $('#select_organisation_button').css("display", "inline-block");
  $('#select_organisation_button').text('Continue to your organisation');
}

function enableTabs() {
  $('#tab_content').css('padding-top', '0');
  if ($('#tab_menu').children().length > 0) {
    $('#tab_menu').css('height', '100%');
    setFirstTabAsActive();
    $.fn.dataTable.ext.search.push(
        function (settings, data) {
          var tagsForIdPAsString = data[3];
          var tagsForIdP = tagsForIdPAsString.split(',');
          var selectedTab = $('#tab_menu a.active').attr('data-tab');
          return tagsForIdP.indexOf(selectedTab) != -1 || selectedTab == '*'
        }
    );
  }
}

function setFirstTabAsActive() {
  $('#tab_menu .item').removeClass('active');
  $('#tab_menu .item:first').addClass('active');
}

function getSP(spJson, initiatingSP) {
  for(var i = 0; i < spJson.length; i++) {
    if (spJson[i].entity_id == initiatingSP) {
      return spJson[i];
    }
  }
  return null;
}

function getUrlParameter(sParam) {
  var sPageURL = decodeURIComponent(window.location.search.substring(1)),
      sURLVariables = sPageURL.split('&'),
      sParameterName,
      i;

  for(var i = 0; i < sURLVariables.length; i++) {
    sParameterName = sURLVariables[i].split('=');

    if (sParameterName[0] === sParam) {
      return sParameterName[1] === undefined ? true : sParameterName[1];
    }
  }
}

function decodeString(source) {
  var textArea = document.createElement('textarea');
  textArea.innerHTML = source;
  decodedString = textArea.value; 

  if ('remove' in Element.prototype) 
      textArea.remove();

  return decodedString;
}

function loadInitiatingSPDetails() {
  var spJson = $.parseJSON($('#sps').html());
  var initiatingSP = getUrlParameter('entityID');

  if (initiatingSP) {
    var sp = getSP(spJson, initiatingSP);
    if (sp == null) return;

    $('.sp_header_name').text(decodeString(sp.name));

    if (sp.description) {
      $('#sp_header_description').text(decodeString(sp.description));
    }
    if (sp.logo_url) {
      $('#sp_header_logo').attr("src", sp.logo_url);
    }
    if (sp.information_url) {
      $('#sp_header_information_url').attr("href", sp.information_url);
      $('#sp_header_information_url').text('Service Information');
    }
    if (sp.privacy_statement_url) {
      $('#sp_header_privacy_statement_url').
          attr("href", sp.privacy_statement_url);
      $('#sp_header_privacy_statement_url').text('Privacy Statement');
    }
  }
}

function setCursorToPointerOnIdPRows() {
  $('#idp_selection_table tbody tr').css('cursor', 'pointer');
}

function hideButtonsAlongsideEachIdP() {
  $('.select_organisation_input').hide();
}

function renderLogo(logoURL) {
  if (logoURL) {
    return '<img class="ui image tiny bordered" src="' + logoURL + '">';
  } else {
    return '';
  }
}

function renderIdPDetails(idPName) {
  return '<strong>' + decodeString(idPName) + '</strong><br/>';
}

function renderEntityIdInput(entityID) {
  return '<input class="select_organisation_input" name="' + entityID + '"' +
      ' type="submit">';
}

function buildDataset(idPData) {
  return idPData.map(function (idP) {
    return [idP.name, idP.logo_url, idP.entity_id, idP.tags];
  });
}

function loadDataTable() {
  var idpJson = $.parseJSON($('#idps').html());

  $('#idp_selection_table').DataTable({
    data: buildDataset(idpJson),
    scrollCollapse: true,
    paging: false,
    sDom: '<"top">rt<"bottom"><"clear">',
    columnDefs: [
      {sClass: "idp_selection_table_name_column", targets: 0 },
      {render: renderIdPDetails, targets: 0},
      {sClass: "idp_selection_logo_column", targets: 1 },
      {render: renderLogo, targets: 1},
      {render: renderEntityIdInput, targets: 2},
      {visible: false, targets: 3}
    ],
    aoColumns: [
      {"bSearchable": true},
      {"bSearchable": false},
      {"bSearchable": false},
      {"bSearchable": true}
    ],
    order: [[0, 'asc']],
    bAutoWidth: false
  });
}

function makeTabsClickable() {
  $('#tab_menu .item').on('click', function () {
    $('#tab_menu .item').removeClass('active');
    $(this).addClass('active');
    $('#idp_selection_table').DataTable().draw();
    hideButtonsAlongsideEachIdP();
    setTabIndexOnRows();
    clearSearch();
    unselectIdP();
    setCursorToPointerOnIdPRows();
  });
}

function performSearchOnIdPSearchKeyup() {
  $('#search_input').keyup(function () {
    $('#idp_selection_table').DataTable().search($(this).val()).draw();
  })
}

function hideBasicModeWarningMessage() {
  $('#basic_mode_warning_message').hide();
}

function hideTabMenu() {
  $('#tab_menu').hide();
}

function preventEnterKey() {
  $(window).keydown(function (event) {
    if (event.keyCode == 13) {
      var focusedIdPRow = $('#idp_selection_table tr:focus');
      if (focusedIdPRow && selectIdPRow(focusedIdPRow)) {
        $("#idp_selection_form").submit();
        return true;
      }
      event.preventDefault();
      return false;
    }
  });
}

function setTabIndexOnRows() {
  $('#select_organisation_button').attr('tabindex', 0);
  $('#idp_selection_table tr:not(:first)').each(function () {
    $(this).attr('tabindex', 0);
  });
}

function initHandlers() {
  preventEnterKey();
  makeTabsClickable();
  makeIdPRowsSelectable();
  appendIdPSelectionOnFormSubmit();
  submitFormOnSelectIdPButtonClick();
  clearSearchOnClearButtonClick();
  performSearchOnIdPSearchKeyup();
  makeMessagesClosable();

}

function showJSEnabledElements() {
  enableTabs();
  showSearchOptions();
  displayMainIdPSelectButton();
  loadInitiatingSPDetails();
  initialiseCheckbox();
  focusSearchField();
  enableHelpLink();
}

function initRichClient() {
  hideBasicModeWarningMessage();
  showJSEnabledElements();

  initHandlers();
  loadDataTable();

  hideButtonsAlongsideEachIdP();
  initScroller();
  setCursorToPointerOnIdPRows();
  setTabIndexOnRows();
}

function initBasicClient() {
  hideTabMenu();
}

function initGroupPage() {
  if (ie9OrEarlier()) {
    initBasicClient();
  } else {
    initRichClient();
  }
}

function ie9OrEarlier() {
  return document.documentMode && document.documentMode <= 9;
}

