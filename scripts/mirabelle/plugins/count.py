from datasette import hookimpl

'''
@hookimpl
def extra_css_urls(database, table, columns, view_name, datasette):
    return [
        "/-/static-plugins/datasette_query_history/datasette-query-history.css",
    ]
'''

@hookimpl
def extra_js_urls(database, table, columns, view_name, datasette):
    return [
        "/-/static-plugins/count/datasette-count-plugin.js",
    ]
