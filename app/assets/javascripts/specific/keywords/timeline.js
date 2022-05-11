
// Load the Visualization API and the piechart package.
// Set a callback to run when the Google Visualization API is loaded.
google.charts.load('current', {packages: ['corechart']});

var year_tags = decode_js_data_div('year-tags');
var charts = decode_js_data_div('chart-urls');
var work_counts = decode_js_data_div('work-counts');
var slider_div = $jq('#track1');

// fallback
function slider_value() {
  var index = slider_div.slider('value');
  if ($jq('#track1').length == 0) { index = 0; }
  return index;
}

function slider_stop() {
  var index = slider_value();
  show_year(index);
  show_google_chart(index);
  show_list(index);
}

function show_year(index) {
  var index = slider_value();
  $jq('#curyear').text(year_tags[index]);
}

// being called ? 
function show_chart(index) {
  drawChart(charts[0]); 
}

function show_google_chart(index) {
	google.charts.setOnLoadCallback( function() { drawChart(charts[index]) });
}

function show_list(index) {
  $jq('#timeline-tagcloud ul').each(function(i, e) {
    if(i == index) {
      $jq(this).css('display', 'block');
    } else {
      $jq(this).css('display', 'none');
    }
  });
}


 // Callback that creates and populates google chart data table,
 function drawChart(rowdata) {
   var data = new google.visualization.DataTable();
   data.addColumn('string', 'Format');
   data.addColumn('number', 'Works');
   /*data.addRows([['Mushrooms', 3],['Onions', 1],['Olives', 1],['Zucchini', 1],['Pepperoni', 2]]); */
	 
	 if (typeof rowdata !== 'undefined' && rowdata.length > 0) {
	   data.addRows(rowdata.length);
	   for (var j = 0; j < rowdata.length; j++) {
	     data.setValue(parseInt(j), 0, rowdata[j][0]);
	     data.setValue(parseInt(j), 1, rowdata[j][1]);
	   }
	
	   var options = {'title':'',
	                  'width':312,
	                  'height':140,
					  'colors': ['#87412D', '#9B6150', '#AF8073', '#C3A096', '#D7C0B9', '#EBDFDC']};

	   //options['title'] = ''; /* title displayed from container */
	   var chart = new google.visualization.PieChart(document.getElementById('chart-img'));
	   chart.draw(data, options);
	 }
 }

$jq(function () {
  slider_div.slider({
    min:0,
    max:year_tags.length - 1,
    value:0,
    stop:function () {
      slider_stop()
    }
  });
  slider_stop();
});

