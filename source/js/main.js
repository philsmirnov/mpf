var timer;
$("#search-field").keyup(function(e){
    if (timer) clearTimeout(timer);
    timer = setTimeout(function(){
        var q = $("#search-field").val();
        //$.getJSON("http://ec2-54-217-232-182.eu-west-1.compute.amazonaws.com/articles/"+q+".json",$.getJSON("http://ec2-54-217-232-182.eu-west-1.compute.amazonaws.com/articles/"+q+".jsonp?callback=?",
        $.getJSON("http://localhost:3000/articles/"+q+".jsonp?callback=?",

            {
            },
            function(data) {
                $("#results").empty();
                $("#results").append("<p>Results for <b>" + q + "</b></p>");
                $.each(data, function(i,item){
                    $("#results").append("<div><a href='" + item.url + "'>" + item.name + "</a><br>" + item.excerpts + "<br><br></div>");
                });
            });

    }, 500);
});