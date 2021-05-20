# SimpleAnalytics Reader

### Desktop app for displaying data collected with the SimpleAnalytics package

The [SimpleAnalytics package](https://github.com/dennisbirch/simple-analytics) allows you to collect data user interaction analytic data in iOS and macOS applications. This _SimpleAnalytics Reader_ app project allows you to more easily make sense of that collected data by displaying it on your Mac. It can run right out of the box with one minor configuration step.

### Setup
SimpleAnalytics Reader works by sending database queries to a backend app, which forwards them to the database that's collecting your analytics data. Therefore you need to make a web app available, and add a text file with the URL for it in the SimpleAnalytics Reader project folder.

##### Web app
The __query.php__ file at the top level of the project's repository folder is the best starting point for providing a web app. If you have PHP and MySQL available on your web service (and you're using MySQL for collecting your data), you can configure the file for database access and upload it to your service. 

If that's not the case, or you prefer to build your web app with another language, your web app should be able to handle POST requests with two parameters encoded in JSON in the request body: 

|Label         | Contents                                                                                                      |
|------------- | --------------------------------                                                                              |
| __query__     | A String with semi-colon delimited SQL queries (usually two at the most)                                                   |
| __queryMode__ | A String with a value of either "array" or "dictionary"

Your web app should pass the request on to your database, and return the search results as a JSON object whose format depends on the _queryMode_ parameter passed in:

|Query Mode         | Format                                                                                                      |
|------------- | --------------------------------                                                                              |
| __Array__ |`[[String]]` Array of arrays containing the retrieved values as strings. In PHP this is a numeric Array. 
| __Dictionary__     |`[[String : String]]` (array of dictionaries) structure. The inner dictionary's key is the database column name, and the value is the row's value for that column. In PHP this is an associative array.

Example of an _Array_ return value: 

```
▿ 2 elements
  ▿ 0 : 1 element
    - 0 : "iOS (iPad)"
  ▿ 1 : 1 element
    - 0 : "iOS (iPhone)"
```

Example of a _Dictionary_ return value:

```
▿ 4 elements
  ▿ 0 : 2 elements
    ▿ 0 : 2 elements
      - key : "count"
      ▿ value : <String>
        - some : "9"
    ▿ 1 : 2 elements
      - key : "description"
      ▿ value : <String>
        - some : "Added observation from phone"
  ▿ 1 : 2 elements
    ▿ 0 : 2 elements
      - key : "description"
      ▿ value : <String>
        - some : "Added observation from watch"
    ▿ 1 : 2 elements
      - key : "count"
      ▿ value : <String>
        - some : "17"
  ▿ 2 : 2 elements
    ▿ 0 : 2 elements
      - key : "description"
      ▿ value : <String>
        - some : "Displayed session summary"
    ▿ 1 : 2 elements
      - key : "count"
      ▿ value : <String>
        - some : "9"
  ▿ 3 : 2 elements
    ▿ 0 : 2 elements
      - key : "description"
      ▿ value : <String>
        - some : "Edited Session title"
    ▿ 1 : 2 elements
      - key : "count"
      ▿ value : <String>
        - some : "2"
```

##### Endpoint file
Once your web app is available, you need to let SimpleAnalytics Reader know where it is by creating a text file named "Endpoint.txt" at the project folder's top level. Then add the file to the project, selecting the "Create folder references" option.

##### Running and debugging
With those two steps complete, you are ready to begin running SimpleAnalytics Reader.

If things are not working as expected, it's probably because the app isn't getting data back in the format expected. You may find the information logged in the Xcode Console can help you make the necessary adjustments.

### Functionality
SimpleAnalytics Reader has two main views you can toggle between to review collected analytics data in different modes: _List_ and _Search_. 

#### List view
The List view lets you navigate through the data collected by selecting from lists of Applications, Platforms, "Items" and "Counters". (Items and Counters are specific types of data that the SimpleAnalytics packages supports collecting.) By clicking through all the way down to an individual Item or Counter listing, you can see details on which device IDs produced the collected data on which dates.

#### Search view
The Search view lets you generate specific search queries to see pretty much whatever data you want.

##### Query generator
Along the left edge of the window is a Query generator that lets you build up the pieces of your query one condition at a time. Each condition block lets you choose the field to match on, and how and what to match. 

You can add additional query blocks by clicking the __+__ button. You can remove a single block by selecting it and clicking the _—_ button, or start from scratch by clicking the __Remove All__ button.

You can choose to require all the conditions or any condition from the radio buttons available. You can choose whether to include "Items", "Counters", or "Both" from a separate set of radio buttons.

You execute your query by clicking the __Search__ button or hitting the Return key. If you'd like to restrict the number of results returned, check the __Limit search results__ checkbox and select or enter an appropriate value in the _Show_ text field.

After you execute a search with the query generator, the SQL that was generated appears in the text view above the control panel. You can copy that to use as a starting point for generating query snippets.

You can save queries you build by choosing _Save Search..._ from the __Search__ menu. Reload a saved search by choosing _Load Search..._, and view a list of saved searches (where you can delete unwanted ones) by choosing _Show Saved Queries_.

##### Running Snippets
For the most flexibility, you may want to run queries based on your own SQL statements. The __Search__ menu offers options for doing that. _Save SQL Snippet..._ allows you to test and save a query for later execution. You can execute those saved snippets by choosing _Execute Saved Query..._, and see a list of those saved snippets by choosing _Show Saved Snippets_ (which also allows you to delete unwanted saved snippets. To execute a one-off snippet, choose _Execute New Snippet_.
