var LOADER = {
  params: {},
  basePath: '',
  loadFile: function (relPath) {
    var body = document.getElementsByTagName('body')[0];
    var script = document.createElement('script');
    script.src = this.basePath + relPath;
    script.type = 'application/javascript';
    script.async = false;
    script.defer = false;
    body.appendChild(script);
  }
};

(function () {

  var sourceOptionList = ['local', 'devel', 'stable', 'none'];

  var sourceOptions = {
    'local': 'http://localhost:8080/',
    'devel': 'https://www.emulab.net/protogeni/flack-devel/',
    'stable': 'https://www.emulab.net/protogeni/flack-stable/',
    'none': ''
  };

  function getQueryParams(qs) {
    qs = qs.split('+').join(' ');
    var params = {};
    var re = /[?&]?([^=]+)=([^&]*)/g;
    var tokens = re.exec(qs);
    
    while (tokens) {
      params[decodeURIComponent(tokens[1])]
        = decodeURIComponent(tokens[2]);
      tokens = re.exec(qs);
    }
    
    return params;
  }

  LOADER.params = getQueryParams(window.location.search);
  LOADER.basePath = sourceOptions['stable'];

  var sourceName = LOADER.params['source'];
  if (sourceOptionList.indexOf(sourceName) !== -1)
  {
    LOADER.basePath = sourceOptions[sourceName];
  }

  LOADER.loadFile('main.js');

}());
