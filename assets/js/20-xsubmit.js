var findElement = function(item, selector) {
   // first time try closest to xsubmit caller
   var elm = $(item).closest(selector);
   if (elm.length>0) return elm;
   // second time direct selector
   elm = $(selector, item);
   if (elm.length>0) return elm;
   elm = $(selector);
   return elm;
}

var processResponse = function(data, item) {
      
  if (data.replace_with) {
    $.each(data.replace_with, function(selector,body){
      findElement(item, selector).replaceWith(body);
    });
  }
  if (data.html) {
    $.each(data.html, function(selector,body){
      findElement(item, selector).html(body);
    });
  }
  if (data.append) {
    $.each(data.append, function(selector,body){
      findElement(item, selector).append(body);
    });
  }
  if (data.prepend) {
    $.each(data.prepend, function(selector,body){
      findElement(item, selector).prepend(body);
    });
  }
  if (data.show) {
    $.each(data.show, function(k,selector){
      findElement(item, selector).show();
    });
  }
  if (data.hide) {
    $.each(data.hide, function(k,selector){
      findElement(item, selector).hide();
    });
  }
  
   if (data.form_errors) {
    $.each(data.form_errors, function(key,body){
       el = findElement(item, '#'+key);
       fg = el.closest('.form-group');
        if (body) {
         fg.addClass('has-error');
         $('.help-block.with-errors', fg).html("<p>"+body+"</p>")
       } else {
         fg.removeClass('has-error');
         $('.help-block.with-errors', fg).html('')
       }
    });
  }
  
  $(document).trigger('update');
  
  if (data.flash_notice) {
    $('.alert.alert-success').html(data.flash_notice).show();
  }
  if (data.flash_error) {
    $('.alert.alert-danger').html(data.flash_error).show();
  }
  
  if (data.alert) {
    alert(data.alert);
  }
  if (data.location) {
    if (window.location.pathname == data.location.replace(/#[^#]*$/,"")) { // same location, we have to reload otherwise nothing would happen
      var hash = data.location.replace(/.*?(#[^#]*)$/, '$1');
      if (hash!='') {
        window.location.hash = hash;
      }
      window.location.reload(true);
    } else {
      window.location = data.location;
    }
  }
  if (data.reload) {
    window.location.reload(true);
  }
}

var xsubmitForm = function(v) {   
  var method = $(v).attr('x-method') || $(v).attr('method') || 'get'; // here works prop instead of attr()
  var data = new FormData(v);
  var csrf;
  if ($('meta[name=_csrf]')) csrf = $('meta[name=_csrf]').attr('content');
  $.ajax({
    url: $(v).attr('action'),
    async: true,
    type: method,
    data: data,
    processData: false,  // tell jQuery not to process the data
    contentType: false,
    dataType: 'text',
    clearForm: true,
    crossDomain: true,
    headers: {'X_CSRF_TOKEN': csrf},
    xhrFields: { withCredentials: true },
    success: function(res) {
      res = $.parseJSON(res);
      processResponse(res, $(v));
    },
    error: function(res,ts) {
      alert('xsubmitForm error');
    }
  });
}

var xsubmitA = function(v) {
  var method = $(v).attr('method') || 'get'; // here works attr() instead of prop() which returns undefined
  var csrf;
  if ($('meta[name=_csrf]')) csrf = $('meta[name=_csrf]').attr('content');
  $.ajax({
    url: v.href,
    async: true,
    type: method,
    contentType: "application/json",
    dataType: 'json',
    crossDomain: true,
    headers: {'X_CSRF_TOKEN': csrf},
    xhrFields: { withCredentials: true },
    success: function(res) {
      processResponse(res, $(v));
    },
    error:  function(res,ts) {
      alert('xsubmitA error');
    }
  });
}

/********************************************************/

formSubmitter = function(event) { xsubmitForm(this); event.preventDefault(); }
aSubmitter    = function(event) { xsubmitA(this); event.preventDefault(); }

$(document).on('update', function() {
    
  // already can't be used if the 'already' has been added and then the html is copied to another div
  // -> this div has the 'already' attribute but has no submit
  
  $('form').each(function(k,v){
    //if ($(v).attr('already')) return;
    var action=$(v).attr('action');
    if (action.indexOf('?')>0) action = action.substring(0,action.indexOf('?'));
    if ( action.substring(action.length-5,action.length)=='.json' || $(v).hasClass('xsubmit') ) {
      //$(v).attr('already', true);
      //$(v).submit(formSubmitter);
      v.addEventListener('submit', formSubmitter);
    }
  });

  $('a').each(function(k,v){
    //if ($(v).attr('already')) return;
    var href=$(v).attr('href');
    if (href)
      if (href.indexOf('?')>0) href = href.substring(0,href.indexOf('?'));
    if ( (href && href.substring(href.length-5,href.length)=='.json') || $(v).hasClass('xsubmit') ) {
      //$(v).attr('already', true);
      //$(v).click(aSubmitter);
      v.addEventListener('click', aSubmitter);
    }
  });

});
