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
                $("#results").empty();
                $("#results").append("<p>Results for <b>" + q + "</b></p>");
                $.each(data, function(i,item){
                    $("#results").append("<div class='large-8 app_smaller'><h4 class='app_normal'><a href='" + item.url + "'>" + item.name + "</a></h4><p>" + item.excerpts + "</p><br></div>");
                });
            });

    }, 500);
});