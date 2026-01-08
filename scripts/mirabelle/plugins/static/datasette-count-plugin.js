// Count and show number of rows
// Test if we're located in a query's page
const hide = document.getElementsByClassName('show-hide-sql')[0] || false;
if (hide) {
	var sql_request = document.getElementById('sql-editor').value;
	// Remove request's comments
	const sql_req_wo_comments = sql_request.replace(/(\/\*[^*]*\*\/)|(\/\/[^*]*)|(--[^.].*)/gm, '');
	// Test if sql query does either not contains "count" or contains "group by"
	if (/count ?\(/.test(sql_req_wo_comments) === false || /group by /i.test(sql_req_wo_comments) === true) {
	hide.insertAdjacentHTML( 'beforeBegin', '<sup><span id="count" title="count the results without LIMIT">count</span></sup> ' );
	document.head.insertAdjacentHTML('beforeend',
		`<style>
			 #count { font-size: 60%; vertical-align: top;
				 cursor: pointer; border-radius: 4px; border: none;
				 padding: 3px 8px; background-color: #0000000d; }
			 #count:hover { background-color: #0000001a; }
		 </style>`);
	const count = document.getElementById('count');
	count.addEventListener("click", displayCount);
	}
}

function displayCount() {
	// Delete limit X
	var sql_request_wo_limit = sql_req_wo_comments.replace(/limit \d+/gi, "");
	sql_request_wo_limit = sql_request_wo_limit.replace(/\n$/gi, "");
	// build query
	const count_request = "select count(*) from (" + sql_request_wo_limit + "\n);";
	var url = document.URL.replace(/\?.*$/gi, ""); // https://example.org/database?sql=..........
	fetch(encodeURI(url + ".json?sql=") + encodeURIComponent(count_request) + "&_shape=arrayfirst")
		.then(function(response) {
		return response.json();
	})
		.then(function(data) {
		console.log('JSON', JSON.stringify(data));
		count.innerHTML = data[0];

	})
		.catch(error => console.error('Error!', error.message));
}
