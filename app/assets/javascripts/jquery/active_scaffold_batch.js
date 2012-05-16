jQuery(document).ready(function() {
  jQuery('.batch-create-rows a').live('ajax:beforeSend', function(event, xhr, settings) {
    var num_records = jQuery(this).closest('.batch-create-rows').find('input[name=num_records]').val();
    if (num_records) settings.url += (settings.url.indexOf('?') != -1 ? '&' : '?') + 'num_records=' + num_records;
    return true;
  });
});
