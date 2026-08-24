const http = require("http");

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  // Health/readiness probe endpoint
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
    return;
  }

  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end("Hello from hello-beeline!\n");
});

server.listen(PORT, () => {
  console.log(`hello-beeline listening on port ${PORT}`);
});
