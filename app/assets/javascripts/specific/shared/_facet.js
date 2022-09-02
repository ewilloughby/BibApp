function toggle_facets(element) {
  var facet = $jq(element).parents('.facet');
  facet.children('.top_facets').toggle();
  facet.children('.all_facets').toggle();
  facet.children('.more_filters').toggle();
  facet.children('.fewer_filters').toggle();
}

/* new with rr 4.2 */
$jq(function() {
  $('.toggle_facets').click(function() {
	toggle_facets($jq(this));
    return false;
  });
});

