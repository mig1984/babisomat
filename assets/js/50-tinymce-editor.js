$().ready(function() {

  tinymce.baseURL = '/public/tinymce';

  /* can't be used on textareas; there is a hidden textarea filled in on change */
  tinymce.init({
    selector: 'div.tinymce',
    theme: 'inlite',
    plugins: 'image media table link paste contextmenu textpattern autolink codesample code',
    insert_toolbar: 'quickimage quicktable media codesample',
    selection_toolbar: 'bold italic | quicklink h2 h3 h4 h5 blockquote code',
    inline: true,
    paste_data_images: true,
    content_css: [
      '//fonts.googleapis.com/css?family=Lato:300,300i,400,400i',
      '//www.tinymce.com/css/codepen.min.css'],
    setup: function (editor) {
      editor.on('change', function () {
        var taId = this.id.substring(3);  // cut off the 'ed-' from the id => id of the hidden textarea
        var contents = tinymce.activeEditor.getContent();
        $('#'+taId).html(contents); // fill a hidden textarea
      });
    } 
  });
  
  tinymce.init({
    selector: 'textarea.tinymce',
    height: 500,
    menubar: false,
    plugins: [
      'advlist autolink lists link image charmap print preview anchor textcolor',
      'searchreplace visualblocks code fullscreen',
      'insertdatetime media table contextmenu paste code help'
    ],
    toolbar: 'insert | undo redo |  styleselect | bold italic backcolor  | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | removeformat code',
    content_css: [
      '//fonts.googleapis.com/css?family=Lato:300,300i,400,400i',
      '//www.tinymce.com/css/codepen.min.css'],
    setup: function (editor) {
      editor.on('change', function () {
        // otherwise won't send contents via xsubmit
        tinymce.triggerSave();
      });
    } 
  });

});
