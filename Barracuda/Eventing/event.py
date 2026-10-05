#!/usr/bin/python3
# vim:expandtab ts=4

import os
import re
import json
import urllib.request
import urllib.error
import ssl
import socket
import struct
from datetime import datetime

# === KONFIGURACJA ===
CONFIG_FILE = os.environ.get("BARRACUDA_CONFIG", "/etc/barracuda-event-forwarder.json")
try:
    with open(CONFIG_FILE, "r") as config_file:
        CONFIG = json.load(config_file)
except (IOError, ValueError) as error:
    raise SystemExit("Nie można wczytać konfiguracji %s: %s" % (CONFIG_FILE, error))

if not isinstance(CONFIG, dict):
    raise SystemExit("Konfiguracja %s musi być obiektem JSON." % CONFIG_FILE)

REQUIRED_CONFIG = (
    "object_name",
    "exclude_object_name",
    "api_token",
    "api_auth_header",
    "api_scheme",
    "api_host",
)
MISSING_CONFIG = [name for name in REQUIRED_CONFIG if not CONFIG.get(name)]
if MISSING_CONFIG:
    raise SystemExit("Brak wymaganych ustawień w %s: %s" % (CONFIG_FILE, ", ".join(MISSING_CONFIG)))

DEBUG = CONFIG.get("debug", False)
BARRACUDA_OBJECT_NAME = CONFIG["object_name"]
BARRACUDA_EXCLUDE_OBJECT_NAME = CONFIG["exclude_object_name"]
BARRACUDA_API_TOKEN = CONFIG["api_token"]
BARRACUDA_API_AUTH_HEADER = CONFIG["api_auth_header"]
BARRACUDA_API_SCHEME = CONFIG["api_scheme"]
BARRACUDA_API_HOST = CONFIG["api_host"]
LOGFILE = CONFIG.get("logfile", "/var/tmp/barracuda_event_forward.log")

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        line = "[%s] %s\n" % (timestamp, message)
        with open(LOGFILE, "a") as f:
            f.write(line)
    except Exception as e:
        try:
            with open("/tmp/fallback_barracuda.log", "a") as f:
                f.write("[%s] BŁĄD LOGOWANIA: %s\n" % (timestamp, str(e)))
                f.write("[%s] ORYGINALNA TREŚĆ: %r\n" % (timestamp, message))
        except:
            pass

def debug_log(msg):
    if DEBUG:
        log_message("[DEBUG] %s" % msg)

def extract_ip():
    event_data = os.environ.get("EVENT_DATA", "")
    ip_match = re.search(r"\((\d{1,3}(?:\.\d{1,3}){3})\)", event_data)
    ip = ip_match.group(1) if ip_match else None
    return ip

def ip_in_network(ip, cidr):
    try:
        ipaddr = struct.unpack('>I', socket.inet_aton(ip))[0]
        netaddr, bits = cidr.split('/')
        netaddr = struct.unpack('>I', socket.inet_aton(netaddr))[0]
        mask = (0xFFFFFFFF << (32 - int(bits))) & 0xFFFFFFFF
        return (ipaddr & mask) == (netaddr & mask)
    except Exception:
        return False

def fetch_object_entries(object_name):
    url = "%s://%s/rest/config/v1/forwarding-firewall/objects/networks/%s?lock=true&envelope=false" % (
        BARRACUDA_API_SCHEME, BARRACUDA_API_HOST, object_name)

    headers = {
        "accept": "application/json",
        "X-API-Token": BARRACUDA_API_TOKEN,
        "Authorization": BARRACUDA_API_AUTH_HEADER
    }

    request = urllib.request.Request(url)
    for key, value in headers.items():
        request.add_header(key, value)

    try:
        if BARRACUDA_API_SCHEME == "https":
            try:
                context = ssl._create_unverified_context()
                response = urllib.request.urlopen(request, context=context)
            except AttributeError:
                import warnings
                warnings.filterwarnings("ignore")
                response = urllib.request.urlopen(request)
        else:
            response = urllib.request.urlopen(request)

        data = json.loads(response.read())
        return data.get("included", [])
    except Exception as e:
        log_message("Błąd podczas pobierania obiektu %s: %s" % (object_name, str(e)))
        return []

