var timer;
$("#search-field").keyup(function(e){
    if (timer) clearTimeout(timer);
    timer = setTimeout(function(){
        var q = $("#search-field").val();
        $.getJSON("http://ec2-54-217-232-182.eu-west-1.compute.amazonaws.com/articles/"+q+".jsonp?callback=?",
        //$.getJSON("http://localhost:3000/articles/"+q+".jsonp?callback=?",

            {
            },
            function(data) {
                var $results = $("#results search_cont");
                $results.empty();
                $results.append("<p>Results for <b>" + q + "</b></p>");
                $.each(data, function(i,item){
                    $("#results").append(
                        '<div class="app_search_results">' +
                        '<h4 class="app_thin"><a href="' + item.url + '" class="app_lgray">Глоссарий</a></h4>' +
                        '<h3 class="app_thin"><a href="' + item.url + '">' + item.name + '</a></h3>' +
                        '<p class="app_gray">' + item.excerpts + '</p></div>');
                });
                if (data && data.length > 0) $results.show();
            });
    }, 500);
});