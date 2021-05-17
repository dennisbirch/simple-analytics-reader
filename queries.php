<?php
/*
Here is an example script written in PHP for handling data queries from SimpleAnalytics Reader on a 
web service that hosts MySQL databases. Please consider this as a starting point, or an 
inspiration for your own solution.

CAVEAT EMPTOR: This script was created by a relatively new PHP programmer, using documentation
and solutions found online. It may have serious unknown flaws as it has only been lightly 
tested. But it has been found to work in at least light usage. As always, your mileage may vary.

===============

This script assumes a MySQL database with tables for "items" and "counters", where...
...the 'items' table's columns are:
description: VarChar
details: VarChar
device_id: VarChar
app_name: VarChar
app_version: VarChar
platform: VarChar
system_version: VarChar
timestamp: DateTime
id: Auto incrementing primary key


...the 'counters' table's columns are:
description: VarChar
count: Integer
device_id: VarChar
app_name: VarChar
app_version: VarChar
platform: VarChar
system_version: VarChar
timestamp: DateTime
id: Auto incrementing primary key

****************
Be sure to configure the following four properties in order to be able to connect to your database.
****************

*/
$servername = "";
$dbname      = "";
$username = "";
$password = "";

$queryString = $_POST['query'];
$queryMode = $_POST['queryMode'];

$dbErrorCode = 503;

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
	echo(generateErrorResponse('Cannot connect to MySQL database.' . $conn->connect_error, $dbErrorCode));
	return;
}

runQuery($conn, $queryString, $queryMode);

function runQuery($conn, $query, $mode) {
	$mode_for_query = MYSQLI_ASSOC;
	if ($mode === 'array') {
	 	$mode_for_query = MYSQLI_NUM;
	 }

	 if (mysqli_multi_query($conn, $query)) {

	 $full_results = array();

	 	do {
	 		if ($result = mysqli_store_result($conn)) {
	 			$fields = mysqli_fetch_all($result, $mode_for_query);
	 			$full_results = array_merge($full_results, $fields);
	 			mysqli_free_result($result);
	 		}
	 		
	 		if (mysqli_more_results($conn) === false) {
	 			$encoded = json_encode($full_results);        
				echo($encoded);
	 			return;
	 		}
	 	} while (mysqli_next_result($conn));
	 	
	 	$encoded = json_encode($full_results);        
        echo($encoded);
	 }



function generateErrorResponse($message, $code) {
	header ($message, true, $code);	

	$response = array('message' => $message);
	$encoded = json_encode($response);
	
	return (string)$encoded;
}

?>
