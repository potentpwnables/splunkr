# Overview

This is a simple wrapper to the Splunk API for R. There are three main ways in which you interact with the API, and that's via the `get`, `post`, and `query` commands, although, the `post` and `query` should be the ones used most often.

# How to use it

After loading the library with `library(splunk)`, initiate the API class by calling `splunk <- API()`. The first time you do this, you'll be prompted to enter the URL of your Splunk instance, which you should be able to get from your Splunk admins. 

You'll also be asked if you'd like to set a default app to be used for queries. 
It is not uncommon for a Splunk environment to only have the default Search & Reporting app, so you can leave the app prompt blank by just hitting enter to use this default app. 

Next, you'll be asked for your username and password. The first two values, URL and default app, don't have to be entered manually every time. If you plan on using the same values every time, you can create two environment variables called SPLUNKHOST and SPLUNKAPP, respectively, with the default values. Be sure to capitalize the environment variable names.

Once you've entered the necessary information to interact with Splunk, you're ready to start interacting with it. 

#### get

`get` is mostly used to access searches that you may have run in an asynchronous fashion. What this means is that if you have a query that you know takes a long time, you can run the query and have Splunk immediately return control back to R while the query runs. It will pass your a search ID, and you can use that ID to query the status of the search via a `get` request.

#### post

`post` is the workhorse of the API. `post` is what you use to query the data and to create KV store lookup tables; `query` is actually just a wrapper for `post` that passes some default values.

#### query

`query` is the main function that should be used when interacting with the API. You start by defining your query, which **must** start with the word "search" unless using something like `| tstats` or `| inputlookup` where the `|` must be the first element. You then specify your earliest time using Splunk's relative time syntax (e.g. -12h for 12 hours ago, or -12h@h for 12 hours ago from the beginning of the current hour). The default search type is what is called "one shot", which means that Splunk will not return control to R until the search has finished. `query` is also the function that uses the default query app you provided when you initialized the API class. 

# Examples

#### Load Splunk and initialize the API

```
library(splunk)
splunk <- API()
```

#### Query Splunk

```
query = '
search source="flights.csv"
| where isnotnull(arr_delay) AND isnotnull(dep_delay)
| stats mean(arr_delay) as avg_arr_delay, mean(dep_delay) as avg_dep_delay by origin
'
results <- splunk$query(query=query, et='-12h@h')
results
```

#### Update a KV store lookup table with lots of records

```
# use the results from the above example
# batch_save is used to store 1,000 records at a time
endpoint <- 'services/NS/nobody/<insert your app>/storage/collections/data/<kv lookup name>/batch_save'
headers <- c('Content-Type'='application/json')
data <- as.character(jsonlite::toJSON(results))
splunk$post(endpoint=endpoint, data=data, headers=headers)
```