def ip_is_in_excluded_object(ip):
    entries = fetch_object_entries(BARRACUDA_EXCLUDE_OBJECT_NAME)
    debug_log("Pobrano %d wpisów z obiektu %s" % (len(entries), BARRACUDA_EXCLUDE_OBJECT_NAME))

    for entry in entries:
        try:
            debug_log("Sprawdzany pełny wpis z whitelisty: %s" % json.dumps(entry))
            net_str = entry.get("entry", {}).get("ip")

            if net_str:
                debug_log(" -> wyciagniety IP/zakres: %s" % net_str)

                if '/' not in net_str:
                    if ip == net_str:
                        log_message("Adres IP %s znajduje się bezpośrednio w obiekcie %s - pomijam (whitelist)." %
                                    (ip, BARRACUDA_EXCLUDE_OBJECT_NAME))
                        return True
                elif ip_in_network(ip, net_str):
                    log_message("Adres IP %s pasuje do zakresu %s w obiekcie %s - pomijam (whitelist)." %
                                (ip, net_str, BARRACUDA_EXCLUDE_OBJECT_NAME))
                    return True
        except Exception as e:
            log_message("Błąd przy sprawdzaniu wpisu z whitelisty (net_str=%s): %s" % (net_str, str(e)))

    debug_log("Adres IP %s nie pasuje do żadnego wpisu w %s" % (ip, BARRACUDA_EXCLUDE_OBJECT_NAME))
    return False

def ip_already_exists(ip):
    entries = fetch_object_entries(BARRACUDA_OBJECT_NAME)

    for entry in entries:
        if entry.get("entry", {}).get("ip") == ip:
            log_message("Adres IP %s już istnieje w obiekcie %s - pomijam." %
                        (ip, BARRACUDA_OBJECT_NAME))
            return True
    return False

def send_to_firewall(ip, comment):
    url = "%s://%s/rest/config/v1/forwarding-firewall/objects/networks/%s/included?emergencyOverride=true&envelope=false" % (
        BARRACUDA_API_SCHEME, BARRACUDA_API_HOST, BARRACUDA_OBJECT_NAME)

    headers = {
        "accept": "*/*",
        "X-API-Token": BARRACUDA_API_TOKEN,
        "Authorization": BARRACUDA_API_AUTH_HEADER,
        "Content-Type": "application/json"
    }

    payload = {
        "entry": {
            "ip": ip,
            "comment": comment
        }
    }

    debug_log("Zbudowany URL: %s" % url)
    debug_log("Payload JSON: %s" % json.dumps(payload))

    request = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"))
    for key, value in headers.items():
        request.add_header(key, value)

    try:
        if BARRACUDA_API_SCHEME == "https":
            try:
                context = ssl._create_unverified_context()
                response = urllib.request.urlopen(request, context=context)
            except AttributeError:
                import warnings
                warnings.filterwarnings("ignore")
                response = urllib.request.urlopen(request)
        else:
            response = urllib.request.urlopen(request)

        resp_body = response.read()
        log_message("Wysłano IP: %s z komentarzem: \"%s\" do obiektu: %s, odpowiedź: %s" %
                    (ip, comment, BARRACUDA_OBJECT_NAME, resp_body))
    except urllib.error.HTTPError as e:
        log_message("Błąd HTTP [%s] przy IP %s do obiektu %s: %s" %
                    (e.code, ip, BARRACUDA_OBJECT_NAME, e.read()))
    except urllib.error.URLError as e:
        log_message("Błąd URL przy IP %s do obiektu %s: %s" %
                    (ip, BARRACUDA_OBJECT_NAME, e.reason))
    except Exception as e:
        log_message("Nieoczekiwany wyjątek: %s" % str(e))

if __name__ == "__main__":
    debug_log("=== Start skryptu ===")
    debug_log("BARRACUDA_API_SCHEME = %s" % BARRACUDA_API_SCHEME)
    debug_log("BARRACUDA_API_HOST = %s" % BARRACUDA_API_HOST)
    debug_log("BARRACUDA_OBJECT_NAME = %s" % BARRACUDA_OBJECT_NAME)
    debug_log("BARRACUDA_EXCLUDE_OBJECT_NAME = %s" % BARRACUDA_EXCLUDE_OBJECT_NAME)

    event_data = os.environ.get("EVENT_DATA", "")
    event_type_id = os.environ.get("EVENT_TYPE_ID", "Unknown")
    event_type_name = os.environ.get("EVENT_TYPE_NAME", "Unknown")

    log_message("Nowe zdarzenie: EVENT_TYPE_ID=%s, EVENT_TYPE_NAME=\"%s\"" %
                (event_type_id, event_type_name))
    log_message("Treść EVENT_DATA: %s" % event_data)

    ip = extract_ip()

    if ip:
        log_message("Wyciągnięto IP: %s" % ip)
        debug_log("-> Sprawdzam czy IP %s znajduje się w %s" % (ip, BARRACUDA_EXCLUDE_OBJECT_NAME))

        if ip_is_in_excluded_object(ip):
            pass
        elif ip_already_exists(ip):
            pass
        else:
            send_to_firewall(ip, event_type_name)
    else:
        log_message("Brak IP w EVENT_DATA. Pomijam zdarzenie.")
