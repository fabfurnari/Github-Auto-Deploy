#!/usr/bin/env python

import json, urlparse, sys, os
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
from subprocess import check_output
import logging

log_file = os.environ.get('BUILDER_LOGFILE','/home/builder/log/daemon.log')
conf_file = os.environ.get('BUILDER_CONFFILE','/home/builder/daemon/GitAutoDeploy.conf.json')

logging.basicConfig(format='%(asctime)s %(message)s',filename=log_file,level=logging.DEBUG)

class GitAutoDeploy(BaseHTTPRequestHandler):

    CONFIG_FILEPATH = conf_file
    config = None
    quiet = False
    daemon = False
    
    @classmethod
    def getConfig(myClass):
        if(myClass.config == None):
            try:
                configString = open(myClass.CONFIG_FILEPATH).read()
            except:
                logging.error('Could not load ' + myClass.CONFIG_FILEPATH + ' file')
                sys.exit('Could not load ' + myClass.CONFIG_FILEPATH + ' file')

            try:
                myClass.config = json.loads(configString)
            except:
                logging.error(myClass.CONFIG_FILEPATH + ' file is not valid json')
                sys.exit(myClass.CONFIG_FILEPATH + ' file is not valid json')

            for repository in myClass.config['repositories']:
                if(not os.path.isdir(repository['path'])):
                    logging.error('Directory ' + repository['path'] + ' not found')
                    sys.exit('Directory ' + repository['path'] + ' not found')
                if(not os.path.isdir(repository['path'] + '/.git')):
                    logging.error('Directory ' + repository['path'] + ' not found')
                    sys.exit('Directory ' + repository['path'] + ' is not a Git repository')

        return myClass.config

    def do_POST(self):
        urls, is_tag = self.parseRequest()
        logging.info("Received POST request for %s " % urls)
        for url in urls:
            paths = self.getMatchingPaths(url)
            for path in paths:
                self.pull(path)
                self.deploy(path, is_tag)

    def parseRequest(self):
	is_tag = False
        length = int(self.headers.getheader('content-length'))
        body = self.rfile.read(length)
        post = urlparse.parse_qs(body, strict_parsing=True)
        items = []
        for itemString in post['payload']:
            item = json.loads(itemString)
            items.append(item['repository']['url'])
        logging.debug("POST payload: %s" % items)
        if 'base_ref' in item:
            # It is a tag
            logging.info("A tag has been committed")
            is_tag = True
        logging.debug("Items: " % items)
        return items, is_tag

    def getMatchingPaths(self, repoUrl):
        res = []
        config = self.getConfig()
        for repository in config['repositories']:
            if(repository['url'] == repoUrl):
                res.append(repository['path'])
        return res

    def respond(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()

    def pull(self, path):
        if(not self.quiet):
            logging.info("Post push request received")
            logging.info('Updating ' + path)
        logging.info(check_output(['cd "' + path + '" && git pull'], shell=True))

    def deploy(self, path, is_tag):
        config = self.getConfig()
        for repository in config['repositories']:
            if(repository['path'] == path):
                if 'deploy' in repository:
                     if(not self.quiet):
                         logging.info("Executing deploy command for %s" % repository['path'])
                     if is_tag:
                        par = 'stable'
                     else:
                        par = 'dev'
                     cmd = 'cd "{0}" && {1} {2}'.format(path, repository['deploy'], par)
                     logging.debug(cmd)
                     logging.info(check_output([cmd], shell=True))
                break

def main():
    try:
        server = None
        for arg in sys.argv:
            if(arg == '-d' or arg == '--daemon-mode'):
                GitAutoDeploy.daemon = True
                GitAutoDeploy.quiet = True
            if(arg == '-q' or arg == '--quiet'):
                GitAutoDeploy.quiet = True

        if(GitAutoDeploy.daemon):
            pid = os.fork()
            if(pid != 0):
                sys.exit()
            os.setsid()

        if(not GitAutoDeploy.quiet):
            logging.info('Github Autodeploy Service v 0.1 started')
        else:
            logging.info('Github Autodeploy Service v 0.1 started in daemon mode')

        server = HTTPServer(('', GitAutoDeploy.getConfig()['port']), GitAutoDeploy)
        server.serve_forever()
    except (KeyboardInterrupt, SystemExit) as e:
        if(e): # wtf, why is this creating a new line?
            print >> sys.stderr, e

        if(not server is None):
            server.socket.close()

        if(not GitAutoDeploy.quiet):
            logging.warning('Goodbye')

if __name__ == '__main__':
     main()
