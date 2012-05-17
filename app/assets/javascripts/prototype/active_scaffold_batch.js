document.observe("dom:loaded", function() {
  document.on('ajax:create', '.batch-create-rows a', function(event, response) {
    var num_records = $(this).up('.batch-create-rows').down('input[name=num_records]').value();
    if (num_records) response.request.url += (response.request.url.include('?') ? '&' : '?') + 'num_records=' + num_records;
    return true;
  });
  document.on('click', '.multiple .form_record > a.remove', function(event) {
    event.stop();
    var record = $(this).up('.form_record'), errors = record.previous('.form_record-errors');
    if (errors) errors.remove();
    record.remove();
  });
});
