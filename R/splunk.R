library(httr)
library(purrr)
library(getPass)

.initialize = function(...) {
    # for host and app, try to read an environment variable. If not present, get the values
    host = Sys.getenv("SPLUNKHOST")
    if (host == "") {
        prompt = paste("What is the URL of your Splunk server?",
                       "This is typically in the format of https://<hostname>:8089.",
                       "Be sure to use the hostname of your search head if you have one.",
                       "To avoid entering this data manually each time, create an environment",
                       "variable called SPLUNKHOST with the appropriate value.",
                       sep="\n")
        cat(prompt)
        host = readline(prompt="URL: ")
    }

    app = Sys.getenv("SPLUNKAPP")
    if (app == "") {
        prompt = paste("What is the default app you would like to use for queries?",
                       "Enter nothing to use the default Search & Reporting app.",
                       "To avoid entering this data manually each time, create an environment",
                       "variable called SPLUNKAPP with the appropriate value.",
                       sep="\n")
        cat(prompt)
        app = readline(prompt="App: ")
        if (app == '') {
            app = 'search'
        }
    }

    username = readline(prompt="Username: ")
    password = getPass(msg="Password: ", noblank=TRUE, forcemask=FALSE)

    callSuper(..., host=host, app=app, username=username, password=password)
}

.request = function(method, endpoint, headers=NULL, data=NULL) {
    endpoint = gsub('^/', '', endpoint)
    url = paste0(.self$host, '/', endpoint)

    if (method == 'GET') {
        request = GET
    } else {
        request = POST
    }

    response = request(url=url,
                       config=config(ssl_verifypeer=0L),
                       use_proxy(""),
                       authenticate(.self$username, .self$password),
                       add_headers(.headers=headers),
                       body=data, encode='form')
    results = .self$parse_results(response)
    return(results)
}

.get = function(endpoint, headers=NULL, data=NULL) {
    return(.self$request('GET', endpoint, headers, data))
}

.post = function(endpoint, headers=NULL, data=NULL) {
    return(.self$request('POST', endpoint, headers, data))
}

.query = function(query, et, lt=NULL, endpoint=NULL, output_mode='json', count=0, headers=c('Content-Type'='application/json'), cache=FALSE) {
    query = trimws(query)
    data = list(exec_mode='oneshot',
                output_mode=output_mode,
                search=query,
                count=count,
                earliest_time=et)
    if (!is.null(lt)) {
        data['latest_time'] = lt
    }
    header = headers
    if (is.null(endpoint)) {
        endpoint = paste('servicesNS', .self$username, .self$app, 'search/jobs', sep='/')
    }
    results = .self$post(endpoint=endpoint, data=data, headers=header)

    if (cache) {
        fname = paste0('cached splunk query results - ', Sys.Date(), '.Rdata')
        write_rds(results, fname)
        print(paste('Results cached:', file.path(getwd(), fname)))
    }
    df = map_df(results, `[`)
    return(df)
}

.parse_results = function(response) {
    response = content(response)

    if ('results' %in% names(response)) {
        results = response$results
    } else if ('entry' %in% names(response)) {
        results = response$entry
    } else if (is.list(response)) {
        results = data.frame('keys'=unlist(response), stringsAsFactors=FALSE)
    } else {
        warning('Could not find a known key for the results', call.=FALSE)
        results = response
    }
    return(results)
}

API = setRefClass('SplunkAPI',
                  field=list(host='character', app='character',
                             username='character', password='character'),
                  method=list(initialize=.initialize, request=.request,
                              post=.post, get=.get, query=.query, parse_results=.parse_results))
