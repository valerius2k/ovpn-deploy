#! /bin/sh
#

torify=proxychains

# input file
if [ "$1" = "-" ]; then
    # stdin
    infile=&0
else
    # servers.txt
    infile=servers.txt
fi

execute() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    cmd=$*

    timeout 30 sshpass -p "$pass" "$torify" ssh -o StrictHostKeyChecking=no -p "$port" \
        "$user@$ip" "echo $cmd | /bin/sh -s -" 2>/dev/null
}

copyto() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$what" "$user@$ip:$where" 2>/dev/null
}

copyfrom() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift
    what=$1; shift
    where=$1;

    timeout 30 sshpass -p "$pass" "$torify" scp -o StrictHostKeyChecking=no -P "$port" \
        "$user@$ip:$what" "$where" 2>/dev/null
}

deploy() {
    ip=$1; shift
    user=$1; shift
    pass=$1; shift
    port=$1; shift

    domainweb=$1; shift
    portweb=$1; shift
    domainvpn=$1; shift
    portvpn=$1; shift

    ovpnip=$1; shift
    ovpnip6=$1; shift
    ovpnport=$1; shift
    ovpnproto=$1; shift
    ovpndns=$1; shift

    # Credentials for a VPS
    creds="$ip $user $pass $port"
    # Installer TCL script params (params for openvpn-install.sh)
    tclparms="$ovpnip $ovpnip6 $ovpnport $ovpnproto $ovpndns"

    # Copy openvpn-install.sh to server
    copyto $creds openvpn-install.sh "/root"
    # Copy ovpn-inst.tcl to server
    copyto $creds ovpn-inst.tcl "/root"
    # Copy letsencrypt.tcl to server
    copyto $creds letsencrypt.tcl "/root"

    # Install software
    cmd="apt install mc nano screen net-tools psmisc wget \
         curl expect nginx ssl-cert certbot -y"
    execute $creds $cmd

    # Start OpenVPN installer
    execute $creds "/usr/bin/expect -f ovpn-inst.tcl $tclparms"

    # Copy Nginx main config file
    copyto $creds files/nginx/nginx.conf /etc/nginx

    # Copy default Nginx config
    cp files/nginx/sites-available/default.tmpl /tmp/default
    sed -i /tmp/default \
        -e "s/{{ port_web }}/$portweb/g" \
        -e "s/{{ domain_web }}/$domainweb/g"
    copyto $creds /tmp/default /etc/nginx/sites-available

    # Copy stream.conf
    cp files/nginx/stream.conf.tmpl /tmp/stream.conf
    sed -i /tmp/stream.conf \
        -e "s/{{ domain_web }}/$domainweb/g" \
        -e "s/{{ domain_vpn }}/$domainvpn/g" \
        -e "s/{{ port_web }}/$portweb/g" \
        -e "s/{{ port_vpn }}/$portvpn/g"
    copyto $creds /tmp/stream.conf /etc/nginx

    # Start make-ssl-cert
    execute $creds "make-ssl-cert generate-default-snakeoil"

    # Remove /etc/letsencrypt directory (if exists)
    execute $creds "rm -rf /etc/letsencrypt"

    # Create a Let's Encrypt cert
    execute $creds "/usr/bin/expect -f letsencrypt.tcl $domainweb $domainvpn"

    # change certs snakeoil to Let's Encrypt
    execute $creds "mv /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem~; \
        mv /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key~; \
        ln -sf /etc/letsencrypt/live/$domainweb/fullchain.pem /etc/ssl/certs/ssl-cert-snakeoil.pem; \
        ln -sf /etc/letsencrypt/live/$domainweb/privkey.pem /etc/ssl/private/ssl-cert-snakeoil.key"

    # Restart Nginx
    execute $creds "systemctl restart nginx"

    # Restart OpenVPN
    execute $creds "systemctl restart openvpn"
}

cat $infile | grep -v '^#' | grep -v '^$' | sed -e "s/\s+#.*$//" | \
\
while read line; do
    deploy $line
done | tee log.txt
