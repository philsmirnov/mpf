$(function(){
    var resize = function(){
        var fontSize = localStorage.getItem('fontSize');
        if (fontSize) {
            $('.app_fonts .columns').removeClass('active')
            if (fontSize == "0.875em") $('.app_fonts .small-font').addClass('active');
            if (fontSize == "1.05em") $('.app_fonts .mid-font').addClass('active');
            if (fontSize == "1.2em") $('.app_fonts .big-font').addClass('active');
        }
    };

    $('.app_fonts .columns').click(function(e){
        var div = $(e.target).parent('div');
        if (div.hasClass('small-font')) localStorage.setItem('fontSize', "0.875em");
        if (div.hasClass('mid-font')) localStorage.setItem('fontSize', "1.05em");
        if (div.hasClass('big-font')) localStorage.setItem('fontSize', "1.2em");
        resize();
        MBP.setFontSize();
    });

    resize();
});