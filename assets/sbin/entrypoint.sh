#!/bin/bash
set -e

# Copy custom configuration files
cp $SPLUNK_USER_ETC/system/local/inputs.conf $SPLUNK_HOME/etc/system/local/inputs.conf

chown -R $SYSTEM_USER:$SYSTEM_USER $SPLUNK_HOME
gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk start --answer-yes --no-prompt --accept-license
trap "gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk stop" SIGINT SIGTERM EXIT

if [ ! -f $SPLUNK_HOME/etc/.ui_login ]; then

    # Change password
    gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk edit user admin \
        -auth admin:changeme \
        -password $SPLUNK_PASSWORD

    if [ -n "$SPLUNK_ENABLE_LISTEN" ]; then
        gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk \
            enable listen $SPLUNK_ENABLE_LISTEN -auth admin:$SPLUNK_PASSWORD $SPLUNK_ENABLE_LISTEN_ARGS
    fi

    if [ -n "$SPLUNK_FORWARD_SERVER" ]; then
        gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk \
            add forward-server $SPLUNK_FORWARD_SERVER -auth admin:$SPLUNK_PASSWORD $SPLUNK_FORWARD_SERVER_ARGS
    fi
    for n in {1..10}; do
        if [[ -n $(eval echo \$\{SPLUNK_FORWARD_SERVER_${n}\}) ]]; then
            gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk \
                add forward-server $(eval echo \$\{SPLUNK_FORWARD_SERVER_${n}\}) -auth admin:$SPLUNK_PASSWORD $(eval echo \$\{SPLUNK_FORWARD_SERVER_${n}_ARGS\})
        else
            break
        fi
    done

    if [ -n "$SPLUNK_ADD" ]; then
        gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk \
            add $SPLUNK_ADD -auth admin:$SPLUNK_PASSWORD
    fi
    for n in {1..30}; do
        if [[ -n $(eval echo \$\{SPLUNK_ADD_${n}\}) ]]; then
            gosu $SYSTEM_USER $SPLUNK_HOME/bin/splunk \
                add $(eval echo \$\{SPLUNK_ADD_${n}\}) -auth admin:$SPLUNK_PASSWORD
        else
            break
        fi
    done

    echo -e "\n[license]\nactive_group = Free" >> /opt/splunk/etc/system/local/server.conf

    # Disable the "First time signing in?" message
    touch $SPLUNK_HOME/etc/.ui_login
fi

gosu $SYSTEM_USER tail -n 0 -f $SPLUNK_HOME/var/log/splunk/splunkd_stderr.log &
wait
