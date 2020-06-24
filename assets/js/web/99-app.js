  // these are set by index

  defaultChapter = null;
  URL_AUDIO = null;
  URL_TV = null;
  sources = {};
  bsources = {}; // there is a special 0.ogg (included in the total count); this will be played once on start of the chapter/spice
  tvpics  = {};
  loops = {};

  // 
  
  imageCache = {};  
  maxHeight = 200;
  
  counter = 0;
  chapterCounter = 0;
  stopped = true;
  chapter = null;
  justActivated = null;
  nextIsBAudio = 0;
  active = {};
  queues = {};
  bqueues = {};
  audios = {};
  baudios = {};
  onTV = null;
  TVSet = null;
  
  spiceTimeout1 = null;
  spiceTimeout2 = null;
  spiceTimeout3 = null;
  spiceTimeout4 = null;
  playChapterAudioTimeout = null;
  loopAudioTimeout = null;
  changeBgTimeout = null;

  loopAudios = [];
  loopCurrent = 0;
  chapterAudio = null;
  spiceAudio = null;
  loopAudioAudio = null;
  
  audioLooping = false;
  
  function removeItem(originalArray, itemToRemove) {
    var j = 0;
    while (j < originalArray.length) {
      if (originalArray[j] == itemToRemove) {
      originalArray.splice(j, 1);
      } else { j++; }
    }
    return originalArray;
  }
    
  function shuffle(a) {
    var j, x, i;
    for (i = a.length - 1; i > 0; i--) {
      j = Math.floor(Math.random() * (i + 1));
      x = a[i];
      a[i] = a[j];
      a[j] = x;
    }
    return a;
  }
  
  function getRandomInt(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  
  // reset queue and preload first item, 0.ogg is baudio, but special (only first time; then another baudio will be played)
  function initQueue(sound) {
    queues[sound] = [];
    if (bsources[sound]>0) {
      var path = URL_AUDIO + '/public/web/audio/'+sound+'/b/0.ogg';  
      bqueues[sound] = [path];
    } else {
      bqueues[sound] = [];
    }
    
    nextIsBAudio = 2; // play 0.ogg and a baudio immediately after
  }
  
  // fill and shuffle queue then return shifted item
  function getItem(sound) {
    if (queues[sound].length==0) {
      for(var i=0;i<sources[sound];i++) {
        queues[sound].unshift(URL_AUDIO + '/public/web/audio/'+sound+'/'+i+'.ogg');
      }
      queues[sound] = shuffle(queues[sound]);  
    }
    return queues[sound].shift()
  }
    
  // fill and shuffle queue then return shifted item
  function getBItem(sound) {
    if (bqueues[sound].length==0) {
      for(var i=1;i<bsources[sound];i++) { // 0 is special
        bqueues[sound].unshift(URL_AUDIO + '/public/web/audio/'+sound+'/b/'+i+'.ogg');
      }
      bqueues[sound] = shuffle(bqueues[sound]);
    }
    return bqueues[sound].shift()
  }
  
  function playSpiceAudio(nxt, chapterAudio, delay) {
    var spice;
    var isBTV;
    
    if (justActivated) {

      spice = justActivated;
      
      if (bsources[spice]>0) {
        var i = getBItem(spice);
      } else {
        var i = getItem(spice);
      }
      
      isBTV = true;
      
      justActivated = null;
      
    } else {
    
      var keys = Object.keys(sources);
      keys = removeItem(keys, /^chapter-/);
      keys = keys.filter(function(key) { return active[key] });
      spice = keys[getRandomInt(0,keys.length-1)];
      i = getItem(spice);          
      
    }

    var a = new Audio(i);
    var already = false;
    a.load();
    a.addEventListener('error', function() { alert('Došlo k chybě, zkus reloadnout stránku.'); });
// preloading if necessary
//     a.addEventListener('timeupdate', function() {
//       if (!already && (a.currentTime>a.duration/2 || a.duration<2)) {
//         already = true;
//         i2 = getItem();
//         a2 = new Audio(i2);
//         a2.load();
//         nextSpiceAudio = a2;
//       }
//     });
    a.addEventListener('canplay', function() {
      if (stopped) return;
      spiceTimeout1 = setTimeout(function() { changeTV(spice, isBTV); }, delay-800); // change screen to spice's in advance
      spiceTimeout2 = setTimeout(function() { a.play(); spiceAudio = a; }, delay-300); // play spice a bit sooner before chapter audio finishes
      spiceTimeout3 = setTimeout(function() { changeTV(chapter); }, delay+a.duration*1000+200); // screen back to chapter a bit after chapter audio
      spiceTimeout4 = setTimeout(nxt, delay+a.duration*1000-400); // chapter audio will start a bit sooner before spice audio finishes
    });
  }  
  
  function loopAudio(delay) {
    if (!loops[chapter]) return ;
    
    console.log("loopAudio");
    
    var a = new Audio(URL_AUDIO + '/public/web/audio/'+chapter+'/loop/0.ogg');
    var already = false;
    a.load();
    a.volume = 0.3;
    a.addEventListener('error', function() { alert('Došlo k chybě, zkus reloadnout stránku.'); });
    a.addEventListener('timeupdate', function() {
      if (stopped) return;
      if (!already && (a.currentTime>a.duration/4 || a.duration<2)) {
        already = true;
        loopAudio( (a.duration-a.currentTime)*1000 );
      }
    });        
    a.addEventListener('canplay', function() {
      if (stopped) return;
      loopAudioTimeout = setTimeout(function() { a.play(); loopAudioAudio = a; }, delay);
    });
  }
  
  function playChapterAudio(delay) {
    
    console.log("playChapterAudio, counter="+counter+", chapterCounter="+chapterCounter);
    
    counter++;
    chapterCounter++;
    
    if (bsources[chapter]>=nextIsBAudio && nextIsBAudio-->0) {
      var i = getBItem(chapter);
    } else {
      var i = getItem(chapter);
    }    
    var a = new Audio(i);
    var already = false;
    a.load();
    a.addEventListener('error', function() { alert('Došlo k chybě, zkus reloadnout stránku.'); });
    a.addEventListener('timeupdate', function() {
      if (stopped) return;
      if (!already && (a.currentTime>a.duration/4 || a.duration<2)) { // /4 also it will make spice audio load sooner
        already = true;
        playChapterAudio( (a.duration-a.currentTime)*1000 );
      }
    });        
    a.addEventListener('canplay', function() {
      if (stopped) return;
      
      nxt = function() {
        if (!audioLooping) { 
          if (chapterCounter==1 && loops[chapter]) new Audio(URL_AUDIO + '/public/web/audio/'+chapter+'/loop/0.ogg'); // preload
          else if (chapterCounter>=2) { loopAudio(); audioLooping = true; }
        }
        if (chapterCounter==2) changeTV(chapter, false); // no titles
        console.log("starting chapter audio");
        a.play();
        chapterAudio = a;
      }
      
      console.log("active "+Object.keys(active).length);
            
      if (counter>1 && delay>0 && (justActivated || getRandomInt(0,3)==1) && Object.keys(active).length>0) { // 'a' will be played via playSpiceAudio after delay plus spice's delay; just after start delay is undefined
        console.log('playing via playSpiceAudio with delay '+delay);
        nextIsBAudio = 1; // i.e. one normal after spice and then baudio (can't be played directly after spice because the audio is already loaded now (and it feels more authentic)
        playSpiceAudio(nxt, a, delay);
      } else { // played directly now
        console.log('playing directly with delay '+delay);
        playChapterAudioTimeout = setTimeout(nxt, delay);
      }

    });
  }
  
  

  function startPlay() {
    if (stopped) {
      stopped = false;
      var tv = document.getElementById('tv');
      tv.classList.remove('grayscale');
      var pb = document.getElementById('playbutton');
      pb.setAttribute('style','display:none');
      changeTV(chapter, chapterCounter==0);
      changeBg();
      playChapterAudio();
      console.log('START START START START START START START START START ');
    }
  }
  
  function stopPlay() {
    if (!stopped) {
      if (changeBgTimeout) clearTimeout(changeBgTimeout);
      if (spiceTimeout1) clearTimeout(spiceTimeout1);
      if (spiceTimeout2) clearTimeout(spiceTimeout2);
      if (spiceTimeout3) clearTimeout(spiceTimeout3);
      if (spiceTimeout4) clearTimeout(spiceTimeout4);
      if (playChapterAudioTimeout) clearTimeout(playChapterAudioTimeout);
      if (loopAudioTimeout) clearTimeout(loopAudioTimeout);
      if (loopAudioAudio) { loopAudioAudio.pause(); loopAudioAudio = null; }
      audioLooping = false;
      if (chapterAudio) { chapterAudio.pause(); chapterAudio = null; }
      if (spiceAudio) { spiceAudio.pause(); spiceAudio = null; }
      var tv = document.getElementById('tv');      
      tv.classList.add('grayscale');
      var pb = document.getElementById('playbutton');
      pb.setAttribute('style','display:block');
      stopped = true;
      console.log('STOP STOP STOP STOP STOP STOP STOP STOP STOP STOP STOP ');
    }
  }
  
  
  function togglePlay() {
    if (stopped) startPlay(); else stopPlay();
  }
  
  function loadImage(sound, TVSet, num) {
    var src = URL_TV + '/public/web/audio/'+sound+'/tv/'+TVSet+'/'+num+'.jpg';
    if (!imageCache[src]) { // if there is no cache, browser stops loading when src changes -> no pictures load
      console.log("loadImage: "+src);
      var x = new Image();
      x.setAttribute('id', 'tv');
      x.setAttribute('src', src);
      imageCache[src] = x;
    }
    return imageCache[src];
  }
  
  function preloadImages(sound,tvset) {
    console.log("PRELOAD IMAGES");
    for(var tvset=0; tvset<tvpics[sound].length; tvset++) {
      console.log("preloadImages: sound="+sound+" tvset="+tvset);
      for(var num=0; num<tvpics[sound][tvset]; num++) {
        loadImage(sound, tvset, num);
      }
    }
  }
  
  // preload queue items
  function getImage(sound, tvset) {
    var rnd = getRandomInt(0, tvpics[sound][tvset]-1);
    var i = loadImage(sound, tvset, rnd);
    i.setAttribute('height', maxHeight);
    if (stopped) i.classList.add('grayscale'); else i.classList.remove('grayscale');
    return i;
  }

  
  function changeTV(source, isBSource) {
    onTV = source;
    if (isBSource) 
      TVSet = 0;
    else
      TVSet = getRandomInt(1, tvpics[onTV].length-1);
    var tv = document.getElementById('tv');
    if (maxHeight<tv.height) maxHeight = tv.height; // maxHeight used for newly created images
    tv.replaceWith(getImage(source, TVSet));
  }
  
  // periodically change the background
  function changeBg() {
    var tv = document.getElementById('tv');
    tv.replaceWith(getImage(onTV,TVSet));
    changeBgTimeout = setTimeout(changeBg, getRandomInt(200,700));
  }
  
  // toggle spice
  function toggle(sound, just) {
    var e = document.getElementById(sound);
    if (!active[sound]) {
      e.classList.add('active');
      if (just) justActivated = sound;
      active[sound] = true;
    } else {
      e.classList.remove('active');
      delete active[sound];
    }
    initQueue(sound); // restart
    preloadImages(sound);
  }
  
  function loadChapter(newChapter) {
    var wasStopped = stopped;

    if (chapter) {
      var curr = document.getElementById(chapter);
      curr.classList.remove('active');
      stopPlay();
    }
    chapter = newChapter;
    var curr = document.getElementById(chapter);
    curr.classList.add('active');

    chapterCounter = 0;
    
    initQueue(chapter);
    preloadImages(chapter);
    changeTV(chapter, true);
    
    if (!wasStopped) startPlay();
  }

  function init() {
    //for (var k in sources) { initQueue(k); }
    loadChapter(defaultChapter);
  }
