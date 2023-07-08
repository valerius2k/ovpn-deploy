#! /usr/bin/expect
#

#exp_internal 1 

if { $argc != 2 } {
    puts "This script requires two parameters:"
    puts "<domain_web> <domain_vpn>"
    exit 1
}

set domain_web [lindex $argv 0]
set domain_vpn [lindex $argv 1]

spawn /usr/bin/certbot certonly --manual --preferred-challenges=http --email admin@$domain_web --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d "$domain_web" -d "$domain_vpn"

while (1) {
    expect {
        "Select the appropriate number" { send "c\n" }
        "(Y)es/(N)o:" { send "y\n" }
        -re {Create a file containing just this data:\r\n\r\n([A-Za-z0-9\-_\.]+)\r\n} {
                set data "$expect_out(1,string)"
        }
        -re {http://(.*)/\.well-known/acme-challenge/([A-Za-z0-9\-_\.]+)\r\n} {
            set filename "$expect_out(2,string)"
        }
        "Press Enter to Continue" {
            exec mkdir -p /var/www/html/.well-known/acme-challenge
            exec echo "$data" >/var/www/html/.well-known/acme-challenge/$filename
            send "\n"
        }
        eof { break }
    }
}

exit 0
