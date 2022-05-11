/* called from below, move this into anonymous function below */
function toggle_license() {
  $jq('#license').toggle();
}

/* called from below, in rr 4.2 unobtrusive js change */
function add_upload_box(url) {
  ajax_append(url, '#upload_files');
}

$jq(function () {
  $jq('form').submit(function () {
        if (!$jq('#license_agree').get(0).checked) {
          $jq('#license_warning').toggle();
          return false;
        } else {
          return true;
        }
      }
  );
  $jq('#license_agree').change(function () {
    if (this.checked) {
      $jq('#license_warning').hide();
    }
  })
});

/* new with rr 4.2 */
$jq(function() {
  $('.add_upload_box').click(function() {
	var path = $jq(this).attr("data-path");
	add_upload_box(path);
    return false;
  });
});

/* new with rr 4.2 */
$jq(function() {
  $('.toggle_license').click(function() {
	toggle_license();
    return false;
  });
});
