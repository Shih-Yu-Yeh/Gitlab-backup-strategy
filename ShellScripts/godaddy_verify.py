# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer, SimpleHTTPRequestHandler
import time
hostName = "10.10.3.99"
serverPort = 5880

class MyServer(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes("<body>", "utf-8"))
        self.wfile.write(bytes("<p>vd16p2mu2gv9bn</p>", "utf-8"))
        self.wfile.write(bytes("</body></html>", "utf-8"))

if __name__ == "__main__":        
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
