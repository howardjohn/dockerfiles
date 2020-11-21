from flask import Flask
from flask import request
import socket
import os
import sys
import requests

app = Flask(__name__)


@app.route('/')
def hello():
    return 'Hello from behind service {}! hostname: {} \n'.format(
        os.environ.get('SERVICE_NAME', 'unknown'),
        socket.gethostbyname(socket.gethostname())
    )


@app.route('/status/<status>')
def status(status):
    return "Sending Status %s\n" % status, status


@app.route('/simple')
def simple():
    return os.environ.get('SERVICE_NAME', 'unknown') + "\n"

port = int(os.environ.get('PORT', '8080'))
if __name__ == "__main__":
    app.run(host='0.0.0.0', port=port, debug=False)
