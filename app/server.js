var fs = require('fs');
var https = require('https');

// We're expecting: node server.js /foo/bar/config.json /foo/bar/tls.crt.key
if (process.argv.length !== 4) {
  throw "This Node.js app requires exactly two arguments to be passed to it: the path to a config file and the path to a private TLS cert key.";
}

var configPath = process.argv[2];
var config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

var privateTlsCertKeyPath = process.argv[3];
var privateTlsCertKey = fs.readFileSync(privateTlsCertKeyPath, 'utf8');

var hostname = "0.0.0.0";
var env = process.env.VPC_NAME || 'development';
var port = process.env.PORT || 3000;
var contextPath = process.env.CONTEXT_PATH || "/sample-app-frontend";
var indexHtml = fs.readFileSync(__dirname + '/index.html');

var loadBalancerBaseUrl = process.env.INTERNAL_ALB_URL || "localhost:" + port;
var backendServicePort = process.env.BACKEND_PORT || 80;
var backendServicePath = "/sample-app-backend";

var options = {
  ca: fs.readFileSync(__dirname + '/../tls/ca-' + env + '.crt.pem'),
  key: privateTlsCertKey,
  cert: fs.readFileSync(__dirname + '/../tls/cert-' + env + '.crt.pem')
};

var internalAlbCaCert = env === 'development' ? "" : fs.readFileSync(__dirname + '/../tls/internal-alb-' + env + '-ca.pem');

var server = https.createServer(options, function (request, response) {
  console.log("Got request: " + request.url);

  switch (request.url) {
    case contextPath:
      writeResponse(response, 200, indexHtml);
      break;

    case contextPath + '/health':
      writeResponse(response, 200, "OK");
      break;

    case contextPath + '/greeting':
      writeResponse(response, 200, config.greeting);
      break;

    case contextPath + '/service':
      makeServiceCall(loadBalancerBaseUrl, backendServicePath, backendServicePort, function(err, data) {
        writeResponse(response, 200, "Response from service: " + data, err);
      });
      break;

    case contextPath + '/service/db':
      makeServiceCall(loadBalancerBaseUrl, backendServicePath + '/db', backendServicePort, function(err, data) {
        writeResponse(response, 200, "Response from service: " + data, err);
      });
      break;

    default:
      writeResponse(response, 404, "Not found");
      break;
  }
});

server.listen(port, hostname);

console.log("Server running at https://" + hostname + ":" + port);

process.on('SIGINT', function() {
  process.exit();
});

var writeResponse = function(response, status, data, err) {
  response.writeHead(err ? 500 : status, {"Content-Type": "text/html"});
  if (err) {
    response.end(JSON.stringify(err));
  } else {
    response.end(data);
  }
};

var makeServiceCall = function(host, path, port, callback) {
  var options = {
    host: host,
    path: path,
    port: port
  };

  if (env === 'development') {
    // In dev, our apps talk to each other directly using self-signed certs, so we disable TLS cert verification.
    options.rejectUnauthorized = false;
  } else {
    // In prod, the apps talk to each other via an internal ALB, which also uses a self-signed cert, but we have the
    // CA for that cert, so we can verify the connection
    options.ca = internalAlbCaCert;
  }

  https.get(options, function(response) {
    var body = '';

    response.on('data', function(data){
      body += data;
    });

    response.on('end', function() {
      callback(null, body);
    });
  }).on('error', callback);
};
