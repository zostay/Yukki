$(document).ready(function() {
    $('input:submit').button();

    if ($('#preview-yukkitext').length > 0) {
        setInterval(function() {
            var url = String(window.location).replace(/\/edit\//, '/preview/');
            $.post(url, { 'yukkitext': $('#yukkitext').val() }, 
                function(data) {
                    $('#preview-yukkitext').html(data);
                }
            );
        }, 10000);
    }
});
