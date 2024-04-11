#!/bin/bash
set -e

export LOGDIR="${LOGDIR:/var/log/airnotifier}"
export LOGFILE="${LOGFILE:airnotifier.log}"
export LOGFILE_ERR="${LOGFILE_ERR:airnotifier.err}"

if [ -f "./config.py" ]; then
# we do not assume passwordsalt and cookiesecrets contain a space or any escape char
  if [ ! -z "${AIRNOTIFIER_PASSWORDSALT}" ] ||  [ ! -z "${AIRNOTIFIER_COOKIESECRETS}" ]; then
    echo "WARNING: will ignore provided \"\${AIRNOTIFIER_PASSWORDSALT}\", \"\${AIRNOTIFIER_COOKIESECRETS}\" and \"\${MONGO_PROTOCOL}\", will read existing configuration from file \"./config.py\""
  fi
  AIRNOTIFIER_PASSWORDSALT=$(grep passwordsalt config.py|grep -vE "[[:space:]]?#[[:space:]]?passwordsalt"|cut -d= -f2|tr -d " '\"")
  AIRNOTIFIER_COOKIESECRETS=$(grep cookiesecret config.py|grep -vE "[[:space:]]?#[[:space:]]?cookiesecret"|cut -d= -f2|tr -d " '\"")
  MONGO_PROTOCOL=$(grep mongouri config.py|grep -vE "[[:space:]]?#[[:space:]]?mongouri"|cut -d= -f2|tr -d " '\""|cut -d: -f1)
  MONGO_USER=$(grep mongouri config.py|grep -vE "[[:space:]]?#[[:space:]]?mongouri"|cut -d= -f2|tr -d " '\""|grep @|cut -d/ -f3|cut -d: -f1)
  MONGO_PASS=$(grep mongouri config.py|grep -vE "[[:space:]]?#[[:space:]]?mongouri"|cut -d= -f2|tr -d " '\""|grep @|cut -d/ -f3|cut -d: -f2|cut -d@ -f1)
fi

# fall-back to random defaults 25 char defaults
__defaultpassordsalt=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 25; echo)
__defaultcookiesecret=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 25; echo)

# setup environment variables with defaults
MONGO_SERVER=${MONGO_SERVER-localhost}
MONGO_PORT=${MONGO_PORT-27017}
AIRNOTIFIER_PASSWORDSALT=${AIRNOTIFIER_PASSWORDSALT-$(echo ${__defaultpassordsalt})}
AIRNOTIFIER_COOKIESECRETS=${AIRNOTIFIER_COOKIESECRETS-$(echo ${__defaultcookiesecret})}
MONGO_PROTOCOL=${MONGO_PROTOCOL-mongodb}
if [ ! -z "${MONGO_USER}" ]; then
	MONGO_URL=${MONGO_PROTOCOL}://${MONGO_USER}:${MONGO_PASS}@${MONGO_SERVER}:${MONGO_PORT}/${MONGO_DATABASE}?${MONGO_OPTIONS}
else
	MONGO_URL=${MONGO_PROTOCOL}://${MONGO_SERVER}:${MONGO_PORT}/${MONGO_DATABASE}?${MONGO_OPTIONS}
fi
MONGO_URL_REGEX=$(echo ${MONGO_URL}|sed "s#\\/#\\\\/#g"|sed "s#\\+#\\\\+#g")
echo "MONGO_URL_REGEX: ${MONGO_URL_REGEX}"
if [ ! -f "./config.py" ]; then
  cp config.py-sample config.py
fi

sed -i 's/https = True/https = False/g' ./config.py

if [ ! -f "./logging.ini" ]; then
  cp logging.ini-sample logging.ini
fi

if [ ! -f "${LOGDIR}/${LOGFILE}" ]; then
   ln -sf /dev/stdout "${LOGDIR}/${LOGFILE}"
fi

if [ ! -f "${LOGDIR}/${LOGFILE_ERR}" ]; then
   ln -sf /dev/stderr "${LOGDIR}/${LOGFILE_ERR}"
fi

# update config.py with our settings (make sure to update these strings if you update config.py-sample
sed -i "s/mongouri = \"mongodb:\/\/localhost:27017\/\"/mongouri = \"${MONGO_URL_REGEX}\"/g" ./config.py
sed -i "s/mongohost = \"localhost\"/mongohost = \"mongodb\"/g"  ./config.py
sed -i "s/passwordsalt = \'d2o0n1g2s0h3e1n1g\'/passwordsalt = \'${AIRNOTIFIER_PASSWORDSALT}\'/g" ./config.py
sed -i "s/cookiesecret = \'airnotifiercookiesecret\'/cookiesecret = \'${AIRNOTIFIER_COOKIESECRETS}\'/g"  ./config.py

# provide configuration settings to user
echo "MONGO_SERVER: ${MONGO_SERVER}"
echo "MONGO_PORT: ${MONGO_PORT}"
echo "AIRNOTIFIER_PASSWORDSALT: ${AIRNOTIFIER_PASSWORDSALT}"
echo "AIRNOTIFIER_COOKIESECRETS: ${AIRNOTIFIER_COOKIESECRETS}"
echo "MONGO_USER: ${MONGO_USER}"
echo "MONGO_PASS: ${MONGO_PASS}"
echo "MONGO_PROTOCOL: ${MONGO_PROTOCOL}"
echo "MONGO_DATABASE: ${MONGO_DATABASE}"
echo "MONGO_OPTIONS: ${MONGO_OPTIONS}"
echo "MONGO_URL: ${MONGO_URL}"
echo "MONGO_URL_REGEX: ${MONGO_URL_REGEX}"
echo "MONGO_URL_FROM_CONFIGPY=$(grep mongouri config.py|grep -vE '[[:space:]]?#[[:space:]]?mongouri')"

echo "Installing AirNotifier ..."
pipenv run ./install.py

echo "Starting AirNotifier ..."
__starttimestamp=`date +%s.%N`
pipenv run ./app.py 
__runtime=$( echo "${__endtimestamp} - ${__starttimestamp}" | bc -l )
echo ${__runtime}
