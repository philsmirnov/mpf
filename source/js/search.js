var timer;
$("#search-field").keyup(function(e){
    if (timer) clearTimeout(timer);
    timer = setTimeout(function(){
        var $results = $("#results .search_cont");
        var q = $("#search-field").val();
        if (q.length == 0) {$results.empty().hide(); return;}
        $.getJSON("http://37.139.29.122/articles/"+q+".jsonp?callback=?",
        //$.getJSON("http://localhost:3000/articles/"+q+".jsonp?callback=?",

            {
            },
            function(data) {
                $results.empty();
                $.each(data, function(i,item){
                    $results.append(
                        '<div class="app_search_results">' +
                        '<h4 class="app_thin"><a href="' + item.parent_link +
                        '" class="app_lgray">' + item.article_type + '</a></h4>' +
                        '<h3 class="app_thin"><a href="' + item.url + '">' + item.name + '</a></h3>' +
                        '<p class="app_gray">' + item.excerpts + '</p></div>');
                });
                if (data && data.length > 0) $results.show();
            });
    }, 500);
});