#!/bin/bash

# Configuration

# This will be used in URLs and file paths, so don't get too fancy
# Alphanumeric characters and underscores should be ok
export APP_NAME=meteorapp

# IP or URL of the server you want to deploy to
export APP_HOST=http://example.com

# pem file
export SSH_PEM=/path/to/local/pem/file

# You usually don't need to change anything below this line

export SSH_HOST=ubuntu@$APP_HOST
export ROOT_URL=http://$APP_HOST
export APP_DIR=/var/www/$APP_NAME
export MONGO_URL=mongodb://localhost:27017/$APP_NAME
if [ -d ".meteor/meteorite" ]; then
    export METEOR_CMD=mrt
  else
    export METEOR_CMD=meteor
fi

case "$1" in
setup )
echo Preparing the server...
echo Get some coffee, this will take a while.
ssh -i $SSH_PEM $SSH_HOST APP_DIR=$APP_DIR DEBIAN_FRONTEND=noninteractive 'bash -s' > /dev/null 2>&1 <<'ENDSSH'
sudo su
apt-get update
apt-get install -y python-software-properties
add-apt-repository ppa:chris-lea/node.js-legacy
apt-get update
apt-get install -y build-essential nodejs npm mongodb
npm install -g forever
ENDSSH
echo Done. You can now deploy your app.
;;
deploy )
echo Deploying...
$METEOR_CMD bundle bundle.tgz
scp -i $SSH_PEM bundle.tgz $SSH_HOST:/tmp/
rm bundle.tgz
echo pre ssh app dir: $APP_DIR
ssh -i $SSH_PEM $SSH_HOST MONGO_URL=$MONGO_URL ROOT_URL=$ROOT_URL APP_DIR=$APP_DIR 'bash -s' <<'ENDSSH'
if [ ! -d "$APP_DIR" ]; then
sudo mkdir -p $APP_DIR
sudo chown -R www-data:www-data $APP_DIR
fi
pushd $APP_DIR
sudo forever stop bundle/main.js
sudo rm -rf bundle
sudo tar xfz /tmp/bundle.tgz -C $APP_DIR
sudo rm /tmp/bundle.tgz
pushd bundle/server/node_modules
sudo rm -rf fibers
sudo npm install fibers
popd
sudo chown -R www-data:www-data bundle
sudo patch -u bundle/server/server.js <<'ENDPATCH'
@@ -286,6 +286,8 @@
     app.listen(port, function() {
       if (argv.keepalive)
         console.log("LISTENING"); // must match run.js
+      process.setgid('www-data');
+      process.setuid('www-data');
     });
 
   }).run();
ENDPATCH
sudo forever start bundle/main.js
popd
ENDSSH
echo Your app is deployed and serving on: $ROOT_URL
;;
* )
cat <<'ENDCAT'
./meteor.sh [action]

Available actions:

  setup   - Install a meteor environment on a fresh Ubuntu server
  deploy  - Deploy the app to the server
ENDCAT
;;
esac
