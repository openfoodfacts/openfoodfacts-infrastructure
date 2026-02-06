document.addEventListener("DOMContentLoaded", function () {
    'use strict';
    // console.log("DS: start");


    // Test if we're located in a query's page
    if (document.getElementsByClassName('show-hide-sql')[0] && document.getElementById('sql-editor') !== null) {

        // console.log("DS: display [count] button");
        var sql_request = document.getElementById('sql-editor').value;

        // Remove request's comments
        var sql_req_wo_comments = sql_request.replace(/(\/\*[^*]*\*\/)|(--[^.].*)/gm, '');

        // Test if sql query does contain "LIMIT X" or "limit x"
        // select * from table limit 1                     => display button
        // select count(*) from table group by f limit 5   => display button
        // select count(*) from table group by f           => don't
        // select count(*) from table                      => don't
        // select count(*) from table limit 5 -- doesn't make sense
        if (/\slimit[ \n]+\d/i.test(sql_req_wo_comments) === true) {
            // Add "CSV without limit" link
            displayCountButton();
            displayLinkCSVWithoutLimit();
        }
    }


    /***
     * Display link "CSV without limit"
     * 
     */
    function displayLinkCSVWithoutLimit() {
        // Get CSV link
        const CSVLink = document.getElementsByClassName("export-links")[0].lastChild.href;
        // Delete limit X
        // TODO: this method can lead to issues if limit xx is commented
        const csv_request_wo_limit = CSVLink.replace(/limit([\+]*(%0D%0A)*[\+]*)*\d+/gi, "");
        // Add new link
        const export_links = document.getElementsByClassName("export-links")[0];
        export_links.innerHTML += ', <a id="csv-without-limit-link" href="' + csv_request_wo_limit + '" download>CSV without limit</a>';
    }


    /***
     * Add "count" button aside the "Custom SQL query returning XX rows" title 
     * Clicking on the button counts and displays total number of rows.
     * 
     * Might not play well with complex queries
     */
    function displayCountButton() {
        document.getElementsByClassName('show-hide-sql')[0].insertAdjacentHTML(
            'beforeBegin', '<sup><span id="count" title="count the results without LIMIT">count</span></sup> ' );
        document.head.insertAdjacentHTML(
            'beforeend',
            `<style>
                #count { font-size: 60%; vertical-align: top;
                    cursor: pointer; border-radius: 4px; border: none;
                    padding: 3px 8px; background-color: #0000000d; }
                #count:hover { background-color: #0000001a; }
             </style>`);
        const count = document.getElementById('count');
        count.addEventListener("click", displayCount);
    }


    /***
     * Display the number of rows when removing "LIMIT X" of the SQL query
     * 
     */
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
            // Display the results in the "count" button
            count.innerHTML = data[0];
            // Display the results near the "CSV without limit" link
            document.getElementById("csv-without-limit-link").innerHTML += ' (' + data[0] +')';

        })
            .catch(error => console.error('Error!', error.message));
    }

}, false);
