$("#search-field").keyup(function(e){
    var q = $("#search-field").val();
    //$.getJSON("http://ec2-54-217-232-182.eu-west-1.compute.amazonaws.com/articles/"+q+".json",$.getJSON("http://ec2-54-217-232-182.eu-west-1.compute.amazonaws.com/articles/"+q+".json",
    $.getJSON("http://localhost:3000/articles/"+q+".jsonp?callback=?",

        {
        },
        function(data) {
            $("#results").empty();
            $("#results").append("<p>Results for <b>" + q + "</b></p>");
            $.each(data, function(i,item){
                $("#results").append("<div><a href='" + item.url + "'>" + item.name + "</a><br>" + item.excerpts + "<br><br></div>");
                //$("#results").append("<div><a href='http://en.wikipedia.org/wiki/" + encodeURIComponent(item.title) + "'>" + item.title + "</a><br>" + item.snippet + "<br><br></div>");
            });
        });
});