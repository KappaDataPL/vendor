#!/bin/bash
#
# URL-e DNS Blocklist do pobrania
DNSBL_URLS=(
    "https://hole.cert.pl/domains/v2/domains.txt"
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"  # URL z PiHole
    # Dodaj więcej URL-i według potrzeby
)

# Ścieżki plików
DNSBL_FILE="/root/small.dnsbl"
ZONE_TEMPLATE="/opt/phion/modules/box/boxsrv/bdns/rpz.custom.zone.template"
TIMESTAMP_FILE="/tmp/dnsbl-zone.timestamp"
TMP_FILE="/tmp/dnsbl-zone.tmp"
CUSTOM_ZONE="/var/phion/run/bdns/rpz.custom.zone"

# Funkcja pobierania i scalań list z zewnętrznych URL
fetch_dnsbl() {
    echo "Pobieranie i scalań DNS Blocklist z URL-i..."
    >"${DNSBL_FILE}"  # Czyść plik przed nowym pobraniem
    for url in "${DNSBL_URLS[@]}"; do
        echo "Pobieranie z ${url}..."
        content=$(curl -s "${url}")
        if [[ $? -ne 0 || -z "$content" ]]; then
            echo "Błąd podczas pobierania listy z ${url}. Sprawdź URL lub połączenie internetowe."
            exit 1
        fi

        # Jeśli URL to plik hosts, listujemy tylko domeny
        if [[ "${url}" == *"StevenBlack/hosts"* ]]; then
            echo "$content" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}' >>"${DNSBL_FILE}"
        else
            echo "$content" >>"${DNSBL_FILE}"
        fi
        echo "" >>"${DNSBL_FILE}"  # Dodaj nową linię po każdej liście
    done

    if [[ ! -s "${DNSBL_FILE}" ]]; then
        echo "Błąd: Plik DNS Blocklist jest pusty po pobraniu."
        exit 1
    fi
    echo "Listy DNS Blocklist zostały pomyślnie pobrane i scalone."
}

# Funkcja sprawdzania zmiany pliku
check_file_changed() {
    if [[ ! -f ${TIMESTAMP_FILE} ]]; then
        touch ${TIMESTAMP_FILE}
    fi
    local prev_hash=$(cat ${TIMESTAMP_FILE} 2>/dev/null || echo "")
    local current_hash=$(sha256sum "${DNSBL_FILE}" | awk '{print $1}')
    if [[ "${current_hash}" != "${prev_hash}" ]]; then
        echo "${current_hash}" >"${TIMESTAMP_FILE}"
        return 0
    else
        return 1
    fi
}

# Pobranie i scalanie list z internetu
fetch_dnsbl

# Jeśli lista się zmieniła, aktualizuj DNS
if check_file_changed; then
    echo "Lista DNS Blocklist uległa zmianie. Aktualizacja DNS..."

    # Generowanie SOA record z aktualnym czasem
    _UNIXSECS=$(date +%s)
    sed -e "s/<serial>/${_UNIXSECS}/" ${ZONE_TEMPLATE} >${TMP_FILE}
    echo >>${TMP_FILE}

    # Konwersja domen do formatu BIND
    while IFS= read -r line; do
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue # Ignorowanie pustych linii i komentarzy
        echo "${line} CNAME ."
    done <"${DNSBL_FILE}" >>"${TMP_FILE}"

    # Podmiana pliku strefy
    chattr -i ${CUSTOM_ZONE}
    mv ${TMP_FILE} ${CUSTOM_ZONE}
    chattr +i ${CUSTOM_ZONE}

    # Przeładowanie serwera DNS
    echo "Przeładowywanie konfiguracji DNS..."
    /sbin/rndc reload
    echo "Aktualizacja DNS zakończona sukcesem."
else
    echo "Lista DNS Blocklist nie zmieniła się. Brak potrzeby aktualizacji."
fi